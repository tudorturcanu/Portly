//
//  DockerManagerTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

final class DockerManagerTests: XCTestCase {

    func testDockerPortDetailsInitialization() {
        let details = DockerPortDetails(
            containerName: "my_web_app",
            composeProject: "ecommerce",
            composeService: "frontend"
        )

        XCTAssertEqual(details.containerName, "my_web_app")
        XCTAssertEqual(details.composeProject, "ecommerce")
        XCTAssertEqual(details.composeService, "frontend")
    }

    func testListeningPortWithComposeDetails() {
        var port = ListeningPort(
            port: 8080,
            pid: 5050,
            processName: "com.docker.backend",
            address: "127.0.0.1",
            user: "user",
            containerName: "ecommerce-web-1"
        )
        port.composeProject = "ecommerce"
        port.composeService = "web"

        XCTAssertEqual(port.displayName, "ecommerce-web-1")
        XCTAssertEqual(port.composeProject, "ecommerce")
        XCTAssertEqual(port.composeService, "web")
    }
}
