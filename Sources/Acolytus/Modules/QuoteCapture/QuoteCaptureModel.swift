import AcolytusCore
import AppKit

struct QuoteDraft: Equatable {
    var author = ""
    var handle = ""
    var content = ""
    var source = ""
}

@MainActor
final class QuoteCaptureModel: ObservableObject {
    @Published var draft = QuoteDraft()
    @Published private(set) var status: String?
    @Published private(set) var isBusy = false
    @Published private(set) var lastSaved: URL?
    @Published private(set) var folderPath: String {
        didSet { UserDefaults.standard.set(folderPath, forKey: Self.folderKey) }
    }

    private static let folderKey = "quote-capture.folder"

    init() {
        folderPath = UserDefaults.standard.string(forKey: Self.folderKey) ?? ""
    }

    var folderURL: URL? {
        folderPath.isEmpty ? nil : URL(fileURLWithPath: folderPath, isDirectory: true)
    }

    /// Ruta corta para mostrar: `…/Root/Frases`.
    var folderDisplay: String {
        guard let url = folderURL else { return "Sin carpeta elegida" }
        let components = url.pathComponents.suffix(2)
        return "…/" + components.joined(separator: "/")
    }

    // MARK: - Captura

    func captureFromScreen() {
        guard !isBusy else { return }
        isBusy = true
        status = nil
        // Cierra el panel de la barra de menú para que no salga en la captura.
        NSApp.keyWindow?.close()
        Task {
            defer { isBusy = false }
            try? await Task.sleep(nanoseconds: 250_000_000)
            do {
                guard let image = try await ScreenCapture.selectRegion() else { return }
                try await recognize(image)
            } catch {
                status = "No se pudo capturar: \(error.localizedDescription)"
            }
        }
    }

    func captureFromClipboard() {
        guard !isBusy else { return }
        status = nil
        let pasteboard = NSPasteboard.general
        let sourceURL = pasteboard.string(forType: NSPasteboard.PasteboardType("org.chromium.source-url")) ?? ""

        if let image = NSImage(pasteboard: pasteboard),
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            isBusy = true
            Task {
                defer { isBusy = false }
                do {
                    try await recognize(cgImage, source: sourceURL)
                } catch {
                    status = "No se pudo leer la imagen: \(error.localizedDescription)"
                }
            }
        } else if let text = pasteboard.string(forType: .string),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            present(QuoteParser.parse(text: text), source: sourceURL)
        } else {
            status = "El portapapeles no tiene texto ni imagen."
        }
    }

    private func recognize(_ image: CGImage, source: String = "") async throws {
        let lines = try await Task.detached(priority: .userInitiated) {
            try TextRecognizer.lines(in: image)
        }.value
        guard !lines.isEmpty else {
            status = "No encontré texto en la imagen."
            return
        }
        present(QuoteParser.parse(lines: lines), source: source)
    }

    private func present(_ parsed: ParsedQuote, source: String) {
        draft = QuoteDraft(author: parsed.author, handle: parsed.handle,
                           content: parsed.content, source: source)
        ReviewWindowController.shared.show(model: self)
    }

    // MARK: - Guardado

    func save() {
        guard let folder = folderURL ?? chooseFolder() else { return }
        let note = QuoteNote(author: draft.author.trimmingCharacters(in: .whitespacesAndNewlines),
                             handle: draft.handle.trimmingCharacters(in: .whitespacesAndNewlines),
                             content: draft.content,
                             source: draft.source.trimmingCharacters(in: .whitespacesAndNewlines))
        do {
            let url = try ObsidianWriter.save(note, in: folder)
            lastSaved = url
            status = "Guardada: \(url.deletingPathExtension().lastPathComponent)"
            draft = QuoteDraft()
            ReviewWindowController.shared.close()
        } catch {
            status = "No se pudo guardar: \(error.localizedDescription)"
            NSSound.beep()
        }
    }

    func cancel() {
        draft = QuoteDraft()
        ReviewWindowController.shared.close()
    }

    func openLastSaved() {
        if let lastSaved { ObsidianWriter.open(lastSaved) }
    }

    @discardableResult
    func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Carpeta de frases en tu bóveda de Obsidian"
        panel.prompt = "Usar esta carpeta"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if let folderURL { panel.directoryURL = folderURL }
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        folderPath = url.path
        return url
    }
}
