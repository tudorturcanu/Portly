//
//  ProcessDetails.swift
//  Portly
//

import Foundation

/// Extra facts about a process, resolved on demand for the details popover.
/// Every field is optional — visibility of other processes varies by owner
/// and by edition (the sandbox hides more), and the UI simply omits gaps.
struct ProcessDetails {
    var arguments: [String]?
    var startedAt: Date?
    var cpuTime: TimeInterval?
    var memoryBytes: UInt64?
}
