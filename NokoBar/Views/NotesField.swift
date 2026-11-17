import SwiftUI

/// Text field with `#tag` autocomplete from the cached tag list.
struct NotesField: View {
    @Environment(AppModel.self) private var model
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("row.notes", text: $text, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
            let suggestions = TagToken.suggestions(for: text, tags: model.tags)
            if !suggestions.isEmpty {
                HStack {
                    ForEach(suggestions) { tag in
                        Button("#\(tag.name)") { text = TagToken.complete(text, with: tag.name) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
        }
    }
}
