//
//  DockerResolver.swift
//  Portly
//

import Foundation

struct DockerPortDetails: Hashable {
    let containerName: String
    var composeProject: String?
    var composeService: String?
}

/// Maps host ports published by Docker containers to container names and Compose metadata,
/// so rows can show "myapp-db" or "compose: web" instead of "com.docker.backend".
enum DockerResolver {
    private static let candidatePaths = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        NSHomeDirectory() + "/.docker/bin/docker",
        "/Applications/Docker.app/Contents/Resources/bin/docker",
    ]

    /// Returns [host port: container name] for all running containers.
    static func publishedPorts() async -> [Int: String] {
        let details = await publishedPortDetails()
        return details.mapValues(\.containerName)
    }

    /// Returns rich [host port: DockerPortDetails] including Compose project/service metadata.
    static func publishedPortDetails() async -> [Int: DockerPortDetails] {
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

        var mapping: [Int: DockerPortDetails] = [:]
        do {
            for try await line in stdout.fileHandleForReading.bytes.lines {
                guard let data = line.data(using: .utf8),
                      let container = try? JSONDecoder().decode(ContainerInfo.self, from: data) else { continue }

                let (composeProj, composeSvc) = parseComposeLabels(container.labels ?? "")

                let details = DockerPortDetails(
                    containerName: container.names,
                    composeProject: composeProj,
                    composeService: composeSvc
                )

                // Ports looks like "0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp".
                for match in container.ports.matches(of: /:(\d+)->/) {
                    if let port = Int(match.1) {
                        mapping[port] = details
                    }
                }
            }
        } catch {
            return mapping
        }
        process.waitUntilExit()

        return mapping
    }

    private static func parseComposeLabels(_ labels: String) -> (project: String?, service: String?) {
        var project: String?
        var service: String?

        for pair in labels.split(separator: ",") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            let key = kv[0].trimmingCharacters(in: .whitespaces)
            let val = kv[1].trimmingCharacters(in: .whitespaces)

            if key == "com.docker.compose.project" {
                project = val
            } else if key == "com.docker.compose.service" {
                service = val
            }
        }
        return (project, service)
    }

    private struct ContainerInfo: Decodable {
        let names: String
        let ports: String
        let labels: String?

        enum CodingKeys: String, CodingKey {
            case names = "Names"
            case ports = "Ports"
            case labels = "Labels"
        }
    }
}
