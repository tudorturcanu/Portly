//
//  SettingsView.swift
//  Portly
//

import SwiftUI

/// The app's Settings window (⌘,), reached via "Settings…" in the gear menu.
/// Accessory apps (no Dock icon) get no automatic Settings menu item, so
/// MenuView opens this explicitly through the `openSettings` environment action.
struct SettingsView: View {
    var monitor: PortMonitor

    var body: some View {
        TabView {
            GeneralSettingsTab(monitor: monitor)
                .tabItem { Label("General", systemImage: "gearshape") }

            FilteringSettingsTab()
                .tabItem { Label("Filtering", systemImage: "line.3.horizontal.decrease.circle") }

            NotificationsSettingsTab(monitor: monitor)
                .tabItem { Label("Notifications", systemImage: "bell") }

            ActionsSettingsTab()
                .tabItem { Label("Actions", systemImage: "command") }
        }
        .frame(width: 480)
        .scenePadding()
    }
}

private struct GeneralSettingsTab: View {
    var monitor: PortMonitor

    @AppStorage("showMenuBarCount") private var showMenuBarCount = true
    @State private var launchAtLogin = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)
            Toggle("Show Dev Server Count in Menu Bar", isOn: $showMenuBarCount)

            Section {
                LabeledContent("Version", value: version)
            }

            Section("Legal & Support") {
                Link("Support & FAQ", destination: URL(string: "https://sudoswisshub.github.io/PortlyLegal/support.html")!)
                Link("Terms of Service", destination: URL(string: "https://sudoswisshub.github.io/PortlyLegal/terms.html")!)
                Link("Privacy Policy", destination: URL(string: "https://sudoswisshub.github.io/PortlyLegal/privacy.html")!)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
        }
        .onChange(of: launchAtLogin) { _, newValue in
            guard newValue != LaunchAtLogin.isEnabled else { return }
            do {
                try LaunchAtLogin.set(newValue)
            } catch {
                launchAtLogin = LaunchAtLogin.isEnabled
                monitor.statusMessage = "Launch at Login failed: \(error.localizedDescription)"
            }
        }
    }
}

private struct FilteringSettingsTab: View {
    @AppStorage("showSystemProcesses") private var showSystemProcesses = false
    @AppStorage("showUDPPorts") private var showUDPPorts = false

    var body: some View {
        Form {
            Section {
                Toggle("Show macOS System Processes", isOn: $showSystemProcesses)
                Toggle("Show UDP Ports", isOn: $showUDPPorts)
            } footer: {
                Text("System processes are macOS daemons like ControlCenter or rapportd — hidden by default so the list stays focused on your own dev servers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct NotificationsSettingsTab: View {
    var monitor: PortMonitor

    @AppStorage(PortNotifier.defaultsKey) private var notifyPortChanges = false
    @AppStorage(PortMonitor.probeDefaultsKey) private var probeLocalhostHTTP = false

    var body: some View {
        Form {
            Section {
                Toggle("Notify When Ports Open or Close", isOn: $notifyPortChanges)
                Toggle("Probe localhost for HTTP Health", isOn: $probeLocalhostHTTP)
            } footer: {
                Text("The health probe sends a lightweight HTTP request to your dev servers every 15 seconds to show a status dot next to each port. Database ports are skipped.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: notifyPortChanges) { _, enabled in
            guard enabled else { return }
            Task {
                if await !PortNotifier.requestPermission() {
                    notifyPortChanges = false
                    monitor.statusMessage = "Notifications are disabled — enable them in System Settings."
                }
            }
        }
    }
}

private struct ActionsSettingsTab: View {
    var actionManager = CustomActionManager.shared
    @State private var showingAddSheet = false
    @State private var editingAction: CustomAction?
    @State private var newName = ""
    @State private var newCommand = ""
    @State private var newRunInTerminal = false
    @State private var newTargetPortString = ""
    @State private var newIcon = "play.fill"

    private let availableIcons = ["play.fill", "terminal", "network", "doc.text.magnifyingglass", "arrow.clockwise", "wrench.and.screwdriver", "bolt.fill", "globe"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Scripts & Actions")
                    .font(.headline)
                Spacer()
                Button("Add Action", systemImage: "plus") {
                    newName = ""
                    newCommand = ""
                    newRunInTerminal = false
                    newTargetPortString = ""
                    newIcon = "play.fill"
                    showingAddSheet = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Text("Attach custom commands to ports or services. Available variables: `$PORT`, `$PID`, `$CWD`, `$NAME`, `$URL`, `$HOST`.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                ForEach(actionManager.actions) { action in
                    HStack(spacing: 8) {
                        Image(systemName: action.icon)
                            .foregroundStyle(.tint)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(action.name)
                                    .font(.callout.weight(.medium))
                                if let port = action.targetPort {
                                    Text(":\(port)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 4)
                                        .background(.quaternary, in: .capsule)
                                }
                                if action.runInTerminal {
                                    Text("Terminal")
                                        .font(.caption2)
                                        .foregroundStyle(.purple)
                                        .padding(.horizontal, 4)
                                        .background(Color.purple.opacity(0.1), in: .capsule)
                                }
                            }
                            Text(action.command)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button("Delete", systemImage: "trash") {
                            actionManager.deleteAction(id: action.id)
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(height: 180)
        }
        .padding()
        .sheet(isPresented: $showingAddSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("New Custom Action")
                    .font(.headline)

                TextField("Name (e.g. Run DB Migrations)", text: $newName)
                    .textFieldStyle(.roundedBorder)

                TextField("Command (e.g. curl -i $URL/health)", text: $newCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                HStack {
                    TextField("Specific Port (optional)", text: $newTargetPortString)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)

                    Toggle("Run in Terminal", isOn: $newRunInTerminal)
                }

                HStack {
                    Text("Icon:")
                        .font(.caption)
                    ForEach(availableIcons, id: \.self) { icon in
                        Button {
                            newIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .padding(4)
                                .background(newIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear, in: .rect(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Spacer()
                    Button("Cancel") {
                        showingAddSheet = false
                    }
                    Button("Save Action") {
                        let targetPort = Int(newTargetPortString.trimmingCharacters(in: .whitespacesAndNewlines))
                        let action = CustomAction(
                            id: UUID(),
                            name: newName.isEmpty ? "Script" : newName,
                            command: newCommand,
                            icon: newIcon,
                            targetPort: targetPort,
                            runInTerminal: newRunInTerminal
                        )
                        actionManager.addAction(action)
                        showingAddSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(16)
            .frame(width: 400)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(monitor: .preview)
    }
}
