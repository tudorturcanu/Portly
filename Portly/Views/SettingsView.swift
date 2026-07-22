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
        }
        .frame(width: 420)
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(monitor: .preview)
    }
}
