//
//  ListeningPortTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

final class ListeningPortTests: XCTestCase {

    func testListeningPortProperties() {
        let port = ListeningPort(
            port: 3000,
            pid: 1234,
            processName: "node",
            address: "*",
            user: "tudor",
            networkProtocol: .tcp,
            executablePath: "/usr/local/bin/node",
            containerName: nil,
            establishedConnections: 3
        )

        XCTAssertEqual(port.id, "1234:3000:TCP")
        XCTAssertTrue(port.isWildcard)
        XCTAssertEqual(port.displayAddress, "all interfaces")
        XCTAssertEqual(port.displayName, "node")
        XCTAssertEqual(port.localURL, URL(string: "http://localhost:3000"))
        XCTAssertFalse(port.isDockerBackend)
        XCTAssertFalse(port.isSystemProcess)
    }

    func testDockerContainerDisplayName() {
        let port = ListeningPort(
            port: 5432,
            pid: 999,
            processName: "com.docker.backend",
            address: "127.0.0.1",
            user: "tudor",
            networkProtocol: .tcp,
            executablePath: "/Applications/Docker.app/Contents/MacOS/com.docker.backend",
            containerName: "myapp-postgres"
        )

        XCTAssertTrue(port.isDockerBackend)
        XCTAssertEqual(port.displayName, "myapp-postgres")
    }

    func testSystemProcessDetection() {
        let systemPort = ListeningPort(
            port: 7000,
            pid: 500,
            processName: "ControlCenter",
            address: "*",
            user: "tudor",
            executablePath: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter"
        )
        XCTAssertTrue(systemPort.isSystemProcess)

        let userPort = ListeningPort(
            port: 8080,
            pid: 1200,
            processName: "node",
            address: "*",
            user: "tudor",
            executablePath: "/Users/tudor/.nvm/versions/node/v20.0.0/bin/node"
        )
        XCTAssertFalse(userPort.isSystemProcess)
    }

    func testPortHintLookup() {
        let pgPort = ListeningPort(
            port: 5432,
            pid: 100,
            processName: "postgres",
            address: "127.0.0.1",
            user: "postgres"
        )
        XCTAssertEqual(pgPort.hint, "PostgreSQL")

        let redisPort = ListeningPort(
            port: 6379,
            pid: 101,
            processName: "redis-server",
            address: "127.0.0.1",
            user: "redis"
        )
        XCTAssertEqual(redisPort.hint, "Redis")
    }

    func testComparableSorting() {
        let port80 = ListeningPort(port: 80, pid: 1, processName: "nginx", address: "*", user: nil)
        let port3000 = ListeningPort(port: 3000, pid: 2, processName: "node", address: "*", user: nil)
        let port8080 = ListeningPort(port: 8080, pid: 3, processName: "java", address: "*", user: nil)

        let sorted = [port8080, port80, port3000].sorted()
        XCTAssertEqual(sorted.map(\.port), [80, 3000, 8080])
    }
}
