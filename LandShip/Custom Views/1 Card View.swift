//
//  1 Card View.swift
//  LandShip
//
//  Created by JP on 9/4/25.
//
//  Summary:
//  A reusable, generic SwiftUI card component that wraps arbitrary content and
//  applies a cohesive "glass" style using system materials, a subtle gradient
//  highlight stroke, and layered shadows. The card stretches horizontally to
//  its container and aligns content to the leading edge.
//
//  Usage:
//  - Embed a single vertical stack (e.g., VStack) of views inside `CardView`.
//  - Place `CardView` within stacks or lists to achieve a consistent card look.
//
//  Example:
//  ```swift
//  CardView {
//      VStack(alignment: .leading, spacing: 8) {
//          Text("Title").font(.headline)
//          Text("Subtitle or descriptive text.")
//              .font(.subheadline)
//              .foregroundStyle(.secondary)
//      }
//  }
//  ```
//
//  Customization:
//  - `backgroundColor`: Tints the outer glow shadow for subtle emphasis.
//  - `cornerRadius`: Adjusts the rounding of the card's corners.
//  - `shadowRadius`: Reserved for future use; current shadows are fine-tuned
//    with explicit radii in the modifier chain.
//
//  Notes:
//  - Uses `.ultraThinMaterial` for a modern translucent backdrop.
//  - Optional noise texture overlay (commented out) can be enabled to add
//    tactile grain to the surface.
//  - The layered shadow stack provides depth: key shadow, ambient shadow, and
//    a faint colored glow derived from `backgroundColor`.
//
//  Considerations:
//  - Keep inner content padded—`CardView` already applies outer padding.
//  - Prefer lightweight content to maintain smooth scrolling in lists.
//  - Ensure text and icon contrast remains legible over translucent materials.
//

import Foundation
import SwiftUI


// MARK: - Card Component (Generic Content)

/// A generic, stylized container for arbitrary SwiftUI content.
///
/// `CardView` applies a translucent material background, a soft gradient
/// highlight stroke, and layered shadows to create a modern, elevated card
/// appearance. Content is laid out to fill the available width and is aligned
/// to the leading edge by default.
///
/// - Important: Wrap your card contents in a single container (typically a
///   `VStack`) when constructing the view via the `@ViewBuilder` initializer.
///
/// - Parameters:
///   - Content: The type of the view content supplied via the `@ViewBuilder`.
///
/// - Example:
/// ```swift
/// CardView {
///     VStack(alignment: .leading, spacing: 6) {
///         Text("Status").font(.caption).foregroundStyle(.secondary)
///         Text("All systems operational").font(.headline)
///     }
/// }
/// ```
struct CardView<Content: View>: View {
    /// The caller-provided content to display inside the card.
	let content: Content
    /// A tint used only for the faint outer glow shadow; does not change the
    /// material fill. Adjust to harmonize the card with surrounding theme colors.
	var backgroundColor: Color = .gray
    /// The corner radius applied to the card's background, stroke, and shadows.
	var cornerRadius: CGFloat = 14
    /// Reserved for future customization. Current implementation uses explicit
    /// shadow radii in the modifier chain below.
	var shadowRadius: CGFloat = 8

    /// Creates a new card with the provided content.
    ///
    /// - Parameter content: A `@ViewBuilder` that constructs the card's content.
	init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}

    /// The composed view hierarchy for the card, including layout, material
    /// background, highlight stroke, and layered shadows.
	var body: some View {
		content
            // Expand horizontally to fill the container; align content to the leading edge.
			.frame(maxWidth: .infinity, alignment: .leading)
            // Outer padding around the inner content to provide breathing room.
			.padding()
			.background(
                // Translucent glass-like surface using system material.
				RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
					.fill(.ultraThinMaterial)
                    // Optional: Add a very subtle noise texture to introduce tactile grain.
                    // Enable if you want a less pristine, more material feel.
//					.overlay(
//						Image("Noise") // a small seamless noise texture in assets
//							.resizable()
//							.scaledToFill()
//							.opacity(0.04)
//							.blendMode(.overlay)
//							.clipped()
//					)
			)
            // Surface highlight: a subtle gradient stroke to enhance edge definition.
			.overlay(
				// Gradient highlight stroke
				RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
					.stroke(
						LinearGradient(
							colors: [.white.opacity(0.18), .white.opacity(0.06)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						),
						lineWidth: 0.75
					)
			)
            // Depth: stack shadows for realism—key shadow, ambient shadow, and a faint glow.
			.shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)   // key shadow
			.shadow(color: .black.opacity(0.04), radius: 20, x: 0, y: 12)  // ambient shadow
			.shadow(color: backgroundColor.opacity(0.18), radius: 10, x: 0, y: 0) // faint glow
	}
}
// MARK: - End Card Component

