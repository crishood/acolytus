import SwiftUI

struct QuoteCaptureView: View {
    @ObservedObject var model: QuoteCaptureModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Selecciona la publicación en pantalla; revisas autor y texto antes de guardarla.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button {
                    model.captureFromScreen()
                } label: {
                    Label("Capturar pantalla", systemImage: "viewfinder")
                }
                .keyboardShortcut(.defaultAction)

                Button {
                    model.captureFromClipboard()
                } label: {
                    Label("Del portapapeles", systemImage: "doc.on.clipboard")
                }
                Spacer()
                if model.isBusy { ProgressView().controlSize(.small) }
            }
            .controlSize(.small)
            .disabled(model.isBusy)

            HStack(spacing: 4) {
                Image(systemName: "folder")
                Text(model.folderDisplay)
                    .lineLimit(1)
                    .truncationMode(.head)
                Spacer()
                Button("Cambiar…") { model.chooseFolder() }
                    .buttonStyle(.link)
            }
            .font(.caption)

            if let status = model.status {
                HStack {
                    Text(status)
                        .lineLimit(2)
                    Spacer()
                    if model.lastSaved != nil {
                        Button("Abrir") { model.openLastSaved() }
                            .buttonStyle(.link)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
