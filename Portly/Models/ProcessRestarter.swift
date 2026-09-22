//
//  ProcessRestarter.swift
//  Portly
//

import Foundation
import AppKit

/// Gracefully stops and respawns running dev servers or Docker containers.
enum ProcessRestarter {
    /// Restarts a dev server process. If Docker, restarts the container.
    /// If native, terminates the process and respawns it with its original command line and working directory.
    @MainActor
    static func restart(_ port: ListeningPort, monitor: PortMonitor) async -> Bool {
        // 1. Docker containers
        if let container = port.containerName {
            let res = await DockerManager.restartContainer(container)
            await monitor.refresh()
            return res.success
        }

        // 2. Native dev servers
        guard port.isOwnedByCurrentUser, port.pid > 0, AppCapabilities.canTerminateProcesses else { return false }

        // Fetch original working directory and command arguments before termination
        let cwd = ProcessInspector.currentWorkingDirectory(for: port.pid)
        let (args, _) = ProcessInspector.procArgs(for: port.pid)

        guard let arguments = args, !arguments.isEmpty else { return false }

        // Send SIGTERM to old process
        kill(port.pid, SIGTERM)

        // Wait up to 3 seconds for port to be released
        for _ in 0..<15 {
            try? await Task.sleep(for: .milliseconds(200))
            if await PortClashManager.inspectPort(port.port) == nil {
                break
            }
        }

        // Re-spawn process using login shell to preserve environment and PATH (nvm, pyenv, homebrew)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")

        let commandString = arguments.map { arg in
            if arg.contains(" ") || arg.contains("\"") || arg.contains("'") {
                return "\"\(arg.replacingOccurrences(of: "\"", with: "\\\""))\""
            }
            return arg
        }.joined(separator: " ")

        process.arguments = ["-l", "-c", commandString]

        if let cwd, FileManager.default.fileExists(atPath: cwd) {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd, isDirectory: true)
        }

        // Run detached as background process
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            try? await Task.sleep(for: .milliseconds(600))
            await monitor.refresh()
            return true
        } catch {
            return false
        }
    }
}
