import Foundation

/// Una frase lista para guardarse como nota de Obsidian.
public struct QuoteNote: Equatable, Sendable {
    public var author: String
    public var handle: String
    public var content: String
    public var source: String
    public var capturedAt: Date

    public init(author: String, handle: String = "", content: String,
                source: String = "", capturedAt: Date = Date()) {
        self.author = author
        self.handle = handle
        self.content = content
        self.source = source
        self.capturedAt = capturedAt
    }

    var displayAuthor: String {
        let name = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (name.isEmpty, user.isEmpty) {
        case (false, false): return "\(name) (\(user))"
        case (false, true): return name
        case (true, false): return user
        case (true, true): return "Anónimo"
        }
    }

    public func markdown(timeZone: TimeZone = .current) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = timeZone

        var frontmatter = ["---", "author: \(yamlString(author.isEmpty ? displayAuthor : author))"]
        if !handle.isEmpty { frontmatter.append("handle: \(yamlString(handle))") }
        if !source.isEmpty { frontmatter.append("source: \(yamlString(source))") }
        frontmatter.append("captured: \(formatter.string(from: capturedAt))")
        frontmatter.append("---")

        let quote = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map { $0.isEmpty ? ">" : "> \($0)" }
            .joined(separator: "\n")

        return frontmatter.joined(separator: "\n") + "\n\n" + quote + "\n>\n> — \(displayAuthor)\n"
    }

    /// `Autor — primeras palabras.md`, sin caracteres que Obsidian o el
    /// sistema de archivos no toleran.
    public var fileName: String {
        let words = content
            .split(whereSeparator: { $0.isWhitespace })
            .prefix(7)
            .joined(separator: " ")
        let name = author.isEmpty ? displayAuthor : author
        var base = sanitize(words.isEmpty ? name : "\(name) — \(words)")
        if base.count > 120 { base = String(base.prefix(120)).trimmingCharacters(in: .whitespaces) }
        return (base.isEmpty ? "Frase" : base) + ".md"
    }

    private func sanitize(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|#^[]\n\r\t")
        let cleaned = value.unicodeScalars.map { forbidden.contains($0) ? " " : String($0) }.joined()
        return cleaned
            .replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".")))
    }

    private func yamlString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
        return "\"\(escaped)\""
    }
}
