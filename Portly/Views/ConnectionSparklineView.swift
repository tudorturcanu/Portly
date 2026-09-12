//
//  ConnectionSparklineView.swift
//  Portly
//

import SwiftUI

/// A compact sparkline graph displaying recent connection activity over time.
struct ConnectionSparklineView: View {
    let samples: [Int]
    var tintColor: Color = .blue
    var height: CGFloat = 16

    private var maxSample: Int {
        max(samples.max() ?? 1, 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let h = geometry.size.height

            if samples.count < 2 {
                // Not enough samples yet: draw subtle baseline
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.8))
                    path.addLine(to: CGPoint(x: width, y: h * 0.8))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .foregroundStyle(Color.secondary.opacity(0.3))
            } else {
                let stepX = width / CGFloat(samples.count - 1)
                let points = samples.enumerated().map { index, value in
                    let x = CGFloat(index) * stepX
                    let normalized = CGFloat(value) / CGFloat(maxSample)
                    let y = h - (normalized * (h - 4)) - 2
                    return CGPoint(x: x, y: y)
                }

                ZStack {
                    // Filled area under sparkline
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: CGPoint(x: first.x, y: h))
                        path.addLine(to: first)
                        for pt in points.dropFirst() {
                            path.addLine(to: pt)
                        }
                        if let last = points.last {
                            path.addLine(to: CGPoint(x: last.x, y: h))
                        }
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [tintColor.opacity(0.25), tintColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Sparkline curve
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for pt in points.dropFirst() {
                            path.addLine(to: pt)
                        }
                    }
                    .stroke(tintColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                    // Peak / current value dot
                    if let last = points.last {
                        Circle()
                            .fill(tintColor)
                            .frame(width: 3.5, height: 3.5)
                            .position(last)
                    }
                }
            }
        }
        .frame(height: height)
    }
}
