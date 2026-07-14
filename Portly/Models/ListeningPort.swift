//
//  ListeningPort.swift
//  Portly
//

import Foundation

enum NetworkProtocol: String {
    case tcp = "TCP"
    case udp = "UDP"
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
    var establishedConnections: Int = 0

    var id: String { "\(pid):\(port):\(networkProtocol.rawValue)" }

    /// True when the socket is bound to all interfaces ("*" in lsof output).
    var isWildcard: Bool { address == "*" }

    var displayAddress: String { isWildcard ? "all interfaces" : address }

    /// The Docker container name when the port is container-published, else the process name.
    var displayName: String { containerName ?? processName }

    var localURL: URL? { URL(string: "http://localhost:\(port)") }

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
