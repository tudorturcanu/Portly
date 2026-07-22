//
//  PortScannerTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

final class PortScannerTests: XCTestCase {

    func testParseLsofOutputWithTCPListeners() {
        let sampleLsofOutput = """
        p1234
        cnode
        Ltudor
        PTCP
        n*:3000
        TST=LISTEN
        p5678
        cpostgres
        Lpostgres
        PTCP
        n127.0.0.1:5432
        TST=LISTEN
        """

        let ports = PortScanner.parse(sampleLsofOutput)

        XCTAssertEqual(ports.count, 2)

        let nodePort = ports.first { $0.port == 3000 }
        XCTAssertNotNil(nodePort)
        XCTAssertEqual(nodePort?.pid, 1234)
        XCTAssertEqual(nodePort?.processName, "node")
        XCTAssertEqual(nodePort?.user, "tudor")
        XCTAssertEqual(nodePort?.address, "*")
        XCTAssertTrue(nodePort?.isWildcard ?? false)

        let pgPort = ports.first { $0.port == 5432 }
        XCTAssertNotNil(pgPort)
        XCTAssertEqual(pgPort?.pid, 5678)
        XCTAssertEqual(pgPort?.processName, "postgres")
        XCTAssertEqual(pgPort?.address, "127.0.0.1")
        XCTAssertFalse(pgPort?.isWildcard ?? true)
    }

    func testParseEstablishedConnectionsCount() {
        let sampleLsofOutput = """
        p100
        cnginx
        Lroot
        PTCP
        n*:80
        TST=LISTEN
        n127.0.0.1:80->127.0.0.1:54321
        TST=ESTABLISHED
        n127.0.0.1:80->127.0.0.1:54322
        TST=ESTABLISHED
        """

        let ports = PortScanner.parse(sampleLsofOutput)

        XCTAssertEqual(ports.count, 1)
        let httpPort = ports.first { $0.port == 80 }
        XCTAssertEqual(httpPort?.establishedConnections, 2)
    }

    func testParseUDPSockets() {
        let sampleLsofOutput = """
        p200
        cchronyd
        Lroot
        PUDP
        n*:5353
        """

        let ports = PortScanner.parse(sampleLsofOutput)

        XCTAssertEqual(ports.count, 1)
        let udpPort = ports.first
        XCTAssertEqual(udpPort?.port, 5353)
        XCTAssertEqual(udpPort?.networkProtocol, .udp)
        XCTAssertEqual(udpPort?.processName, "chronyd")
    }

    func testParseIgnoresConnectedUDPSockets() {
        let sampleLsofOutput = """
        p300
        cclient
        Luser
        PUDP
        n192.168.1.10:12345->1.1.1.1:53
        """

        let ports = PortScanner.parse(sampleLsofOutput)
        XCTAssertTrue(ports.isEmpty)
    }

    func testParseEmptyOutputReturnsEmptyArray() {
        let ports = PortScanner.parse("")
        XCTAssertTrue(ports.isEmpty)
    }
}
