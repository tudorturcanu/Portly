//
//  PortFreeView.swift
//  Portly
//

import SwiftUI

/// Assistant to inspect and terminate processes occupying a port to resolve EADDRINUSE conflicts.
struct PortFreeView: View {
    var monitor: PortMonitor?

    @State private var portInput = ""
    @State private var inspectedPort: Int?
    @State private var occupant: PortOccupant?
    @State private var isChecking = false
    @State private var freedMessage: String?
    @State private var errorMessage: String?

    private let commonPorts = [3000, 3001, 5173, 8000, 8080, 5432, 6379, 27017]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            portInputField

            commonPortChips

            Divider()

            statusSection

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 440, height: 420)
        .task {
            if let first = monitor?.ports.first {
                portInput = String(first.port)
                await checkPort(first.port)
            } else {
                portInput = "3000"
                await checkPort(3000)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.shield.fill")
                .font(.title)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("Free a Port (Clash Resolver)")
                    .font(.headline)
                Text("Inspect and terminate processes blocking a port to resolve EADDRINUSE errors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var portInputField: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(":")
                    .font(.system(.body, design: .monospaced).weight(.bold))
                    .foregroundStyle(.secondary)
                TextField("Port number (e.g. 3000)", text: $portInput)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        if let port = Int(portInput.trimmingCharacters(in: .whitespaces)) {
                            Task { await checkPort(port) }
                        }
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 6))

            Button("Check Port") {
                if let port = Int(portInput.trimmingCharacters(in: .whitespaces)) {
                    Task { await checkPort(port) }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(Int(portInput.trimmingCharacters(in: .whitespaces)) == nil || isChecking)
        }
    }

    private var commonPortChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quick Presets")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(commonPorts, id: \.self) { p in
                        let isOccupied = monitor?.ports.contains(where: { $0.port == p }) ?? false
                        Button {
                            portInput = "\(p)"
                            Task { await checkPort(p) }
                        } label: {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(isOccupied ? Color.red : Color.green.opacity(0.7))
                                    .frame(width: 6, height: 6)
                                Text(":\(p)")
                                    .font(.system(.caption, design: .monospaced))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(inspectedPort == p ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.quaternary.opacity(0.5)), in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if isChecking {
            HStack {
                Spacer()
                ProgressView("Inspecting port :\(inspectedPort ?? 0)…")
                    .font(.caption)
                Spacer()
            }
            .padding(.vertical, 30)
        } else if let msg = freedMessage {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
                Text(msg)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("The port is now completely free and available for binding.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.green.opacity(0.08), in: .rect(cornerRadius: 10))
        } else if let occ = occupant {
            occupantCard(occ)
        } else if let port = inspectedPort {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
                Text("Port :\(port) is Available")
                    .font(.headline)
                Text("No process is currently listening on port \(port). Ready to start your dev server!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.green.opacity(0.06), in: .rect(cornerRadius: 10))
        }

        if let err = errorMessage {
            Text(err)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private func occupantCard(_ occ: PortOccupant) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Port :\(occ.port) is Blocked")
                        .font(.headline)
                    Text("Occupied by \(occ.processName) (PID \(occ.pid))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if occ.isOwnedByCurrentUser {
                    Text("Your Process")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12), in: .capsule)
                } else {
                    Text("Other User (\(occ.user ?? "system"))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12), in: .capsule)
                }
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 4) {
                GridRow {
                    Text("Command:")
                        .foregroundStyle(.secondary)
                    if let cmd = occ.commandLine?.joined(separator: " ") {
                        Text(cmd)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    } else {
                        Text(occ.processName)
                    }
                }
                if let path = occ.executablePath {
                    GridRow {
                        Text("Path:")
                            .foregroundStyle(.secondary)
                        Text(path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }
            }
            .font(.caption)

            HStack(spacing: 10) {
                if occ.isOwnedByCurrentUser {
                    Button(role: .destructive) {
                        Task { await terminateOccupant(occ, force: false) }
                    } label: {
                        Label("Free Port (SIGTERM)", systemImage: "stop.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button(role: .destructive) {
                        Task { await terminateOccupant(occ, force: true) }
                    } label: {
                        Label("Force Kill (SIGKILL)", systemImage: "bolt.circle.fill")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Copy Kill Command", systemImage: "terminal") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("sudo kill -9 \(occ.pid)", forType: .string)
                    }
                    .buttonStyle(.bordered)
                }

                if let path = occ.executablePath {
                    Button("Reveal", systemImage: "folder") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
                    }
                    .buttonStyle(.borderless)
                }
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.2), lineWidth: 1))
    }

    private func checkPort(_ port: Int) async {
        isChecking = true
        inspectedPort = port
        freedMessage = nil
        errorMessage = nil

        let found = await PortClashManager.inspectPort(port)
        occupant = found
        isChecking = false
    }

    private func terminateOccupant(_ occ: PortOccupant, force: Bool) async {
        let success = await PortClashManager.freePort(occupant: occ, force: force)
        if success {
            freedMessage = "Successfully freed port :\(occ.port)!"
            occupant = nil
            await monitor?.refresh()
        } else {
            errorMessage = "Failed to terminate process \(occ.pid). Try force kill or sudo."
        }
    }
}
