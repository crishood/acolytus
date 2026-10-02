// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Acolytus",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Acolytus", targets: ["Acolytus"]),
    ],
    targets: [
        // Lógica pura (sin AppKit): parseo de `ps`, parseo de frases y notas Markdown.
        .target(name: "AcolytusCore"),
        // La app de barra de menú y sus módulos.
        .executableTarget(name: "Acolytus", dependencies: ["AcolytusCore"]),
        .testTarget(name: "AcolytusCoreTests", dependencies: ["AcolytusCore"]),
    ]
)
