import SwiftUI

struct LoginView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("login.heading").font(.headline)
            Text("login.help").font(.callout).foregroundStyle(.secondary)
            Link("login.getToken", destination: URL(string: "https://help.nokotime.com/en/articles/6003686-connecting-to-the-freckle-api")!)
                .font(.callout)
            SecureField("login.token", text: $token)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("finish.cancel", role: .cancel) { dismiss() }
                Button("login.submit", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(token.isEmpty || busy)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private func submit() {
        guard !token.isEmpty, !busy else { return }
        busy = true
        Task {
            do {
                try await model.login(token: token)
                token = ""
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}
