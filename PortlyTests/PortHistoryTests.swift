//
//  PortHistoryTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

@MainActor
final class PortHistoryTests: XCTestCase {
    var manager: PortHistoryManager!

    override func setUp() {
        super.setUp()
        manager = PortHistoryManager()
        manager.clearHistory()
    }

    override func tearDown() {
        manager.clearHistory()
        super.tearDown()
    }

    func testRecordActiveAndClosedPorts() {
        let port1 = ListeningPort(port: 3000, pid: 101, processName: "node", address: "*", user: "user", networkProtocol: .tcp)
        let port2 = ListeningPort(port: 8080, pid: 102, processName: "java", address: "*", user: "user", networkProtocol: .tcp)

        manager.recordScan(activePorts: [port1, port2])

        XCTAssertEqual(manager.records.count, 2)
        XCTAssertTrue(manager.records.allSatisfy(\.isActive))
        XCTAssertEqual(manager.uniquePortsCount, 2)

        // Simulate port 8080 closing in next scan
        manager.recordScan(activePorts: [port1])

        XCTAssertEqual(manager.records.count, 2)
        let closed = manager.records.first(where: { $0.port == 8080 })
        XCTAssertNotNil(closed)
        XCTAssertFalse(closed!.isActive)
        XCTAssertNotNil(closed!.stoppedAt)

        let active = manager.records.first(where: { $0.port == 3000 })
        XCTAssertNotNil(active)
        XCTAssertTrue(active!.isActive)
    }

    func testAnalyticsCalculations() {
        let p1 = ListeningPort(port: 3000, pid: 201, processName: "node", address: "*", user: "user", networkProtocol: .tcp)
        let p2 = ListeningPort(port: 3000, pid: 202, processName: "next-server", address: "*", user: "user", networkProtocol: .tcp)
        let p3 = ListeningPort(port: 5432, pid: 203, processName: "postgres", address: "*", user: "user", networkProtocol: .tcp)

        manager.recordScan(activePorts: [p1, p3])
        manager.recordScan(activePorts: []) // Close both
        manager.recordScan(activePorts: [p2]) // Reopen 3000

        XCTAssertEqual(manager.totalSessions, 3)
        XCTAssertEqual(manager.uniquePortsCount, 2)

        let mostUsed = manager.mostUsedPorts
        XCTAssertEqual(mostUsed.first?.port, 3000)
        XCTAssertEqual(mostUsed.first?.count, 2)
    }

    func testExportFormats() {
        let port = ListeningPort(port: 3000, pid: 301, processName: "vite", address: "*", user: "user", networkProtocol: .tcp, customAlias: "Vite App")
        manager.recordScan(activePorts: [port])

        let markdown = manager.export(format: .markdown)
        XCTAssertTrue(markdown.contains("Vite App"))
        XCTAssertTrue(markdown.contains("| 3000 |"))

        let csv = manager.export(format: .csv)
        XCTAssertTrue(csv.contains("3000,\"Vite App\",301,TCP"))

        let json = manager.export(format: .json)
        XCTAssertTrue(json.contains("\"port\" : 3000"))
        XCTAssertTrue(json.contains("\"customAlias\" : \"Vite App\""))
    }
}
