//
//  DockerResolver.swift
//  Portly
//

import Foundation

/// Maps host ports published by Docker containers to container names,
/// so rows can show "myapp-db" instead of "com.docker.backend".
enum DockerResolver {
    private static let candidatePaths = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        NSHomeDirectory() + "/.docker/bin/docker",
        "/Applications/Docker.app/Contents/Resources/bin/docker",
    ]

    /// Returns [host port: container name] for all running containers.
    /// Silently returns an empty map when the Docker CLI is unavailable.
    static func publishedPorts() async -> [Int: String] {
        guard let dockerPath = candidatePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return [:]
        }

        let process = Process()
        process.executableURL = URL(filePath: dockerPath)
        process.arguments = ["ps", "--format", "{{json .}}"]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return [:]
        }

        var mapping: [Int: String] = [:]
        do {
            for try await line in stdout.fileHandleForReading.bytes.lines {
                guard let data = line.data(using: .utf8),
                      let container = try? JSONDecoder().decode(ContainerInfo.self, from: data) else { continue }

                // Ports looks like "0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp".
                for match in container.ports.matches(of: /:(\d+)->/) {
                    if let port = Int(match.1) {
                        mapping[port] = container.names
                    }
                }
            }
        } catch {
            return mapping
        }
        process.waitUntilExit()

        return mapping
    }

    private struct ContainerInfo: Decodable {
        let names: String
        let ports: String

        enum CodingKeys: String, CodingKey {
            case names = "Names"
            case ports = "Ports"
        }
    }
}
