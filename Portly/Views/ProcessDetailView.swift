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
    @State private var aliasText = ""
    @State private var showingEnvVars = false
    @State private var showingRequestTester = false
    @State private var showingConnections = false
    @State private var envSearchText = ""
    @State private var maskSecrets = true

    private var siblingPorts: [ListeningPort] {
        monitor.ports.filter { $0.pid == port.pid && $0.id != port.id }
    }

    private var customActions: [CustomAction] {
        CustomActionManager.shared.actions(for: port)
    }

    private var filteredEnvVars: [EnvironmentVariable] {
        guard let vars = details.environmentVariables else { return [] }
        if envSearchText.isEmpty { return vars }
        return vars.filter {
            $0.key.localizedCaseInsensitiveContains(envSearchText)
                || $0.value.localizedCaseInsensitiveContains(envSearchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 4) {
                aliasRow
                if let lanURL = port.lanURL() {
                    lanURLRow(lanURL)
                }
                tunnelRow
                if let cwd = details.currentWorkingDirectory {
                    workingDirectoryRow(cwd)
                }
                if let path = port.executablePath {
                    pathRow(path)
                }
                if let container = port.containerName {
                    detailRow("Container") { Text(container) }
                }
                if let proj = port.composeProject {
                    detailRow("Compose Proj") { Text(proj) }
                }
                if let svc = port.composeService {
                    detailRow("Compose Svc") { Text(svc) }
                }
                if let user = port.user {
                    detailRow("User") { Text(user) }
                }
                detailRow("PID") { Text(verbatim: "\(port.pid)") }
                if port.establishedConnections > 0 {
                    detailRow("Connections") {
                        HStack(spacing: 6) {
                            Text("\(port.establishedConnections) established")
                                .foregroundStyle(.tint)
                            let samples = monitor.connectionHistory[port.port] ?? [port.establishedConnections]
                            ConnectionSparklineView(samples: samples, tintColor: .blue, height: 14)
                                .frame(width: 48)
                                .help("Recent connection activity")
                        }
                    }
                }
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

            if port.networkProtocol == .tcp && !port.activeConnections.isEmpty {
                Divider()
                activeConnectionsSection
            }

            if port.networkProtocol == .tcp {
                Divider()
                requestTesterSection
            }

            if let envVars = details.environmentVariables, !envVars.isEmpty {
                Divider()
                environmentSection(envVars: envVars)
            }

            if !customActions.isEmpty {
                Divider()
                customActionsSection
            }

            Divider()

            footerActions
        }
        .padding(12)
        .frame(width: (showingEnvVars || showingRequestTester || showingConnections) ? 440 : 360)
        .onAppear {
            aliasText = monitor.customAliases[port.port] ?? ""
            details = ProcessInspector.details(
                for: port.pid,
                processName: port.processName,
                executablePath: port.executablePath
            )
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(port.displayName)
                .font(.headline)
                .lineLimit(1)
            Text(verbatim: ":\(port.port)")
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(.secondary)

            if let smart = details.smartDescriptor ?? port.smartDescriptor {
                Text(smart)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12), in: .capsule)
            }

            Spacer()
        }
    }

    private var aliasRow: some View {
        detailRow("Alias") {
            HStack(spacing: 4) {
                TextField("e.g. Frontend Web", text: $aliasText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        monitor.setAlias(aliasText, for: port.port)
                    }
                if monitor.customAliases[port.port] != nil {
                    Button("Clear") {
                        aliasText = ""
                        monitor.setAlias(nil, for: port.port)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private func lanURLRow(_ lanURL: URL) -> some View {
        detailRow("LAN URL") {
            HStack(spacing: 4) {
                Text(lanURL.absoluteString)
                    .textSelection(.enabled)
                Button("Show Mobile QR Code", systemImage: "qrcode") {
                    MobileQRCodeWindow.show(for: port)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Show Mobile QR Code to scan with phone camera")

                Button("Copy", systemImage: "doc.on.doc") {
                    copyToPasteboard(lanURL.absoluteString)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Copy LAN URL")
            }
        }
    }

    @ViewBuilder
    private var tunnelRow: some View {
        if let tunnelURL = TunnelManager.shared.tunnelURL(for: port.port) {
            detailRow("Tunnel") {
                HStack(spacing: 4) {
                    Text(tunnelURL.absoluteString)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Button("Mobile QR Code", systemImage: "qrcode") {
                        MobileQRCodeWindow.show(for: port)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Show Mobile QR Code")

                    Button("Copy", systemImage: "doc.on.doc") {
                        copyToPasteboard(tunnelURL.absoluteString)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)

                    Button("Open", systemImage: "safari") {
                        NSWorkspace.shared.open(tunnelURL)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)

                    Button("Stop", systemImage: "xmark.circle") {
                        TunnelManager.shared.stopTunnel(for: port.port)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }
            }
        }
    }

    private func workingDirectoryRow(_ cwd: String) -> some View {
        detailRow("Work Dir") {
            HStack(spacing: 4) {
                Text(cwd)
                    .truncationMode(.middle)
                    .lineLimit(1)
                    .textSelection(.enabled)
                Button("Copy", systemImage: "doc.on.doc") {
                    copyToPasteboard(cwd)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Copy working directory path")
            }
        }
    }

    private func pathRow(_ path: String) -> some View {
        detailRow("Path") {
            Text(path)
                .truncationMode(.middle)
                .lineLimit(1)
                .textSelection(.enabled)
        }
    }

    private var requestTesterSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingRequestTester.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showingRequestTester ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                    Text("API / HTTP Tester")
                        .font(.caption.weight(.semibold))
                }
            }
            .buttonStyle(.plain)

            if showingRequestTester {
                QuickRequestView(port: port)
            }
        }
    }

    private func environmentSection(envVars: [EnvironmentVariable]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingEnvVars.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showingEnvVars ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                        Text("Environment Variables (\(envVars.count))")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if showingEnvVars {
                    Button(maskSecrets ? "Reveal Values" : "Mask Secrets", systemImage: maskSecrets ? "eye" : "eye.slash") {
                        maskSecrets.toggle()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help(maskSecrets ? "Reveal secret values" : "Mask secret values")

                    Button("Copy .env", systemImage: "doc.on.doc") {
                        let dotEnv = envVars.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
                        copyToPasteboard(dotEnv)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                    .help("Copy all environment variables in .env format")
                }
            }

            if showingEnvVars {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                    TextField("Filter variables", text: $envSearchText)
                        .textFieldStyle(.plain)
                        .font(.caption2)
                    if !envSearchText.isEmpty {
                        Button("Clear", systemImage: "xmark.circle.fill") {
                            envSearchText = ""
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 4))

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(filteredEnvVars) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(item.key)
                                    .font(.system(.caption2, design: .monospaced).weight(.medium))
                                    .foregroundStyle(item.isSensitive ? Color.orange : Color.primary)
                                    .textSelection(.enabled)

                                Text("=")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                Text(maskSecrets && item.isSensitive ? item.maskedValue : item.value)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)

                                Spacer(minLength: 4)

                                Button("Copy", systemImage: "doc.on.doc") {
                                    copyToPasteboard(item.value)
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .font(.system(size: 9))
                                .help("Copy \(item.key) value")
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }
                .frame(maxHeight: 140)
            }
        }
    }

    private var customActionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Custom Actions")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(customActions) { act in
                        Button {
                            let cwd = details.currentWorkingDirectory
                            Task {
                                await CustomActionManager.shared.run(act, on: port, workingDirectory: cwd)
                            }
                        } label: {
                            Label(act.name, systemImage: act.icon)
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var footerActions: some View {
        HStack(spacing: 8) {
            if let cwd = details.currentWorkingDirectory {
                Button("Terminal", systemImage: "terminal") {
                    TerminalLauncher.openInTerminal(at: cwd)
                }
                Button("IDE", systemImage: "chevron.left.forwardslash.chevron.right") {
                    TerminalLauncher.openInEditor(at: cwd)
                }
            } else if let path = port.executablePath {
                Button("Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
                }
            }

            Button("Logs", systemImage: "text.alignleft") {
                ProcessLogWindow.show(for: port)
            }

            if port.networkProtocol == .tcp, let url = port.localURL {
                Button("Browser", systemImage: "safari") {
                    NSWorkspace.shared.open(url)
                }
            }

            if let container = port.containerName {
                Button("Restart", systemImage: "arrow.clockwise") {
                    Task {
                        await DockerManager.restartContainer(container)
                        await monitor.refresh()
                    }
                }
            }

            if !TunnelManager.shared.isTunneling(port.port) {
                Button("Tunnel", systemImage: "globe") {
                    Task { await TunnelManager.shared.startTunnel(for: port.port) }
                }
                .disabled(TunnelManager.shared.isStarting(port.port))
            }

            Spacer()
        }
        .controlSize(.small)
    }

    private var activeConnectionsSection: some View {
        DisclosureGroup(isExpanded: $showingConnections) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(port.activeConnections.count) peer connection(s)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    let samples = monitor.connectionHistory[port.port] ?? [port.establishedConnections]
                    ConnectionSparklineView(samples: samples, tintColor: .blue, height: 16)
                        .frame(width: 80)
                        .help("Real-time connection activity over time")
                }
                .padding(.bottom, 2)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(port.activeConnections) { conn in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(conn.state == "ESTABLISHED" ? Color.green : Color.orange)
                                    .frame(width: 6, height: 6)

                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 4) {
                                        Text(conn.remoteEndpointString)
                                            .font(.system(.caption2, design: .monospaced).weight(.medium))
                                            .textSelection(.enabled)

                                        Text(conn.originDescription)
                                            .font(.system(size: 9).weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(.quaternary, in: .capsule)
                                    }

                                    if let client = conn.clientDisplayName {
                                        Text(client)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tint)
                                    }
                                }

                                Spacer()

                                Text(conn.state)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                Button("Copy Address", systemImage: "doc.on.doc") {
                                    copyToPasteboard(conn.remoteEndpointString)
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .help("Copy remote address")
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 4))
                        }
                    }
                }
                .frame(maxHeight: 140)
            }
            .padding(.top, 4)
        } label: {
            HStack {
                Label("Active Connections", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.caption.weight(.medium))
                Spacer()
                Text("\(port.activeConnections.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.12), in: .capsule)
            }
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

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

struct ProcessDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ProcessDetailView(
            port: ListeningPort(port: 3000, pid: 501, processName: "node", address: "*", user: NSUserName(), executablePath: "/opt/homebrew/bin/node"),
            monitor: .preview
        )
    }
}
