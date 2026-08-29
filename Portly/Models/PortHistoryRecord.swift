//
//  PortHistoryRecord.swift
//  Portly
//

import Foundation

/// A single recorded port session (active or completed) tracked in history.
struct PortHistoryRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let port: Int
    let processName: String
    let pid: Int32
    var networkProtocol: String = "TCP"
    var address: String = "*"
    var executablePath: String?
    var currentWorkingDirectory: String?
    var customAlias: String?
    var smartDescriptor: String?
    var containerName: String?
    let startedAt: Date
    var stoppedAt: Date?
    var peakConnections: Int = 0

    var isActive: Bool {
        stoppedAt == nil
    }

    var duration: TimeInterval {
        let end = stoppedAt ?? Date.now
        return max(0, end.timeIntervalSince(startedAt))
    }

    var displayName: String {
        customAlias ?? containerName ?? processName
    }

    var sessionKey: String {
        "\(pid):\(port):\(networkProtocol)"
    }
}
