import XCTest
@testable import NokoBar

final class ReportTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        return c
    }()

    private func d(_ s: String) -> Date { ReportDate.date(from: s, calendar: cal)! }
    private func e(_ id: Int, _ date: String, _ min: Int, _ tags: [String]? = nil, project: (Int, String, String?)? = nil) -> NokoEntry {
        NokoEntry(id: id, date: date, minutes: min, description: nil,
                  tags: tags?.enumerated().map { EntryTag(id: $0.offset, name: $0.element) },
                  project: project.map { EntryProject(id: $0.0, name: $0.1, color: $0.2) })
    }
    private let today = "2026-11-17"
    private func range(_ p: ReportPeriod, offset: Int = 0, today t: String = "2026-11-17") -> ClosedRange<Date> {
        p.range(today: d(t), calendar: cal, offset: offset)
    }
    private func r(_ a: String, _ b: String) -> ClosedRange<Date> { d(a)...d(b) }

    // MARK: Ranges

    func testRanges() {
        XCTAssertEqual(range(.day), r("2026-11-17", "2026-11-17"))
        XCTAssertEqual(range(.week), r("2026-11-11", "2026-11-17"))
        XCTAssertEqual(range(.month), r("2026-10-19", "2026-11-17"))
        XCTAssertEqual(range(.mtd), r("2026-11-01", "2026-11-17"))
    }

    func testMTDOnFirstOfMonthAndYearTurn() {
        XCTAssertEqual(range(.mtd, today: "2026-12-01"), r("2026-12-01", "2026-12-01"))
        XCTAssertEqual(range(.month, today: "2027-01-10").lowerBound, d("2026-12-12"))
        XCTAssertEqual(range(.mtd, today: "2027-01-10"), r("2027-01-01", "2027-01-10"))
    }

    func testOffsets() {
        XCTAssertEqual(range(.day, offset: -1), r("2026-11-16", "2026-11-16"))
        XCTAssertEqual(range(.week, offset: -1), r("2026-11-04", "2026-11-10"))
        XCTAssertEqual(range(.month, offset: -1), r("2026-09-19", "2026-10-18"))
        XCTAssertEqual(range(.mtd, offset: -1), r("2026-10-01", "2026-10-31"))
        XCTAssertEqual(range(.mtd, offset: -2), r("2026-09-01", "2026-09-30"))
        XCTAssertEqual(range(.mtd, offset: -1, today: "2027-01-10"), r("2026-12-01", "2026-12-31"))
        XCTAssertEqual(range(.mtd, offset: -1, today: "2026-03-31"), r("2026-02-01", "2026-02-28"))
    }

    func testRangeTitles() {
        let pl = Locale(identifier: "pl_PL")
        let mtdPrev = ReportPeriod.mtd.title(for: range(.mtd, offset: -1), offset: -1, calendar: cal, locale: pl)
        XCTAssertTrue(mtdPrev.lowercased().contains("październik"), mtdPrev)
        let day = ReportPeriod.day.title(for: range(.day), offset: 0, calendar: cal, locale: pl)
        XCTAssertTrue(day.contains("listopada"), day)
        XCTAssertFalse(ReportPeriod.week.title(for: range(.week), offset: 0, calendar: cal, locale: pl).isEmpty)
    }

    // MARK: Project scope

    func testWeekBarsZeroFilled() {
        let entries = [e(1, "2026-11-17", 60), e(2, "2026-11-15", 30), e(3, "2026-11-10", 100)]
        let rg = range(.week)
        let bars = ReportBuilder.bars(entries, period: .week, range: rg, scope: .project(1), calendar: cal)
        XCTAssertEqual(bars.count, 7)
        XCTAssertEqual(bars.last?.minutes, 60)
        XCTAssertEqual(bars[4].minutes, 30)
        XCTAssertEqual(bars.map(\.minutes).reduce(0, +), 90)
        XCTAssertEqual(ReportBuilder.totalMinutes(entries, range: rg, calendar: cal), 90)
    }

    func testPreviousWeekShowsOlderEntries() {
        let entries = [e(1, "2026-11-17", 60), e(3, "2026-11-10", 100)]
        let rg = range(.week, offset: -1)
        XCTAssertEqual(ReportBuilder.totalMinutes(entries, range: rg, calendar: cal), 100)
        XCTAssertEqual(ReportBuilder.bars(entries, period: .week, range: rg, scope: .project(1), calendar: cal).last?.minutes, 100)
    }

    func testMonthAndMTDBarCounts() {
        XCTAssertEqual(ReportBuilder.bars([], period: .month, range: range(.month), scope: .all, calendar: cal).count, 30)
        XCTAssertEqual(ReportBuilder.bars([], period: .mtd, range: range(.mtd), scope: .all, calendar: cal).count, 17)
        XCTAssertEqual(ReportBuilder.bars([], period: .mtd, range: range(.mtd, offset: -1), scope: .all, calendar: cal).count, 31)
    }

    func testDayBarsSplitByTag() {
        let entries = [e(1, today, 60, ["a", "b"]), e(2, today, 30, ["a"]),
                       e(3, today, 20), e(4, "2026-11-16", 999, ["a"])]
        let rg = range(.day)
        let bars = ReportBuilder.bars(entries, period: .day, range: rg, scope: .project(1), calendar: cal, untaggedLabel: "untagged")
        XCTAssertEqual(bars.map(\.label), ["a", "b", "untagged"])
        XCTAssertEqual(bars.map(\.minutes), [90, 60, 20])
        XCTAssertEqual(ReportBuilder.totalMinutes(entries, range: rg, calendar: cal), 110)
    }

    func testBarTitles() {
        let entries = [e(1, today, 60, ["a"]), e(2, today, 20)]
        let week = ReportBuilder.bars(entries, period: .week, range: range(.week), scope: .project(1), calendar: cal,
                                      locale: Locale(identifier: "pl_PL"))
        XCTAssertTrue(week.last!.title.contains("listopada"))
        XCTAssertNotEqual(week.last!.title, week.last!.label)
        let day = ReportBuilder.bars(entries, period: .day, range: range(.day), scope: .project(1), calendar: cal, untaggedLabel: "untagged")
        XCTAssertEqual(day.map(\.title), ["#a", "untagged"])
    }

    // MARK: All-projects scope

    private var multi: [NokoEntry] {
        [e(1, today, 60, project: (1, "Alpha", "#ff0000")),
         e(2, today, 30, project: (2, "Beta", "#00ff00")),
         e(3, today, 15, project: (1, "Alpha", "#ff0000")),
         e(4, "2026-11-16", 45, project: (2, "Beta", "#00ff00")),
         e(5, today, 10)]   // no project
    }

    func testAllScopeStackedByProject() {
        let bars = ReportBuilder.bars(multi, period: .week, range: range(.week), scope: .all, calendar: cal, noProjectLabel: "No project")
        let todayBar = bars.last!
        XCTAssertEqual(todayBar.segments.map(\.name), ["Alpha", "Beta", "No project"])
        XCTAssertEqual(todayBar.segments.map(\.minutes), [75, 30, 10])
        XCTAssertEqual(todayBar.minutes, 115)
        XCTAssertEqual(bars[5].minutes, 45)
        XCTAssertEqual(bars[5].segments.map(\.name), ["Beta"])
    }

    func testAllScopeDayOneBarPerProject() {
        let bars = ReportBuilder.bars(multi, period: .day, range: range(.day), scope: .all, calendar: cal, noProjectLabel: "No project")
        XCTAssertEqual(bars.map(\.label), ["Alpha", "Beta", "No project"])
        XCTAssertEqual(bars.map(\.minutes), [75, 30, 10])
        XCTAssertEqual(bars.first?.segments.first?.color, "#ff0000")
    }

    func testProjectTotalsSumToTotal() {
        let rg = range(.week)
        let totals = ReportBuilder.projectTotals(multi, range: rg, calendar: cal, noProjectLabel: "No project")
        XCTAssertEqual(totals.map(\.name), ["Alpha", "Beta", "No project"])
        XCTAssertEqual(totals.map(\.minutes), [75, 75, 10])
        XCTAssertEqual(totals.reduce(0) { $0 + $1.minutes }, ReportBuilder.totalMinutes(multi, range: rg, calendar: cal))
    }
}
