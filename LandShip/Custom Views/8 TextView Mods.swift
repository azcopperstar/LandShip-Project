//
//  Custom Views.swift
//  LandShip
//
//  Created by JP on 9/4/25.
//

import Foundation
import SwiftUI
import Combine

//import SwiftData


// MARK: label + textfield string
struct LabelDataTextview: View {
	let label: String
	@Binding var data: String
	var body: some View {
		Text(label)
			.textLabelModified()
		TextField("", text: $data, prompt: Text(label.replacingOccurrences(of: ":", with: "")))
			.textViewModified()
#if os(iOS)
			.selectAllTextOnBeginEditing()
#endif

	}
}

// MARK: label + textfield INT
struct LabelDataTextview_Numberpad_Int: View {
	let label: String
	@Binding var data: Int
	let functions: Functions = Functions()
	var body: some View {
		Text(label)
			.textLabelModified()
		TextField("", value: $data, formatter: functions.IntFormatter, prompt: Text(label.replacingOccurrences(of: ":", with: "")))
			.textViewModified()
#if os(iOS)
			.selectAllTextOnBeginEditing()
			.keyboardType(.numberPad)
#endif
	}
}

// MARK: label + textfield Double
struct LabelDataTextview_Numberpad_Float: View {
	let label: String
	@Binding var data: Float
	let functions: Functions = Functions()
	var body: some View {
		Text(label)
			.textLabelModified()
		TextField("", value: $data, formatter: functions.DoubleFormatter, prompt: Text(label.replacingOccurrences(of: ":", with: "")))
			.textViewModified()
#if !os(macOS)
			.selectAllTextOnBeginEditing()
			.keyboardType(.decimalPad)
#endif
	}
}

// MARK: label + textfield for fuel added
struct LabelDataTextview_Numberpad_Fuel: View {
	let label: String
	@Binding var dataQuantity: Float
	@Binding var dataFuelLog: Bool
	var fuelEntryValue: Float
	@Binding var dataPrice: Float
	@Binding var fuelOdometer: Float
	@Binding var fuelEngHours: Float
	@Binding var fuelLocation: String
	@Binding var oilAdded: Float
	let labelOil: String
	@Binding var defAdded: Float
	let labelDEF: String
	let functions: Functions = Functions()
//	@State private var selection: TextSelection?
	
	var body: some View {
		VStack {
			HStack {
				if fuelEntryValue == 0 {
					// only display fuel log option if new entry
					// edited entry would be > 0 so log already created
					Toggle(isOn: $dataFuelLog){
						Text("Create Fuel Log")
							.textLabelModified()
					}
				}
				Text("Location")
					.textLabelModified()
				TextField("", text: $fuelLocation)
					.textViewModified_Medium()
#if !os(macOS)
					.selectAllTextOnBeginEditing()
#endif
			}
			HStack {
				Text("Qty\(label)")
					.textLabelModified()
				TextField("", value: $dataQuantity, formatter: functions.DoubleFormatter)
					.textViewModified_Medium()
#if !os(macOS)
					.selectAllTextOnBeginEditing()
					.keyboardType(.decimalPad)
#endif
				if dataFuelLog {
					Text("Price/\(label)")
						.textLabelModified()
					TextField("", value: $dataPrice, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
						.textViewModified_Medium()
#if !os(macOS)
						.selectAllTextOnBeginEditing()
						.keyboardType(.decimalPad)
#endif
				}
			}
					
			if dataFuelLog {
					HStack {
						Text("Odometer")
							.textLabelModified()
						TextField("", value: $fuelOdometer, formatter: functions.FloatFormatter)
							.textViewModified_Medium()
#if !os(macOS)
							.selectAllTextOnBeginEditing()
							.keyboardType(.numberPad)
#endif
						Text("Eng Hours")
							.textLabelModified()
						TextField("", value: $fuelEngHours, formatter: functions.FloatFormatter)
							.textViewModified_Medium()
#if !os(macOS)
							.selectAllTextOnBeginEditing()
							.keyboardType(.numberPad)
#endif
					}
				VStack {
					HStack(alignment: .center) {
						Text("--------- Fluids Added ---------")
					}
					HStack {
						Text("Oil \(labelOil)")
							.textLabelModified()
						TextField("", value: $oilAdded, formatter: functions.FloatFormatter)
							.textViewModified_Medium()
#if !os(macOS)
							.selectAllTextOnBeginEditing()
							.keyboardType(.decimalPad)
#endif
						Text("DEF \(labelDEF)")
							.textLabelModified()
						TextField("", value: $defAdded, formatter: functions.FloatFormatter)
							.textViewModified_Medium()
#if !os(macOS)
							.selectAllTextOnBeginEditing()
							.keyboardType(.decimalPad)
#endif
					}
				}
				}
			}
		}
	}
	


// MARK: label + textfield currency
struct LabelDataTextview_Currency_Float: View {
	let label: String
	@Binding var data: Float
	let functions: Functions = Functions()
	var body: some View {
		Text(label)
			.textLabelModified()
		TextField("", value: $data, format: .currency(code: Locale.current.currency?.identifier ?? "USD"), prompt: Text(label.replacingOccurrences(of: ":", with: "")))
			.textViewModified()
#if !os(macOS)
			.selectAllTextOnBeginEditing()
			.keyboardType(.decimalPad)
#endif
	}
}

// MARK: label + textfield currency
//struct LabelDataTextview_Currency_Float_Multiply: View {
//	let label: String
//	@Binding var data1: Float
//	@Binding var data2: Float
//	let functions: Functions = Functions()
//	var body: some View {
//		let data:Float = data1 * data2
//		Text(label)
//			.textLabelModified()
//		TextField("", value: data, formatter: functions.DoubleFormatter)
//			.textViewModified()
//#if !os(macOS)
//			.keyboardType(.decimalPad)
//#endif
//	}
//}

// MARK: label + textfield Double
struct LabelDataTextview_Numberpad_Currency: View {
	let label: String
	@Binding var data: Float
	let functions: Functions = Functions()
	var body: some View {
		Text(label)
			.textLabelModified()
		TextField("", value: $data, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
			.textViewModified()
#if !os(macOS)
			.selectAllTextOnBeginEditing()
			.keyboardType(.decimalPad)
#endif
	}
}

// MARK: label + textfield phone
struct LabelDataTextview_Numberpad_Phone: View {
	let label: String
	@Binding var data: String
	let functions: Functions = Functions()
	var body: some View {
		Text(label)
			.textLabelModified()
		TextField("", text: $data, prompt: Text(label.replacingOccurrences(of: ":", with: "")))
#if !os(macOS)
			.selectAllTextOnBeginEditing()
			.keyboardType(.phonePad)
#endif
	}
}

// MARK: modifier for all textfields >>>>>
struct TextFieldModifier: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
			.textFieldStyle(RoundedBorderTextFieldStyle())
			.padding(EdgeInsets(top: 3, leading: 3, bottom: 3, trailing: 3))
			.cornerRadius(corner)
			.frame(maxWidth: .infinity, alignment: .trailing)
			.multilineTextAlignment(.trailing)
			.overlay(RoundedRectangle(cornerRadius: 7)
					.stroke(.secondary.opacity(0.5), lineWidth: 1))
		//			.background(Color.blue)
	}
}

// MARK: modifier for textfields with short input field >>>>>
struct TextFieldModifier_Short: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
			.textFieldStyle(RoundedBorderTextFieldStyle())
			.padding(EdgeInsets(top: 3, leading: 3, bottom: 3, trailing: 3))
			.cornerRadius(corner)
			.frame(width: 50, alignment: .trailing)
			.multilineTextAlignment(.trailing)
			.overlay(RoundedRectangle(cornerRadius: 7)
				.stroke(.secondary.opacity(0.5), lineWidth: 1))
	}
}

struct TextFieldModifier_Medium: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
			.textFieldStyle(RoundedBorderTextFieldStyle())
			.padding(EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
			.cornerRadius(corner)
			.frame(width: 80, alignment: .trailing)
			.multilineTextAlignment(.trailing)
			.overlay(RoundedRectangle(cornerRadius: 7)
				.stroke(.secondary.opacity(0.5), lineWidth: 1))
	}
}

// MARK: convenience extension for all modifiers
extension View {
	func textViewModified(with radius: CGFloat = 5) -> some View {
		self.modifier(TextFieldModifier(corner: radius))}
	func textViewModified_Short(with radius: CGFloat = 5) -> some View {
		self.modifier(TextFieldModifier_Short(corner: radius))}
	func textViewModified_Medium(with radius: CGFloat = 5) -> some View {
		self.modifier(TextFieldModifier_Medium(corner: radius))}
}

// used to select all text when textview field is entered (import Combine)
public struct SelectAllTextOnBeginEditingModifier: ViewModifier {
	public func body(content: Content) -> some View {
#if os(iOS)
		content
			.onReceive(NotificationCenter.default.publisher(
				for: UITextField.textDidBeginEditingNotification)) { _ in
					DispatchQueue.main.async {
						UIApplication.shared.sendAction(
							#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil
						)
					}
				}
#endif
	}

}
extension View {
#if os(iOS)
	public func selectAllTextOnBeginEditing() -> some View {
		modifier(SelectAllTextOnBeginEditingModifier())
	}
#endif
}
