import Foundation

/// Noko API v2 client. An actor so requests are serialised and throttled
/// (the API allows 2 requests/second per IP).
actor NokoClient {
    static let baseURL = URL(string: "https://api.nokotime.com/v2")!
    static let userAgent = "NokoBar/1.0"

    private let session: URLSession
    private let baseURL: URL
    private let minInterval: Duration
    private let maxRetries: Int
    private var token: String?
    private var lastRequest: ContinuousClock.Instant?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    init(session: URLSession = .shared,
         baseURL: URL = NokoClient.baseURL,
         minInterval: Duration = .milliseconds(500),
         maxRetries: Int = 3) {
        self.session = session
        self.baseURL = baseURL
        self.minInterval = minInterval
        self.maxRetries = maxRetries
    }

    func setToken(_ token: String?) { self.token = token }

    // MARK: Endpoints

    func currentUser() async throws -> NokoUser {
        try await get("current_user")
    }

    func projects() async throws -> [NokoProject] {
        try await getAll("projects", query: [.init(name: "enabled", value: "true")])
    }

    func tags() async throws -> [NokoTag] {
        try await getAll("tags")
    }

    func timers() async throws -> [NokoTimer] {
        try await getAll("timers")
    }

    func entries(projectID: Int, userID: Int, from: String, to: String) async throws -> [NokoEntry] {
        try await getAll("entries", query: [
            .init(name: "project_ids", value: String(projectID)),
            .init(name: "user_ids", value: String(userID)),
            .init(name: "from", value: from),
            .init(name: "to", value: to),
        ])
    }

    func startTimer(projectID: Int) async throws {
        _ = try await send("PUT", "projects/\(projectID)/timer/start")
    }

    func pauseTimer(projectID: Int) async throws {
        _ = try await send("PUT", "projects/\(projectID)/timer/pause")
    }

    func updateNotes(projectID: Int, description: String) async throws {
        _ = try await send("PUT", "projects/\(projectID)/timer", json: ["description": description])
    }

    func logTimer(projectID: Int, description: String) async throws {
        _ = try await send("PUT", "projects/\(projectID)/timer/log", json: ["description": description])
    }

    func discardTimer(projectID: Int) async throws {
        _ = try await send("DELETE", "projects/\(projectID)/timer")
    }

    // MARK: Plumbing

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        let (data, _) = try await send("GET", path, query: query)
        do { return try decoder.decode(T.self, from: data) } catch { throw NokoError.invalidResponse }
    }

    /// Follows `Link: <...>; rel="next"` headers.
    private func getAll<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> [T] {
        var items: [T] = []
        var q = query
        q.append(.init(name: "per_page", value: "1000"))
        var (data, response) = try await send("GET", path, query: q)
        while true {
            do { items += try decoder.decode([T].self, from: data) } catch { throw NokoError.invalidResponse }
            guard let next = Self.nextURL(from: response) else { break }
            (data, response) = try await perform(URLRequestBuilder.make(url: next, method: "GET", token: token, json: nil))
        }
        return items
    }

    static func nextURL(from response: HTTPURLResponse) -> URL? {
        guard let link = response.value(forHTTPHeaderField: "Link") else { return nil }
        for part in link.split(separator: ",") {
            let segs = part.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard segs.count >= 2, segs.dropFirst().contains(where: { $0 == "rel=\"next\"" }) else { continue }
            let raw = segs[0].trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            return URL(string: raw)
        }
        return nil
    }

    private func send(_ method: String, _ path: String,
                      query: [URLQueryItem] = [],
                      json: [String: String]? = nil) async throws -> (Data, HTTPURLResponse) {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        let request = URLRequestBuilder.make(url: comps.url!, method: method, token: token, json: json)
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        while true {
            try await throttle()
            let data: Data
            let http: HTTPURLResponse
            do {
                let (d, r) = try await session.data(for: request)
                guard let h = r as? HTTPURLResponse else { throw NokoError.invalidResponse }
                data = d; http = h
            } catch let e as NokoError {
                throw e
            } catch {
                throw NokoError.transport(error.localizedDescription)
            }

            switch http.statusCode {
            case 200..<300:
                return (data, http)
            case 401:
                throw NokoError.unauthorized
            case 404:
                throw NokoError.notFound
            case 429:
                attempt += 1
                if attempt > maxRetries { throw NokoError.rateLimited }
                try await Task.sleep(for: minInterval * (1 << attempt))
            default:
                let body = try? decoder.decode(APIErrorBody.self, from: data)
                throw NokoError.server(status: http.statusCode, code: body?.code, message: body?.message)
            }
        }
    }

    private func throttle() async throws {
        let now = ContinuousClock.now
        if let last = lastRequest {
            let elapsed = now - last
            if elapsed < minInterval { try await Task.sleep(for: minInterval - elapsed) }
        }
        lastRequest = ContinuousClock.now
    }
}

enum URLRequestBuilder {
    /// Noko API v2 expects JSON request bodies (form-encoded bodies get "JSON Parsing Error").
    static func make(url: URL, method: String, token: String?, json: [String: String]?) -> URLRequest {
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue(NokoClient.userAgent, forHTTPHeaderField: "User-Agent")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { r.setValue(token, forHTTPHeaderField: "X-NokoToken") }
        if let json {
            r.httpBody = try? JSONEncoder().encode(json)
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return r
    }
}
