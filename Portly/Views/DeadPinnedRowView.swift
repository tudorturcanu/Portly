//
//  DeadPinnedRowView.swift
//  Portly
//

import SwiftUI

/// A pinned port with nothing listening on it — the "did my server start?" row.
struct DeadPinnedRowView: View {
    let port: Int
    var monitor: PortMonitor

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: ":\(port)")
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 62, alignment: .leading)

            Label("Nothing listening", systemImage: "powerplug")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer(minLength: 4)

            if isHovering {
                Button("Unpin Port", systemImage: "pin.slash") {
                    monitor.togglePin(port)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Unpin :\(port)")
            } else {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .contentShape(.rect)
        .background(isHovering ? AnyShapeStyle(.quaternary.opacity(0.6)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 6))
        .onHover { isHovering = $0 }
    }
}

struct DeadPinnedRowView_Previews: PreviewProvider {
    static var previews: some View {
        DeadPinnedRowView(port: 3000, monitor: .preview)
            .padding()
            .frame(width: 340)
    }
}
