import SwiftUI

/// Captura frases de internet (autor + contenido) y las deja como notas en
/// una carpeta de Obsidian, sin clasificar.
@MainActor
final class QuoteCaptureModule: AcolytusModule {
    let id = "quote-capture"
    let title = "Capturar frase"
    let symbol = "quote.bubble"

    private let model = QuoteCaptureModel()

    func makeView() -> AnyView {
        AnyView(QuoteCaptureView(model: model))
    }
}
