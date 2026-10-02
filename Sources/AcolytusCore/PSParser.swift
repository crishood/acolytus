import Foundation

/// Interpreta la salida de `ps` de macOS.
///
/// Se usan dos llamadas porque `comm` y `args` pueden contener espacios y
/// sólo uno de ellos puede ir al final de la línea:
///
///     ps -ax   -o pid=,ppid=,uid=,rss=,stat=,etime=,comm=
///     ps -axww -o pid=,args=
public enum PSParser {
    public static let statsArguments = ["-ax", "-o", "pid=,ppid=,uid=,rss=,stat=,etime=,comm="]
    public static let argsArguments = ["-axww", "-o", "pid=,args="]

    struct StatRow: Equatable {
        let pid: Int32
        let ppid: Int32
        let uid: UInt32
        let rssKB: Int
        let state: String
        let elapsedSeconds: Int
        let executable: String
    }

    /// Procesos de Node del usuario `uid`, ordenados por memoria descendente.
    public static func nodeProcesses(statsOutput: String, argsOutput: String,
                                     uid: UInt32, excluding ownPID: Int32) -> [NodeProcess] {
        let args = parseArgs(argsOutput)
        return parseStats(statsOutput)
            .filter { $0.uid == uid && $0.pid != ownPID }
            .compactMap { row -> NodeProcess? in
                let command = args[row.pid] ?? row.executable
                guard isNode(executable: row.executable, command: command) else { return nil }
                return NodeProcess(pid: row.pid, ppid: row.ppid, uid: row.uid, rssKB: row.rssKB,
                                   state: row.state, elapsedSeconds: row.elapsedSeconds,
                                   executable: row.executable, command: command)
            }
            .sorted { $0.rssKB > $1.rssKB }
    }

    /// `comm` conserva el nombre real del binario aunque el proceso cambie su
    /// título (Next.js se renombra a `next-server`, por ejemplo).
    public static func isNode(executable: String, command: String) -> Bool {
        if isNodeBinary(executable) { return true }
        guard let first = command.split(separator: " ").first else { return false }
        return isNodeBinary(String(first))
    }

    public static func isNodeBinary(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent
        return name == "node" || name == "nodejs"
    }

    static func parseStats(_ output: String) -> [StatRow] {
        output.split(whereSeparator: \.isNewline).compactMap { line -> StatRow? in
            let (fields, rest) = splitFields(String(line), leading: 6)
            guard fields.count == 6,
                  let pid = Int32(fields[0]),
                  let ppid = Int32(fields[1]),
                  let uid = UInt32(fields[2]),
                  let rss = Int(fields[3]),
                  let elapsed = parseElapsed(fields[5]),
                  !rest.isEmpty
            else { return nil }
            return StatRow(pid: pid, ppid: ppid, uid: uid, rssKB: rss, state: fields[4],
                           elapsedSeconds: elapsed, executable: rest)
        }
    }

    static func parseArgs(_ output: String) -> [Int32: String] {
        var result: [Int32: String] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            let (fields, rest) = splitFields(String(line), leading: 1)
            guard let first = fields.first, let pid = Int32(first) else { continue }
            result[pid] = rest
        }
        return result
    }

    /// Formato de `etime`: `[[dd-]hh:]mm:ss`.
    public static func parseElapsed(_ value: String) -> Int? {
        var days = 0
        var clock = Substring(value)
        if let dash = value.firstIndex(of: "-") {
            guard let d = Int(value[..<dash]) else { return nil }
            days = d
            clock = value[value.index(after: dash)...]
        }
        let parts = clock.split(separator: ":").map { Int($0) }
        guard !parts.isEmpty, parts.count <= 3, !parts.contains(where: { $0 == nil }) else { return nil }
        let seconds = parts.compactMap { $0 }.reduce(0) { $0 * 60 + $1 }
        return days * 86_400 + seconds
    }

    /// Separa los primeros `leading` campos (delimitados por espacios) y
    /// devuelve el resto de la línea sin espacios en los extremos.
    static func splitFields(_ line: String, leading: Int) -> ([String], String) {
        var fields: [String] = []
        var index = line.startIndex
        while fields.count < leading {
            while index < line.endIndex, line[index].isWhitespace { index = line.index(after: index) }
            guard index < line.endIndex else { break }
            let start = index
            while index < line.endIndex, !line[index].isWhitespace { index = line.index(after: index) }
            fields.append(String(line[start..<index]))
        }
        let rest = line[index...].trimmingCharacters(in: .whitespaces)
        return (fields, rest)
    }
}
