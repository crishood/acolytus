import Foundation

/// Un proceso de Node visto a través de `ps`.
public struct NodeProcess: Identifiable, Equatable, Sendable {
    public let pid: Int32
    public let ppid: Int32
    public let uid: UInt32
    /// Memoria residente en KB.
    public let rssKB: Int
    /// Estado de `ps` (p. ej. `S`, `R`, `T`, `Z`, `Ss+`).
    public let state: String
    public let elapsedSeconds: Int
    /// Ruta del ejecutable (`comm`), p. ej. `/opt/homebrew/bin/node`.
    public let executable: String
    /// Línea de comando completa (`args`).
    public let command: String

    public var id: Int32 { pid }

    public init(pid: Int32, ppid: Int32, uid: UInt32, rssKB: Int, state: String,
                elapsedSeconds: Int, executable: String, command: String) {
        self.pid = pid
        self.ppid = ppid
        self.uid = uid
        self.rssKB = rssKB
        self.state = state
        self.elapsedSeconds = elapsedSeconds
        self.executable = executable
        self.command = command
    }

    /// Su padre murió y lo adoptó `launchd` (PPID 1): el típico servidor de
    /// desarrollo que sobrevivió a la terminal que lo lanzó.
    public var isOrphan: Bool { ppid == 1 }

    /// Suspendido (Ctrl+Z y olvidado): sigue ocupando memoria sin hacer nada.
    public var isStopped: Bool { state.hasPrefix("T") }

    /// Zombi: ya no ocupa memoria y no se puede matar; sólo su padre lo recoge.
    public var isZombie: Bool { state.hasPrefix("Z") }

    /// Candidato a limpieza automática.
    public var isReapCandidate: Bool { !isZombie && (isOrphan || isStopped) }

    public var memoryMB: Double { Double(rssKB) / 1024 }

    /// Nombre del proyecto deducido de la ruta `…/<proyecto>/node_modules/…`.
    public var projectHint: String? {
        guard let range = command.range(of: "/node_modules/") else { return nil }
        let prefix = command[..<range.lowerBound]
        let path = prefix.split(separator: " ").last.map(String.init) ?? String(prefix)
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? nil : name
    }

    /// Comando legible: sin la ruta de `node` y con rutas reducidas a su último componente.
    public var shortCommand: String {
        var tokens = command.split(separator: " ").map(String.init)
        if let first = tokens.first, PSParser.isNodeBinary(first) {
            tokens.removeFirst()
        }
        let short = tokens.prefix(4).map { token -> String in
            token.contains("/") ? (token as NSString).lastPathComponent : token
        }
        let joined = short.joined(separator: " ")
        return joined.isEmpty ? "node" : joined
    }

    public var elapsedDescription: String {
        let days = elapsedSeconds / 86_400
        let hours = (elapsedSeconds % 86_400) / 3_600
        let minutes = (elapsedSeconds % 3_600) / 60
        if days > 0 { return "\(days) d \(hours) h" }
        if hours > 0 { return "\(hours) h \(minutes) min" }
        if minutes > 0 { return "\(minutes) min" }
        return "\(elapsedSeconds) s"
    }
}
