//
//  PortBenchmarkView.swift
//  Portly
//

import SwiftUI

/// Interactive tool to run HTTP latency and throughput benchmarks against a listening port.
struct PortBenchmarkView: View {
    let port: ListeningPort

    @State private var path = "/"
    @State private var iterations = 10
    @State private var isRunning = false
    @State private var result: BenchmarkResult?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            controlsRow

            Divider()

            if isRunning {
                HStack {
                    Spacer()
                    ProgressView("Benchmarking \(iterations) requests against :\(port.port)…")
                        .font(.caption)
                    Spacer()
                }
                .padding(.vertical, 30)
            } else if let res = result {
                resultCard(res)
            } else if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("Click \"Run Benchmark\" to send \(iterations) HTTP requests and analyze latency distribution.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 420, height: 350)
        .task {
            await startBenchmark()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "gauge.with.needle.fill")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 1) {
                Text("Latency Benchmark")
                    .font(.headline)
                Text(":\(port.port) · \(port.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                Text("Path:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("/", text: $path)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            Picker("Count", selection: $iterations) {
                Text("5x").tag(5)
                Text("10x").tag(10)
                Text("25x").tag(25)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)

            Button("Run Benchmark") {
                Task { await startBenchmark() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)
        }
    }

    private func resultCard(_ res: BenchmarkResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(res.ratingText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ratingColor(res.avgLatencyMs).opacity(0.15), in: .capsule)

                Spacer()

                Text("HTTP \(res.statusCode)")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(res.statusCode < 400 ? .green : .orange)
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    metricItem(label: "Average", value: String(format: "%.2f ms", res.avgLatencyMs), color: .primary)
                    metricItem(label: "Minimum", value: String(format: "%.2f ms", res.minLatencyMs), color: .green)
                    metricItem(label: "Maximum", value: String(format: "%.2f ms", res.maxLatencyMs), color: .orange)
                }
                GridRow {
                    metricItem(label: "Samples", value: "\(res.iterations) reqs", color: .secondary)
                    metricItem(label: "Throughput", value: String(format: "%.0f req/s", res.requestsPerSecond), color: .accentColor)
                    metricItem(label: "Status", value: "\(res.statusCode)", color: .secondary)
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 8))

            HStack {
                Button("Copy Results", systemImage: "doc.on.doc") {
                    let summary = """
                    Port :\(res.port) Benchmark (\(res.iterations) requests to \(path)):
                    • Average: \(String(format: "%.2f ms", res.avgLatencyMs))
                    • Min: \(String(format: "%.2f ms", res.minLatencyMs))
                    • Max: \(String(format: "%.2f ms", res.maxLatencyMs))
                    • Throughput: \(String(format: "%.0f req/s", res.requestsPerSecond))
                    • Status: HTTP \(res.statusCode)
                    """
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(summary, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Text("Tested on \(res.timestamp, format: .dateTime.hour().minute().second())")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func metricItem(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.callout, design: .monospaced).weight(.bold))
                .foregroundStyle(color)
        }
    }

    private func ratingColor(_ avgMs: Double) -> Color {
        if avgMs < 15.0 { return .green }
        if avgMs < 60.0 { return .blue }
        if avgMs < 200.0 { return .yellow }
        return .orange
    }

    private func startBenchmark() async {
        isRunning = true
        errorMessage = nil
        result = nil

        let res = await PortBenchmarkManager.runBenchmark(port: port.port, iterations: iterations, path: path)
        if let res {
            result = res
        } else {
            errorMessage = "Could not complete benchmark on port :\(port.port). Ensure the HTTP server is running."
        }
        isRunning = false
    }
}
