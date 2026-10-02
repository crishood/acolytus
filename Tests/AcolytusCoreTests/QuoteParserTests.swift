@testable import AcolytusCore
import XCTest

final class QuoteParserTests: XCTestCase {
    /// Recreación de una captura de Threads: Vision separa el nombre, la
    /// insignia, la hora y los iconos de la cabecera.
    func testThreadsScreenshot() {
        let lines = [
            OCRLine(text: "Audrey London", top: 0.10, left: 0.12, height: 0.06),
            OCRLine(text: "®", top: 0.105, left: 0.37, height: 0.05),
            OCRLine(text: "12h", top: 0.10, left: 0.41, height: 0.06),
            OCRLine(text: "...", top: 0.10, left: 0.86, height: 0.05),
            OCRLine(text: "X", top: 0.10, left: 0.92, height: 0.06),
            OCRLine(text: "One German philosopher declared that God was a human projection, and an",
                    top: 0.22, left: 0.12, height: 0.06),
            OCRLine(text: "entire civilization shrugged and agreed.", top: 0.31, left: 0.12, height: 0.06),
            OCRLine(text: "58", top: 0.55, left: 0.15, height: 0.05),
            OCRLine(text: "9", top: 0.55, left: 0.25, height: 0.05),
            OCRLine(text: "5", top: 0.55, left: 0.35, height: 0.05),
        ]
        let quote = QuoteParser.parse(lines: lines)
        XCTAssertEqual(quote.author, "Audrey London")
        XCTAssertEqual(quote.handle, "")
        XCTAssertEqual(quote.content,
                       "One German philosopher declared that God was a human projection, and an entire civilization shrugged and agreed.")
    }

    func testXHeaderWithHandleAndParagraphs() {
        let lines = [
            OCRLine(text: "G. K. Chesterton @gkc · 3d", top: 0.05, left: 0.1, height: 0.04),
            OCRLine(text: "Tradition means giving a vote to", top: 0.12, left: 0.1, height: 0.04),
            OCRLine(text: "the dead.", top: 0.17, left: 0.1, height: 0.04),
            OCRLine(text: "It is the democracy of the dead.", top: 0.27, left: 0.1, height: 0.04),
            OCRLine(text: "10:15 AM · Oct 2, 2026 · 1.2M Views", top: 0.35, left: 0.1, height: 0.04),
        ]
        let quote = QuoteParser.parse(lines: lines)
        XCTAssertEqual(quote.author, "G. K. Chesterton")
        XCTAssertEqual(quote.handle, "@gkc")
        XCTAssertEqual(quote.content, "Tradition means giving a vote to the dead.\n\nIt is the democracy of the dead.")
    }

    func testHyphenatedWrapIsJoined() {
        let lines = [
            OCRLine(text: "Ana", top: 0.0, left: 0, height: 0.1),
            OCRLine(text: "La contempla-", top: 0.15, left: 0, height: 0.1),
            OCRLine(text: "ción precede a la acción.", top: 0.28, left: 0, height: 0.1),
        ]
        XCTAssertEqual(QuoteParser.parse(lines: lines).content, "La contemplación precede a la acción.")
    }

    func testCopiedTextWithSpanishTimeAndHandleRow() {
        let text = """
        San Agustín · hace 3 h
        @agustin_hipona

        Nos hiciste, Señor, para ti,
        y nuestro corazón está inquieto hasta que descanse en ti.

        Ver traducción
        1,2 K 340
        """
        let quote = QuoteParser.parse(text: text)
        XCTAssertEqual(quote.author, "San Agustín")
        XCTAssertEqual(quote.handle, "@agustin_hipona")
        XCTAssertEqual(quote.content,
                       "Nos hiciste, Señor, para ti,\ny nuestro corazón está inquieto hasta que descanse en ti.")
    }

    func testContentMentioningLikesIsNotTruncated() {
        let quote = QuoteParser.parse(text: "Autor\nShe likes cats and quiet mornings.")
        XCTAssertEqual(quote.content, "She likes cats and quiet mornings.")
    }
}

final class QuoteNoteTests: XCTestCase {
    func testMarkdownAndFileName() {
        let note = QuoteNote(author: "Audrey London",
                             content: "One German philosopher declared that God was a human projection.",
                             capturedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(note.fileName, "Audrey London — One German philosopher declared that God was.md")
        XCTAssertEqual(note.markdown(timeZone: TimeZone(identifier: "UTC")!), """
        ---
        author: "Audrey London"
        captured: 1970-01-01T00:00:00Z
        ---

        > One German philosopher declared that God was a human projection.
        >
        > — Audrey London

        """)
    }

    func testFileNameDropsForbiddenCharacters() {
        let note = QuoteNote(author: "A/B", handle: "@ab", content: "¿Qué es #verdad? [dijo] Pilato:")
        XCTAssertEqual(note.fileName, "A B — ¿Qué es verdad dijo Pilato.md")
    }

    func testYAMLEscapesQuotes() {
        let note = QuoteNote(author: "Dwayne \"The Rock\"", content: "x", source: "https://threads.net/x")
        let markdown = note.markdown()
        XCTAssertTrue(markdown.contains(#"author: "Dwayne \"The Rock\"""#))
        XCTAssertTrue(markdown.contains(#"source: "https://threads.net/x""#))
    }
}
