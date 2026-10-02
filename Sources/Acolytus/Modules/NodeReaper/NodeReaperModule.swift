import SwiftUI

/// Encuentra procesos de Node huérfanos o suspendidos y libera su memoria.
@MainActor
final class NodeReaperModule: AcolytusModule {
    let id = "node-reaper"
    let title = "Procesos de Node"
    let symbol = "memorychip"

    private let model = NodeReaperModel()

    func makeView() -> AnyView {
        AnyView(NodeReaperView(model: model))
    }
}
