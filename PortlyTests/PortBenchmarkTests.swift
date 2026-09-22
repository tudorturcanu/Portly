//
//  PortBenchmarkTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

final class PortBenchmarkTests: XCTestCase {
    func testBenchmarkResultRatings() {
        let blazing = BenchmarkResult(
            port: 3000,
            iterations: 10,
            minLatencyMs: 4.0,
            avgLatencyMs: 8.5,
            maxLatencyMs: 14.0,
            statusCode: 200,
            requestsPerSecond: 117.6,
            timestamp: .now
        )
        XCTAssertTrue(blazing.ratingText.contains("Blazing Fast"))

        let responsive = BenchmarkResult(
            port: 8080,
            iterations: 10,
            minLatencyMs: 25.0,
            avgLatencyMs: 45.0,
            maxLatencyMs: 58.0,
            statusCode: 200,
            requestsPerSecond: 22.2,
            timestamp: .now
        )
        XCTAssertTrue(responsive.ratingText.contains("Responsive"))

        let moderate = BenchmarkResult(
            port: 5000,
            iterations: 10,
            minLatencyMs: 100.0,
            avgLatencyMs: 150.0,
            maxLatencyMs: 190.0,
            statusCode: 200,
            requestsPerSecond: 6.6,
            timestamp: .now
        )
        XCTAssertTrue(moderate.ratingText.contains("Moderate"))

        let high = BenchmarkResult(
            port: 9000,
            iterations: 10,
            minLatencyMs: 210.0,
            avgLatencyMs: 320.0,
            maxLatencyMs: 450.0,
            statusCode: 200,
            requestsPerSecond: 3.1,
            timestamp: .now
        )
        XCTAssertTrue(high.ratingText.contains("High Latency"))
    }

    func testBenchmarkResultDataIntegrity() {
        let result = BenchmarkResult(
            port: 8000,
            iterations: 25,
            minLatencyMs: 12.3,
            avgLatencyMs: 18.7,
            maxLatencyMs: 29.1,
            statusCode: 200,
            requestsPerSecond: 53.4,
            timestamp: .now
        )

        XCTAssertEqual(result.port, 8000)
        XCTAssertEqual(result.iterations, 25)
        XCTAssertEqual(result.minLatencyMs, 12.3)
        XCTAssertEqual(result.avgLatencyMs, 18.7)
        XCTAssertEqual(result.maxLatencyMs, 29.1)
        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(result.requestsPerSecond, 53.4)
    }
}
