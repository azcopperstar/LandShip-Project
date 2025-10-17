//
//  Custom Views.swift
//  LandShip
//
//  Created by JP on 9/4/25.
//

import Foundation
import SwiftUI


struct GrowingButton: ButtonStyle {
	let buttonColor: Color
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.padding(.horizontal, 8)
			.padding(.vertical, 5)
			.background(buttonColor)
			.foregroundStyle(.white)
			.clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 10, topTrailingRadius: 10))
			.shadow(color: Color.red.opacity(0.5), radius: 8, x: -5, y: -5) // Top-left shadow
			.shadow(color: Color.gray.opacity(0.5), radius: 8, x: 5, y: 5) // Bottom-right shadow
			.scaleEffect(configuration.isPressed ? 1.2 : 1)
			.animation(.easeOut(duration: 0.5), value: configuration.isPressed)
	}
}

//// MARK: label + text (string)
//struct ButtonWithShadow: View {
//	let label: String
//	let action: ACTION
//	var body: some View {
//		Button(action: {
//			action
//		}) {
//			Text("label")
//				.foregroundColor(.white)
//				.padding()
//				.frame(width: 200)
//		}
//		.background(Color.orange)
//		.cornerRadius(15)
//		.shadow(color: Color.red.opacity(0.4), radius: 8, x: -5, y: -5) // Top-left shadow
//		.shadow(color: Color.blue.opacity(0.4), radius: 8, x: 5, y: 5) // Bottom-right shadow
//		.padding()
//	}
//}

// MARK: modifier for shadowed buttons
struct ButtonModifier_Shadowed: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
			.textFieldStyle(RoundedBorderTextFieldStyle())
			.padding(EdgeInsets(top: 3, leading: 3, bottom: 3, trailing: 3))
			.cornerRadius(corner)
			.frame(width: 60, alignment: .trailing)
			.multilineTextAlignment(.trailing)
			.overlay(RoundedRectangle(cornerRadius: 7)
				.stroke(.secondary.opacity(0.5), lineWidth: 1))
	}
}

// MARK: convenience extension for all modifiers
extension View {
//	func textViewModified(with radius: CGFloat = 5) -> some View {
//		self.modifier(TextFieldModifier(corner: radius))}
//	func textViewModified_Short(with radius: CGFloat = 5) -> some View {
//		self.modifier(TextFieldModifier_Short(corner: radius))}
}


