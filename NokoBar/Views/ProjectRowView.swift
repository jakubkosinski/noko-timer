import SwiftUI

struct ProjectRowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    let project: NokoProject
    let timer: NokoTimer?
    @State private var notes = ""
    @State private var nameHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: project.color) ?? .gray).frame(width: 10, height: 10)
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "report", value: ReportScope.project(project.id))
                    MenuPopover.close()
                } label: {
                    Text(project.name).lineLimit(1).underline(nameHovered)
                }
                .buttonStyle(.plain)
                .onHover { nameHovered = $0 }
                .help(Text("row.report"))
                Spacer()
                if let timer, timer.isActive {
                    Text(TimeFormat.hms(model.elapsedSeconds(timer)))
                        .monospacedDigit()
                        .foregroundStyle(timer.state == .running ? .primary : .secondary)
                    Button {
                        Task {
                            if timer.state == .running { await model.pause(projectID: project.id) }
                            else { await model.start(projectID: project.id) }
                        }
                    } label: {
                        Image(systemName: timer.state == .running ? "pause.fill" : "play.fill")
                    }
                    .help(Text(timer.state == .running ? "row.pause" : "row.resume"))
                    Button {
                        NSApp.activate(ignoringOtherApps: true)
                        openWindow(id: "log-timer", value: project.id)
                        MenuPopover.close()
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .help(Text("row.finish"))
                } else {
                    Button {
                        Task { await model.start(projectID: project.id) }
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .help(Text("row.start"))
                }
            }
            .buttonStyle(.borderless)

            if let timer, timer.isActive {
                TextField("row.notes", text: $notes)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .onSubmit { Task { await model.updateNotes(projectID: project.id, text: notes) } }
                    .task(id: notes) {
                        // Debounced save.
                        try? await Task.sleep(for: .milliseconds(800))
                        guard !Task.isCancelled else { return }
                        await model.updateNotes(projectID: project.id, text: notes)
                    }
                    .onAppear { notes = timer.description ?? "" }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

extension Color {
    init?(hex: String?) {
        guard var h = hex?.trimmingCharacters(in: .whitespaces), !h.isEmpty else { return nil }
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
