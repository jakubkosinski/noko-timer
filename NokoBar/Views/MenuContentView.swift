import SwiftUI

struct MenuContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var search = ""

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
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(projects) { project in
                            ProjectRowView(project: project, timer: model.timers[project.id])
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 480)
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
            }
            Button("menu.settings") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            Spacer()
            Button("menu.quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .buttonStyle(.borderless)
        .padding(10)
    }
}
