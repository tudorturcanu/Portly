//
//  ProcessLogView.swift
//  Portly
//

import SwiftUI

/// Live terminal-style log streaming viewer for a running process or Docker container.
struct ProcessLogView: View {
    let port: ListeningPort
    @State private var streamer: ProcessLogStreamer
    @State private var searchText = ""
    @State private var autoScroll = true

    init(port: ListeningPort) {
        self.port = port
        _streamer = State(initialValue: ProcessLogStreamer(port: port))
    }

    private var filteredLines: [String] {
        if searchText.isEmpty {
            return streamer.lines
        }
        return streamer.lines.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbarHeader
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            logTerminalBody

            Divider()

            statusBar
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .frame(minWidth: 620, minHeight: 400)
        .onAppear {
            streamer.start()
        }
        .onDisappear {
            streamer.stop()
        }
    }

    private var toolbarHeader: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(port.displayName)
                        .font(.headline)
                    Text(verbatim: ":\(port.port)")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if port.containerName != nil {
                        Text("Docker")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.12), in: .capsule)
                    }
                }
                Text("PID \(port.pid) · \(port.displayAddress)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                TextField("Filter logs…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(width: 140)

                if !searchText.isEmpty {
                    Button("Clear Filter", systemImage: "xmark.circle.fill") {
                        searchText = ""
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))

            Button(streamer.isStreaming ? "Pause" : "Resume",
                   systemImage: streamer.isStreaming ? "pause.fill" : "play.fill") {
                if streamer.isStreaming {
                    streamer.stop()
                } else {
                    streamer.start()
                }
            }
            .controlSize(.small)

            Button("Clear", systemImage: "trash") {
                streamer.clear()
            }
            .controlSize(.small)
        }
    }

    private var logTerminalBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if filteredLines.isEmpty {
                        Text(streamer.lines.isEmpty ? "Waiting for log output…" : "No lines match filter")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(12)
                    } else {
                        ForEach(Array(filteredLines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: streamer.lines.count) { _, _ in
                if autoScroll, let last = filteredLines.indices.last {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Toggle("Auto-scroll", isOn: $autoScroll)
                .toggleStyle(.checkbox)
                .font(.caption2)

            Spacer()

            if let msg = streamer.statusMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("\(streamer.lines.count) lines")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Button("Copy All", systemImage: "doc.on.doc") {
                let all = streamer.lines.joined(separator: "\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(all, forType: .string)
            }
            .labelStyle(.titleAndIcon)
            .controlSize(.mini)
            .buttonStyle(.borderless)
        }
    }
}
