//
//  PortFreeWindow.swift
//  Portly
//

import SwiftUI
import AppKit

enum PortFreeWindow {
    private static var currentWindow: NSWindow?

    static func show(monitor: PortMonitor?) {
        if let existing = currentWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: PortFreeView(monitor: monitor))
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.title = "Free a Port (Port Clash Resolver)"
        window.isReleasedWhenClosed = false
        window.center()

        currentWindow = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            currentWindow = nil
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
