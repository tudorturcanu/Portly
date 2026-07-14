//
//  ClosedPort.swift
//  Portly
//

import Foundation

/// A port that recently stopped listening — shown as a ghost row for a few
/// minutes so "my server just died" is answerable at a glance.
struct ClosedPort: Identifiable, Hashable {
    let port: Int
    let displayName: String
    let networkProtocol: NetworkProtocol
    let closedAt: Date

    var id: String { "\(port):\(networkProtocol.rawValue)" }
}
