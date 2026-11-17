import XCTest
@testable import NokoBar

final class ReportTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        return c
    }()

    private func d(_ s: String) -> Date { ReportDate.date(from: s, calendar: cal)! }
    private func e(_ id: Int, _ date: String, _ min: Int, _ tags: [String]? = nil) -> NokoEntry {
        NokoEntry(id: id, date: date, minutes: min, description: nil,
                  tags: tags?.enumerated().map { EntryTag(id: $0.offset, name: $0.element) })
    }

    func testRanges() {
        let today = d("2026-11-17")
        XCTAssertEqual(ReportPeriod.day.range(today: today, calendar: cal), d("2026-11-17")...d("2026-11-17"))
        XCTAssertEqual(ReportPeriod.week.range(today: today, calendar: cal).lowerBound, d("2026-11-11"))
        XCTAssertEqual(ReportPeriod.month.range(today: today, calendar: cal).lowerBound, d("2026-10-19"))
        XCTAssertEqual(ReportPeriod.mtd.range(today: today, calendar: cal).lowerBound, d("2026-11-01"))
    }

    func testMTDOnFirstOfMonthAndYearTurn() {
        XCTAssertEqual(ReportPeriod.mtd.range(today: d("2026-12-01"), calendar: cal), d("2026-12-01")...d("2026-12-01"))
        let jan = d("2027-01-10")
        XCTAssertEqual(ReportPeriod.month.range(today: jan, calendar: cal).lowerBound, d("2026-12-12"))
        XCTAssertEqual(ReportPeriod.mtd.range(today: jan, calendar: cal).lowerBound, d("2027-01-01"))
    }

    func testFetchRangeCoversAllPeriods() {
        let r = ReportPeriod.fetchRange(today: d("2026-11-17"), calendar: cal)
        XCTAssertEqual(r.lowerBound, d("2026-10-19"))
        XCTAssertEqual(r.upperBound, d("2026-11-17"))
        // Early in the month, MTD is shorter than month, so month start wins; late in a 31-day month MTD can't be longer than 30 days.
        let r2 = ReportPeriod.fetchRange(today: d("2026-12-31"), calendar: cal)
        XCTAssertEqual(r2.lowerBound, d("2026-12-01"))
    }

    func testWeekBarsZeroFilled() {
        let entries = [e(1, "2026-11-17", 60), e(2, "2026-11-15", 30), e(3, "2026-11-10", 100)]
        let bars = ReportBuilder.bars(entries, period: .week, today: d("2026-11-17"), calendar: cal)
        XCTAssertEqual(bars.count, 7)
        XCTAssertEqual(bars.last?.minutes, 60)
        XCTAssertEqual(bars[4].minutes, 30)
        XCTAssertEqual(bars.map(\.minutes).reduce(0, +), 90)
        XCTAssertEqual(ReportBuilder.totalMinutes(entries, period: .week, today: d("2026-11-17"), calendar: cal), 90)
    }

    func testMonthAndMTDBarCounts() {
        let today = d("2026-11-17")
        XCTAssertEqual(ReportBuilder.bars([], period: .month, today: today, calendar: cal).count, 30)
        XCTAssertEqual(ReportBuilder.bars([], period: .mtd, today: today, calendar: cal).count, 17)
    }

    func testDayBarsSplitByTag() {
        let entries = [e(1, "2026-11-17", 60, ["a", "b"]), e(2, "2026-11-17", 30, ["a"]),
                       e(3, "2026-11-17", 20), e(4, "2026-11-16", 999, ["a"])]
        let bars = ReportBuilder.bars(entries, period: .day, today: d("2026-11-17"), calendar: cal, untaggedLabel: "untagged")
        XCTAssertEqual(bars.map(\.label), ["a", "b", "untagged"])
        XCTAssertEqual(bars.map(\.minutes), [90, 60, 20])
        // Total counts each entry once.
        XCTAssertEqual(ReportBuilder.totalMinutes(entries, period: .day, today: d("2026-11-17"), calendar: cal), 110)
    }

    func testBarTitles() {
        let entries = [e(1, "2026-11-17", 60, ["a"]), e(2, "2026-11-17", 20)]
        let week = ReportBuilder.bars(entries, period: .week, today: d("2026-11-17"), calendar: cal,
                                      locale: Locale(identifier: "pl_PL"))
        XCTAssertTrue(week.last!.title.contains("listopada"))
        XCTAssertNotEqual(week.last!.title, week.last!.label)
        let day = ReportBuilder.bars(entries, period: .day, today: d("2026-11-17"), calendar: cal, untaggedLabel: "untagged")
        XCTAssertEqual(day.map(\.title), ["#a", "untagged"])
    }
}
