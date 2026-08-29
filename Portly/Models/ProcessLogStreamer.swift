//
//  ProcessLogStreamer.swift
//  Portly
//

import Foundation
import Observation

/// Streams unified macOS system logs or Docker container logs for a given process/port in real time.
@Observable
@MainActor
final class ProcessLogStreamer {
    let port: ListeningPort
    private(set) var lines: [String] = []
    private(set) var isStreaming: Bool = false
    private(set) var statusMessage: String?

    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    private static let maxLines = 1000

    init(port: ListeningPort) {
        self.port = port
    }

    func start() {
        guard !isStreaming else { return }
        isStreaming = true
        statusMessage = "Streaming logs…"

        let isDocker = port.containerName != nil
        let targetContainer = port.containerName
        let pid = port.pid
        let procName = port.processName

        streamTask = Task.detached { [weak self] in
            let proc = Process()
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            if isDocker, let container = targetContainer, let dockerPath = DockerManager.dockerPath {
                proc.executableURL = URL(filePath: dockerPath)
                proc.arguments = ["logs", "--tail", "100", "-f", container]
            } else {
                proc.executableURL = URL(filePath: "/usr/bin/log")
                proc.arguments = [
                    "stream",
                    "--predicate", "processID == \(pid) || processImagePath contains '\(procName)'",
                    "--style", "compact"
                ]
            }

            do {
                try proc.run()
                await MainActor.run {
                    self?.process = proc
                }

                for try await line in pipe.fileHandleForReading.bytes.lines {
                    if Task.isCancelled { break }
                    await MainActor.run {
                        self?.appendLine(line)
                    }
                }
            } catch {
                await MainActor.run {
                    self?.statusMessage = "Stream ended: \(error.localizedDescription)"
                    self?.isStreaming = false
                }
            }

            await MainActor.run {
                self?.isStreaming = false
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil
        isStreaming = false
        statusMessage = "Stream stopped"
    }

    func clear() {
        lines.removeAll()
    }

    private func appendLine(_ line: String) {
        lines.append(line)
        if lines.count > Self.maxLines {
            lines.removeFirst(lines.count - Self.maxLines)
        }
    }
}
