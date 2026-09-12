//
//  MobileQRCodeView.swift
//  Portly
//

import SwiftUI

/// Shows a sharp QR code for the dev server's local LAN or public tunnel URL,
/// allowing developers to instantly open the server on physical iOS/Android devices.
struct MobileQRCodeView: View {
    let port: ListeningPort
    @State private var selectedURLType: URLType = .lan
    @State private var copied = false

    enum URLType: String, CaseIterable, Identifiable {
        case lan = "Local Wi-Fi"
        case tunnel = "Public Tunnel"

        var id: String { rawValue }
    }

    private var tunnelURL: URL? {
        TunnelManager.shared.tunnelURL(for: port.port)
    }

    private var lanURL: URL? {
        port.lanURL()
    }

    private var activeURL: URL? {
        switch selectedURLType {
        case .lan:
            return lanURL ?? tunnelURL ?? port.localURL
        case .tunnel:
            return tunnelURL ?? lanURL ?? port.localURL
        }
    }

    private var qrImage: NSImage? {
        guard let url = activeURL else { return nil }
        return QRCodeGenerator.generate(from: url.absoluteString, size: 180)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.title2)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mobile Testing QR Code")
                        .font(.headline)
                    Text(":\(port.port) · \(port.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if tunnelURL != nil && lanURL != nil {
                Picker("Target URL", selection: $selectedURLType) {
                    ForEach(URLType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // QR code container with white background to ensure high contrast in Dark Mode
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)

                if let image = qrImage {
                    Image(nsImage: image)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(14)
                } else {
                    ContentUnavailableView("Cannot Generate QR", systemImage: "qrcode.viewfinder", description: Text("No valid URL found for port \(port.port)"))
                }
            }
            .frame(width: 208, height: 208)

            if let url = activeURL {
                VStack(spacing: 6) {
                    Text(url.absoluteString)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .textSelection(.enabled)
                        .padding(.horizontal, 8)

                    HStack(spacing: 8) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url.absoluteString, forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copied = false
                            }
                        } label: {
                            Label(copied ? "Copied!" : "Copy URL", systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        if selectedURLType == .lan {
                            if let ip = NetworkUtility.localIPAddress {
                                Text("Wi-Fi IP: \(ip)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Text("Scan with your phone's camera to test instantly on the same network.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(width: 280)
        .onAppear {
            if lanURL == nil && tunnelURL != nil {
                selectedURLType = .tunnel
            }
        }
    }
}
