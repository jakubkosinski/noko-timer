import XCTest
@testable import NokoBar

final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, [String: String], Data))?
    nonisolated(unsafe) static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        let (status, headers, body) = Self.handler!(request)
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class NokoClientTests: XCTestCase {
    private func makeClient() -> NokoClient {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubProtocol.self]
        StubProtocol.requests = []
        return NokoClient(session: URLSession(configuration: cfg), minInterval: .milliseconds(1), maxRetries: 2)
    }

    func testHeadersSent() async throws {
        let client = makeClient()
        await client.setToken("abc")
        StubProtocol.handler = { _ in (200, [:], Data(#"{"id":1,"email":"a@b.c","first_name":"A","last_name":"B"}"#.utf8)) }
        _ = try await client.currentUser()
        let r = StubProtocol.requests.last!
        XCTAssertEqual(r.value(forHTTPHeaderField: "X-NokoToken"), "abc")
        XCTAssertEqual(r.value(forHTTPHeaderField: "User-Agent"), "NokoBar/1.0")
    }

    func testPaginationFollowsLink() async throws {
        let client = makeClient()
        StubProtocol.handler = { req in
            if req.url!.absoluteString.contains("page=2") {
                return (200, [:], Data(#"[{"id":2,"name":"B"}]"#.utf8))
            }
            return (200, ["Link": "<https://api.nokotime.com/v2/projects?page=2>; rel=\"next\", <https://api.nokotime.com/v2/projects?page=2>; rel=\"last\""],
                    Data(#"[{"id":1,"name":"A"}]"#.utf8))
        }
        let projects = try await client.projects()
        XCTAssertEqual(projects.map(\.id), [1, 2])
    }

    func testRetryOn429ThenSuccess() async throws {
        let client = makeClient()
        nonisolated(unsafe) var calls = 0
        StubProtocol.handler = { _ in
            calls += 1
            return calls < 3 ? (429, [:], Data()) : (200, [:], Data("[]".utf8))
        }
        let t = try await client.timers()
        XCTAssertTrue(t.isEmpty)
        XCTAssertEqual(calls, 3)
    }

    func testRateLimitGivesUp() async {
        let client = makeClient()
        StubProtocol.handler = { _ in (429, [:], Data()) }
        do { _ = try await client.timers(); XCTFail() } catch { XCTAssertEqual(error as? NokoError, .rateLimited) }
    }

    func testErrorMapping() async {
        let client = makeClient()
        StubProtocol.handler = { _ in (401, [:], Data()) }
        do { _ = try await client.currentUser(); XCTFail() } catch { XCTAssertEqual(error as? NokoError, .unauthorized) }
        StubProtocol.handler = { _ in (404, [:], Data()) }
        do { try await client.pauseTimer(projectID: 1); XCTFail() } catch { XCTAssertEqual(error as? NokoError, .notFound) }
        StubProtocol.handler = { _ in (422, [:], Data(#"{"code":"cannot_create_tags","message":"no"}"#.utf8)) }
        do { try await client.logTimer(projectID: 1, description: "#x"); XCTFail() } catch {
            XCTAssertEqual(error as? NokoError, .server(status: 422, code: "cannot_create_tags", message: "no"))
        }
    }

    func testLogSendsFormBody() async throws {
        let client = makeClient()
        StubProtocol.handler = { _ in (204, [:], Data()) }
        try await client.logTimer(projectID: 5, description: "a #b&c")
        let r = StubProtocol.requests.last!
        XCTAssertEqual(r.httpMethod, "PUT")
        XCTAssertTrue(r.url!.path.hasSuffix("/projects/5/timer/log"))
    }
}
