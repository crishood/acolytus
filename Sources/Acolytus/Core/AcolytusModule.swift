import SwiftUI

/// Una función de Acolytus. Para añadir una nueva:
///
/// 1. Crea una carpeta en `Modules/` con un tipo que conforme a este protocolo.
/// 2. Regístralo en `ModuleRegistry.modules`.
///
/// Cada módulo es dueño de su estado (normalmente un `ObservableObject`) y de
/// su configuración (`UserDefaults` con prefijo `<id>.`).
protocol AcolytusModule: AnyObject {
    /// Identificador estable; se usa para recordar la pestaña elegida.
    var id: String { get }
    var title: String { get }
    /// Nombre de un SF Symbol.
    var symbol: String { get }
    /// Contenido que se muestra en el panel de la barra de menú.
    @MainActor func makeView() -> AnyView
}

@MainActor
enum ModuleRegistry {
    static let modules: [any AcolytusModule] = [
        NodeReaperModule(),
        QuoteCaptureModule(),
    ]
}
