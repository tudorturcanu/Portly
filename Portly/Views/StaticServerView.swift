//
//  StaticServerView.swift
//  Portly
//

import SwiftUI
import AppKit

/// Simple assistant to instantly host any local directory on an open HTTP port.
struct StaticServerView: View {
    var monitor: PortMonitor?

    @State private var folderPath = ""
    @State private var portText = "8000"
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var serverManager: StaticServerManager {
        StaticServerManager.shared
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            folderSelectionSection

            portSelectionSection

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let success = successMessage {
                Text(success)
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            HStack {
                Spacer()
                Button("Start Serving") {
                    startServing()
                }
                .buttonStyle(.borderedProminent)
                .disabled(folderPath.isEmpty || Int(portText) == nil)
            }

            if !serverManager.activeServers.isEmpty {
                Divider()
                activeServersSection
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 440, height: serverManager.activeServers.isEmpty ? 300 : 440)
        .onAppear {
            suggestPort()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.badge.gearshape")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 1) {
                Text("Serve Folder on Port")
                    .font(.headline)
                Text("Host static assets, mock API fixtures, or frontend builds over local HTTP.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var folderSelectionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Directory:")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                TextField("Choose a folder to serve…", text: $folderPath)
                    .textFieldStyle(.roundedBorder)

                Button("Browse…") {
                    selectFolder()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var portSelectionSection: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Port:")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Text(":")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    TextField("8000", text: $portText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 100)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("URL:")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("http://localhost:\(portText.isEmpty ? "8000" : portText)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tint)
            }
        }
    }

    private var activeServersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Static Servers")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(serverManager.activeServers) { s in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                    Text(":\(s.port)")
                                        .font(.system(.caption, design: .monospaced).weight(.bold))
                                    Text(s.directoryName)
                                        .font(.caption)
                                }
                                Text(s.directoryPath)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Button("Browser", systemImage: "safari") {
                                if let url = s.localURL {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)

                            Button("Copy URL", systemImage: "doc.on.doc") {
                                if let url = s.localURL {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                                }
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)

                            Button("Stop", systemImage: "xmark.circle.fill") {
                                serverManager.stopServer(port: s.port)
                                Task { await monitor?.refresh() }
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                        }
                        .padding(8)
                        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 6))
                    }
                }
            }
            .frame(maxHeight: 120)
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"

        if panel.runModal() == .OK, let url = panel.url {
            folderPath = url.path
            errorMessage = nil
        }
    }

    private func suggestPort() {
        let common = [8000, 8080, 5000, 3000, 8888]
        let occupied = Set(monitor?.ports.map(\.port) ?? [])
        if let free = common.first(where: { !occupied.contains($0) }) {
            portText = "\(free)"
        }
    }

    private func startServing() {
        guard let p = Int(portText.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = "Please specify a valid port number."
            return
        }
        guard !folderPath.isEmpty, FileManager.default.fileExists(atPath: folderPath) else {
            errorMessage = "Directory does not exist."
            return
        }

        errorMessage = nil
        let success = serverManager.startServer(directoryPath: folderPath, port: p)
        if success {
            successMessage = "Started HTTP server on :\(p)!"
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                await monitor?.refresh()
            }
        } else {
            errorMessage = "Could not start server on port :\(p). It may already be in use."
        }
    }
}
