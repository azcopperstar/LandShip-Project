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
		HStack(spacing: 6) {
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

// MARK: Fuel Type picker content — land/marine keep a small fixed list; aviation offers
// the grouped catalog the user has enabled in Settings > Fuel Types (Settings1.enabledFuelTypes).
// Shared between EditVehicle and EditFuelLog so both stay in sync with the same settings.
struct FuelTypePickerOptions: View {
	/// The field's current value, so an existing entry that's no longer in the enabled
	/// list (e.g. after the user unchecks it in Settings) still shows up as a selectable
	/// tag instead of silently going blank.
	let currentValue: String

	@Query(filter: #Predicate<Settings1> { $0.userName == "primary1" }) private var settingsFetched: [Settings1]

	private var enabledAviationFuels: [AviationFuelType] {
		settingsFetched.first?.enabledFuelTypes ?? AviationFuelType.defaultEnabled
	}

	var body: some View {
		if Vertical.current.id == .aviation {
			let enabled = enabledAviationFuels
			ForEach(AviationFuelType.Category.allCases, id: \.self) { category in
				let fuelsInCategory = enabled.filter { $0.category == category }
				if !fuelsInCategory.isEmpty {
					Section(category.rawValue) {
						ForEach(fuelsInCategory) { fuel in
							Text(fuel.rawValue).tag(fuel.rawValue)
						}
					}
				}
			}
			if !currentValue.isEmpty && !enabled.contains(where: { $0.rawValue == currentValue }) {
				Text(currentValue).tag(currentValue)
			}
		} else {
			Text("Gasoline").tag("Gasoline")
			Text("Diesel").tag("Diesel")
			Text("EV").tag("EV")
			Text("Hybrid").tag("Hybrid")
		}
	}
}

// MARK: label + editable dropdown for vehicle systems (pick existing or type a new one)
struct Picker_VehicleSystem: View {
	let label: String
	@Binding var data: String

	// Systems from every vehicle are offered as suggestions, since the same system
	// name (e.g. "Engine") is commonly reused across a fleet.
	@Query(sort: \VehicleSystems1.systemName, order: .forward) private var systems: [VehicleSystems1]

	init(label: String, data: Binding<String>) {
		self.label = label
		self._data = data
	}

	// Existing system names across all vehicles, plus whatever is currently typed so the
	// Picker always has a matching tag even for a not-yet-saved new name.
	private var systemNames: [String] {
		var names = Set(systems.map { $0.systemName }.filter { !$0.isEmpty })
		if !data.isEmpty { names.insert(data) }
		return names.sorted()
	}

	var body: some View {
		HStack(spacing: 6) {
			Text(label)
				.textLabelModified()
			// A custom Menu (rather than Picker) so we control the trigger's label directly —
			// Picker's automatic menu-style trigger on iPad ignores SwiftUI's .lineLimit and
			// wraps long system names, overlapping the row below it.
			Menu {
				Button("—") { data = "" }
				ForEach(systemNames, id: \.self) { name in
					Button(name) { data = name }
				}
			} label: {
				Text(data.isEmpty ? "—" : data)
					.lineLimit(1)
					.truncationMode(.tail)
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
		HStack(spacing: 6) {
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
		HStack(spacing: 6) {
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
		HStack(spacing: 6) {
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
		HStack(spacing: 6) {
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
		HStack(spacing: 6) {
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
		HStack(spacing: 6) {
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
		HStack(spacing: 6) {
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
		HStack(spacing: 6) {
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
	/// Actual quantity in the tank. Supply this to make the quantity editable, for vehicles with
	/// a digital fuel readout where a typed figure beats an eighths estimate. When `nil` the
	/// quantity stays read-only and is computed from the fraction, as before.
	var quantity: Binding<Float>? = nil
	let functions: Functions = Functions()
	var body: some View {
		HStack(spacing: 6) {
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
			if let quantity {
				TextField("", value: quantity, formatter: functions.DoubleFormatter)
					.textViewModified_Short()
#if !os(macOS)
					.selectAllTextOnBeginEditing()
					.keyboardType(.decimalPad)
#endif
					.accessibilityLabel("\(label) quantity")
					.accessibilityHint("Enter the exact amount in the tank, or use the dropdown to estimate")
			} else {
				let currentFuel: Float = data * data1
				No_LabelDataNumber(data: currentFuel, fractionalLength: 1)
					.textViewModified_Short()
			}
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
	/// When set, the value cannot be moved earlier than this date. Used to keep an exit
	/// time from preceding the entry time it belongs to.
	var notEarlierThan: Date? = nil
	let functions: Functions = Functions()
	var body: some View {
		HStack(spacing: 6) {
			Button("Now"){data = clamped(Date())}
				.buttonStyle(GrowingButton(buttonColor: Color.blue))
			Text(label)
				.textLabelModified()
			if let lower = notEarlierThan {
				DatePicker("", selection: $data, in: lower..., displayedComponents: [.date, .hourAndMinute])
					.pickerModifier()
					// Follow the lower bound up if the entry time moves past the exit time.
					.onChange(of: lower) { _, _ in data = clamped(data) }
			} else {
				DatePicker("", selection: $data, displayedComponents: [.date, .hourAndMinute])
					.pickerModifier()
			}
		}
	}

	/// Pushes a date forward to the lower bound when one is set.
	private func clamped(_ date: Date) -> Date {
		guard let lower = notEarlierThan else { return date }
		return max(date, lower)
	}
}

// MARK: vehicle picker (used in Records, Items, Parts, Systems)
private struct IntrinsicWidthKey: PreferenceKey {
	static var defaultValue: CGFloat { 0 }
	static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
		value = max(value, nextValue())
	}
}

struct PickerVehicle: View {
	@Binding var trackVehicleSelected: String
	@Query(sort: \Vehicle8.name, order: .forward) var vehicles: [Vehicle8]
	let functions: Functions = Functions()
	@State private var minPickerWidth: CGFloat = 0

	private func titleForSelection(_ selection: String) -> String {
		if FleetScope.isAll(selection) {
			return FleetScope.allDisplayLabel
		}
		if let v = vehicles.first(where: { $0.name == selection }) {
			return "\(v.year) \(v.displayName)"
		}
		return selection
	}

	var body: some View {
		HStack(spacing: 3) {
			Text("\(Vertical.current.assetSingular):")
				.textLabelModified()

			let currentTitle = titleForSelection(trackVehicleSelected)

			Picker(selection: $trackVehicleSelected, label: Text("")) {
				ForEach(vehicles) { vehicle in
					let year = String(vehicle.year)
					Text("\(year) \(vehicle.displayName)")
						.tag(vehicle.name)
				}
				Text(FleetScope.allDisplayLabel)
					.tag(FleetScope.allSentinel)
			}
			.frame(minWidth: max(0, minPickerWidth), alignment: .trailing)
			.fixedSize(horizontal: true, vertical: false)
			.onAppear {
				if trackVehicleSelected.isEmpty {
					trackVehicleSelected = FleetScope.allSentinel
				}
			}

			// Invisible measurement of the current title to drive minWidth
			Text(currentTitle)
				.font(.body)
				.padding(.horizontal, 6)
				.background(
					GeometryReader { geo in
						Color.clear
							.preference(key: IntrinsicWidthKey.self, value: geo.size.width)
					}
				)
				.hidden()
		}
		.onPreferenceChange(IntrinsicWidthKey.self) { measured in
			// Add a little extra to account for platform chrome
			#if os(macOS)
			minPickerWidth = measured + 28
			#else
			minPickerWidth = measured + 25
			#endif
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
			.frame(width: 110, alignment: .trailing)
	}
}

// MARK: modifier for all Pickers short >>>>>
struct PickerModifier_Short: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
#if os(macOS)
			.frame(width: 140, alignment: .trailing)
#else
			.frame(width: 110, alignment: .trailing)
#endif
	}
}
// MARK: modifier for all Pickers medium >>>>>
struct PickerModifier_Medium: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
#if os(macOS)
			.frame(width: 150, alignment: .trailing)
#else
			.frame(width: 120, alignment: .trailing)
#endif
	}
}
struct PickerModifier_Wide: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
			.frame(width: 150, alignment: .trailing)
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
