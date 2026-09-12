//
//  PortConnection.swift
//  Portly
//

import Foundation

/// Represents an established or transitioning TCP peer connection to a listening port.
struct PortConnection: Identifiable, Hashable, Codable {
    var id: String { "\(localAddress):\(localPort)->\(remoteAddress):\(remotePort)" }
    let localAddress: String
    let localPort: Int
    let remoteAddress: String
    let remotePort: Int
    let state: String
    var clientProcessName: String?
    var clientPid: Int32?

    /// True when connected from loopback address (e.g., 127.0.0.1 or ::1).
    var isLocalhost: Bool {
        remoteAddress == "127.0.0.1" || remoteAddress == "::1" || remoteAddress == "localhost"
    }

    /// True when connected from private/local network (RFC 1918).
    var isLAN: Bool {
        remoteAddress.hasPrefix("192.168.")
            || remoteAddress.hasPrefix("10.")
            || remoteAddress.hasPrefix("172.16.")
            || remoteAddress.hasPrefix("172.17.")
            || remoteAddress.hasPrefix("172.18.")
            || remoteAddress.hasPrefix("172.19.")
            || remoteAddress.hasPrefix("172.20.")
            || remoteAddress.hasPrefix("172.21.")
            || remoteAddress.hasPrefix("172.22.")
            || remoteAddress.hasPrefix("172.23.")
            || remoteAddress.hasPrefix("172.24.")
            || remoteAddress.hasPrefix("172.25.")
            || remoteAddress.hasPrefix("172.26.")
            || remoteAddress.hasPrefix("172.27.")
            || remoteAddress.hasPrefix("172.28.")
            || remoteAddress.hasPrefix("172.29.")
            || remoteAddress.hasPrefix("172.30.")
            || remoteAddress.hasPrefix("172.31.")
    }

    /// High-level origin descriptor.
    var originDescription: String {
        if isLocalhost { return "Localhost" }
        if isLAN { return "Local Network (LAN)" }
        return "Remote WAN"
    }

    /// Display string for client process if available, e.g. "Google Chrome (PID 1234)"
    var clientDisplayName: String? {
        guard let name = clientProcessName else { return nil }
        if let pid = clientPid {
            return "\(name) (\(pid))"
        }
        return name
    }

    var remoteEndpointString: String {
        "\(remoteAddress):\(remotePort)"
    }
}
