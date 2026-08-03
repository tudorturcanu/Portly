//
//  PortExporterTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

final class PortExporterTests: XCTestCase {

    func testPortExporterMarkdown() {
        let ports = [
            ListeningPort(port: 3000, pid: 101, processName: "node", address: "*", user: "tudor", customAlias: "Frontend")
        ]

        let md = PortExporter.export(ports, format: .markdown)
        XCTAssertTrue(md.contains("| :3000 | TCP | Frontend | Frontend | 101 | all interfaces |"))
    }

    func testPortExporterJSON() {
        let ports = [
            ListeningPort(port: 5432, pid: 202, processName: "postgres", address: "127.0.0.1", user: "tudor")
        ]

        let json = PortExporter.export(ports, format: .json)
        XCTAssertTrue(json.contains("\"port\" : 5432"))
        XCTAssertTrue(json.contains("\"processName\" : \"postgres\""))
    }

    func testPortExporterCSV() {
        let ports = [
            ListeningPort(port: 8080, pid: 303, processName: "java", address: "*", user: "tudor")
        ]

        let csv = PortExporter.export(ports, format: .csv)
        XCTAssertTrue(csv.contains("Port,Protocol,ProcessName,DisplayName,Alias,PID,Address,SystemProcess"))
        XCTAssertTrue(csv.contains("8080,TCP,\"java\",\"java\",\"\",303,\"all interfaces\",false"))
    }
}
