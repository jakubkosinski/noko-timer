import Foundation

enum ReportPeriod: String, CaseIterable, Identifiable {
    case day, week, month, mtd
    var id: String { rawValue }
    var titleKey: String { "report.period.\(rawValue)" }

    /// Rolling periods, all ending today (inclusive).
    func range(today: Date, calendar: Calendar) -> ClosedRange<Date> {
        let end = calendar.startOfDay(for: today)
        let start: Date
        switch self {
        case .day: start = end
        case .week: start = calendar.date(byAdding: .day, value: -6, to: end)!
        case .month: start = calendar.date(byAdding: .day, value: -29, to: end)!
        case .mtd: start = calendar.date(from: calendar.dateComponents([.year, .month], from: end))!
        }
        return start...end
    }

    /// One range that covers every period, so a single fetch serves all of them.
    static func fetchRange(today: Date, calendar: Calendar) -> ClosedRange<Date> {
        let ranges = allCases.map { $0.range(today: today, calendar: calendar) }
        return ranges.map(\.lowerBound).min()!...ranges.map(\.upperBound).max()!
    }
}

enum ReportDate {
    private static func formatter(_ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
    static func string(from date: Date, calendar: Calendar) -> String { formatter(calendar).string(from: date) }
    static func date(from string: String, calendar: Calendar) -> Date? { formatter(calendar).date(from: string) }
}

struct ReportBar: Identifiable, Equatable {
    let id: String
    let label: String      // short x-axis category
    let title: String      // tooltip header
    let minutes: Int
    var hours: Double { Double(minutes) / 60 }
}

enum ReportBuilder {
    private static func entries(_ entries: [NokoEntry], in range: ClosedRange<Date>, calendar: Calendar) -> [NokoEntry] {
        entries.filter {
            guard let d = ReportDate.date(from: $0.date, calendar: calendar) else { return false }
            return range.contains(d)
        }
    }

    /// Each entry counted once.
    static func totalMinutes(_ all: [NokoEntry], period: ReportPeriod, today: Date, calendar: Calendar) -> Int {
        entries(all, in: period.range(today: today, calendar: calendar), calendar: calendar).reduce(0) { $0 + $1.minutes }
    }

    static func bars(_ all: [NokoEntry], period: ReportPeriod, today: Date, calendar: Calendar,
                     untaggedLabel: String = String(localized: "report.untagged"),
                     locale: Locale = .current) -> [ReportBar] {
        let range = period.range(today: today, calendar: calendar)
        let inRange = entries(all, in: range, calendar: calendar)

        if period == .day {
            // One bar per tag; an entry with several tags counts in each of them.
            var byTag: [String: Int] = [:]
            for e in inRange {
                let names = (e.tags ?? []).map(\.name)
                if names.isEmpty { byTag[untaggedLabel, default: 0] += e.minutes }
                else { for n in names { byTag[n, default: 0] += e.minutes } }
            }
            return byTag.map { ReportBar(id: "tag-\($0.key)", label: $0.key,
                                          title: $0.key == untaggedLabel ? untaggedLabel : "#\($0.key)", minutes: $0.value) }
                .sorted { ($0.minutes, $1.label) > ($1.minutes, $0.label) }
        }

        // One zero-filled bar per day.
        var perDay: [String: Int] = [:]
        for e in inRange { perDay[e.date, default: 0] += e.minutes }
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate(period == .week ? "EEE d" : "d MMM")
        let full = DateFormatter()
        full.calendar = calendar
        full.timeZone = calendar.timeZone
        full.locale = locale
        full.setLocalizedDateFormatFromTemplate("EEEE d MMMM")

        var result: [ReportBar] = []
        var day = range.lowerBound
        while day <= range.upperBound {
            let key = ReportDate.string(from: day, calendar: calendar)
            result.append(ReportBar(id: key, label: f.string(from: day),
                                    title: full.string(from: day), minutes: perDay[key] ?? 0))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }
}
