//
//  ProcessDetailView.swift
//  Portly
//

import SwiftUI

/// Popover with everything Portly knows about the process behind a port.
struct ProcessDetailView: View {
    let port: ListeningPort
    var monitor: PortMonitor

    @State private var details = ProcessDetails()

    private var siblingPorts: [ListeningPort] {
        monitor.ports.filter { $0.pid == port.pid && $0.id != port.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(port.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(verbatim: ":\(port.port)")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 4) {
                if let path = port.executablePath {
                    detailRow("Path") {
                        Text(path)
                            .truncationMode(.middle)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                }
                if let user = port.user {
                    detailRow("User") { Text(user) }
                }
                detailRow("PID") { Text(verbatim: "\(port.pid)") }
                if let startedAt = details.startedAt {
                    detailRow("Started") {
                        Text(startedAt, format: .relative(presentation: .named))
                    }
                }
                if let cpuTime = details.cpuTime {
                    detailRow("CPU time") {
                        Text(Duration.seconds(cpuTime), format: .time(pattern: .hourMinuteSecond))
                    }
                }
                if let memory = details.memoryBytes {
                    detailRow("Memory") {
                        Text(Int64(memory), format: .byteCount(style: .memory))
                    }
                }
                if let arguments = details.arguments, arguments.count > 1 {
                    detailRow("Command") {
                        Text(arguments.joined(separator: " "))
                            .lineLimit(3)
                            .truncationMode(.tail)
                            .textSelection(.enabled)
                    }
                }
                if !siblingPorts.isEmpty {
                    detailRow("Also on") {
                        Text(siblingPorts.map { ":\($0.port)" }.joined(separator: "  "))
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
            .font(.caption)

            HStack(spacing: 8) {
                if let path = port.executablePath {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
                    }
                }
                if port.networkProtocol == .tcp, let url = port.localURL {
                    Button("Open in Browser") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Spacer()
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 330)
        .onAppear {
            details = ProcessInspector.details(for: port.pid)
        }
    }

    private func detailRow(_ label: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    ProcessDetailView(
        port: ListeningPort(port: 3000, pid: 501, processName: "node", address: "*", user: NSUserName(), executablePath: "/opt/homebrew/bin/node"),
        monitor: .preview
    )
}
