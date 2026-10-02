import AcolytusCore
import Darwin
import Foundation

@MainActor
final class NodeReaperModel: ObservableObject {
    @Published private(set) var processes: [NodeProcess] = []
    @Published var selection: Set<Int32> = []
    @Published private(set) var status: String?
    @Published private(set) var isBusy = false

    /// Subcadenas separadas por comas; los procesos cuyo comando las contenga
    /// nunca se marcan para limpieza automática.
    @Published var protectedPatterns: String {
        didSet { UserDefaults.standard.set(protectedPatterns, forKey: Self.protectedKey) }
    }

    private static let protectedKey = "node-reaper.protectedPatterns"

    init() {
        protectedPatterns = UserDefaults.standard.string(forKey: Self.protectedKey) ?? ""
    }

    var candidates: [NodeProcess] {
        processes.filter { $0.isReapCandidate && !isProtected($0) }
    }

    var totalMB: Double { processes.reduce(0) { $0 + $1.memoryMB } }

    func isProtected(_ process: NodeProcess) -> Bool {
        protectedPatterns
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .contains { !$0.isEmpty && process.command.localizedCaseInsensitiveContains($0) }
    }

    /// Vuelve a leer los procesos. `message` se muestra al terminar.
    func refresh(message: String? = nil) {
        guard !isBusy else { return }
        isBusy = true
        Task {
            do {
                let found = try await Task.detached(priority: .userInitiated) {
                    try NodeScanner.scan()
                }.value
                processes = found
                selection = Set(candidates.map(\.pid))
                status = message
            } catch {
                status = "No se pudo leer la lista de procesos: \(error.localizedDescription)"
            }
            isBusy = false
        }
    }

    func reapCandidates() {
        terminate(candidates)
    }

    func killSelected() {
        terminate(processes.filter { selection.contains($0.pid) })
    }

    private func terminate(_ targets: [NodeProcess]) {
        let targets = targets.filter { !$0.isZombie }
        guard !targets.isEmpty, !isBusy else { return }
        isBusy = true
        Task {
            let result = await ProcessTerminator.terminate(targets)
            let freed = result.killed.reduce(0) { $0 + $1.memoryMB }
            var message = "Liberados \(Self.format(mb: freed)) · \(result.killed.count) proceso(s)"
            if !result.survivors.isEmpty {
                message += " · \(result.survivors.count) se resistieron"
            }
            isBusy = false
            refresh(message: message)
        }
    }

    static func format(mb: Double) -> String {
        mb >= 1024 ? String(format: "%.1f GB", mb / 1024) : String(format: "%.0f MB", mb)
    }
}

enum NodeScanner {
    static func scan() throws -> [NodeProcess] {
        let stats = try Shell.run("/bin/ps", PSParser.statsArguments).output
        let args = try Shell.run("/bin/ps", PSParser.argsArguments).output
        return PSParser.nodeProcesses(statsOutput: stats, argsOutput: args,
                                      uid: getuid(), excluding: getpid())
    }
}

enum ProcessTerminator {
    struct Outcome {
        var killed: [NodeProcess] = []
        var survivors: [NodeProcess] = []
    }

    /// SIGTERM con cortesía; SIGKILL a quien siga vivo tras un momento.
    static func terminate(_ targets: [NodeProcess]) async -> Outcome {
        for process in targets {
            kill(process.pid, SIGTERM)
            // Un proceso suspendido no atiende SIGTERM hasta que se reanuda.
            if process.isStopped { kill(process.pid, SIGCONT) }
        }
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        let stubborn = targets.filter(isAlive)
        for process in stubborn {
            kill(process.pid, SIGKILL)
        }
        if !stubborn.isEmpty {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        var outcome = Outcome()
        for process in targets {
            if isAlive(process) {
                outcome.survivors.append(process)
            } else {
                outcome.killed.append(process)
            }
        }
        return outcome
    }

    private static func isAlive(_ process: NodeProcess) -> Bool {
        kill(process.pid, 0) == 0 || errno == EPERM
    }
}
