import SwiftUI

struct LogTimerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let projectID: Int
    @State private var notes = ""
    @State private var loaded = false
    @State private var error: String?
    @State private var submitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let timer = model.timers[projectID] {
                Text(timer.project.name).font(.headline)
                HStack {
                    Text("finish.time")
                    Text(TimeFormat.hm(model.elapsedSeconds(timer))).monospacedDigit().bold()
                }
                NotesField(text: $notes)
                if let error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                HStack {
                    Spacer()
                    Button("finish.cancel", role: .cancel) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button("finish.confirm") { submit() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(submitting)
                }
                .onAppear {
                    if !loaded { notes = timer.description ?? ""; loaded = true }
                }
            } else {
                Text("finish.noTimer")
                Button("finish.cancel") { dismiss() }
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func submit() {
        submitting = true
        Task {
            do {
                try await model.finish(projectID: projectID, notes: notes)
                dismiss()
            } catch {
                self.error = error.localizedDescription
                submitting = false
            }
        }
    }
}
