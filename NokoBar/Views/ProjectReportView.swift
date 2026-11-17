import SwiftUI
import Charts

struct ProjectReportView: View {
    @Environment(AppModel.self) private var model
    let projectID: Int

    @State private var period: ReportPeriod = .week
    @State private var entries: [NokoEntry] = []
    @State private var loading = false
    @State private var error: String?
    @State private var loadedOnce = false
    @State private var hovered: String?

    private var calendar: Calendar { .current }
    private var project: NokoProject? { model.project(id: projectID) }

    var body: some View {
        let today = Date()
        let bars = ReportBuilder.bars(entries, period: period, today: today, calendar: calendar)
        let total = ReportBuilder.totalMinutes(entries, period: period, today: today, calendar: calendar)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle().fill(Color(hex: project?.color) ?? .gray).frame(width: 12, height: 12)
                Text(project?.name ?? "").font(.title3.bold()).lineLimit(1)
                Spacer()
                Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .disabled(loading)
            }

            Picker("", selection: $period) {
                ForEach(ReportPeriod.allCases) { p in Text(LocalizedStringKey(p.titleKey)).tag(p) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(TimeFormat.hm(total * 60)).font(.system(size: 34, weight: .semibold)).monospacedDigit()
                Text("report.total").foregroundStyle(.secondary)
            }

            if loading && !loadedOnce {
                ProgressView().frame(maxWidth: .infinity, minHeight: 220)
            } else if let error {
                Text(error).font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, minHeight: 220)
            } else if total == 0 {
                Text("report.empty").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 220)
            } else {
                Chart(bars) { bar in
                    BarMark(x: .value("", bar.label), y: .value("h", bar.hours))
                        .foregroundStyle(Color(hex: project?.color) ?? .accentColor)
                        .opacity(hovered == nil || hovered == bar.id ? 1 : 0.45)
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            if hovered == bar.id { tooltip(for: bar) }
                        }
                }
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
                if period == .day {
                    Text("report.multiTagNote").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 520)
        .task { await load() }
        .onChange(of: period) { hovered = nil }
        .onAppear { DockPresence.windowOpened() }
        .onDisappear { DockPresence.windowClosed() }
    }

    private func tooltip(for bar: ReportBar) -> some View {
        VStack(spacing: 2) {
            Text(bar.title).font(.caption).foregroundStyle(.secondary)
            Text("\(TimeFormat.hm(bar.minutes * 60)) h").font(.callout.bold()).monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .shadow(radius: 3, y: 1)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        let range = ReportPeriod.fetchRange(today: Date(), calendar: calendar)
        do {
            entries = try await model.entries(
                projectID: projectID,
                from: ReportDate.string(from: range.lowerBound, calendar: calendar),
                to: ReportDate.string(from: range.upperBound, calendar: calendar))
            error = nil
            loadedOnce = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
