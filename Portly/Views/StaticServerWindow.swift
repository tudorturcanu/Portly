//
//  StaticServerWindow.swift
//  Portly
//

import SwiftUI
import AppKit

enum StaticServerWindow {
    private static var currentWindow: NSWindow?

    static func show(monitor: PortMonitor?) {
        if let existing = currentWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: StaticServerView(monitor: monitor))
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.title = "Serve Folder on Port"
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
