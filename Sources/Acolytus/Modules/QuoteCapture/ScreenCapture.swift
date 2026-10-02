import AppKit
import ImageIO

enum ScreenCapture {
    /// Abre la selección interactiva de región de macOS (como ⌘⇧4).
    /// Devuelve `nil` si se cancela con Esc.
    ///
    /// La primera vez macOS pedirá permiso de Grabación de pantalla.
    static func selectRegion() async throws -> CGImage? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("acolytus-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        _ = try await Task.detached(priority: .userInitiated) {
            try Shell.run("/usr/sbin/screencapture", ["-i", "-x", url.path])
        }.value

        guard FileManager.default.fileExists(atPath: url.path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return image
    }
}
