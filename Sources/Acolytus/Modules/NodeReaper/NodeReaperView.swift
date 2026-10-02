import AcolytusCore
import SwiftUI

struct NodeReaperView: View {
    @ObservedObject var model: NodeReaperModel
    @State private var showsSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            summary
            if model.processes.isEmpty {
                Text(model.isBusy ? "Buscando…" : "No hay procesos de Node. Todo en paz.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                list
            }
            actions
            if let status = model.status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            DisclosureGroup("Proteger", isExpanded: $showsSettings) {
                TextField("tsserver, mi-servicio, …", text: $model.protectedPatterns)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                Text("Los comandos que contengan alguno de estos textos nunca se limpian automáticamente.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .onAppear { model.refresh() }
    }

    private var summary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.processes.count) procesos · \(NodeReaperModel.format(mb: model.totalMB))")
                    .font(.subheadline.weight(.medium))
                Text("\(model.candidates.count) huérfanos o suspendidos")
                    .font(.caption)
                    .foregroundStyle(model.candidates.isEmpty ? Color.secondary : Color.orange)
            }
            Spacer()
            if model.isBusy {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    model.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Actualizar")
            }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(model.processes) { process in
                    ProcessRow(process: process,
                               isProtected: model.isProtected(process),
                               isSelected: Binding(
                                   get: { model.selection.contains(process.pid) },
                                   set: { selected in
                                       if selected {
                                           model.selection.insert(process.pid)
                                       } else {
                                           model.selection.remove(process.pid)
                                       }
                                   }))
                }
            }
        }
        .frame(maxHeight: 240)
    }

    private var actions: some View {
        HStack {
            Button {
                model.reapCandidates()
            } label: {
                Label("Limpiar huérfanos", systemImage: "sparkles")
            }
            .disabled(model.candidates.isEmpty || model.isBusy)
            .keyboardShortcut(.defaultAction)

            Spacer()

            Button("Terminar selección (\(model.selection.count))", role: .destructive) {
                model.killSelected()
            }
            .disabled(model.selection.isEmpty || model.isBusy)
        }
        .controlSize(.small)
    }
}

private struct ProcessRow: View {
    let process: NodeProcess
    let isProtected: Bool
    @Binding var isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Toggle("", isOn: $isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(process.isZombie)
            VStack(alignment: .leading, spacing: 2) {
                Text(process.shortCommand)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 4) {
                    Text(details)
                    if process.isOrphan { Badge(text: "huérfano", color: .orange) }
                    if process.isStopped { Badge(text: "suspendido", color: .yellow) }
                    if process.isZombie { Badge(text: "zombi", color: .gray) }
                    if isProtected { Badge(text: "protegido", color: .blue) }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text(NodeReaperModel.format(mb: process.memoryMB))
                .font(.system(.caption, design: .monospaced))
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .help(process.command)
    }

    private var details: String {
        var parts = ["pid \(process.pid)", process.elapsedDescription]
        if let project = process.projectHint { parts.append(project) }
        return parts.joined(separator: " · ")
    }
}

private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}
