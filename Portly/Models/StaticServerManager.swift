//
//  StaticServerManager.swift
//  Portly
//

import Foundation
import AppKit

/// Represents an active local static HTTP server managed by Portly.
struct ManagedStaticServer: Identifiable {
    let id = UUID()
    let port: Int
    let directoryPath: String
    let process: Process
    let startedAt: Date

    var directoryName: String {
        URL(fileURLWithPath: directoryPath).lastPathComponent
    }

    var localURL: URL? {
        URL(string: "http://localhost:\(port)")
    }
}

/// Spawns and tracks lightweight local HTTP file servers for arbitrary folders.
@Observable
@MainActor
final class StaticServerManager {
    static let shared = StaticServerManager()

    private(set) var activeServers: [ManagedStaticServer] = []

    /// Starts serving the specified directory on the specified port.
    func startServer(directoryPath: String, port: Int) -> Bool {
        guard FileManager.default.fileExists(atPath: directoryPath) else { return false }
        guard !activeServers.contains(where: { $0.port == port }) else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-m", "http.server", "\(port)", "--directory", directoryPath]

        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let server = ManagedStaticServer(
                port: port,
                directoryPath: directoryPath,
                process: process,
                startedAt: .now
            )
            activeServers.append(server)
            return true
        } catch {
            return false
        }
    }

    /// Stops the static server running on the specified port.
    func stopServer(port: Int) {
        guard let index = activeServers.firstIndex(where: { $0.port == port }) else { return }
        let server = activeServers[index]
        server.process.terminate()
        activeServers.remove(at: index)
    }

    /// Checks if a port is currently being served by Portly's static server.
    func isServing(port: Int) -> Bool {
        activeServers.contains(where: { $0.port == port })
    }
}
