//
//  StoppedProfileRowView.swift
//  Portly
//

import SwiftUI

/// A port declared in the active Dev Profile that is currently not listening.
struct StoppedProfileRowView: View {
    let port: Int
    var monitor: PortMonitor

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: ":\(port)")
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)

            Label("Offline (in profile)", systemImage: "circle.dashed")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            if isHovering {
                Button("Inspect Port", systemImage: "bolt.shield") {
                    PortFreeWindow.show(for: port, monitor: monitor)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Inspect or free port :\(port)")
            } else {
                Text("Offline")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: .capsule)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .contentShape(.rect)
        .background(isHovering ? AnyShapeStyle(.quaternary.opacity(0.6)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 6))
        .onHover { isHovering = $0 }
    }
}
