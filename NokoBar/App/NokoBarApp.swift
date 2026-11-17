import SwiftUI

@main
struct NokoBarApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environment(model)
        } label: {
            MenuBarLabel()
                .environment(model)
        }
        .menuBarExtraStyle(.window)

        Window("login.title", id: "login") {
            LoginView()
                .environment(model)
        }
        .windowResizability(.contentSize)

        WindowGroup("finish.title", id: "log-timer", for: Int.self) { $projectID in
            if let projectID {
                LogTimerView(projectID: projectID)
                    .environment(model)
            }
        }
        .windowResizability(.contentSize)

        WindowGroup("report.title", id: "project-report", for: Int.self) { $projectID in
            if let projectID {
                ProjectReportView(projectID: projectID)
                    .environment(model)
            }
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let timer = model.displayedTimer {
            HStack(spacing: 4) {
                Image(systemName: timer.state == .running ? "clock.fill" : "pause.circle")
                Text(TimeFormat.hm(model.elapsedSeconds(timer)))
                    .monospacedDigit()
            }
        } else {
            Image(systemName: "clock")
        }
    }
}
