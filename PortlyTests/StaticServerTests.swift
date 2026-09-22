//
//  StaticServerTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

@MainActor
final class StaticServerTests: XCTestCase {
    func testServerRejectsNonexistentDirectory() {
        let manager = StaticServerManager()
        let fakePath = "/path/does/not/exist/at/all/\(UUID().uuidString)"
        let success = manager.startServer(directoryPath: fakePath, port: 49152)
        XCTAssertFalse(success)
        XCTAssertFalse(manager.isServing(port: 49152))
    }

    func testManagedStaticServerProperties() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let process = Process()
        let server = ManagedStaticServer(
            port: 8088,
            directoryPath: tempDir.path,
            process: process,
            startedAt: .now
        )

        XCTAssertEqual(server.port, 8088)
        XCTAssertEqual(server.directoryPath, tempDir.path)
        XCTAssertEqual(server.directoryName, tempDir.lastPathComponent)
        XCTAssertEqual(server.localURL?.absoluteString, "http://localhost:8088")
    }
}
