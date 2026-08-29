//
//  PortHistoryManager.swift
//  Portly
//

import Foundation
import Observation

/// Manages persistent history and analytics of listening port sessions across app launches.
@Observable
@MainActor
final class PortHistoryManager {
    static let shared = PortHistoryManager()

    private static let maxRecords = 500
    private static let historyFilename = "port_history.json"

    private(set) var records: [PortHistoryRecord] = []
    @ObservationIgnored private var activeSessionMap: [String: UUID] = [:]

    init() {
        loadHistory()
    }

    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let portlyDir = appSupport.appendingPathComponent("Portly", isDirectory: true)
        try? FileManager.default.createDirectory(at: portlyDir, withIntermediateDirectories: true)
        return portlyDir.appendingPathComponent(Self.historyFilename)
    }

    func loadHistory() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([PortHistoryRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded
        // Rebuild active map
        activeSessionMap = [:]
        for record in records where record.isActive {
            activeSessionMap[record.sessionKey] = record.id
        }
    }

    func saveHistory() {
        guard let data = try? JSONEncoder().encode(records.prefix(Self.maxRecords).map { $0 }) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    /// Called on every scan cycle to update active sessions and detect newly opened or closed listeners.
    func recordScan(activePorts: [ListeningPort]) {
        let now = Date.now
        let nonSystemPorts = activePorts.filter { !$0.isSystemProcess }
        var currentKeys = Set<String>()

        for port in nonSystemPorts {
            let key = "\(port.pid):\(port.port):\(port.networkProtocol.rawValue)"
            currentKeys.insert(key)

            if let existingID = activeSessionMap[key],
               let idx = records.firstIndex(where: { $0.id == existingID }) {
                // Update existing active record
                if port.establishedConnections > records[idx].peakConnections {
                    records[idx].peakConnections = port.establishedConnections
                }
                if let alias = port.customAlias, records[idx].customAlias != alias {
                    records[idx].customAlias = alias
                }
                if let smart = port.smartDescriptor, records[idx].smartDescriptor != smart {
                    records[idx].smartDescriptor = smart
                }
            } else {
                // New session started
                let cwd = ProcessInspector.currentWorkingDirectory(for: port.pid)
                let record = PortHistoryRecord(
                    id: UUID(),
                    port: port.port,
                    processName: port.processName,
                    pid: port.pid,
                    networkProtocol: port.networkProtocol.rawValue,
                    address: port.address,
                    executablePath: port.executablePath,
                    currentWorkingDirectory: cwd,
                    customAlias: port.customAlias,
                    smartDescriptor: port.smartDescriptor,
                    containerName: port.containerName,
                    startedAt: now,
                    stoppedAt: nil,
                    peakConnections: port.establishedConnections
                )
                records.insert(record, at: 0)
                activeSessionMap[key] = record.id
            }
        }

        // Close any sessions that are no longer active
        for (key, id) in activeSessionMap where !currentKeys.contains(key) {
            if let idx = records.firstIndex(where: { $0.id == id }) {
                records[idx].stoppedAt = now
            }
            activeSessionMap.removeValue(forKey: key)
        }

        // Trim older records beyond limit
        if records.count > Self.maxRecords {
            records = Array(records.prefix(Self.maxRecords))
        }

        saveHistory()
    }

    func clearHistory() {
        records.removeAll()
        activeSessionMap.removeAll()
        try? FileManager.default.removeItem(at: storageURL)
    }

    // MARK: - Analytics

    var totalSessions: Int {
        records.count
    }

    var uniquePortsCount: Int {
        Set(records.map(\.port)).count
    }

    var mostUsedPorts: [(port: Int, count: Int)] {
        let counts = Dictionary(grouping: records, by: \.port).mapValues(\.count)
        return counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    var longestSession: PortHistoryRecord? {
        records.max(by: { $0.duration < $1.duration })
    }

    var totalTrackedSeconds: TimeInterval {
        records.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Export

    func export(format: ExportFormat) -> String {
        switch format {
        case .markdown:
            var lines = [
                "| Port | Process | Proto | Duration | Started | Stopped | CWD |",
                "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |"
            ]
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            for r in records {
                let dur = Duration.seconds(r.duration).formatted(.time(pattern: .hourMinuteSecond))
                let started = formatter.string(from: r.startedAt)
                let stopped = r.stoppedAt.map { formatter.string(from: $0) } ?? "Active"
                let cwd = r.currentWorkingDirectory ?? "-"
                lines.append("| \(r.port) | \(r.displayName) | \(r.networkProtocol) | \(dur) | \(started) | \(stopped) | `\(cwd)` |")
            }
            return lines.joined(separator: "\n")

        case .csv:
            var lines = ["Port,Process,PID,Protocol,DurationSeconds,StartedAt,StoppedAt,WorkingDirectory,PeakConnections"]
            let iso = ISO8601DateFormatter()
            for r in records {
                let started = iso.string(from: r.startedAt)
                let stopped = r.stoppedAt.map { iso.string(from: $0) } ?? ""
                let cwd = (r.currentWorkingDirectory ?? "").replacingOccurrences(of: "\"", with: "\"\"")
                let name = r.displayName.replacingOccurrences(of: "\"", with: "\"\"")
                lines.append("\(r.port),\"\(name)\",\(r.pid),\(r.networkProtocol),\(Int(r.duration)),\(started),\(stopped),\"\(cwd)\",\(r.peakConnections)")
            }
            return lines.joined(separator: "\n")

        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(records),
                  let json = String(data: data, encoding: .utf8) else {
                return "[]"
            }
            return json
        }
    }
}
