//
//  QuotaRingView.swift
//  TokenUsage
//
//  Created by Xueliang Zhu on 20/3/26.
//

import SwiftUI

struct PieSliceShape: Shape {
    var progress: Double   // 0...1

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * clamped),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

struct QuotaPieView: View {
    let used: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(used) / Double(total), 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.gray.opacity(0.2))

            PieSliceShape(progress: progress)
                .fill(.white)

            Circle()
                .stroke(.gray.opacity(0.35), lineWidth: 0.8)
        }
        .frame(width: 18, height: 18)
        .padding(2)
    }
}
