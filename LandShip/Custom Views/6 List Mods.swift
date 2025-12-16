//
//  Custom Views.swift
//  LandShip
//
//  Created by JP on 9/4/25.
//

import Foundation
import SwiftUI


// MARK: modifier for all list titles >>>>>
struct TextModifier_ListTitle: ViewModifier {
	func body(content: Content) -> some View {
		content
			.font(.system(size: 15, weight: .bold))
			.foregroundColor(.green)
			.frame(maxWidth: .infinity, alignment: .trailing)
	}
}

// MARK: modifier for all list sub titles .leading >>>>>
struct TextModifier_ListSubTitle_L: ViewModifier {
	func body(content: Content) -> some View {
		content
			.font(.system(size: 12))
			.frame(maxWidth: .infinity, alignment: .leading)
	}
}

// MARK: modifier for all list sub titles .trailing >>>>>
struct TextModifier_ListSubTitle_R: ViewModifier {
	func body(content: Content) -> some View {
		content
			.font(.system(size: 12))
			.frame(maxWidth: .infinity, alignment: .trailing)
	}
}

// MARK: modifier for all list dividers >>>>>
struct TextModifier_ListDivider: ViewModifier {
	func body(content: Content) -> some View {
		content
			.listRowSeparatorTint(.blue, edges: .all)
			.listStyle(.automatic)
	}
}

// MARK: convenience extension for all modifiers
extension View {
	func textModifier_ListTitle() -> some View {
		self.modifier(TextModifier_ListTitle())}
	
	func textModifier_ListSubTitle_L() -> some View {
		self.modifier(TextModifier_ListSubTitle_L())}
	
	func textModifier_ListSubTitle_R() -> some View {
		self.modifier(TextModifier_ListSubTitle_R())}
	
	func textModifier_ListDivider() -> some View {
		self.modifier(TextModifier_ListDivider())}
}


