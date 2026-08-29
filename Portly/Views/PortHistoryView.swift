//
//  PortHistoryView.swift
//  Portly
//

import SwiftUI

/// Detailed timeline and analytics window for past and active port sessions.
struct PortHistoryView: View {
    var historyManager: PortHistoryManager = .shared

    @State private var searchText = ""
    @State private var confirmingClear = false

    private var filteredRecords: [PortHistoryRecord] {
        if searchText.isEmpty {
            return historyManager.records
        }
        return historyManager.records.filter {
            String($0.port).contains(searchText)
                || $0.displayName.localizedCaseInsensitiveContains(searchText)
                || ($0.smartDescriptor?.localizedCaseInsensitiveContains(searchText) ?? false)
                || ($0.currentWorkingDirectory?.localizedCaseInsensitiveContains(searchText) ?? false)
                || ($0.executablePath?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            analyticsHeader
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            Divider()

            searchAndFilterBar
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            Divider()

            if filteredRecords.isEmpty {
                emptyState
            } else {
                historyList
            }

            Divider()

            footerBar
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .frame(minWidth: 540, minHeight: 440)
        .confirmationDialog("Clear all history?", isPresented: $confirmingClear) {
            Button("Clear All History", role: .destructive) {
                historyManager.clearHistory()
            }
        } message: {
            Text("This will permanently remove all tracked port session records.")
        }
    }

    private var analyticsHeader: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Total Sessions",
                value: "\(historyManager.totalSessions)",
                icon: "clock.arrow.circlepath",
                color: .blue
            )

            statCard(
                title: "Unique Ports",
                value: "\(historyManager.uniquePortsCount)",
                icon: "number",
                color: .purple
            )

            if let top = historyManager.mostUsedPorts.first {
                statCard(
                    title: "Top Port",
                    value: ":\(top.port) (\(top.count)×)",
                    icon: "star.fill",
                    color: .orange
                )
            } else {
                statCard(
                    title: "Top Port",
                    value: "-",
                    icon: "star",
                    color: .secondary
                )
            }

            statCard(
                title: "Total Time",
                value: formatDuration(historyManager.totalTrackedSeconds),
                icon: "hourglass",
                color: .green
            )
        }
    }

    private func statCard(title: LocalizedStringKey, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
    }

    private var searchAndFilterBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search history by port, process, or working directory…", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") {
                    searchText = ""
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var historyList: some View {
        List {
            ForEach(filteredRecords) { record in
                historyRow(record)
                    .contextMenu {
                        if let cwd = record.currentWorkingDirectory {
                            Button("Open in Terminal", systemImage: "terminal") {
                                TerminalLauncher.openInTerminal(at: cwd)
                            }
                            Button("Open in IDE", systemImage: "chevron.left.forwardslash.chevron.right") {
                                TerminalLauncher.openInEditor(at: cwd)
                            }
                        }
                        Button("Copy Port (: \(record.port))", systemImage: "doc.on.doc") {
                            copyToPasteboard(":\(record.port)")
                        }
                        if let cwd = record.currentWorkingDirectory {
                            Button("Copy Working Directory", systemImage: "folder") {
                                copyToPasteboard(cwd)
                            }
                        }
                        Button("Copy Details", systemImage: "list.bullet.clipboard") {
                            let json = try? JSONEncoder().encode(record)
                            if let json, let str = String(data: json, encoding: .utf8) {
                                copyToPasteboard(str)
                            }
                        }
                    }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func historyRow(_ record: PortHistoryRecord) -> some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 4) {
                if record.isActive {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                } else {
                    Circle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                }

                Text(verbatim: ":\(record.port)")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
            }
            .frame(width: 65, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(record.displayName)
                        .font(.callout.weight(.medium))

                    if let smart = record.smartDescriptor {
                        Text(smart)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tint)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.12), in: .capsule)
                    }

                    if record.networkProtocol == "UDP" {
                        Text("UDP")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: .capsule)
                    }
                }

                if let cwd = record.currentWorkingDirectory {
                    Text(cwd)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .truncationMode(.middle)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if record.isActive {
                    Text("ACTIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                } else {
                    Text(formatDuration(record.duration))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(record.startedAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(searchText.isEmpty ? "No Port History" : "No Matches",
                  systemImage: searchText.isEmpty ? "clock.arrow.circlepath" : "magnifyingglass")
                .font(.headline)
        } description: {
            Text(searchText.isEmpty
                 ? "Portly records dev server sessions as they open and close."
                 : "No historical sessions match “\(searchText)”.")
        }
        .frame(maxHeight: .infinity)
    }

    private var footerBar: some View {
        HStack {
            Button("Clear History…", systemImage: "trash") {
                confirmingClear = true
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .disabled(historyManager.records.isEmpty)

            Spacer()

            Menu("Export History", systemImage: "square.and.arrow.up") {
                Button("Export as Markdown Table") {
                    exportToClipboard(format: .markdown)
                }
                Button("Export as CSV") {
                    exportToClipboard(format: .csv)
                }
                Button("Export as JSON") {
                    exportToClipboard(format: .json)
                }
            }
            .menuStyle(.borderlessButton)
            .disabled(historyManager.records.isEmpty)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            let hours = Int(seconds / 3600)
            let mins = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(mins)m"
        }
    }

    private func exportToClipboard(format: ExportFormat) {
        let content = historyManager.export(format: format)
        copyToPasteboard(content)
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
