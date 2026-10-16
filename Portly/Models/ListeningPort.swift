//
//  ListeningPort.swift
//  Portly
//

import Foundation

enum NetworkProtocol: String {
    case tcp = "TCP"
    case udp = "UDP"
}

enum InterfaceExposure: String, CaseIterable, Identifiable {
    case localhost = "Localhost Only"
    case lan = "LAN Exposed"
    case custom = "Specific Interface"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .localhost: return "shield.lefthalf.filled"
        case .lan: return "network.badge.shield.half.filled"
        case .custom: return "network"
        }
    }
}

/// One listening socket, deduplicated per process, port, and protocol.
struct ListeningPort: Identifiable, Hashable {
    let port: Int
    let pid: Int32
    let processName: String
    let address: String
    let user: String?
    var networkProtocol: NetworkProtocol = .tcp
    var executablePath: String?
    var containerName: String?
    var composeProject: String?
    var composeService: String?
    var customAlias: String?
    var customNote: String?
    var smartDescriptor: String?
    var establishedConnections: Int = 0
    var activeConnections: [PortConnection] = []

    var id: String { "\(pid):\(port):\(networkProtocol.rawValue)" }

    /// True when the socket is bound to all interfaces ("*" in lsof output).
    var isWildcard: Bool { address == "*" }

    var displayAddress: String { isWildcard ? "all interfaces" : address }

    /// True when the socket is bound to a loopback interface only (127.0.0.1, ::1, localhost).
    var isLoopbackOnly: Bool {
        address == "127.0.0.1" || address == "::1" || address.lowercased() == "localhost"
    }

    /// True when the socket is bound to all network interfaces (wildcard), exposing it to the local Wi-Fi / LAN.
    var isLANExposed: Bool {
        isWildcard || address == "0.0.0.0" || address == "::" || address == "[::]"
    }

    var exposure: InterfaceExposure {
        if isLANExposed {
            return .lan
        } else if isLoopbackOnly {
            return .localhost
        } else {
            return .custom
        }
    }

    var exposureSecuritySummary: String {
        switch exposure {
        case .localhost:
            return "Loopback only (\(address)) — isolated to this Mac."
        case .lan:
            return "Exposed to all interfaces (\(displayAddress)) — accessible by devices on your local Wi-Fi."
        case .custom:
            return "Bound to specific address (\(address))."
        }
    }

    /// The custom alias if set, otherwise Docker container name if container-published, else process name.
    var displayName: String { customAlias ?? containerName ?? processName }

    var localURL: URL? { URL(string: "http://localhost:\(port)") }

    /// Returns a localhost URL appended with the specified route path.
    func routeURL(path: String) -> URL? {
        var clean = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.hasPrefix("/") {
            clean = "/" + clean
        }
        return URL(string: "http://localhost:\(port)\(clean)")
    }

    /// Returns the local network (LAN) URL e.g. http://192.168.1.150:3000
    func lanURL(ipAddress: String? = NetworkUtility.localIPAddress) -> URL? {
        guard let ip = ipAddress else { return nil }
        return URL(string: "http://\(ip):\(port)")
    }

    var isOwnedByCurrentUser: Bool { user == NSUserName() }

    /// Best guess at what typically runs on this port.
    var hint: String? { PortHint.wellKnown[port] }

    /// True when this socket belongs to Docker's host-side port proxy.
    var isDockerBackend: Bool {
        processName.localizedCaseInsensitiveContains("docker")
            || processName == "vpnkit"
            || (executablePath?.contains("Docker.app") ?? false)
    }

    /// True for binaries shipped with macOS (not user-installed software).
    var isSystemProcess: Bool {
        guard let executablePath else { return false }
        if executablePath.hasPrefix("/usr/local/") { return false }
        return executablePath.hasPrefix("/System/")
            || executablePath.hasPrefix("/usr/")
            || executablePath.hasPrefix("/Library/Apple/")
            || executablePath.hasPrefix("/sbin/")
    }
}

extension ListeningPort: Comparable {
    static func < (lhs: ListeningPort, rhs: ListeningPort) -> Bool {
        (lhs.port, lhs.networkProtocol.rawValue, lhs.processName, lhs.pid)
            < (rhs.port, rhs.networkProtocol.rawValue, rhs.processName, rhs.pid)
    }
}
