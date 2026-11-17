import SwiftUI
import Charts

struct ReportView: View {
    @Environment(AppModel.self) private var model
    let scope: ReportScope

    /// The data currently on screen. It lags behind the selection while a new range loads,
    /// so the chart doesn't jump.
    private struct Shown {
        let period: ReportPeriod
        let range: ClosedRange<Date>
        let entries: [NokoEntry]
    }

    @State private var period: ReportPeriod = .week
    @State private var offset = 0
    @State private var today = Date()
    @State private var cache: [String: [NokoEntry]] = [:]
    @State private var shown: Shown?
    @State private var loading = false
    @State private var error: String?
    @State private var hovered: String?

    private var calendar: Calendar { .current }
    private var project: NokoProject? { scope.projectID.flatMap { model.project(id: $0) } }
    private var currentRange: ClosedRange<Date> { period.range(today: today, calendar: calendar, offset: offset) }

    private func key(_ r: ClosedRange<Date>) -> String {
        "\(ReportDate.string(from: r.lowerBound, calendar: calendar))|\(ReportDate.string(from: r.upperBound, calendar: calendar))"
    }

    private var projectColor: Color { Color(hex: project?.color) ?? .accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Picker("", selection: $period) {
                ForEach(ReportPeriod.allCases) { p in Text(LocalizedStringKey(p.titleKey)).tag(p) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            navigation
            content
        }
        .padding(20)
        .frame(width: 560)
        .navigationTitle(scope == .all ? String(localized: "report.allProjects") : (project?.name ?? String(localized: "report.title")))
        .task(id: key(currentRange)) { await load(force: false) }
        .onChange(of: period) { offset = 0; hovered = nil }
        .onChange(of: offset) { hovered = nil }
        .onAppear { DockPresence.windowOpened() }
        .onDisappear { DockPresence.windowClosed() }
    }

    // MARK: Header and navigation

    private var header: some View {
        HStack {
            if scope == .all {
                Image(systemName: "chart.bar.xaxis").foregroundStyle(.secondary)
                Text("report.allProjects").font(.title3.bold())
            } else {
                Circle().fill(projectColor).frame(width: 12, height: 12)
                Text(project?.name ?? "").font(.title3.bold()).lineLimit(1)
            }
            Spacer()
            if loading { ProgressView().controlSize(.small) }
            Button {
                Task {
                    today = Date()
                    cache = [:]
                    await load(force: true)
                }
            } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
                .disabled(loading)
        }
    }

    private var navigation: some View {
        HStack {
            Button { offset -= 1 } label: { Image(systemName: "chevron.left") }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .help(Text("report.previous"))
            Spacer()
            Text(period.title(for: currentRange, offset: offset, calendar: calendar))
                .font(.headline)
                .monospacedDigit()
            if offset < 0 {
                Button { offset = 0 } label: { Image(systemName: "arrow.uturn.forward") }
                    .buttonStyle(.borderless)
                    .help(Text("report.current"))
            }
            Spacer()
            Button { offset += 1 } label: { Image(systemName: "chevron.right") }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(offset >= 0)
                .help(Text("report.next"))
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if let shown {
            let bars = ReportBuilder.bars(shown.entries, period: shown.period, range: shown.range, scope: scope, calendar: calendar)
            let total = ReportBuilder.totalMinutes(shown.entries, range: shown.range, calendar: calendar)
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(TimeFormat.hm(total * 60)).font(.system(size: 34, weight: .semibold)).monospacedDigit()
                    Text("report.total").foregroundStyle(.secondary)
                }
                if let error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                if total == 0 {
                    Text("report.empty").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    chart(bars, period: shown.period)
                    if shown.period == .day && scope != .all {
                        Text("report.multiTagNote").font(.caption).foregroundStyle(.secondary)
                    }
                    if scope == .all { projectList(shown) }
                }
            }
            .opacity(loading ? 0.5 : 1)
        } else if let error {
            Text(error).font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, minHeight: 220)
        } else {
            ProgressView().frame(maxWidth: .infinity, minHeight: 220)
        }
    }

    private func chart(_ bars: [ReportBar], period: ReportPeriod) -> some View {
        // One colour per segment id, shared by the chart and the project list.
        var colors: [String: Color] = [:]
        for seg in bars.flatMap(\.segments) where colors[seg.id] == nil {
            colors[seg.id] = scope == .all ? (Color(hex: seg.color) ?? .gray) : projectColor
        }
        let ids = colors.keys.sorted()
        let hoveredBar = bars.first { $0.id == hovered }

        return Chart {
            ForEach(bars) { bar in
                ForEach(bar.segments) { seg in
                    BarMark(x: .value("", bar.label), y: .value("h", seg.hours))
                        .foregroundStyle(by: .value("p", seg.id))
                        .opacity(hovered == nil || hovered == bar.id ? 1 : 0.45)
                }
            }
            if let hoveredBar {
                RuleMark(x: .value("", hoveredBar.label))
                    .foregroundStyle(.gray.opacity(0.12))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .annotation(position: .overlay, alignment: .top, spacing: 0,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        tooltip(for: hoveredBar, colors: colors)
                    }
            }
        }
        .chartForegroundStyleScale(domain: ids, range: ids.map { colors[$0]! })
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: period == .week || period == .day ? 8 : 6))
        }
        .chartYAxisLabel("h")
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let p):
                            guard let frame = proxy.plotFrame else { hovered = nil; return }
                            let x = p.x - geo[frame].origin.x
                            if let label: String = proxy.value(atX: x),
                               let bar = bars.first(where: { $0.label == label }) {
                                hovered = bar.id
                            } else {
                                hovered = nil
                            }
                        case .ended:
                            hovered = nil
                        }
                    }
            }
        }
        .frame(height: 220)
    }

    private func tooltip(for bar: ReportBar, colors: [String: Color]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(bar.title).font(.caption).foregroundStyle(.secondary)
            Text("\(TimeFormat.hm(bar.minutes * 60)) h").font(.callout.bold()).monospacedDigit()
            if bar.segments.count > 1 {
                Divider()
                ForEach(bar.segments.prefix(5)) { seg in
                    HStack(spacing: 5) {
                        Circle().fill(colors[seg.id] ?? .gray).frame(width: 7, height: 7)
                        Text(seg.name).font(.caption).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(TimeFormat.hm(seg.minutes * 60)).font(.caption).monospacedDigit()
                    }
                }
                if bar.segments.count > 5 {
                    Text("+\(bar.segments.count - 5)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(minWidth: 110, maxWidth: 200)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .shadow(radius: 3, y: 1)
    }

    private func projectList(_ shown: Shown) -> some View {
        let totals = ReportBuilder.projectTotals(shown.entries, range: shown.range, calendar: calendar)
        return ScrollView {
            VStack(spacing: 0) {
                ForEach(totals) { t in
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: t.color) ?? .gray).frame(width: 9, height: 9)
                        Text(t.name).lineLimit(1)
                        Spacer()
                        Text(TimeFormat.hm(t.minutes * 60)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
        .frame(maxHeight: 180)
    }

    // MARK: Loading

    private func load(force: Bool) async {
        let period = self.period
        let range = currentRange
        let k = key(range)
        if !force, let cached = cache[k] {
            shown = Shown(period: period, range: range, entries: cached)
            error = nil
            return
        }
        loading = true
        defer { loading = false }
        do {
            let list = try await model.entries(
                projectID: scope.projectID,
                from: ReportDate.string(from: range.lowerBound, calendar: calendar),
                to: ReportDate.string(from: range.upperBound, calendar: calendar))
            cache[k] = list
            if k == key(currentRange) {
                shown = Shown(period: period, range: range, entries: list)
                error = nil
            }
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }
}
