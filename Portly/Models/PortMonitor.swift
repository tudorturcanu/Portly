//
//  PortMonitor.swift
//  Portly
//

import Foundation
import Observation

/// Owns the list of listening ports, refreshes it in the background,
/// and posts notifications when ports open or close.
@Observable
@MainActor
final class PortMonitor {
    static let probeDefaultsKey = "probeLocalhostHTTP"
    private static let pinnedDefaultsKey = "pinnedPorts"
    private static let aliasesDefaultsKey = "customPortAliases"
    private static let ghostLifetime: TimeInterval = 300
    private static let probeInterval: TimeInterval = 15

    private(set) var ports: [ListeningPort] = []
    private(set) var recentlyClosed: [ClosedPort] = []
    private(set) var pinnedPorts: Set<Int> = []
    private(set) var customAliases: [Int: String] = [:]
    /// Port → last HTTP status code from the localhost health probe.
    private(set) var health: [Int: Int] = [:]
    /// Port -> recent established connection counts over scan samples (for sparkline).
    private(set) var connectionHistory: [Int: [Int]] = [:]
    private(set) var lastUpdated: Date?
    private(set) var isScanning = false
    var statusMessage: String?

    @ObservationIgnored private var monitoringTask: Task<Void, Never>?
    @ObservationIgnored private var lastProbeAt: [Int: Date] = [:]

    init(ports: [ListeningPort] = [], startsMonitoring: Bool = true) {
        if let stored = UserDefaults.standard.dictionary(forKey: Self.aliasesDefaultsKey) as? [String: String] {
            var loaded: [Int: String] = [:]
            for (key, val) in stored {
                if let p = Int(key) { loaded[p] = val }
            }
            self.customAliases = loaded
        }
        self.ports = ports.map { p in
            var copy = p
            if let alias = self.customAliases[p.port] { copy.customAlias = alias }
            return copy
        }
        pinnedPorts = Set(UserDefaults.standard.array(forKey: Self.pinnedDefaultsKey) as? [Int] ?? [])
        if startsMonitoring {
            startMonitoring()
        }
    }

    /// Count of non-system TCP listeners — what the menu bar badge shows.
    var devServerCount: Int {
        ports.count { !$0.isSystemProcess && $0.networkProtocol == .tcp }
    }

    /// Slow background scan so the badge and notifications stay current
    /// even while the panel is closed. The panel runs its own faster loop.
    func startMonitoring() {
        guard monitoringTask == nil else { return }
        monitoringTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    func refresh() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        do {
            let previous = ports
            let hadBaseline = lastUpdated != nil
            let scanned = try await PortScanner.scan()
            ports = scanned.map { p in
                var copy = p
                copy.customAlias = customAliases[p.port]
                return copy
            }
            lastUpdated = .now
            statusMessage = nil

            for p in ports {
                var hist = connectionHistory[p.port] ?? []
                hist.append(p.establishedConnections)
                if hist.count > 20 { hist.removeFirst() }
                connectionHistory[p.port] = hist
            }

            updateRecentlyClosed(from: previous, to: ports, hadBaseline: hadBaseline)
            TunnelManager.shared.pruneInactive(listeningPorts: ports)
            PortHistoryManager.shared.recordScan(activePorts: ports)
            if hadBaseline {
                await notifyChanges(from: previous, to: ports)
            }
            await probeHealthIfEnabled()
        } catch {
            statusMessage = "Scan failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Custom Aliases

    func setAlias(_ alias: String?, for port: Int) {
        let trimmed = alias?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            customAliases[port] = trimmed
        } else {
            customAliases.removeValue(forKey: port)
        }

        var dict: [String: String] = [:]
        for (key, val) in customAliases {
            dict[String(key)] = val
        }
        UserDefaults.standard.set(dict, forKey: Self.aliasesDefaultsKey)

        ports = ports.map { p in
            var copy = p
            copy.customAlias = customAliases[p.port]
            return copy
        }
    }

    // MARK: - Pinning

    func togglePin(_ port: Int) {
        if pinnedPorts.contains(port) {
            pinnedPorts.remove(port)
        } else {
            pinnedPorts.insert(port)
        }
        UserDefaults.standard.set(pinnedPorts.sorted(), forKey: Self.pinnedDefaultsKey)
    }

    /// Pinned port numbers with no listener at all right now.
    var deadPinnedPorts: [Int] {
        pinnedPorts.filter { pinned in !ports.contains { $0.port == pinned } }.sorted()
    }

    // MARK: - Stopping processes

    /// The current user's own dev servers — what "Stop All" targets.
    var userDevServers: [ListeningPort] {
        ports.filter { !$0.isSystemProcess && $0.networkProtocol == .tcp && $0.isOwnedByCurrentUser }
    }

    /// SIGTERMs every process with a non-system TCP listener owned by the user.
    func terminateAllDevServers() {
        guard AppCapabilities.canTerminateProcesses else { return }
        let ownPid = ProcessInfo.processInfo.processIdentifier
        let pids = Set(userDevServers.map(\.pid)).filter { $0 > 0 && $0 != ownPid }
        for pid in pids {
            kill(pid, SIGTERM)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await refresh()
        }
    }

    /// Asks the process behind `port` to exit — SIGTERM by default, SIGKILL when forced.
    /// No-op in the sandboxed App Store build, which cannot signal other processes.
    func terminate(_ port: ListeningPort, force: Bool = false) {
        guard AppCapabilities.canTerminateProcesses, port.pid > 0 else { return }

        if kill(port.pid, force ? SIGKILL : SIGTERM) != 0 {
            let reason = String(cString: strerror(errno))
            statusMessage = "Couldn't stop \(port.processName): \(reason)"
            return
        }

        statusMessage = nil
        Task {
            // Give the process a moment to exit before rescanning.
            try? await Task.sleep(for: .milliseconds(400))
            await refresh()
        }
    }

    // MARK: - Change tracking

    /// User software on a non-ephemeral port — what ghosts and notifications track.
    private func isInteresting(_ port: ListeningPort) -> Bool {
        !port.isSystemProcess && port.networkProtocol == .tcp && port.port < 49152
    }

    private func updateRecentlyClosed(from previous: [ListeningPort], to current: [ListeningPort], hadBaseline: Bool) {
        let cutoff = Date.now.addingTimeInterval(-Self.ghostLifetime)
        let currentIDs = Set(current.map { "\($0.port):\($0.networkProtocol.rawValue)" })

        // Ghosts expire, and leave immediately if the port comes back.
        recentlyClosed.removeAll { $0.closedAt < cutoff || currentIDs.contains($0.id) }

        guard hadBaseline else { return }
        for port in previous where isInteresting(port) {
            let id = "\(port.port):\(port.networkProtocol.rawValue)"
            guard !currentIDs.contains(id),
                  !recentlyClosed.contains(where: { $0.id == id }) else { continue }
            recentlyClosed.append(
                ClosedPort(
                    port: port.port,
                    displayName: port.displayName,
                    networkProtocol: port.networkProtocol,
                    closedAt: .now
                )
            )
        }
    }

    private func notifyChanges(from previous: [ListeningPort], to current: [ListeningPort]) async {
        guard PortNotifier.isEnabled else { return }

        let previousIDs = Set(previous.filter(isInteresting).map(\.id))
        let currentIDs = Set(current.filter(isInteresting).map(\.id))

        let added = current.filter { isInteresting($0) && !previousIDs.contains($0.id) }
        let removed = previous.filter { isInteresting($0) && !currentIDs.contains($0.id) }

        guard !added.isEmpty || !removed.isEmpty else { return }
        await PortNotifier.post(added: added, removed: removed)
    }

    // MARK: - Health probing

    /// Ports where speaking HTTP would only pollute the server's logs.
    private static let nonHTTPPorts: Set<Int> = [
        22, 25, 53, 631, 1025, 3306, 5432, 5900, 6379, 11211, 27017,
    ]

    private func probeHealthIfEnabled() async {
        guard UserDefaults.standard.bool(forKey: Self.probeDefaultsKey) else {
            if !health.isEmpty { health = [:] }
            lastProbeAt = [:]
            return
        }

        let now = Date.now
        let candidates = Set(
            ports
                .filter { isInteresting($0) && !Self.nonHTTPPorts.contains($0.port) }
                .map(\.port)
        )
        let due = candidates.filter { port in
            guard let last = lastProbeAt[port] else { return true }
            return now.timeIntervalSince(last) >= Self.probeInterval
        }

        if !due.isEmpty {
            for port in due { lastProbeAt[port] = now }
            await withTaskGroup(of: (Int, Int?).self) { group in
                for port in due.prefix(16) {
                    group.addTask { await Self.probe(port: port) }
                }
                for await (port, status) in group {
                    if let status {
                        health[port] = status
                    } else {
                        health.removeValue(forKey: port)
                    }
                }
            }
        }

        // Drop results for ports that stopped listening.
        health = health.filter { candidates.contains($0.key) }
    }

    private static let probeSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1.5
        configuration.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: configuration)
    }()

    private static func probe(port: Int) async -> (Int, Int?) {
        guard let url = URL(string: "http://localhost:\(port)/") else { return (port, nil) }
        do {
            let (_, response) = try await probeSession.data(from: url)
            return (port, (response as? HTTPURLResponse)?.statusCode)
        } catch {
            // Not speaking HTTP (or not answering) — show no health dot.
            return (port, nil)
        }
    }
}

extension PortMonitor {
    /// Sample data for SwiftUI previews.
    static var preview: PortMonitor {
        PortMonitor(
            ports: [
                ListeningPort(port: 3000, pid: 501, processName: "node", address: "*", user: NSUserName(), executablePath: "/opt/homebrew/bin/node", establishedConnections: 2),
                ListeningPort(port: 5353, pid: 504, processName: "chronyd", address: "*", user: NSUserName(), networkProtocol: .udp, executablePath: "/opt/homebrew/sbin/chronyd"),
                ListeningPort(port: 5432, pid: 502, processName: "com.docker.backend", address: "127.0.0.1", user: NSUserName(), executablePath: "/Applications/Docker.app/Contents/MacOS/com.docker.backend", containerName: "myapp-db"),
                ListeningPort(port: 7000, pid: 503, processName: "ControlCenter", address: "*", user: NSUserName(), executablePath: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter"),
            ],
            startsMonitoring: false
        )
    }
}
