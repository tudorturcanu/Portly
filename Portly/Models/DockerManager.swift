//
//  DockerManager.swift
//  Portly
//

import Foundation

/// Provides lifecycle controls and container operations for Docker-backed services.
enum DockerManager {
    private static let candidatePaths = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        NSHomeDirectory() + "/.docker/bin/docker",
        "/Applications/Docker.app/Contents/Resources/bin/docker",
    ]

    static var dockerPath: String? {
        candidatePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }

    static var isDockerAvailable: Bool {
        dockerPath != nil
    }

    @discardableResult
    static func restartContainer(_ name: String) async -> (success: Bool, message: String) {
        guard let path = dockerPath else { return (false, "Docker CLI not found") }
        let process = Process()
        process.executableURL = URL(filePath: path)
        process.arguments = ["restart", name]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return (process.terminationStatus == 0, output)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    @discardableResult
    static func stopContainer(_ name: String) async -> (success: Bool, message: String) {
        guard let path = dockerPath else { return (false, "Docker CLI not found") }
        let process = Process()
        process.executableURL = URL(filePath: path)
        process.arguments = ["stop", name]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return (process.terminationStatus == 0, output)
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
