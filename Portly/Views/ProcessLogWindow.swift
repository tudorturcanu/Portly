//
//  ProcessLogWindow.swift
//  Portly
//

import SwiftUI
import AppKit

enum ProcessLogWindow {
    private static var activeWindows: [String: NSWindow] = [:]

    static func show(for port: ListeningPort) {
        let key = "\(port.pid):\(port.port)"

        if let existing = activeWindows[key] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: ProcessLogView(port: port))
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = "Logs: \(port.displayName) (:\(port.port))"
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 680, height: 440))
        window.minSize = NSSize(width: 500, height: 300)
        window.center()

        activeWindows[key] = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            activeWindows.removeValue(forKey: key)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
