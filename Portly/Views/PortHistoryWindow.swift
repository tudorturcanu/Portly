//
//  PortHistoryWindow.swift
//  Portly
//

import SwiftUI
import AppKit

enum PortHistoryWindow {
    private static var window: NSWindow?

    static func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: PortHistoryView())
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = "Port History & Analytics"
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 580, height: 460))
        window.minSize = NSSize(width: 480, height: 350)
        window.center()

        Self.window = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            Self.window = nil
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func close() {
        window?.close()
        window = nil
    }
}
