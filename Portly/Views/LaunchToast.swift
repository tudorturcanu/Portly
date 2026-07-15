//
//  LaunchToast.swift
//  Portly
//

import SwiftUI

/// A transient toast under the menu bar confirming Portly launched — a menu
/// bar app otherwise gives no visible sign it started.
enum LaunchToast {
    private static var panel: NSPanel?

    static func show() {
        dismiss()

        let hosting = NSHostingView(rootView: ToastView())
        hosting.setFrameSize(hosting.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hosting.frame.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        // Top-right of the screen, tucked under the menu bar near Portly's icon.
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(
                NSPoint(
                    x: visible.maxX - panel.frame.width - 16,
                    y: visible.maxY - panel.frame.height - 12
                )
            )
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        Self.panel = panel

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 1
        }

        Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard Self.panel === panel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
                if Self.panel === panel {
                    Self.panel = nil
                }
            })
        }
    }

    static func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct ToastView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                .font(.title3)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 1) {
                Text("Portly is running")
                    .font(.callout.weight(.semibold))
                Text("Click the icon in your menu bar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }
}
