//
//  Custom Views.swift
//  LandShip
//
//  Created by JP on 9/4/25.
//

import Foundation
import SwiftUI

// MARK: textfield used for notes on forms
struct TextNoteDisplay_FullWidth: View {
	let sectionText: String
	let data: String
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			SectionText(label: sectionText)
			Text(data)
				.frame(maxWidth: .infinity, alignment: .leading)
				.multilineTextAlignment(.leading)
				.foregroundStyle(.primary)
		}
	}
}

/// Read-only display of a multi-line field as one more row inside an existing card section,
/// mirroring `TextNoteDisplay_FullWidth` but without its own `SectionText` header.
struct TextNoteDisplay_Inline: View {
	let label: String
	let data: String
	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(label)
				.textLabelModified()
			Text(data)
				.frame(maxWidth: .infinity, alignment: .leading)
				.multilineTextAlignment(.leading)
				.foregroundStyle(.primary)
		}
	}
}


struct CreatedUpdatedText: View {
	let created: Date
	let updated: Date
	let functions: Functions = Functions()
	var body: some View {
		VStack {
			Text("Created: \(functions.formatDate_DDMMMyy_HHmm(date:created))")
				.frame(maxWidth: .infinity, alignment: .center)
				.font(.system(size: 14))
			Text("Updated: \(functions.formatDate_DDMMMyy_HHmm(date:updated))")
				.frame(maxWidth: .infinity, alignment: .center)
				.font(.system(size: 14))
				.foregroundColor(.red)
				.bold()
		}
	}
}
struct SectionText: View {
	let label: String
	var body: some View {
		Text(label)
			.font(.system(size: 15, weight: .black, design: .rounded))
			.foregroundColor(.blue)
			.frame(maxWidth: .infinity, alignment: .center)
	}
}

// MARK: section heading on a tinted banner
/// A `SectionText` on a filled bar, for headings that separate repeated blocks of fields
/// — an enroute stop, say — where a plain centred label is easy to scroll past.
struct SectionBanner: View {
	let label: String
	var body: some View {
		Text(label)
			.font(.system(size: 15, weight: .black, design: .rounded))
			.foregroundColor(.white)
			.frame(maxWidth: .infinity, alignment: .center)
			.padding(.vertical, 5)
			.background(Color.blue.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
			.padding(.top, 6)
			.accessibilityAddTraits(.isHeader)
	}
}

// MARK: label + text (string)
struct LabelDataText_Toolbar: View {
	let label: String
	var body: some View {
		Text(label)
			.font(.system(size: 12, weight: .bold))
			.padding(.horizontal, 10)
			.frame(maxWidth: .infinity, alignment: .leading)
	}
}

// MARK: label + text (string)
struct LabelDataText: View {
	let label: String
	let data: String
	var body: some View {
		Text(label)
			.textLabelModified()
		Text(data)
			.frame(maxWidth: .infinity, alignment: .trailing)
	}
}

//// MARK: label + text (string)
//struct LabelDataText_Fuel: View {
//	let label: String
//	let data: String
//	let data1: String
//	var body: some View {
//		Text(label)
//			.textLabelModified()
//		Text(data)
//			.frame(maxWidth: .infinity, alignment: .trailing)
//	}
//}

// MARK: label + hyperlink (URL string)
struct LabelDataLink: View {
	let label: String
	let data: String
	var body: some View {
		Text(label)
			.textLabelModified()
		if let url = URL(string: data) {
			Link(data, destination: url)
				.frame(maxWidth: .infinity, alignment: .trailing)
		} else {
			Text(data)
				.frame(maxWidth: .infinity, alignment: .trailing)
		}
	}
}

// MARK: label + text (number [no units])
///fractionalLength = number of decimal places
struct LabelDataNumber: View {
	let label: String
	let data: Float
	let fractionalLength: Int
	var body: some View {
		Text(label)
			.textLabelModified()
		Text(data.formatted(.number.precision(.fractionLength(fractionalLength))))
			.frame(maxWidth: .infinity, alignment: .trailing)
	}
}
struct No_LabelDataNumber: View {
	let data: Float
	let fractionalLength: Int
	var body: some View {
		Text(data.formatted(.number.precision(.fractionLength(fractionalLength))))
			.frame(maxWidth: .infinity, alignment: .trailing)
	}
}

// MARK: label + text (Bool)
///fractionalLength = number of decimal places
struct LabelDataBool: View {
	let label: String
	let data: Bool
	var body: some View {
		Text(label)
			.textLabelModified()
		if data {
			Text("Yes")
				.frame(maxWidth: .infinity, alignment: .trailing)
		} else {
			Text("No")
				.frame(maxWidth: .infinity, alignment: .trailing)
		}
	}
}

// MARK: label + text (measurement [w/ units]])
/// The width property specifies the display of the measurement unit.
struct LabelDataMeasurement: View {
	let label: String
	let unit: UnitLength
	let data: Double
	var body: some View {
		Text(label)
			.textLabelModified()
		Text(Measurement(
			value: data,
			unit: unit),
			format: .measurement(width: .abbreviated))
			.frame(maxWidth: .infinity, alignment: .trailing)
	}
}

// MARK: label + text (currency)
struct LabelDataCurrency: View {
	let label: String
	let data: Float
	let unit: String //used to display posible units (qt, each...)
	let systemCurrency = Locale.current.currency?.identifier ?? "USD"
	var body: some View {
		HStack{
			Text(label)
				.textLabelModified()
			HStack{
				Text(data, format: .currency(code: systemCurrency))
					.frame(maxWidth: .infinity, alignment: .trailing)
				if unit != "" {
					Text(unit)
				}
			}
		}
	}
}

// MARK: modifier for all text labels >>>>>
struct TextLabelModifier: ViewModifier {
	func body(content: Content) -> some View {
		content
			.bold()
			.frame(maxWidth: .infinity, alignment: .trailing)
	}
}
// MARK: modifier for all text labels >>>>>
struct TextLabelModifier_Leading: ViewModifier {
	func body(content: Content) -> some View {
		content
			.bold()
			.frame(maxWidth: .infinity, alignment: .leading)
	}
}
struct TextLabelCentered: ViewModifier {
	func body(content: Content) -> some View {
		content
			.bold()
			.frame(maxWidth: .infinity, alignment: .center)
	}
}

//onboarding page modifiers
struct OnboardingHeaderModifier: ViewModifier {
	func body(content: Content) -> some View {
		content
			.font(.subheadline).bold()
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.top, 5)
			.padding(.horizontal)
	}
}
struct OnboardingMessageModifier: ViewModifier {
	func body(content: Content) -> some View {
		content
			.multilineTextAlignment(.leading)
			.foregroundStyle(.secondary)
			.padding(.horizontal)
	}
}



// MARK: modifier for all vehicle picker header sections >>>>>
struct Vehicle_SectionHeaderModifier: ViewModifier {
	func body(content: Content) -> some View {
		content
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
//			.foregroundColor(.white)
//			.fontWeight(.bold)
//			.background(Color.gray.opacity(0.2))
//			.cornerRadius(2)
			.frame(alignment: .center)
	}
}

// Reusable centered SectionHeader (used in contentView sidebar sections)
struct CenteredSectionHeader: View {
	let title: String
	var body: some View {
		Text(title.uppercased())
			.font(.caption.bold())
			.foregroundStyle(.tint)
			.padding(.horizontal, 10)
			.padding(.vertical, 4)
			.background(
				title.isEmpty ? Color.clear : Color.accentColor.opacity(0.12),
				in: RoundedRectangle(cornerRadius: 8, style: .continuous)
			)
			.frame(maxWidth: .infinity, alignment: .center)
			.multilineTextAlignment(.center)
			.textCase(nil) // we uppercase manually above; prevent double-uppercasing from list styles
	}
}

// MARK: convenience extension for all modifiers
extension View {
	func textLabelModified() -> some View {
		self.modifier(TextLabelModifier())}
	func textLabelModified_Leading() -> some View {
		self.modifier(TextLabelModifier_Leading())}
	func textLabelCentered() -> some View {
		self.modifier(TextLabelCentered())}
	func vehicle_SectionHeaderModifier() -> some View {
		self.modifier(Vehicle_SectionHeaderModifier())}
	func onboardingHeaderModifier() -> some View {
		self.modifier(OnboardingHeaderModifier())}
	func onboardingMessageModifier() -> some View {
		self.modifier(OnboardingMessageModifier())}
}


