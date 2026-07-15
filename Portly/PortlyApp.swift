//
//  PortlyApp.swift
//  Portly
//
//  A menu bar utility that shows every listening port on your Mac.
//

import SwiftUI

@main
struct PortlyApp: App {
    @State private var monitor = PortMonitor()
    @AppStorage("showMenuBarCount") private var showMenuBarCount = true

    init() {
        // Menu bar apps are invisible on launch: first launch gets the
        // onboarding window, every later launch gets a brief toast.
        Task { @MainActor in
            if OnboardingWindow.isNeeded {
                try? await Task.sleep(for: .milliseconds(300))
                OnboardingWindow.showIfNeeded()
            } else {
                try? await Task.sleep(for: .milliseconds(600))
                LaunchToast.show()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(monitor: monitor)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(monitor: monitor)
        }
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        if monitor.deadPinnedPorts.isEmpty {
            Image(systemName: "point.3.filled.connected.trianglepath.dotted")
        } else {
            // A pinned port has nothing listening — surface it without opening the panel.
            Image(systemName: "exclamationmark.triangle.fill")
        }

        if showMenuBarCount, monitor.devServerCount > 0 {
            Text(verbatim: "\(monitor.devServerCount)")
        }
    }
}
