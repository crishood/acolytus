import Foundation

enum Shell {
    struct Result {
        let status: Int32
        let output: String
    }

    /// Ejecuta un binario y devuelve su salida estándar. Bloqueante: llámalo
    /// fuera del hilo principal.
    @discardableResult
    static func run(_ path: String, _ arguments: [String]) throws -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        // Leer antes de esperar evita bloquearse si la salida llena el pipe.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Result(status: process.terminationStatus,
                      output: String(decoding: data, as: UTF8.self))
    }
}
