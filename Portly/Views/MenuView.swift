//
//  MenuView.swift
//  Portly
//

import SwiftUI

/// The panel shown when clicking the menu bar icon.
struct MenuView: View {
    var monitor: PortMonitor

    @Environment(\.openSettings) private var openSettings

    @AppStorage("showSystemProcesses") private var showSystemProcesses = false
    @AppStorage("showUDPPorts") private var showUDPPorts = false
    @State private var searchText = ""
    @State private var listHeight = 0.0
    @State private var confirmingStopAll = false

    private let maxListHeight = 400.0

    private var visiblePorts: [ListeningPort] {
        var ports = monitor.ports
        if !showSystemProcesses {
            ports = ports.filter { !$0.isSystemProcess }
        }
        if !showUDPPorts {
            ports = ports.filter { $0.networkProtocol == .tcp }
        }
        if !searchText.isEmpty {
            ports = ports.filter {
                $0.displayName.localizedStandardContains(searchText)
                    || String($0.port).contains(searchText)
                    || ($0.customAlias?.localizedStandardContains(searchText) ?? false)
                    || ($0.hint?.localizedStandardContains(searchText) ?? false)
                    || $0.networkProtocol.rawValue.localizedStandardContains(searchText)
            }
        }
        return ports
    }

    private var pinnedVisible: [ListeningPort] {
        visiblePorts.filter { monitor.pinnedPorts.contains($0.port) }
    }

    private var unpinnedVisible: [ListeningPort] {
        visiblePorts.filter { !monitor.pinnedPorts.contains($0.port) }
    }

    /// Ghost rows, minus ports already represented by a dead pinned row.
    private var visibleGhosts: [ClosedPort] {
        guard searchText.isEmpty else { return [] }
        return monitor.recentlyClosed.filter { !monitor.pinnedPorts.contains($0.port) }
    }

    private var hasListContent: Bool {
        !visiblePorts.isEmpty || !monitor.deadPinnedPorts.isEmpty || !visibleGhosts.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 12)
                .padding(.vertical, 9)

            Divider()

            if monitor.ports.count > 6 {
                searchField
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
            }

            if hasListContent {
                portList
            } else {
                emptyState
                    .frame(height: 170)
            }

            Divider()

            footer
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: 340)
        .confirmationDialog(
            "Stop all dev servers?",
            isPresented: $confirmingStopAll
        ) {
            Button("Stop \(monitor.userDevServers.count) Listeners", role: .destructive) {
                monitor.terminateAllDevServers()
            }
        } message: {
            Text("Sends SIGTERM to every non-system process of yours with a listening TCP port.")
        }
        .task {
            // Fast refresh while the panel is open; PortMonitor keeps its own
            // slower loop running in the background for the badge and notifications.
            while !Task.isCancelled {
                await monitor.refresh()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Portly")
                .font(.headline)

            if !visiblePorts.isEmpty {
                Text(visiblePorts.count, format: .number)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: .capsule)
            }

            Spacer()

            settingsMenu
        }
    }

    private var settingsMenu: some View {
        Menu {
            Button("Settings…", systemImage: "gearshape") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Menu("Copy Port List", systemImage: "list.clipboard") {
                Button("Copy as Markdown Table") {
                    copyPortList(format: .markdown)
                }
                Button("Copy as JSON") {
                    copyPortList(format: .json)
                }
                Button("Copy as CSV") {
                    copyPortList(format: .csv)
                }
            }

            if AppCapabilities.canTerminateProcesses {
                Button("Stop All Dev Servers…", systemImage: "stop.circle", role: .destructive) {
                    confirmingStopAll = true
                }
                .disabled(monitor.userDevServers.isEmpty)
            }

            Divider()

            Button("About Portly") {
                AboutWindow.show()
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("Quit Portly") {
                NSApp.terminate(nil)
            }
        } label: {
            Image(systemName: "gearshape")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var searchField: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Filter by port or process", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button("Clear Filter", systemImage: "xmark.circle.fill") {
                    searchText = ""
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 6))
    }

    private var portList: some View {
        ScrollView {
            VStack(spacing: 1) {
                if !pinnedVisible.isEmpty || !monitor.deadPinnedPorts.isEmpty {
                    sectionHeader("Pinned")
                    ForEach(pinnedVisible) { port in
                        PortRowView(port: port, monitor: monitor)
                    }
                    ForEach(monitor.deadPinnedPorts, id: \.self) { port in
                        DeadPinnedRowView(port: port, monitor: monitor)
                    }
                    if !unpinnedVisible.isEmpty {
                        sectionHeader("Ports")
                    }
                }

                ForEach(unpinnedVisible) { port in
                    PortRowView(port: port, monitor: monitor)
                }

                if !visibleGhosts.isEmpty {
                    sectionHeader("Recently Stopped")
                    ForEach(visibleGhosts) { closed in
                        ClosedPortRowView(closed: closed)
                    }
                }
            }
            .padding(6)
            .onGeometryChange(for: Double.self, of: { $0.size.height }) {
                listHeight = $0
            }
        }
        .frame(height: min(listHeight, maxListHeight))
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(emptyStateTitle, systemImage: searchText.isEmpty ? "moon.zzz" : "magnifyingglass")
                .font(.headline)
        } description: {
            Text(emptyStateDescription)
        }
    }

    private var emptyStateTitle: String {
        searchText.isEmpty ? "No Open Ports" : "No Matches"
    }

    private var emptyStateDescription: String {
        if !searchText.isEmpty {
            "Nothing matches “\(searchText)”."
        } else if showSystemProcesses {
            "Nothing is listening on this Mac right now."
        } else {
            "No dev servers are listening right now. System processes are hidden — show them in Settings."
        }
    }

    private func copyPortList(format: ExportFormat = .markdown) {
        let content = PortExporter.export(visiblePorts, format: format)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    private var footer: some View {
        HStack(spacing: 4) {
            if let message = monitor.statusMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            } else if let lastUpdated = monitor.lastUpdated {
                Text("Updated \(lastUpdated, format: .relative(presentation: .numeric))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Scanning…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Refresh", systemImage: "arrow.clockwise") {
                Task { await monitor.refresh() }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Refresh now")
        }
    }
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        MenuView(monitor: .preview)
    }
}
