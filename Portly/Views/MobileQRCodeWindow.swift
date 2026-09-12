//
//  MobileQRCodeWindow.swift
//  Portly
//

import SwiftUI
import AppKit

enum MobileQRCodeWindow {
    private static var activeWindows: [Int: NSWindow] = [:]

    static func show(for port: ListeningPort) {
        if let existing = activeWindows[port.port] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: MobileQRCodeView(port: port))
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.title = "Mobile QR Code (:\(port.port))"
        window.isReleasedWhenClosed = false
        window.center()

        activeWindows[port.port] = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            activeWindows.removeValue(forKey: port.port)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
