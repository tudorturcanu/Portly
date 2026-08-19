//
//  ProcessDetails.swift
//  Portly
//

import Foundation

/// Represents a single environment variable of a process.
struct EnvironmentVariable: Identifiable, Hashable {
    let key: String
    let value: String

    var id: String { key }

    /// Returns true if the variable key likely contains sensitive information like a secret, token, or password.
    var isSensitive: Bool {
        let lower = key.lowercased()
        return lower.contains("secret")
            || lower.contains("key")
            || lower.contains("password")
            || lower.contains("pass")
            || lower.contains("token")
            || lower.contains("auth")
            || lower.contains("cert")
            || lower.contains("credential")
            || lower.contains("private")
            || lower.contains("api_")
            || lower.contains("apikey")
    }

    /// Masked string representation (e.g. `sk_••••••••12`).
    var maskedValue: String {
        guard !value.isEmpty else { return "" }
        if value.count <= 6 {
            return String(repeating: "•", count: 8)
        }
        let prefix = value.prefix(3)
        let suffix = value.suffix(2)
        return "\(prefix)••••••••\(suffix)"
    }
}

/// Extra facts about a process, resolved on demand for the details popover.
/// Every field is optional — visibility of other processes varies by owner
/// and by edition (the sandbox hides more), and the UI simply omits gaps.
struct ProcessDetails {
    var arguments: [String]?
    var environmentVariables: [EnvironmentVariable]?
    var currentWorkingDirectory: String?
    var smartDescriptor: String?
    var startedAt: Date?
    var cpuTime: TimeInterval?
    var memoryBytes: UInt64?
}
