//
//  Custom Views.swift
//  LandShip
//
//  Created by JP on 9/4/25.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: label + picker parts units
struct Picker_PartsUnit: View {
	let label: String
	@Binding var data: String
	var body: some View {
		HStack {
			Text(label)
				.textLabelModified()
			Picker("", selection: $data) {
				Text("Each").tag("Each")
				Text("Gallon").tag("gal")
				Text("Quart").tag("qt")
				Text("Pint").tag("pt")
				Text("Cup").tag("c")
				Text("Fluid Ounce").tag("fl oz")
				Text("Milliliter").tag("ml")
				Text("Liter").tag("l")
			}
				.pickerModifier_Short()
			TextField("", text: $data)
				.textViewModified_Medium()
		}
	}
}

// MARK: label + picker LWH
struct Picker_LWH: View {
	let label: String
	@Binding var data: String
	var body: some View {
		HStack {
			Text(label)
				.textLabelModified()
			Picker("", selection: $data) {
				Text("Foot").tag("ft")
				Text("Inch").tag("in")
				Text("Millimter").tag("mm")
				Text("Centemter").tag("cm")
				Text("Meter").tag("m")
				Text("Kilometer").tag("km")
			}
			.pickerModifier()
			TextField("", text: $data)
				.textViewModified_Medium()
		}
	}
}

// MARK: label + picker Area
struct Picker_Area: View {
	let label: String
	@Binding var data: String
	var body: some View {
		HStack {
			Text(label)
				.textLabelModified()
			Picker("", selection: $data) {
				Text("Square Foot").tag("ft²")
				Text("Square Inch").tag("in²")
				Text("Square Centemter").tag("cm²")
				Text("Square Meter").tag("m²")
			}
			.pickerModifier()
			TextField("", text: $data)
				.textViewModified_Medium()
		}
	}
}

// MARK: label + picker distance
struct Picker_Dist: View {
	let label: String
	@Binding var data: String
	var body: some View {
		HStack {
			Text(label)
				.textLabelModified()
			Picker("", selection: $data) {
				Text("Mile").tag("mi")
				Text("Meter").tag("m")
				Text("Kilometer").tag("km")
			}
			.pickerModifier()
			TextField("", text: $data)
				.textViewModified_Medium()
		}
	}
}

// MARK: label + picker mass
struct Picker_Mass: View {
	let label: String
	@Binding var data: String
	var body: some View {
		HStack {
			Text(label)
				.textLabelModified()
			Picker("", selection: $data) {
				Text("Pound").tag("lb")
				Text("Ounce").tag("oz")
				Text("Milligram").tag("mg")
				Text("Gram").tag("g")
				Text("Kilogram").tag("kg")
				Text("Ton").tag("T")
				Text("Stone").tag("st")
			}
			.pickerModifier()
			TextField("", text: $data)
				.textViewModified_Medium()
		}
	}
}

// MARK: label + picker pressure
struct Picker_Press: View {
	let label: String
	@Binding var data: String
	var body: some View {
		HStack {
			Text(label)
				.textLabelModified()
			Picker("", selection: $data) {
				Text("lb/in²").tag("PSI")
				Text("Pascal- N/m­²").tag("Pa")
			}
			.pickerModifier()
			TextField("", text: $data)
				.textViewModified_Medium()
		}
	}
}

// MARK: label + picker speed
struct Picker_Speed: View {
	let label: String
	@Binding var data: String
	var body: some View {
		HStack {
			Text(label)
				.textLabelModified()
			Picker("", selection: $data) {
				Text("Mile per Hour").tag("mph")
				Text("Kilometer per Hour").tag("kph")
				Text("Knots").tag("kn")
			}
			.pickerModifier()
			TextField("", text: $data)
				.textViewModified_Medium()
		}
	}
}

// MARK: label + picker volume
struct Picker_Volume: View {
	let label: String
	@Binding var data: String
	var body: some View {
		HStack {
			Text(label)
				.textLabelModified()
			Picker("", selection: $data) {
				Text("Gallon").tag("gal")
				Text("Quart").tag("qt")
				Text("Pint").tag("pt")
				Text("Cup").tag("c")
				Text("Fluid Ounce").tag("fl oz")
				Text("Milliliter").tag("ml")
				Text("Liter").tag("l")
			}
			.pickerModifier()
			TextField("", text: $data)
				.textViewModified_Medium()
		}
	}
}

// MARK: label + picker temp
struct Picker_Temp: View {
	let label: String
	@Binding var data: String
	var body: some View {
		HStack {
			Text(label)
				.textLabelModified()
			Picker("", selection: $data) {
				Text("Fahrenheit").tag("°F")
				Text("Celsius").tag("°C")
				Text("Kelvin").tag("K")
			}
			.pickerModifier()
			TextField("", text: $data)
				.textViewModified_Medium()
		}
	}
}

// MARK: label + picker parts units
//struct Picker_FuelLevel: View {
//	let label: String
//	@Binding var data: Float
//	@Binding var data1: String
//	let functions: Functions = Functions()
//	var body: some View {
//		HStack {
//			Text(label)
//				.textLabelModified()
//			Picker("", selection: $data1) {
//				Text("Full").tag("Full")
//				Text("7/8").tag("7/8")
//				Text("3/4").tag("3/4")
//				Text("5/8").tag("5/8")
//				Text("1/2").tag("1/2")
//				Text("3/8").tag("3/8")
//				Text("1/4").tag("1/4")
//				Text("1/8").tag("1/8")
//				Text("Empty").tag("Empty")
//			}
//			.pickerStyle(.wheel)
//			.pickerModifier_Short()
//			TextField("", value: $data, formatter: functions.FloatFormatter)
//				.textViewModified_Short()
//		}
//	}
//}
// MARK: label + picker parts units
struct Picker_FuelLevel1: View {
	let label: String
	@Binding var data: Float
	var data1: Float
	let functions: Functions = Functions()
	var body: some View {
		HStack {
			Text(label)
				.textLabelModified()
			Picker("", selection: $data) {
				Text("Full").tag(Float(1.0))
				Text("7/8").tag(Float(0.875))
				Text("3/4").tag(Float(0.75))
				Text("5/8").tag(Float(0.625))
				Text("1/2").tag(Float(0.5))
				Text("3/8").tag(Float(0.375))
				Text("1/4").tag(Float(0.25))
				Text("1/8").tag(Float(0.125))
				Text("Empty").tag(Float(0.0))
			}
//			.pickerStyle(.wheel)
			.pickerModifier_Short()
			let currentFuel: Float = data * data1
			No_LabelDataNumber(data: currentFuel, fractionalLength: 1)
				.textViewModified_Short()
		}
	}
}
struct Picker_FuelLevelWheel: View {
	let label: String
	@Binding var data: Float
	var data1: Float
	let functions: Functions = Functions()
	var body: some View {
		VStack {
			Text(label)
				.textLabelModified()
			Picker("", selection: $data) {
				Text("Full").tag(Float(1.0))
				Text("7/8").tag(Float(0.875))
				Text("3/4").tag(Float(0.75))
				Text("5/8").tag(Float(0.625))
				Text("1/2").tag(Float(0.5))
				Text("3/8").tag(Float(0.375))
				Text("1/4").tag(Float(0.25))
				Text("1/8").tag(Float(0.125))
				Text("Empty").tag(Float(0.0))
			}
//				.pickerStyle(.wheel)
//				.defaultWheelPickerItemHeight(30)
				.pickerModifier_Short()
//			let currentFuel: Float = data * data1
//			LabelDataNumber(label: "", data: currentFuel, fractionalLength: 1)
//				.textViewModified_Short()
		}
	}
}

// MARK: label + picker date
struct LabelDataPicker_Date: View {
	let label: String
	@Binding var data: Date
	let functions: Functions = Functions()
	var body: some View {
		Button("Now"){data = Date()}
			.buttonStyle(GrowingButton(buttonColor: Color.blue))
		Text(label)
			.textLabelModified()
		DatePicker("", selection: $data, displayedComponents: [.date])
			.pickerModifier()
	}
}

// MARK: label + picker date
struct LabelDataPicker_DateTime: View {
	let label: String
	@Binding var data: Date
	let functions: Functions = Functions()
	var body: some View {
		HStack {
			Button("Now"){data = Date()}
				.buttonStyle(GrowingButton(buttonColor: Color.blue))
			Text(label)
				.textLabelModified()
			DatePicker("", selection: $data, displayedComponents: [.date, .hourAndMinute])
				.pickerModifier()
		}
	}
}

// MARK: vehicle picker (used in Records, Items, Parts, Systems)
struct PickerVehicle: View {
	@Binding var trackVehicleSelected: String
	@Query(sort: \Vehicle8.name, order: .forward) var vehicles: [Vehicle8]
	let functions: Functions = Functions()
	var body: some View {
		HStack {
			Text("Vehicle:")
				.textLabelModified()
			Picker(selection: $trackVehicleSelected, label: Text("")) {
				ForEach(vehicles) { vehicle in
					let year = String(vehicle.year)
					Text("\(year) \(vehicle.name)")
						.tag(vehicle.name)
				}
				Text("All Vehicles")
					.tag("All Vehicles")
			}
			.pickerModifier_Wide()
			.frame(maxWidth: .infinity, alignment: .leading)
			.onAppear {
				if trackVehicleSelected == "" {
					trackVehicleSelected = "All Vehicles"
				}
			}
		}
	}
}
//<<<

// MARK: label + picker date
struct LabelDataToggle: View {
	let label: String
	@Binding var data: Bool
	var body: some View {
		Text(label)
			.textLabelModified()
		Toggle("", isOn: $data)
			.pickerModifier()
	}
}



// MARK: modifier for all Pickers >>>>>
struct PickerModifier: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
			.frame(width: 150, alignment: .trailing)
	}
}

// MARK: modifier for all Pickers short >>>>>
struct PickerModifier_Short: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
#if os(macOS)
			.frame(width: 185, alignment: .trailing)
#else
			.frame(width: 133, alignment: .trailing)
#endif
	}
}
// MARK: modifier for all Pickers medium >>>>>
struct PickerModifier_Medium: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
#if os(macOS)
			.frame(width: 185, alignment: .trailing)
#else
			.frame(width: 145, alignment: .trailing)
#endif
	}
}
struct PickerModifier_Wide: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
			.frame(width: 170, alignment: .trailing)
	}
}


// MARK: convenience extension for all modifiers
extension View {
	func pickerModifier(with radius: CGFloat = 5) -> some View {
		self.modifier(PickerModifier(corner: radius))}
	func pickerModifier_Short(with radius: CGFloat = 5) -> some View {
		self.modifier(PickerModifier_Short(corner: radius))}
	func pickerModifier_Medium(with radius: CGFloat = 5) -> some View {
		self.modifier(PickerModifier_Medium(corner: radius))}
	func pickerModifier_Wide(with radius: CGFloat = 5) -> some View {
		self.modifier(PickerModifier_Wide(corner: radius))}
}


