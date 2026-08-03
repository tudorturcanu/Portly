//
//  CustomAliasTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

@MainActor
final class CustomAliasTests: XCTestCase {

    func testCustomAliasSetAndClear() {
        let samplePorts = [
            ListeningPort(port: 3000, pid: 101, processName: "node", address: "*", user: "user"),
            ListeningPort(port: 8080, pid: 102, processName: "java", address: "*", user: "user")
        ]

        let monitor = PortMonitor(ports: samplePorts, startsMonitoring: false)

        monitor.setAlias("Frontend App", for: 3000)
        XCTAssertEqual(monitor.customAliases[3000], "Frontend App")
        XCTAssertEqual(monitor.ports.first(where: { $0.port == 3000 })?.displayName, "Frontend App")

        // Clear alias
        monitor.setAlias("", for: 3000)
        XCTAssertNil(monitor.customAliases[3000])
        XCTAssertEqual(monitor.ports.first(where: { $0.port == 3000 })?.displayName, "node")
    }
}
