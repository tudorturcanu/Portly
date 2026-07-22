//
//  ClosedPortRowView.swift
//  Portly
//

import SwiftUI

/// A ghost row for a port that stopped listening in the last few minutes.
struct ClosedPortRowView: View {
    let closed: ClosedPort

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: ":\(closed.port)")
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .strikethrough(color: .secondary)
                .foregroundStyle(.tertiary)
                .frame(width: 62, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(closed.displayName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("Stopped \(closed.closedAt, format: .relative(presentation: .numeric))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}

struct ClosedPortRowView_Previews: PreviewProvider {
    static var previews: some View {
        ClosedPortRowView(
            closed: ClosedPort(port: 3000, displayName: "node", networkProtocol: .tcp, closedAt: .now)
        )
        .padding()
        .frame(width: 340)
    }
}
