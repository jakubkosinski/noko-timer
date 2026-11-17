import SwiftUI

struct MenuContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var search = ""
    @State private var listHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isLoggedIn {
                projectList
            } else {
                loggedOut
            }
            if let error = model.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            footer
        }
        .frame(width: 340)
        .task { await model.popoverOpened() }
    }

    private var loggedOut: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock").font(.largeTitle).foregroundStyle(.secondary)
            Text("menu.loggedOut").foregroundStyle(.secondary)
            Button("menu.login") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "login")
                MenuPopover.close()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    private var projectList: some View {
        VStack(spacing: 0) {
            TextField("menu.search", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(10)
            let projects = model.sortedProjects(matching: search)
            if projects.isEmpty {
                Text(model.isLoading ? "menu.loading" : "menu.noProjects")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            } else {
                // The popover has no intrinsic height for a ScrollView, so measure the content
                // and give the ScrollView an explicit height (capped at 480 pt).
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(projects) { project in
                            ProjectRowView(project: project, timer: model.timers[project.id])
                            Divider()
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
                }
                .frame(height: min(max(listHeight, 44), 480))
            }
        }
    }

    private var footer: some View {
        HStack {
            if model.isLoggedIn {
                Button { Task { await model.refreshAll() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help(Text("menu.refresh"))
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "report", value: ReportScope.all)
                    MenuPopover.close()
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                }
                .help(Text("menu.reports"))
            }
            Button("menu.settings") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
                MenuPopover.close()
            }
            Spacer()
            Button("menu.quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .buttonStyle(.borderless)
        .padding(10)
    }
}
