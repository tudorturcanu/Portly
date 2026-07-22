//
//  PortMonitorTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

@MainActor
final class PortMonitorTests: XCTestCase {

    func testDevServerCount() {
        let samplePorts = [
            ListeningPort(port: 3000, pid: 101, processName: "node", address: "*", user: "user", networkProtocol: .tcp, executablePath: "/opt/homebrew/bin/node"),
            ListeningPort(port: 5432, pid: 102, processName: "postgres", address: "127.0.0.1", user: "user", networkProtocol: .tcp, executablePath: "/opt/homebrew/bin/postgres"),
            ListeningPort(port: 5353, pid: 103, processName: "chronyd", address: "*", user: "user", networkProtocol: .udp, executablePath: "/opt/homebrew/bin/chronyd"),
            ListeningPort(port: 7000, pid: 104, processName: "ControlCenter", address: "*", user: "user", networkProtocol: .tcp, executablePath: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter")
        ]

        let monitor = PortMonitor(ports: samplePorts, startsMonitoring: false)

        // 2 user-installed TCP ports (3000, 5432) — excluding UDP (5353) and System (7000)
        XCTAssertEqual(monitor.devServerCount, 2)
    }

    func testPinningAndDeadPinnedPorts() {
        let samplePorts = [
            ListeningPort(port: 3000, pid: 101, processName: "node", address: "*", user: "user")
        ]

        let monitor = PortMonitor(ports: samplePorts, startsMonitoring: false)

        monitor.togglePin(3000)
        monitor.togglePin(8080)

        XCTAssertTrue(monitor.pinnedPorts.contains(3000))
        XCTAssertTrue(monitor.pinnedPorts.contains(8080))

        // 8080 is pinned but not in active ports list -> dead pinned port
        XCTAssertEqual(monitor.deadPinnedPorts, [8080])

        // Toggle 8080 off
        monitor.togglePin(8080)
        XCTAssertFalse(monitor.pinnedPorts.contains(8080))
        XCTAssertTrue(monitor.deadPinnedPorts.isEmpty)
    }

    func testUserDevServersFiltering() {
        let currentUser = NSUserName()
        let samplePorts = [
            ListeningPort(port: 3000, pid: 201, processName: "node", address: "*", user: currentUser, networkProtocol: .tcp, executablePath: "/usr/local/bin/node"),
            ListeningPort(port: 8000, pid: 202, processName: "python", address: "*", user: "otheruser", networkProtocol: .tcp, executablePath: "/usr/local/bin/python")
        ]

        let monitor = PortMonitor(ports: samplePorts, startsMonitoring: false)
        XCTAssertEqual(monitor.userDevServers.count, 1)
        XCTAssertEqual(monitor.userDevServers.first?.port, 3000)
    }
}
