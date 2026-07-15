//
//  OnboardingWindow.swift
//  Portly
//

import SwiftUI

/// Shows the first-launch welcome window. Menu bar apps are invisible on
/// launch, so without this a fresh install looks like nothing happened.
enum OnboardingWindow {
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    private static var window: NSWindow?

    static var isNeeded: Bool {
        !UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
    }

    static func showIfNeeded() {
        guard isNeeded, window == nil else { return }
        // Mark as seen immediately so onboarding is once-ever, even if the
        // window is closed with the traffic light instead of "Get Started".
        UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)

        let hosting = NSHostingController(rootView: OnboardingView { close() })
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()

        Self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func close() {
        window?.close()
        window = nil
    }
}
