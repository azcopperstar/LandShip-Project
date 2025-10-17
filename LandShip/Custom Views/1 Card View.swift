//
//  Custom Views.swift
//  LandShip
//
//  Created by JP on 9/4/25.
//

import Foundation
import SwiftUI


// MARK: - Card Component with Generic Content >>>
// all content for 1 card should be within a VStack to make 1 card
struct CardView<Content: View>: View {
	let content: Content
	var backgroundColor: Color = .gray
	var cornerRadius: CGFloat = 12
	var shadowRadius: CGFloat = 1
	init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}
	var body: some View {
		content
			.padding()
			.background(backgroundColor.opacity(0.1))
			.cornerRadius(cornerRadius)
			.shadow(radius: shadowRadius)
	}
}
// <<<

