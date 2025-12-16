//
//  CardStyle.swift
//  LandShip
//
//  Created by Assistant on 10/20/25.
//
//  A reusable ViewModifier that applies the same visual adornments used by CardView
//  (material background, subtle noise, gradient stroke highlight, and layered shadows)
//  to any view. Use `.cardStyle()` in List rows, NavigationLink labels, etc.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct CardStyle: ViewModifier {
    var backgroundColor: Color = .gray
    var cornerRadius: CGFloat = 14

    // Simple deterministic LCG for procedural noise positions
    private struct LCG {
        private var state: UInt64
        init(seed: UInt64) { self.state = seed &* 6364136223846793005 &+ 1 }
        mutating func next() -> UInt64 {
            state = 2862933555777941757 &* state &+ 3037000493
            return state
        }
        mutating func nextFraction() -> Double {
            Double(next()) / Double(UInt64.max)
        }
    }

    @ViewBuilder
    private func proceduralNoise() -> some View {
        Canvas { context, size in
            // Density scales with area; tweak divisor to change noise amount
            let count = max(200, Int((size.width * size.height) / 900))
            var rng = LCG(seed: UInt64(size.width * size.height).nonzeroBitCount == 0 ? 1 : UInt64(size.width * size.height))
            for _ in 0..<count {
                let x = CGFloat(rng.nextFraction()) * size.width
                let y = CGFloat(rng.nextFraction()) * size.height
                let d = CGFloat(rng.nextFraction()) * 1.2 + 0.2 // dot diameter 0.2–1.4
                let rect = CGRect(x: x, y: y, width: d, height: d)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.06)))
            }
        }
        .blendMode(.overlay)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func noiseOverlay() -> some View {
			proceduralNoise()
//#if canImport(UIKit)
//			proceduralNoise()
//#elseif canImport(AppKit)
//				proceduralNoise()
//#else
//        proceduralNoise()
//#endif
    }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        noiseOverlay()
                    )
            )
            .overlay(
                // Gradient highlight stroke that suggests light direction
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.18),
                                .white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
            // Layered shadows for natural depth
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)   // key shadow
            .shadow(color: .black.opacity(0.04), radius: 20, x: 0, y: 12)  // ambient shadow
            .shadow(color: backgroundColor.opacity(0.18), radius: 10, x: 0, y: 0) // faint glow
    }
}

public extension View {
    /// Apply the LandShip card adornments to any view.
    /// - Parameters:
    ///   - backgroundColor: The tint used for the faint gradient and glow.
    ///   - cornerRadius: Corner radius for the rounded rectangle surface.
    func cardStyle(backgroundColor: Color = .gray, cornerRadius: CGFloat = 14) -> some View {
        modifier(CardStyle(backgroundColor: backgroundColor, cornerRadius: cornerRadius))
    }
}

extension Color {
    static var platformGroupedBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
}

#if DEBUG
#Preview("CardStyle Demo") {
    VStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card-styled Row")
                .font(.headline)
            Text("This row uses the reusable .cardStyle() modifier.")
                .foregroundStyle(.secondary)
        }
        .cardStyle(backgroundColor: .blue.opacity(0.6))

        VStack(alignment: .leading, spacing: 8) {
            Text("Neutral Card")
                .font(.headline)
            Text("Default gray tint and radius.")
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
    .padding()
    .background(Color.platformGroupedBackground)
}
#endif

