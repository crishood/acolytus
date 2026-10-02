import AcolytusCore
import AppKit

enum ObsidianWriter {
    /// Escribe la nota en `folder` sin pisar ninguna existente.
    static func save(_ note: QuoteNote, in folder: URL) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        let base = (note.fileName as NSString).deletingPathExtension
        var url = folder.appendingPathComponent(note.fileName)
        var counter = 2
        while fileManager.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base) \(counter).md")
            counter += 1
        }
        try note.markdown().write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Abre la nota en Obsidian (si la carpeta pertenece a una bóveda) o en
    /// el editor por defecto.
    static func open(_ url: URL) {
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "path", value: url.path)]
        if let obsidianURL = components.url,
           NSWorkspace.shared.urlForApplication(toOpen: obsidianURL) != nil {
            NSWorkspace.shared.open(obsidianURL)
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
