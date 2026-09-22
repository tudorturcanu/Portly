//
//  ProcessRestarterTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

@MainActor
final class ProcessRestarterTests: XCTestCase {
    func testRestartRejectsInvalidProcess() async {
        let monitor = PortMonitor()
        let invalidPort = ListeningPort(
            port: 80,
            pid: 0,
            processName: "kernel_task",
            address: "*",
            user: "root"
        )

        let success = await ProcessRestarter.restart(invalidPort, monitor: monitor)
        XCTAssertFalse(success)
    }

    func testRestartRejectsForeignUserProcess() async {
        let monitor = PortMonitor()
        let foreignPort = ListeningPort(
            port: 9999,
            pid: 99999,
            processName: "other_user_service",
            address: "*",
            user: "someone_else_42"
        )

        let success = await ProcessRestarter.restart(foreignPort, monitor: monitor)
        XCTAssertFalse(success)
    }
}
