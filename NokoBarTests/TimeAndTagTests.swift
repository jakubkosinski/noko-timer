import XCTest
@testable import NokoBar

final class TimeAndTagTests: XCTestCase {
    func testTimeFormat() {
        XCTAssertEqual(TimeFormat.hm(0), "00:00")
        XCTAssertEqual(TimeFormat.hm(3660), "01:01")
        XCTAssertEqual(TimeFormat.hm(100 * 3600), "100:00")
        XCTAssertEqual(TimeFormat.hms(3661), "01:01:01")
        XCTAssertEqual(TimeFormat.hm(-5), "00:00")
    }

    func testTagPartial() {
        XCTAssertEqual(TagToken.partial(in: "work #me"), "me")
        XCTAssertEqual(TagToken.partial(in: "#"), "")
        XCTAssertNil(TagToken.partial(in: "work #me done"))
        XCTAssertNil(TagToken.partial(in: "no tag"))
        XCTAssertNil(TagToken.partial(in: "a#b"))
    }

    func testTagComplete() {
        XCTAssertEqual(TagToken.complete("work #me", with: "meeting"), "work #meeting ")
        XCTAssertEqual(TagToken.complete("plain", with: "x"), "plain")
    }

    func testSuggestions() {
        let tags = [NokoTag(id: 1, name: "meeting", formattedName: "#meeting", billable: true),
                    NokoTag(id: 2, name: "mail", formattedName: "#mail", billable: true),
                    NokoTag(id: 3, name: "dev", formattedName: "#dev", billable: true)]
        XCTAssertEqual(TagToken.suggestions(for: "x #m", tags: tags).map(\.name), ["meeting", "mail"])
        XCTAssertTrue(TagToken.suggestions(for: "x #meeting", tags: tags).isEmpty)
    }
}
