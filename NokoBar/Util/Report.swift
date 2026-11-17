import Foundation

/// What a report window covers.
enum ReportScope: Hashable, Codable {
    case project(Int)
    case all

    var projectID: Int? {
        if case .project(let id) = self { return id }
        return nil
    }
}

enum ReportPeriod: String, CaseIterable, Identifiable {
    case day, week, month, mtd
    var id: String { rawValue }
    var titleKey: String { "report.period.\(rawValue)" }

    /// Rolling periods ending today. `offset` (≤ 0) moves back by one period length per step:
    /// 1 day, 7 days, 30 days; MTD steps back by whole calendar months.
    func range(today: Date, calendar: Calendar, offset: Int = 0) -> ClosedRange<Date> {
        let t = calendar.startOfDay(for: today)
        func add(_ days: Int, _ base: Date) -> Date { calendar.date(byAdding: .day, value: days, to: base)! }
        switch self {
        case .day:
            let d = add(offset, t)
            return d...d
        case .week:
            let end = add(7 * offset, t)
            return add(-6, end)...end
        case .month:
            let end = add(30 * offset, t)
            return add(-29, end)...end
        case .mtd:
            let firstOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: t))!
            if offset == 0 { return firstOfThisMonth...t }
            let first = calendar.date(byAdding: .month, value: offset, to: firstOfThisMonth)!
            let last = add(-1, calendar.date(byAdding: .month, value: 1, to: first)!)
            return first...last
        }
    }

    /// Label for the navigation header.
    func title(for range: ClosedRange<Date>, offset: Int, calendar: Calendar, locale: Locale = .current) -> String {
        func template(_ t: String) -> String {
            let f = DateFormatter()
            f.calendar = calendar
            f.timeZone = calendar.timeZone
            f.locale = locale
            f.setLocalizedDateFormatFromTemplate(t)
            return f.string(from: range.lowerBound)
        }
        switch self {
        case .day:
            return template("EEEE d MMMM yyyy")
        case .mtd where offset < 0:
            return template("LLLL yyyy")
        default:
            let f = DateIntervalFormatter()
            f.calendar = calendar
            f.timeZone = calendar.timeZone
            f.locale = locale
            f.dateStyle = .medium
            f.timeStyle = .none
            return f.string(from: range.lowerBound, to: range.upperBound)
        }
    }
}

enum ReportDate {
    static func formatter(_ calendar: Calendar) -> DateFormatter {
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

/// One coloured part of a bar (a project in the all-projects report).
struct ReportSegment: Identifiable, Equatable {
    let id: String
    let name: String
    let color: String?
    let minutes: Int
    var hours: Double { Double(minutes) / 60 }
}

struct ReportBar: Identifiable, Equatable {
    let id: String
    let label: String      // short x-axis category
    let title: String      // tooltip header
    let segments: [ReportSegment]
    var minutes: Int { segments.reduce(0) { $0 + $1.minutes } }
    var hours: Double { Double(minutes) / 60 }
}

enum ReportBuilder {
    private static func entries(_ entries: [NokoEntry], in range: ClosedRange<Date>, calendar: Calendar) -> [NokoEntry] {
        let f = ReportDate.formatter(calendar)
        return entries.filter {
            guard let d = f.date(from: $0.date) else { return false }
            return range.contains(d)
        }
    }

    private static func projectKey(_ e: NokoEntry, noProject: String) -> (id: String, name: String, color: String?) {
        guard let p = e.project else { return ("proj-none", noProject, nil) }
        return ("proj-\(p.id)", p.name, p.color)
    }

    private static func sorted(_ segments: [ReportSegment]) -> [ReportSegment] {
        segments.sorted { ($0.minutes, $1.name) > ($1.minutes, $0.name) }
    }

    /// Each entry counted once.
    static func totalMinutes(_ all: [NokoEntry], range: ClosedRange<Date>, calendar: Calendar) -> Int {
        entries(all, in: range, calendar: calendar).reduce(0) { $0 + $1.minutes }
    }

    /// Per-project totals for the period (the list under the all-projects chart).
    static func projectTotals(_ all: [NokoEntry], range: ClosedRange<Date>, calendar: Calendar,
                              noProjectLabel: String = String(localized: "report.noProject")) -> [ReportSegment] {
        var acc: [String: ReportSegment] = [:]
        for e in entries(all, in: range, calendar: calendar) {
            let k = projectKey(e, noProject: noProjectLabel)
            acc[k.id] = ReportSegment(id: k.id, name: k.name, color: k.color, minutes: (acc[k.id]?.minutes ?? 0) + e.minutes)
        }
        return sorted(Array(acc.values))
    }

    static func bars(_ all: [NokoEntry], period: ReportPeriod, range: ClosedRange<Date>, scope: ReportScope,
                     calendar: Calendar,
                     untaggedLabel: String = String(localized: "report.untagged"),
                     noProjectLabel: String = String(localized: "report.noProject"),
                     locale: Locale = .current) -> [ReportBar] {
        let inRange = entries(all, in: range, calendar: calendar)

        if period == .day {
            if scope == .all {
                // One bar per project.
                return projectTotals(inRange, range: range, calendar: calendar, noProjectLabel: noProjectLabel).map {
                    ReportBar(id: $0.id, label: $0.name, title: $0.name, segments: [$0])
                }
            }
            // One bar per tag; an entry with several tags counts in each of them.
            var byTag: [String: Int] = [:]
            for e in inRange {
                let names = (e.tags ?? []).map(\.name)
                if names.isEmpty { byTag[untaggedLabel, default: 0] += e.minutes }
                else { for n in names { byTag[n, default: 0] += e.minutes } }
            }
            return byTag
                .map { name, minutes in
                    ReportBar(id: "tag-\(name)", label: name,
                              title: name == untaggedLabel ? untaggedLabel : "#\(name)",
                              segments: [ReportSegment(id: "tag-\(name)", name: name, color: nil, minutes: minutes)])
                }
                .sorted { ($0.minutes, $1.label) > ($1.minutes, $0.label) }
        }

        // One zero-filled bar per day; in the all-projects scope each bar is split by project.
        var perDay: [String: [String: ReportSegment]] = [:]
        for e in inRange {
            let seg: ReportSegment
            if scope == .all {
                let k = projectKey(e, noProject: noProjectLabel)
                let prev = perDay[e.date]?[k.id]?.minutes ?? 0
                seg = ReportSegment(id: k.id, name: k.name, color: k.color, minutes: prev + e.minutes)
            } else {
                let prev = perDay[e.date]?["all"]?.minutes ?? 0
                seg = ReportSegment(id: "all", name: "", color: nil, minutes: prev + e.minutes)
            }
            perDay[e.date, default: [:]][seg.id] = seg
        }

        let short = DateFormatter()
        short.calendar = calendar
        short.timeZone = calendar.timeZone
        short.locale = locale
        short.setLocalizedDateFormatFromTemplate(period == .week ? "EEE d" : "d MMM")
        let full = DateFormatter()
        full.calendar = calendar
        full.timeZone = calendar.timeZone
        full.locale = locale
        full.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        let keyFormatter = ReportDate.formatter(calendar)

        var result: [ReportBar] = []
        var day = range.lowerBound
        while day <= range.upperBound {
            let key = keyFormatter.string(from: day)
            let segments = sorted(Array((perDay[key] ?? [:]).values))
            result.append(ReportBar(id: key, label: short.string(from: day), title: full.string(from: day), segments: segments))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }
}
