//
//  PortNotifier.swift
//  Portly
//

import Foundation
import UserNotifications

/// Posts macOS notifications when ports open or close.
enum PortNotifier {
    static let defaultsKey = "notifyPortChanges"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func post(added: [ListeningPort], removed: [ListeningPort]) async {
        var lines = added.map { "\($0.displayName) started listening on :\($0.port)" }
        lines += removed.map { "\($0.displayName) stopped listening on :\($0.port)" }
        guard !lines.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "Portly"
        content.body = lines.prefix(4).joined(separator: "\n")
        if lines.count > 4 {
            content.body += "\n…and \(lines.count - 4) more"
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
