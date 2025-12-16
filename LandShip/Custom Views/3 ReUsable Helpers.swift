//
//  EmptySectionState.swift
//  LandShip
//
//  Created by JP on 10/4/25.
//

// SwiftUI helper you can reuse in any list.
import Foundation
import SwiftUI

// used in each table catagory column (2nd) when no data exists
struct EmptyStateSection: View {
	let title: String
	let systemImage: String
	let description: String
	let actionTitle: String
	let action: () -> Void
	
	var body: some View {
		Section {
			ContentUnavailableView(
				title,
				systemImage: systemImage,
				description: Text(description)
			)
			.frame(maxWidth: .infinity, alignment: .center)
			.listRowInsets(EdgeInsets())
		} footer: {
			Button(actionTitle, action: action)
				.buttonStyle(GrowingButton(buttonColor: Color.green))
				.frame(maxWidth: .infinity, alignment: .center)
				.padding(.vertical, 10)
		}
	}
}
