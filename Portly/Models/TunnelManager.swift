//
//  TunnelManager.swift
//  Portly
//

import AppKit
import Foundation
import Observation

/// Represents an active public tunnel exposing a local port.
struct ActiveTunnel: Identifiable {
    let port: Int
    let publicURL: URL
    let toolName: String
    let startedAt: Date
    @ObservationIgnored let process: Process?

    var id: Int { port }
}

/// Manages background tunnel processes (cloudflared, localtunnel, ngrok)
/// and tracks active public URLs.
@Observable
@MainActor
final class TunnelManager {
    static let shared = TunnelManager()

    private(set) var activeTunnels: [Int: ActiveTunnel] = [:]
    private(set) var startingPorts: Set<Int> = []
    private(set) var lastError: String?

    func isTunneling(_ port: Int) -> Bool {
        activeTunnels[port] != nil
    }

    func isStarting(_ port: Int) -> Bool {
        startingPorts.contains(port)
    }

    func tunnelURL(for port: Int) -> URL? {
        activeTunnels[port]?.publicURL
    }

    /// Discovers available tunnel tools in standard paths or PATH.
    nonisolated static func findToolPath(_ tool: String) -> String? {
        let candidatePaths = [
            "/opt/homebrew/bin/\(tool)",
            "/usr/local/bin/\(tool)",
            "/usr/bin/\(tool)",
            "~/.nvm/current/bin/\(tool)",
        ]

        let fileManager = FileManager.default
        for path in candidatePaths {
            let expanded = (path as NSString).expandingTildeInPath
            if fileManager.isExecutableFile(atPath: expanded) {
                return expanded
            }
        }
        return nil
    }

    /// Pure parser to extract public tunnel URL from log output.
    nonisolated static func parseTunnelURL(from text: String) -> URL? {
        // Cloudflare: https://*.trycloudflare.com
        if let match = text.firstMatch(of: /https:\/\/[a-zA-Z0-9-]+\.trycloudflare\.com/) {
            return URL(string: String(match.output))
        }

        // Localtunnel: https://*.loca.lt
        if let match = text.firstMatch(of: /https:\/\/[a-zA-Z0-9-]+\.loca\.lt/) {
            return URL(string: String(match.output))
        }

        // ngrok: https://*.ngrok-free.app or https://*.ngrok.io or https://*.ngrok.app
        if let match = text.firstMatch(of: /https:\/\/[a-zA-Z0-9-]+\.(?:ngrok-free\.app|ngrok\.io|ngrok\.app)/) {
            return URL(string: String(match.output))
        }

        return nil
    }

    /// Starts a public tunnel for the given local port.
    func startTunnel(for port: Int) async {
        guard activeTunnels[port] == nil, !startingPorts.contains(port) else { return }

        startingPorts.insert(port)
        lastError = nil
        defer { startingPorts.remove(port) }

        do {
            let tunnel = try await launchTunnelProcess(for: port)
            activeTunnels[port] = tunnel

            // Copy to pasteboard
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(tunnel.publicURL.absoluteString, forType: .string)
        } catch {
            lastError = "Tunnel failed for :\(port): \(error.localizedDescription)"
        }
    }

    /// Stops the tunnel for a specific port.
    func stopTunnel(for port: Int) {
        guard let tunnel = activeTunnels.removeValue(forKey: port) else { return }
        tunnel.process?.terminate()
    }

    /// Stops all running tunnels.
    func stopAll() {
        for (_, tunnel) in activeTunnels {
            tunnel.process?.terminate()
        }
        activeTunnels.removeAll()
    }

    /// Cleans up tunnels for ports that are no longer active.
    func pruneInactive(listeningPorts: [ListeningPort]) {
        let activePortNumbers = Set(listeningPorts.map(\.port))
        for port in activeTunnels.keys where !activePortNumbers.contains(port) {
            stopTunnel(for: port)
        }
    }

    private func launchTunnelProcess(for port: Int) async throws -> ActiveTunnel {
        let (executable, arguments, toolName) = try selectTunnelRunner(for: port)

        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments

        var environment = ProcessInfo.processInfo.environment
        let path = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(path)"
        process.environment = environment

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        // Asynchronously scan output lines for public URL
        let url = try await withThrowingTaskGroup(of: URL?.self) { group in
            group.addTask {
                for try await line in outputPipe.fileHandleForReading.bytes.lines {
                    if let parsed = Self.parseTunnelURL(from: line) {
                        return parsed
                    }
                }
                return nil
            }

            group.addTask {
                try await Task.sleep(for: .seconds(12))
                return nil
            }

            guard let firstResult = try await group.next(), let resolvedURL = firstResult else {
                process.terminate()
                throw NSError(
                    domain: "PortlyTunnel",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for tunnel URL from \(toolName). Make sure \(toolName) is installed."]
                )
            }
            group.cancelAll()
            return resolvedURL
        }

        return ActiveTunnel(
            port: port,
            publicURL: url,
            toolName: toolName,
            startedAt: .now,
            process: process
        )
    }

    private func selectTunnelRunner(for port: Int) throws -> (executable: String, arguments: [String], toolName: String) {
        if let cloudflared = Self.findToolPath("cloudflared") {
            return (cloudflared, ["tunnel", "--url", "http://localhost:\(port)"], "Cloudflare")
        }

        if let ngrok = Self.findToolPath("ngrok") {
            return (ngrok, ["http", "\(port)", "--log", "stdout"], "ngrok")
        }

        if let npx = Self.findToolPath("npx") {
            return (npx, ["localtunnel", "--port", "\(port)"], "localtunnel")
        }

        throw NSError(
            domain: "PortlyTunnel",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "No tunnel tool found. Install cloudflared (brew install cloudflared) or ngrok to use tunnels."]
        )
    }
}
