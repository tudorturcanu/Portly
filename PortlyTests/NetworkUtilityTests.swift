//
//  NetworkUtilityTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

final class NetworkUtilityTests: XCTestCase {

    func testLANURLGeneration() {
        let port = ListeningPort(
            port: 3000,
            pid: 1234,
            processName: "node",
            address: "*",
            user: "tudor"
        )

        let lanURL = port.lanURL(ipAddress: "192.168.1.150")
        XCTAssertEqual(lanURL?.absoluteString, "http://192.168.1.150:3000")

        let nilLanURL = port.lanURL(ipAddress: nil)
        XCTAssertNil(nilLanURL)
    }
}
