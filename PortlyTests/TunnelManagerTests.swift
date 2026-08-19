//
//  TunnelManagerTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

@MainActor
final class TunnelManagerTests: XCTestCase {

    func testParseCloudflareTunnelURL() {
        let sampleLog = """
        2026-08-19T10:00:00Z INF +--------------------------------------------------------------------------------------------+
        2026-08-19T10:00:00Z INF |  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):  |
        2026-08-19T10:00:00Z INF |  https://purple-butterfly-swift.trycloudflare.com                                          |
        2026-08-19T10:00:00Z INF +--------------------------------------------------------------------------------------------+
        """

        let url = TunnelManager.parseTunnelURL(from: sampleLog)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "https://purple-butterfly-swift.trycloudflare.com")
    }

    func testParseLocaltunnelURL() {
        let sampleLog = "your url is: https://fancy-elephant-42.loca.lt"
        let url = TunnelManager.parseTunnelURL(from: sampleLog)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "https://fancy-elephant-42.loca.lt")
    }

    func testParseNgrokURL() {
        let sampleLog = "t=2026-08-19T10:00:00+0200 lvl=info msg=\"started tunnel\" obj=tunnels name=command_line addr=http://localhost:3000 url=https://abcd-12-34-56-78.ngrok-free.app"
        let url = TunnelManager.parseTunnelURL(from: sampleLog)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "https://abcd-12-34-56-78.ngrok-free.app")
    }

    func testPruneInactiveTunnels() {
        let manager = TunnelManager()
        let activePort = ListeningPort(port: 3000, pid: 100, processName: "node", address: "*", user: "tudor")

        manager.pruneInactive(listeningPorts: [activePort])
        XCTAssertFalse(manager.isTunneling(8080))
    }
}
