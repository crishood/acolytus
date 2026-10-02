import AppKit
import SwiftUI

@main
struct AcolytusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Acolytus", systemImage: "flame") {
            RootView(modules: ModuleRegistry.modules)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Sin icono en el Dock: sólo la llama en la barra de menú.
        NSApp.setActivationPolicy(.accessory)
    }
}
