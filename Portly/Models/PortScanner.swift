//
//  PortScanner.swift
//  Portly
//

import Foundation

/// Runs `lsof` and parses its machine-readable output into `ListeningPort` values.
enum PortScanner {
    /// Lists every TCP socket in LISTEN state and every bound UDP socket.
    static func scan() async throws -> [ListeningPort] {
        #if APPSTORE
        // The sandbox forbids inspecting other processes via lsof (and reaching
        // the Docker socket); read the kernel socket tables directly instead.
        return SysctlPortScanner.scan()
        #else
        return try await lsofScan()
        #endif
    }

    /// Runs lsof and enriches the results with executable paths and
    /// Docker container names. Direct-download build only.
    private static func lsofScan() async throws -> [ListeningPort] {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/sbin/lsof")
        // -F emits one field per line: p = pid, c = command, L = login name,
        // P = protocol, n = address, T = TCP state info. +c 0 disables
        // command-name truncation. All TCP sockets are listed (not just
        // listeners) so established connections can be counted per port.
        process.arguments = ["-nP", "-iTCP", "-iUDP", "+c", "0", "-FpcLnPT"]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        try process.run()

        var output = ""
        for try await line in stdout.fileHandleForReading.bytes.lines {
            output.append(line)
            output.append("\n")
        }
        process.waitUntilExit()

        var ports = parse(output).map { port in
            var port = port
            port.executablePath = executablePath(for: port.pid)
            if port.isOwnedByCurrentUser {
                let (args, _) = ProcessInspector.procArgs(for: port.pid)
                if let args {
                    port.smartDescriptor = SmartProcessDescriptor.describe(
                        processName: port.processName,
                        executablePath: port.executablePath,
                        arguments: args
                    )
                }
            }
            return port
        }

        // When Docker's port proxy owns sockets, resolve which container each
        // published port belongs to so rows can show the container name.
        if ports.contains(where: \.isDockerBackend) {
            let containerDetails = await DockerResolver.publishedPortDetails()
            if !containerDetails.isEmpty {
                ports = ports.map { port in
                    guard port.isDockerBackend, let details = containerDetails[port.port] else { return port }
                    var port = port
                    port.containerName = details.containerName
                    port.composeProject = details.composeProject
                    port.composeService = details.composeService
                    return port
                }
            }
        }

        return ports
    }

    /// Parses `lsof -F` field output. Pure so it can be tested without spawning lsof.
    static func parse(_ output: String) -> [ListeningPort] {
        var listeners: [ListeningPort] = []
        var connectionCounts: [Int: Int] = [:]
        var seen = Set<String>()
        var pid: Int32?
        var command: String?
        var user: String?
        var networkProtocol = NetworkProtocol.tcp
        var pendingTCPPort: (address: String, port: Int)?
        var pendingTCPConnection: (localAddress: String, localPort: Int, remoteAddress: String, remotePort: Int)?

        struct RawConnection {
            let pid: Int32?
            let command: String?
            let localAddress: String
            let localPort: Int
            let remoteAddress: String
            let remotePort: Int
            let state: String
        }
        var allConnections: [RawConnection] = []
        var endpointOwner: [String: (command: String, pid: Int32)] = [:]

        func addListener(address: String, port: Int, protocol networkProtocol: NetworkProtocol) {
            guard let pid, let command,
                  seen.insert("\(pid):\(port):\(networkProtocol.rawValue)").inserted else { return }
            listeners.append(
                ListeningPort(
                    port: port,
                    pid: pid,
                    processName: command,
                    address: address,
                    user: user,
                    networkProtocol: networkProtocol
                )
            )
        }

        for line in output.split(separator: "\n") {
            guard let field = line.first else { continue }
            let value = String(line.dropFirst())

            switch field {
            case "p":
                pid = Int32(value)
                command = nil
                user = nil
                pendingTCPPort = nil
                pendingTCPConnection = nil
            case "c":
                command = value
            case "L":
                user = value
            case "P":
                networkProtocol = NetworkProtocol(rawValue: value) ?? .tcp
            case "f":
                pendingTCPPort = nil
                pendingTCPConnection = nil
            case "n":
                switch networkProtocol {
                case .udp:
                    // A UDP socket with a peer ("->") is connected, not listening.
                    guard !value.contains("->"),
                          let (address, port) = splitAddress(value) else { continue }
                    addListener(address: address, port: port, protocol: .udp)
                case .tcp:
                    if value.contains("->") {
                        let parts = value.split(separator: "->", maxSplits: 1)
                        if let local = splitAddress(String(parts[0])),
                           let remote = splitAddress(String(parts[1])) {
                            pendingTCPPort = (local.address, local.port)
                            pendingTCPConnection = (local.address, local.port, remote.address, remote.port)
                            if let pid, let command {
                                endpointOwner["\(local.address):\(local.port)"] = (command, pid)
                            }
                        }
                    } else {
                        pendingTCPPort = splitAddress(value)
                        pendingTCPConnection = nil
                    }
                }
            case "T":
                guard value.hasPrefix("ST=") else { continue }
                let state = String(value.dropFirst(3))
                if let pending = pendingTCPPort, pendingTCPConnection == nil {
                    pendingTCPPort = nil
                    if state == "LISTEN" {
                        addListener(address: pending.address, port: pending.port, protocol: .tcp)
                    }
                } else if let conn = pendingTCPConnection {
                    pendingTCPPort = nil
                    pendingTCPConnection = nil
                    if state == "ESTABLISHED" {
                        connectionCounts[conn.localPort, default: 0] += 1
                    }
                    allConnections.append(
                        RawConnection(
                            pid: pid,
                            command: command,
                            localAddress: conn.localAddress,
                            localPort: conn.localPort,
                            remoteAddress: conn.remoteAddress,
                            remotePort: conn.remotePort,
                            state: state
                        )
                    )
                }
            default:
                break
            }
        }

        return listeners
            .map { listener in
                var listener = listener
                if listener.networkProtocol == .tcp {
                    listener.establishedConnections = connectionCounts[listener.port] ?? 0
                    let conns = allConnections
                        .filter { $0.localPort == listener.port }
                        .map { raw in
                            let owner = endpointOwner["\(raw.remoteAddress):\(raw.remotePort)"]
                            return PortConnection(
                                localAddress: raw.localAddress,
                                localPort: raw.localPort,
                                remoteAddress: raw.remoteAddress,
                                remotePort: raw.remotePort,
                                state: raw.state,
                                clientProcessName: owner?.command,
                                clientPid: owner?.pid
                            )
                        }
                    listener.activeConnections = conns
                }
                return listener
            }
            .sorted()
    }

    /// Splits "127.0.0.1:8000", "*:3000", or "[::1]:8080" into address and port.
    /// Returns nil for unbound sockets like "*:*".
    private static func splitAddress(_ name: String) -> (address: String, port: Int)? {
        guard let colon = name.lastIndex(of: ":"),
              let port = Int(name[name.index(after: colon)...]),
              port > 0 else { return nil }

        var address = String(name[..<colon]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if address == "::" || address.isEmpty {
            address = "*"
        }
        return (address, port)
    }

    /// Resolves a pid to its executable path via libproc.
    private static func executablePath(for pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }
}
