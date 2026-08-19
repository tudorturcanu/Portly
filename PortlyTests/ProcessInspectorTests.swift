//
//  ProcessInspectorTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

final class ProcessInspectorTests: XCTestCase {

    func testEnvironmentVariableSensitivity() {
        let secretKey = EnvironmentVariable(key: "STRIPE_API_KEY", value: "sk_live_1234567890abcdef")
        XCTAssertTrue(secretKey.isSensitive)
        XCTAssertTrue(secretKey.maskedValue.contains("••••••••"))

        let regularVar = EnvironmentVariable(key: "PORT", value: "3000")
        XCTAssertFalse(regularVar.isSensitive)

        let passwordVar = EnvironmentVariable(key: "DB_PASSWORD", value: "supersecretpass")
        XCTAssertTrue(passwordVar.isSensitive)
        XCTAssertTrue(passwordVar.maskedValue.hasPrefix("sup"))
        XCTAssertTrue(passwordVar.maskedValue.hasSuffix("ss"))
    }

    func testOwnProcessInspection() {
        let ownPid = ProcessInfo.processInfo.processIdentifier
        let details = ProcessInspector.details(for: ownPid)

        // Own process should have readable arguments
        XCTAssertNotNil(details.arguments)
        XCTAssertFalse(details.arguments?.isEmpty ?? true)

        // Own process should have readable working directory
        let cwd = ProcessInspector.currentWorkingDirectory(for: ownPid)
        XCTAssertNotNil(cwd)
        XCTAssertFalse(cwd?.isEmpty ?? true)
    }
}
