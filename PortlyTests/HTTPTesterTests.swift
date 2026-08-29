//
//  HTTPTesterTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

final class HTTPTesterTests: XCTestCase {

    func testHTTPTestResponseFormatting() {
        let jsonString = "{\"status\":\"ok\",\"count\":42}"
        let response = HTTPTestResponse(
            statusCode: 200,
            latencyMilliseconds: 5.2,
            contentType: "application/json",
            headers: ["Content-Type": "application/json"],
            rawBody: jsonString
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertFalse(response.isClientError)
        XCTAssertFalse(response.isServerError)
        XCTAssertTrue(response.formattedBody.contains("\n"))
        XCTAssertTrue(response.formattedBody.contains("\"status\" : \"ok\""))
    }

    func testHTTPStatusClassifications() {
        let notFound = HTTPTestResponse(statusCode: 404, latencyMilliseconds: 1.0, contentType: nil, headers: [:], rawBody: "")
        XCTAssertTrue(notFound.isClientError)
        XCTAssertFalse(notFound.isSuccess)

        let serverError = HTTPTestResponse(statusCode: 500, latencyMilliseconds: 2.0, contentType: nil, headers: [:], rawBody: "")
        XCTAssertTrue(serverError.isServerError)
        XCTAssertFalse(serverError.isSuccess)
    }
}
