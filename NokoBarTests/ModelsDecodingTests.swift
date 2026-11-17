import XCTest
@testable import NokoBar

final class ModelsDecodingTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d
    }()

    func testTimerDecoding() throws {
        let json = """
        [{"id":1,"state":"running","seconds":180,"formatted_time":"00:03:00","date":"2026-11-17",
          "description":"Work #noko","project":{"id":7,"name":"Gear","billing_increment":15,"enabled":true,"billable":true,"color":"#ff0000","url":"x"},
          "user":{"id":1},"url":"u","start_url":"s"}]
        """
        let t = try decoder.decode([NokoTimer].self, from: Data(json.utf8))
        XCTAssertEqual(t.first?.state, .running)
        XCTAssertEqual(t.first?.seconds, 180)
        XCTAssertEqual(t.first?.project.id, 7)
        XCTAssertTrue(t.first!.isActive)
    }

    func testUserAndProjectDecoding() throws {
        let u = try decoder.decode(NokoUser.self, from: Data("""
        {"id":1,"email":"a@b.c","first_name":"Ann","last_name":"Lee","profile_image_url":"http://x","role":"leader","state":"active"}
        """.utf8))
        XCTAssertEqual(u.fullName, "Ann Lee")
        let p = try decoder.decode(NokoProject.self, from: Data(##"{"id":2,"name":"P","billing_increment":15,"enabled":true,"color":"#00ff00"}"##.utf8))
        XCTAssertEqual(p.billingIncrement, 15)
    }
}
