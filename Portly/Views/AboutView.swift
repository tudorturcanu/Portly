//
//  AboutView.swift
//  Portly
//

import SwiftUI

struct AboutView: View {
    var onClose: () -> Void

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            // App Icon
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .frame(width: 72, height: 72)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

            // Title and Version
            VStack(spacing: 4) {
                Text("Portly")
                    .font(.title2.bold())
                Text("Version \(version) (Build \(build))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Description
            Text("A lightweight macOS menu bar utility for software developers to monitor active network sockets, inspect parent processes, and manage local dev servers.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)

            Divider()
                .padding(.vertical, 4)

            // Quick Links
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Link("Privacy", destination: URL(string: "https://sudoswisshub.github.io/PortlyLegal/privacy.html")!)
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Link("Terms", destination: URL(string: "https://sudoswisshub.github.io/PortlyLegal/terms.html")!)
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Link("Support", destination: URL(string: "https://sudoswisshub.github.io/PortlyLegal/support.html")!)
                }
                .font(.body)
            }

            Spacer()

            // Copyright Footnote
            Text("© 2026 Portly. All rights reserved.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 320, height: 380)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea())
    }
}

// Helper view to enable system vibrancy background
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    AboutView(onClose: {})
}
