import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var launch = LaunchAtLogin()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("settings.launchAtLogin", isOn: Binding(
                get: { launch.isEnabled },
                set: { launch.setEnabled($0) }
            ))
            if launch.requiresApproval {
                HStack {
                    Text("settings.requiresApproval").font(.caption).foregroundStyle(.secondary)
                    Button("settings.openLoginItems") { launch.openSystemSettings() }
                        .controlSize(.small)
                }
            }
            if let error = launch.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Divider()

            if let user = model.user, model.isLoggedIn {
                HStack(spacing: 12) {
                    AsyncImage(url: user.profileImageUrl.flatMap(URL.init)) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary)
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    VStack(alignment: .leading) {
                        Text(user.fullName).font(.headline)
                        Text(user.email).foregroundStyle(.secondary)
                        if let role = user.role { Text(role.capitalized).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                Button("settings.logout", role: .destructive) { model.logout() }
            } else {
                Text("settings.notLoggedIn").foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 360, alignment: .leading)
        .onAppear { launch.refresh() }
    }
}
