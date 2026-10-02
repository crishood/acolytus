import AppKit
import SwiftUI

/// Ventana flotante para revisar autor y texto antes de guardar.
@MainActor
final class ReviewWindowController {
    static let shared = ReviewWindowController()

    private var window: NSWindow?

    func show(model: QuoteCaptureModel) {
        let window = self.window ?? makeWindow()
        self.window = window
        window.contentViewController = NSHostingController(rootView: QuoteReviewView(model: model))
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "Acolytus · Nueva frase"
        window.level = .floating
        window.isReleasedWhenClosed = false
        return window
    }
}

struct QuoteReviewView: View {
    @ObservedObject var model: QuoteCaptureModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Autor", text: $model.draft.author)
                TextField("@usuario", text: $model.draft.handle)
                    .frame(width: 140)
            }
            .textFieldStyle(.roundedBorder)

            TextEditor(text: $model.draft.content)
                .font(.body)
                .frame(minHeight: 160)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))

            TextField("Fuente (URL, opcional)", text: $model.draft.source)
                .textFieldStyle(.roundedBorder)

            HStack {
                Image(systemName: "folder")
                Text(model.folderDisplay)
                    .lineLimit(1)
                    .truncationMode(.head)
                Button("Cambiar…") { model.chooseFolder() }
                    .buttonStyle(.link)
                Spacer()
                Button("Cancelar") { model.cancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Guardar") { model.save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.draft.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .font(.caption)

            if let status = model.status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 460)
    }
}
