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

    var body: some Scene {
        MenuBarExtra {
            MenuView(monitor: monitor)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
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
