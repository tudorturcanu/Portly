//
//  PortBenchmarkManager.swift
//  Portly
//

import Foundation

/// Performance result of an HTTP latency benchmark against a listening port.
struct BenchmarkResult: Identifiable, Sendable {
    let id = UUID()
    let port: Int
    let iterations: Int
    let minLatencyMs: Double
    let avgLatencyMs: Double
    let maxLatencyMs: Double
    let statusCode: Int
    let requestsPerSecond: Double
    let timestamp: Date

    var ratingText: String {
        if avgLatencyMs < 15.0 {
            return "⚡ Blazing Fast (<15ms)"
        } else if avgLatencyMs < 60.0 {
            return "✓ Responsive (<60ms)"
        } else if avgLatencyMs < 200.0 {
            return "⏳ Moderate (<200ms)"
        } else {
            return "⚠️ High Latency (>200ms)"
        }
    }
}

/// Measures HTTP request latency and throughput against local servers.
enum PortBenchmarkManager {
    /// Runs multiple fast requests to determine response latency distribution.
    static func runBenchmark(port: Int, iterations: Int = 10, path: String = "/") async -> BenchmarkResult? {
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = URL(string: "http://127.0.0.1:\(port)\(cleanPath)") else { return nil }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2.0
        config.timeoutIntervalForResource = 3.0
        let session = URLSession(configuration: config)

        var latencies: [Double] = []
        var lastStatus = 0

        for _ in 0..<iterations {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Portly-Benchmark/1.0", forHTTPHeaderField: "User-Agent")

            let start = ContinuousClock.now
            do {
                let (_, response) = try await session.data(for: request)
                let elapsed = start.duration(to: .now)
                let ms = Double(elapsed.components.seconds) * 1000.0 + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000.0
                latencies.append(ms)

                if let http = response as? HTTPURLResponse {
                    lastStatus = http.statusCode
                }
            } catch {
                // Connection error or timeout
                continue
            }
        }

        guard !latencies.isEmpty else { return nil }

        let minMs = latencies.min() ?? 0
        let maxMs = latencies.max() ?? 0
        let avgMs = latencies.reduce(0, +) / Double(latencies.count)
        let rps = avgMs > 0 ? (1000.0 / avgMs) : 0

        return BenchmarkResult(
            port: port,
            iterations: latencies.count,
            minLatencyMs: minMs,
            avgLatencyMs: avgMs,
            maxLatencyMs: maxMs,
            statusCode: lastStatus,
            requestsPerSecond: rps,
            timestamp: .now
        )
    }
}
