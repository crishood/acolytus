import ServiceManagement
import SwiftUI

@MainActor
struct RootView: View {
    let modules: [any AcolytusModule]
    @AppStorage("acolytus.selectedModule") private var selectedID = ""

    private var selected: any AcolytusModule {
        modules.first { $0.id == selectedID } ?? modules[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            selected.makeView()
                .id(selected.id)
                .padding(12)
            Divider()
            footer
        }
        .frame(width: 360)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text("Acolytus")
                .font(.headline)
            Spacer()
            ForEach(modules.indices, id: \.self) { index in
                let module = modules[index]
                Button {
                    selectedID = module.id
                } label: {
                    Image(systemName: module.symbol)
                        .frame(width: 26, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(module.id == selected.id ? Color.accentColor.opacity(0.2) : .clear)
                        )
                }
                .buttonStyle(.plain)
                .help(module.title)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack {
            LaunchAtLoginToggle()
            Spacer()
            Button("Salir") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .keyboardShortcut("q")
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

private struct LaunchAtLoginToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Abrir al iniciar sesión", isOn: Binding(
            get: { enabled },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    NSLog("Acolytus: no se pudo cambiar el inicio de sesión: \(error)")
                }
                enabled = SMAppService.mainApp.status == .enabled
            }
        ))
        .toggleStyle(.checkbox)
    }
}
