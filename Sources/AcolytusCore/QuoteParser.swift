import Foundation

/// Un fragmento de texto reconocido por OCR, en coordenadas normalizadas
/// (0…1) con el origen arriba a la izquierda.
public struct OCRLine: Equatable, Sendable {
    public var text: String
    public var top: Double
    public var left: Double
    public var height: Double

    public var bottom: Double { top + height }
    var centerY: Double { top + height / 2 }

    public init(text: String, top: Double, left: Double, height: Double) {
        self.text = text
        self.top = top
        self.left = left
        self.height = height
    }
}

public struct ParsedQuote: Equatable, Sendable {
    public var author: String
    public var handle: String
    public var content: String

    public init(author: String = "", handle: String = "", content: String = "") {
        self.author = author
        self.handle = handle
        self.content = content
    }
}

/// Extrae autor y contenido de una publicación de red social (Threads, X,
/// Bluesky, Mastodon…) capturada como imagen o copiada como texto.
///
/// Estructura esperada:
///
///     Nombre [@usuario] [· 12h]      ← cabecera (autor)
///     [@usuario]                     ← opcional
///     Texto de la publicación…       ← contenido
///     ♡ 58  💬 9  🔁 5               ← pie (se descarta)
///
/// No pretende ser perfecto: el resultado se revisa antes de guardarse.
public enum QuoteParser {

    // MARK: - Entradas

    public static func parse(lines: [OCRLine]) -> ParsedQuote {
        let rows = groupIntoRows(lines)
        let (author, handle, bodyStart) = extractHeader(rows.map(\.text))
        let body = bodyRows(Array(rows[bodyStart...]), text: { $0.text })
        return ParsedQuote(author: author, handle: handle, content: joinWrapped(body))
    }

    public static func parse(text: String) -> ParsedQuote {
        // En texto copiado los saltos de línea son intencionales: se conservan.
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let nonEmpty = lines.filter { !$0.isEmpty }
        let (author, handle, consumed) = extractHeader(nonEmpty)

        // Avanza sobre `lines` (con vacías) hasta saltar las `consumed` primeras no vacías.
        var start = 0
        var seen = 0
        while start < lines.count, seen < consumed {
            if !lines[start].isEmpty { seen += 1 }
            start += 1
        }
        let rest = Array(lines[start...])
        let body = bodyRows(rest, text: { $0 }, keepBlank: true)
        let content = body.joined(separator: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedQuote(author: author, handle: handle, content: content)
    }

    // MARK: - Filas

    /// Vision devuelve por separado textos de una misma línea visual
    /// ("Audrey London" y "12h"); se unen de izquierda a derecha.
    static func groupIntoRows(_ lines: [OCRLine]) -> [OCRLine] {
        let sorted = lines
            .filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.top < $1.top }
        var rows: [[OCRLine]] = []
        for line in sorted {
            if let reference = rows.last?.first,
               abs(line.centerY - reference.centerY) < max(reference.height, line.height) * 0.5 {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }
        return rows.map { parts -> OCRLine in
            let ordered = parts.sorted { $0.left < $1.left }
            let top = ordered.map(\.top).min() ?? 0
            let bottom = ordered.map(\.bottom).max() ?? 0
            return OCRLine(text: ordered.map { $0.text.trimmingCharacters(in: .whitespaces) }.joined(separator: " "),
                           top: top,
                           left: ordered.map(\.left).min() ?? 0,
                           height: bottom - top)
        }
    }

    // MARK: - Cabecera

    /// Devuelve autor, usuario y cuántas filas ocupa la cabecera.
    static func extractHeader(_ rows: [String]) -> (author: String, handle: String, consumed: Int) {
        var index = 0
        var author = ""
        var handle = ""
        while index < rows.count {
            let header = parseHeader(rows[index])
            index += 1
            if !header.author.isEmpty || !header.handle.isEmpty {
                author = header.author
                handle = header.handle
                break
            }
        }
        // Usuario en su propia fila, debajo del nombre.
        if handle.isEmpty, index < rows.count {
            let next = parseHeader(rows[index])
            if next.author.isEmpty, !next.handle.isEmpty {
                handle = next.handle
                index += 1
            }
        }
        return (author, handle, index)
    }

    static func parseHeader(_ raw: String) -> (author: String, handle: String) {
        var tokens = raw.split(whereSeparator: \.isWhitespace).map(String.init)
        stripTrailingNoise(&tokens)
        var handle = ""
        if let at = tokens.firstIndex(where: { isHandle($0) }) {
            handle = tokens[at].trimmingCharacters(in: separators)
            tokens = Array(tokens[..<at])
            stripTrailingNoise(&tokens)
        }
        while let first = tokens.first, isSymbolOnly(first) { tokens.removeFirst() }
        return (tokens.joined(separator: " "), handle)
    }

    static func stripTrailingNoise(_ tokens: inout [String]) {
        var strippedNumber = false
        while let last = tokens.last {
            let token = last.trimmingCharacters(in: separators)
            let lower = token.lowercased()
            if token.isEmpty || isSymbolOnly(token)
                || matches(lower, relativeTimePattern)
                || timeWords.contains(lower)
                || closeGlyphs.contains(token) {
                tokens.removeLast()
            } else if isCount(token) {
                tokens.removeLast()
                strippedNumber = true
            } else if strippedNumber, months.contains(lower.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))) {
                tokens.removeLast()
            } else {
                break
            }
        }
    }

    static func isHandle(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: separators)
        guard trimmed.hasPrefix("@"), trimmed.count > 1 else { return false }
        return trimmed.dropFirst().contains { $0.isLetter || $0.isNumber }
    }

    // MARK: - Cuerpo

    static func bodyRows<Row>(_ rows: [Row], text: (Row) -> String, keepBlank: Bool = false) -> [Row] {
        var body: [Row] = []
        for row in rows {
            let value = text(row).trimmingCharacters(in: .whitespaces)
            if value.isEmpty {
                if keepBlank, !body.isEmpty { body.append(row) }
                continue
            }
            let hasContent = body.contains { !text($0).trimmingCharacters(in: .whitespaces).isEmpty }
            if hasContent, isFooter(value) { break }
            if isNoise(value) { continue }
            body.append(row)
        }
        return body
    }

    /// Fila de interacciones ("58 9 5", "1,2 K 340") o marca de tiempo de X
    /// ("10:15 AM · Oct 2, 2026 · 1.2M Views").
    static func isFooter(_ row: String) -> Bool {
        let tokens = row.split(whereSeparator: \.isWhitespace).map(String.init)
        let meaningful = tokens.filter { !isSymbolOnly($0) }
        if !meaningful.isEmpty, meaningful.allSatisfy({ isCount($0) || isCountSuffix($0) }) {
            return true
        }
        let lower = row.lowercased()
        return matches(lower, clockPattern) || matches(lower, statsPattern)
    }

    static func isNoise(_ row: String) -> Bool {
        isSymbolOnly(row) || noiseRows.contains(row.lowercased().trimmingCharacters(in: separators))
    }

    /// Une las líneas que el OCR partió por ajuste de texto. Un hueco vertical
    /// mayor que una línea marca un párrafo nuevo.
    static func joinWrapped(_ rows: [OCRLine]) -> String {
        guard !rows.isEmpty else { return "" }
        let heights = rows.map(\.height).sorted()
        let lineHeight = heights[heights.count / 2]
        var result = rows[0].text
        for (previous, row) in zip(rows, rows.dropFirst()) {
            let gap = row.top - previous.bottom
            if gap > lineHeight * 1.0 {
                result += "\n\n" + row.text
            } else if result.hasSuffix("-"),
                      result.dropLast().last?.isLetter == true,
                      row.text.first?.isLowercase == true {
                result.removeLast()
                result += row.text
            } else {
                result += " " + row.text
            }
        }
        return result
    }

    // MARK: - Léxico

    static let separators = CharacterSet(charactersIn: "·•|—–-…,:")

    /// "12h", "3d", "5m", "2min", "1sem", "4 w"…
    static let relativeTimePattern = #"^\d{1,3}\s?(s|m|min|mins|h|hr|hrs|d|w|sem|mo|y|a)\.?$"#
    static let clockPattern = #"\b\d{1,2}:\d{2}\s?(am|pm|a\.\s?m\.|p\.\s?m\.)\s?·"#
    /// "1.2M Views", "340 reposts", "12 mil visualizaciones".
    static let statsPattern = #"\d[\d.,]*\s?(k|m|mil)?\s+(views|vistas|visualizaciones|reposts|quotes|likes|me gusta|replies|respuestas)\b"#

    static let timeWords: Set<String> = [
        "hace", "ago", "s", "m", "min", "h", "hr", "hrs", "d", "w", "sem", "now", "ahora",
        "edited", "editado", "editada",
    ]
    static let closeGlyphs: Set<String> = ["x", "X", "×", "✕", "...", "…", "•••", "⋯"]
    static let months: Set<String> = [
        "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "sept", "oct", "nov", "dec",
        "ene", "abr", "ago", "dic",
        "january", "february", "march", "april", "june", "july", "august", "september",
        "october", "november", "december",
        "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre",
        "octubre", "noviembre", "diciembre",
    ]
    static let noiseRows: Set<String> = [
        "translate", "traducir", "see translation", "ver traducción", "show translation",
        "mostrar traducción", "show more", "ver más", "mostrar más", "follow", "seguir",
        "pinned", "fijado", "reply", "responder",
    ]

    static func isCount(_ token: String) -> Bool {
        matches(token.trimmingCharacters(in: separators), #"^\d+([.,]\d+)?\s?[KkMm]?$"#)
    }

    static func isCountSuffix(_ token: String) -> Bool {
        ["k", "m", "mil", "mill."].contains(token.lowercased())
    }

    static func isSymbolOnly(_ token: String) -> Bool {
        !token.contains { $0.isLetter || $0.isNumber }
    }

    static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
