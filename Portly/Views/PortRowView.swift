//
//  PortRowView.swift
//  Portly
//

import SwiftUI

/// A single listening port: port number, owning process, and quick actions.
struct PortRowView: View {
    let port: ListeningPort
    var monitor: PortMonitor

    @State private var isHovering = false
    @State private var showingDetails = false

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                if let status = monitor.health[port.port] {
                    Circle()
                        .fill(status < 400 ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                        .help("localhost:\(port.port) answered HTTP \(status)")
                        .accessibilityLabel("HTTP status \(status)")
                }
                Text(verbatim: ":\(port.port)")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
            }
            .frame(width: 62, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(port.displayName)
                    .font(.callout)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if isHovering {
                actions
            } else if monitor.pinnedPorts.contains(port.port) {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .contentShape(.rect)
        .background(isHovering ? AnyShapeStyle(.quaternary.opacity(0.6)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 6))
        .onHover { isHovering = $0 }
        .onTapGesture { showingDetails = true }
        .popover(isPresented: $showingDetails, arrowEdge: .trailing) {
            ProcessDetailView(port: port, monitor: monitor)
        }
        .contextMenu { contextMenuItems }
        .help(port.executablePath ?? port.processName)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let smart = port.smartDescriptor {
            parts.append(smart)
        }
        if port.networkProtocol == .udp {
            parts.append("UDP")
        }
        if port.containerName != nil {
            parts.append("Docker")
        }
        parts.append(port.displayAddress)
        parts.append("pid \(port.pid)")
        if port.establishedConnections > 0 {
            parts.append("\(port.establishedConnections) connected")
        }
        if let hint = port.hint {
            parts.append(hint)
        }
        return parts.joined(separator: " · ")
    }

    private var actions: some View {
        HStack(spacing: 2) {
            if let tunnelURL = TunnelManager.shared.tunnelURL(for: port.port) {
                Button("Copy Tunnel URL", systemImage: "globe") {
                    copyToPasteboard(tunnelURL.absoluteString)
                }
                .help("Copy public tunnel URL: \(tunnelURL.absoluteString)")
                .foregroundStyle(.tint)
            }

            if port.networkProtocol == .tcp {
                Button("Open in Browser", systemImage: "safari", action: openInBrowser)
                    .help("Open localhost:\(port.port) in your browser")

                Button("Copy URL", systemImage: "doc.on.doc", action: copyURL)
                    .help("Copy http://localhost:\(port.port)")
            }

            if port.isOwnedByCurrentUser, AppCapabilities.canTerminateProcesses {
                Button("Stop Process", systemImage: "xmark.circle.fill", role: .destructive) {
                    stop(force: NSEvent.modifierFlags.contains(.option))
                }
                .help("Stop \(port.displayName) — hold ⌥ to force kill")
            } else if port.isOwnedByCurrentUser {
                Button("Copy kill Command", systemImage: "terminal") {
                    copyKillCommand(force: NSEvent.modifierFlags.contains(.option))
                }
                .help("Copy a Terminal command to stop \(port.displayName) — hold ⌥ for force kill")
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.tertiary)
                    .help("Owned by \(port.user ?? "another user") — Portly can't stop it")
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        if monitor.pinnedPorts.contains(port.port) {
            Button("Unpin :\(port.port)", systemImage: "pin.slash") {
                monitor.togglePin(port.port)
            }
        } else {
            Button("Pin :\(port.port)", systemImage: "pin") {
                monitor.togglePin(port.port)
            }
        }
        Divider()

        if port.networkProtocol == .tcp {
            Button("Open in Browser", systemImage: "safari", action: openInBrowser)
            Button("Copy URL", systemImage: "doc.on.doc", action: copyURL)
            if let lanURL = port.lanURL() {
                Button("Copy LAN URL", systemImage: "wifi") {
                    copyToPasteboard(lanURL.absoluteString)
                }
            }
            if let tunnelURL = TunnelManager.shared.tunnelURL(for: port.port) {
                Button("Copy Public Tunnel URL", systemImage: "globe") {
                    copyToPasteboard(tunnelURL.absoluteString)
                }
                Button("Stop Public Tunnel", systemImage: "xmark.circle") {
                    TunnelManager.shared.stopTunnel(for: port.port)
                }
            } else {
                Button("Start Public Tunnel…", systemImage: "globe") {
                    Task { await TunnelManager.shared.startTunnel(for: port.port) }
                }
                .disabled(TunnelManager.shared.isStarting(port.port))
            }
            Button("Copy curl Command", systemImage: "terminal") {
                copyToPasteboard("curl http://localhost:\(port.port)/")
            }
        }

        Button("Copy lsof Command", systemImage: "terminal") {
            copyToPasteboard("lsof -i :\(port.port)")
        }
        Button("Copy PID", systemImage: "number") {
            copyToPasteboard("\(port.pid)")
        }

        Divider()
        Button("Show Details", systemImage: "info.circle") {
            showingDetails = true
        }
        Button("Open in Terminal", systemImage: "terminal") {
            openInTerminal()
        }
        if let path = port.executablePath {
            Button("Reveal in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
            }
        }

        if port.isOwnedByCurrentUser {
            Divider()
            if AppCapabilities.canTerminateProcesses {
                Button("Stop Process", systemImage: "stop.circle") {
                    stop(force: false)
                }
                Button("Force Kill", systemImage: "bolt.circle", role: .destructive) {
                    stop(force: true)
                }
            } else {
                Button("Copy kill Command", systemImage: "terminal") {
                    copyKillCommand(force: false)
                }
                Button("Copy Force-Kill Command", systemImage: "bolt.circle") {
                    copyKillCommand(force: true)
                }
            }
        }
    }

    private func openInTerminal() {
        if let cwd = ProcessInspector.currentWorkingDirectory(for: port.pid) {
            TerminalLauncher.openInTerminal(at: cwd)
        } else if let path = port.executablePath {
            let dir = URL(fileURLWithPath: path).deletingLastPathComponent().path
            TerminalLauncher.openInTerminal(at: dir)
        }
    }

    private func openInBrowser() {
        guard let url = port.localURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func copyURL() {
        copyToPasteboard("http://localhost:\(port.port)")
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func stop(force: Bool) {
        monitor.terminate(port, force: force)
    }

    private func copyKillCommand(force: Bool) {
        copyToPasteboard(force ? "kill -9 \(port.pid)" : "kill \(port.pid)")
    }
}

struct PortRowView_Previews: PreviewProvider {
    static var previews: some View {
        PortRowView(
            port: ListeningPort(port: 3000, pid: 501, processName: "node", address: "*", user: NSUserName(), executablePath: "/opt/homebrew/bin/node"),
            monitor: .preview
        )
        .padding()
        .frame(width: 340)
    }
}
