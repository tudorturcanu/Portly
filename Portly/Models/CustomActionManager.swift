//
//  CustomActionManager.swift
//  Portly
//

import Foundation
import Observation
import AppKit

/// Manages user-configured custom actions and handles execution.
@Observable
@MainActor
final class CustomActionManager {
    static let shared = CustomActionManager()
    static let defaultsKey = "customDeveloperActions"

    var actions: [CustomAction] = []

    init() {
        loadActions()
    }

    func loadActions() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([CustomAction].self, from: data) {
            actions = decoded
        } else {
            actions = Self.defaultActions
            saveActions()
        }
    }

    func saveActions() {
        if let data = try? JSONEncoder().encode(actions) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    func addAction(_ action: CustomAction) {
        actions.append(action)
        saveActions()
    }

    func updateAction(_ action: CustomAction) {
        if let idx = actions.firstIndex(where: { $0.id == action.id }) {
            actions[idx] = action
            saveActions()
        }
    }

    func deleteAction(id: UUID) {
        actions.removeAll { $0.id == id }
        saveActions()
    }

    func actions(for port: ListeningPort) -> [CustomAction] {
        actions.filter { action in
            action.targetPort == nil || action.targetPort == port.port
        }
    }

    @discardableResult
    func run(_ action: CustomAction, on port: ListeningPort, workingDirectory: String? = nil) async -> (success: Bool, output: String) {
        let cmd = action.interpolatedCommand(port: port, workingDirectory: workingDirectory)

        if action.runInTerminal {
            let script = "tell application \"Terminal\" to do script \"\(cmd.replacingOccurrences(of: "\"", with: "\\\""))\""
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
            return (error == nil, "Launched in Terminal")
        }

        // Run as background process
        let process = Process()
        process.executableURL = URL(filePath: "/bin/zsh")
        process.arguments = ["-c", cmd]

        if let cwd = workingDirectory, FileManager.default.fileExists(atPath: cwd) {
            process.currentDirectoryURL = URL(filePath: cwd)
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(decoding: data, as: UTF8.self)
            return (process.terminationStatus == 0, output)
        } catch {
            return (false, "Execution failed: \(error.localizedDescription)")
        }
    }

    static var defaultActions: [CustomAction] = [
        CustomAction(
            name: "cURL Root",
            command: "curl -i $URL/",
            icon: "network",
            targetPort: nil,
            runInTerminal: false
        ),
        CustomAction(
            name: "Inspect HTTP Headers",
            command: "curl -I $URL/",
            icon: "doc.text.magnifyingglass",
            targetPort: nil,
            runInTerminal: false
        )
    ]
}
