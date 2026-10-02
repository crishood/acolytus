import SwiftUI

/// Encuentra procesos de Node huérfanos o suspendidos y libera su memoria.
@MainActor
final class NodeReaperModule: AcolytusModule {
    nonisolated let id = "node-reaper"
    nonisolated let title = "Procesos de Node"
    nonisolated let symbol = "memorychip"

    private let model = NodeReaperModel()

    func makeView() -> AnyView {
        AnyView(NodeReaperView(model: model))
    }
}
