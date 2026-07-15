//
//  OnboardingView.swift
//  Portly
//

import SwiftUI

/// Content of the first-launch welcome window.
struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var launchAtLogin = false

    private var stopFeatureText: String {
        if AppCapabilities.canTerminateProcesses {
            "Hover a row to open localhost in your browser, copy the URL, or stop the process. Click a row for full process details."
        } else {
            "Hover a row to open localhost in your browser, copy the URL, or copy a kill command. Click a row for full process details."
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .frame(width: 88, height: 88)

            VStack(spacing: 4) {
                Text("Welcome to Portly")
                    .font(.title.bold())
                Text("Every local dev server, one click away.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                featureRow(
                    symbol: "menubar.rectangle",
                    title: "Portly lives in your menu bar",
                    text: "Look for the connected-dots icon near your clock. Click it to see every port something is listening on — refreshed live."
                )
                featureRow(
                    symbol: "pin.fill",
                    title: "Pin the ports you care about",
                    text: "Right-click a port to pin it. The menu bar icon warns you whenever a pinned port has nothing listening."
                )
                featureRow(
                    symbol: "cursorarrow.click.2",
                    title: "Act without the Terminal",
                    text: stopFeatureText
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)

            Toggle("Launch Portly at Login", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)

            Button("Get Started", action: onFinish)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

            HStack(spacing: 8) {
                Link("Terms", destination: URL(string: "https://sudoswisshub.github.io/PortlyLegal/terms.html")!)
                Text("•")
                    .foregroundStyle(.secondary)
                Link("Privacy", destination: URL(string: "https://sudoswisshub.github.io/PortlyLegal/privacy.html")!)
                Text("•")
                    .foregroundStyle(.secondary)
                Link("Support", destination: URL(string: "https://sudoswisshub.github.io/PortlyLegal/support.html")!)
            }
            .font(.caption)
            .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 420)
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
        }
        .onChange(of: launchAtLogin) { _, newValue in
            guard newValue != LaunchAtLogin.isEnabled else { return }
            do {
                try LaunchAtLogin.set(newValue)
            } catch {
                launchAtLogin = LaunchAtLogin.isEnabled
            }
        }
    }

    private func featureRow(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
