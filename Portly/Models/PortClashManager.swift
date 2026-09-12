//
//  PortClashManager.swift
//  Portly
//

import Foundation

/// Represents a process occupying a specific port.
struct PortOccupant: Identifiable {
    var id: String { "\(pid):\(port)" }
    let port: Int
    let pid: Int32
    let processName: String
    let user: String?
    let executablePath: String?
    let commandLine: [String]?
    let isOwnedByCurrentUser: Bool
}

/// Discovers and frees processes occupying specific ports to resolve EADDRINUSE errors.
enum PortClashManager {
    /// Inspects whether a specific port is currently occupied, running a direct lsof check.
    static func inspectPort(_ port: Int) async -> PortOccupant? {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "+c", "0", "-FpcLnPT"]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            var output = ""
            for try await line in stdout.fileHandleForReading.bytes.lines {
                output.append(line)
                output.append("\n")
            }
            process.waitUntilExit()

            var pid: Int32?
            var command: String?
            var user: String?

            for line in output.split(separator: "\n") {
                guard let field = line.first else { continue }
                let value = String(line.dropFirst())
                switch field {
                case "p":
                    pid = Int32(value)
                case "c":
                    command = value
                case "L":
                    user = value
                default:
                    break
                }
            }

            guard let foundPid = pid, let foundCmd = command else { return nil }

            var path: String?
            var buffer = [CChar](repeating: 0, count: 4096)
            if proc_pidpath(foundPid, &buffer, UInt32(buffer.count)) > 0 {
                path = String(cString: buffer)
            }

            let (args, _) = ProcessInspector.procArgs(for: foundPid)

            return PortOccupant(
                port: port,
                pid: foundPid,
                processName: foundCmd,
                user: user,
                executablePath: path,
                commandLine: args,
                isOwnedByCurrentUser: user == NSUserName()
            )
        } catch {
            return nil
        }
    }

    /// Frees the port by terminating the occupant process.
    static func freePort(occupant: PortOccupant, force: Bool = false) async -> Bool {
        guard occupant.isOwnedByCurrentUser, occupant.pid > 0 else { return false }
        let signal = force ? SIGKILL : SIGTERM
        let res = kill(occupant.pid, signal)
        if res == 0 {
            // Give it a brief moment to release socket
            try? await Task.sleep(for: .milliseconds(300))
            return true
        }
        return false
    }
}
