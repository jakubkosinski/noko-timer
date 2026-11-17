import Foundation

enum TimeFormat {
    /// "HH:MM" (hours may exceed 24).
    static func hm(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%02d:%02d", s / 3600, (s % 3600) / 60)
    }

    /// "HH:MM:SS"
    static func hms(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}

/// Helpers for the `#tag` token being typed at the end of a notes string.
enum TagToken {
    /// Returns the partial tag (without '#') if the text ends with a `#word` token.
    static func partial(in text: String) -> String? {
        guard let hash = text.lastIndex(of: "#") else { return nil }
        if hash > text.startIndex {
            let before = text[text.index(before: hash)]
            guard before.isWhitespace else { return nil }
        }
        let word = text[text.index(after: hash)...]
        guard !word.contains(where: { $0.isWhitespace }) else { return nil }
        return String(word)
    }

    /// Replaces the trailing `#partial` with `#tag ` .
    static func complete(_ text: String, with tag: String) -> String {
        guard let hash = text.lastIndex(of: "#"), partial(in: text) != nil else { return text }
        return String(text[..<hash]) + "#" + tag + " "
    }

    static func suggestions(for text: String, tags: [NokoTag], limit: Int = 5) -> [NokoTag] {
        guard let p = partial(in: text) else { return [] }
        let needle = p.lowercased()
        return tags
            .filter { needle.isEmpty || $0.name.lowercased().hasPrefix(needle) }
            .filter { $0.name.lowercased() != needle }
            .prefix(limit).map { $0 }
    }
}
