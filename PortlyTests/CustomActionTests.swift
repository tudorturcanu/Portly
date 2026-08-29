//
//  CustomActionTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

@MainActor
final class CustomActionTests: XCTestCase {
    var manager: CustomActionManager!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: CustomActionManager.defaultsKey)
        manager = CustomActionManager()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: CustomActionManager.defaultsKey)
        super.tearDown()
    }

    func testVariableInterpolation() {
        let action = CustomAction(
            name: "Test Command",
            command: "echo 'Port $PORT on $HOST with PID $PID for $NAME at $URL in $CWD'"
        )

        let port = ListeningPort(
            port: 3000,
            pid: 1234,
            processName: "next-server",
            address: "*",
            user: "user",
            customAlias: "Frontend"
        )

        let interpolated = action.interpolatedCommand(port: port, workingDirectory: "/Users/dev/myproject")
        XCTAssertEqual(interpolated, "echo 'Port 3000 on 127.0.0.1 with PID 1234 for Frontend at http://localhost:3000 in /Users/dev/myproject'")
    }

    func testAddAndFilterActions() {
        let genericAction = CustomAction(
            name: "Universal Ping",
            command: "curl -I $URL",
            targetPort: nil
        )
        let specificAction = CustomAction(
            name: "Postgres Dump",
            command: "pg_dump -p $PORT",
            targetPort: 5432
        )

        manager.addAction(genericAction)
        manager.addAction(specificAction)

        let nodePort = ListeningPort(port: 3000, pid: 101, processName: "node", address: "*", user: "user")
        let dbPort = ListeningPort(port: 5432, pid: 102, processName: "postgres", address: "*", user: "user")

        let nodeActions = manager.actions(for: nodePort)
        XCTAssertTrue(nodeActions.contains(where: { $0.name == "Universal Ping" }))
        XCTAssertFalse(nodeActions.contains(where: { $0.name == "Postgres Dump" }))

        let dbActions = manager.actions(for: dbPort)
        XCTAssertTrue(dbActions.contains(where: { $0.name == "Universal Ping" }))
        XCTAssertTrue(dbActions.contains(where: { $0.name == "Postgres Dump" }))
    }
}
