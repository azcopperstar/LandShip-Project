//
//  Custom Views.swift
//  LandShip
//
//  Created by JP on 9/4/25.
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import CoreLocation

//import SwiftData


// MARK: textfield used for notes on forms
struct TextFieldNote_FullWidth_3lines: View {
	let sectionText: String
	let prompt: String
	@Binding var data: String
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			SectionText(label: sectionText)
			TextField(prompt, text: $data, axis: .vertical)
				.textFieldStyle(.roundedBorder)
				.lineLimit(3...)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

// MARK: title of page + app name
struct PageTitle_Col2_NoPhoto: View {
	/// this is used in column 2 of the app to list the name of the database being presented along with the app name and version.  It is displayed in the app .safeAreaInset()
	/// Inputs:
	///	label: database name (ie VEHICLE DATABASE)
	///	i.e.
	///	.safeAreaInset(edge: .top) { PageTitle_Col2_NoPhoto(label: "VEHICLE DATABASE") }

	let label: String
	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 6) {
			Text(label)
			Text("\(VersionStrings.fullVersionStringWithAppName)")
				.font(.caption2)
				.foregroundStyle(.secondary)
				.baselineOffset(6)
		}
		.safeArea_TitleNoGraphic_Modifier()
	}
}
// MARK: photo + title of page + app name
struct PageTitle_Col3_Photo: View {
	/// this is used in column 3 of the app to list the a photo, name of the record being presented along with the app name and version.  It is displayed in the app .safeAreaInset()
	/// Inputs:
	///	label: database name (ie VEHICLE DATABASE)
	///	photo: optional photo
	///	i.e.
	///	.safeAreaInset(edge: .top) { PageTitle_Col2_NoPhoto(label: "VEHICLE DATABASE") }
	
	let label: String
	let action: String /// edit or display
	let dbRecord: String	/// record being displayed (may be a vehicleId UUID that needs lookup)
	@Environment(\.modelContext) private var modelContext
	
	var body: some View {
		/// Look up display name if dbRecord is a vehicle UUID
		let displayText = Functions().getVehicleDisplayName(vehicleId: dbRecord, context: modelContext)
		
		HStack(alignment: .firstTextBaseline, spacing: 6) {
			if action == "edit" {
				Text("EDIT \(displayText)".uppercased())
			} else {
				Text("\(displayText) DETAILS".uppercased())
			}
			Text("\(VersionStrings.fullVersionStringWithAppName)")
				.font(.caption2)
				.foregroundStyle(.secondary)
				.baselineOffset(6)
		}
		.safeArea_TitleNoGraphic_Modifier()
	}
}


// MARK: label + textfield string
// CHANGELOG: [Added] [iOS] LabelLocationTextview: added location service to location textfield
@MainActor
struct LabelLocationTextview: View {
    let label: String
    @Binding var data: String
    /// When `false`, the field never auto-fills on appear/becoming empty — it only fills when the location button is pressed.
    var autoFillOnAppear: Bool = true

    @StateObject private var locationProvider = LocationProvider()
    @State private var userClearedField: Bool = false
    @State private var isFetchingLocation: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .textLabelModified()
            TextField("", text: $data, prompt: Text(label.replacingOccurrences(of: ":", with: "")))
                .textViewModified()
#if os(iOS)
                .selectAllTextOnBeginEditing()
#endif
                .onChange(of: data) { oldValue, newValue in
                    // If the user cleared the field (transitioned from non-empty to empty), disable future auto-fill
                    let wasNonEmpty = !oldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let isNowEmpty = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    if wasNonEmpty && isNowEmpty {
                        userClearedField = true
                    }
                }
                .onChange(of: data) { _, newValue in
                    if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        userClearedField = false
                    }
                }
#if os(iOS)
            Button {
                userClearedField = false
                Task { @MainActor in
                    if isFetchingLocation { return }
                    isFetchingLocation = true
                    defer { isFetchingLocation = false }
                    do {
                        // Prefer a business/area-of-interest name when available
                        if let place = await locationProvider.currentPlaceString(preferBusinessName: true) {
                            let trimmed = place.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                data = trimmed
                            }
                        } else {
                            // Fallback: try again without preferring business name
                            if let place = await locationProvider.currentPlaceString(preferBusinessName: false) {
                                let trimmed = place.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    data = trimmed
                                }
                            }
                        }
                    }
                }
            } label: {
                if isFetchingLocation {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 20, height: 20)
                        .accessibilityLabel("Fetching current location")
                } else {
                    Image(systemName: "location.fill")
                        .imageScale(.medium)
                        .accessibilityLabel("Use current location")
                }
            }
            .buttonStyle(.borderless)
            .disabled(!data.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help(data.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Fill with current place" : "Clear the field to auto-fill location")
#endif
        }
        .task(id: data.isEmpty) {
            guard autoFillOnAppear else { return }
            // Only auto-fill when the field is empty and the user hasn't explicitly cleared it
            let shouldAutofill = await MainActor.run {
                data.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !userClearedField
            }
            guard shouldAutofill else { return }

            // Call through a MainActor-isolated closure to avoid sending the provider across actors
            let fetchPlace: @MainActor () async -> String? = { [locationProvider] in
                await locationProvider.currentPlaceString(preferBusinessName: true)
            }
            let place = await fetchPlace()

            // Assign back on the main actor, but only if the user hasn't started typing meanwhile
            if let place {
                let allowFill = await MainActor.run {
                    data.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !userClearedField
                }
                if allowFill {
                    await MainActor.run { data = place }
                }
            }
        }
        .accessibilityHint("Auto-fills with current place if empty")
    }
}


// MARK: label + textfield string
struct LabelDataTextview: View {
	let label: String
	@Binding var data: String
	/// Overrides the placeholder text shown when `data` is empty. Defaults to `label` when nil.
	var prompt: String? = nil
	var body: some View {
		Text(label)
			.textLabelModified()
		TextField("", text: $data, prompt: Text(prompt ?? label.replacingOccurrences(of: ":", with: "")))
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
	@Binding var fuelNotes: String
	@Binding var oilAdded: Float
	let labelOil: String
	@Binding var defAdded: Float
	let labelDEF: String
	@Binding var oilChecked: Bool
	@Binding var engineCoolantChecked: Bool
	@Binding var secondaryCoolantChecked: Bool
	@Binding var powerSteeringChecked: Bool
	@Binding var brakeFluidChecked: Bool
	@Binding var transmissionFluidChecked: Bool
	@Binding var rearAxleChecked: Bool
	@Binding var frontAxleChecked: Bool
	@Binding var fuelWaterSeparatorChecked: Bool
	@Binding var airSystemWaterBleedChecked: Bool
	@Binding var fuelDateTime: Date
	@Binding var fuelImage1: Data?
	@Binding var fuelImage2: Data?
	@Binding var fuelImage3: Data?
	var fuelExitTime: Binding<Date>? = nil
	var stopReason: Binding<String>? = nil
	var stopComment: Binding<String>? = nil
	let functions: Functions = Functions()
	
	/// Optional callback invoked when any of the fuel fields (notably notes) change or commit
	var onUpdate: (() -> Void)? = nil
	@State private var showFluidChecks: Bool = false
	
	private var isLocationValid: Bool { !fuelLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !dataFuelLog }
	private var isQuantityValid: Bool { dataQuantity >= 0 }
	private var isPriceValid: Bool { !dataFuelLog || dataPrice >= 0 }
	private var isOdometerValid: Bool { !dataFuelLog || fuelOdometer >= 0 }
	private var isEngHoursValid: Bool { !dataFuelLog || fuelEngHours >= 0 }
	private var isOilValid: Bool { !dataFuelLog || oilAdded >= 0 }
	private var isDEFValid: Bool { !dataFuelLog || defAdded >= 0 }
	/// Stop details stay hidden until a stop reason is chosen, so a freshly-added stop doesn't show a wall of empty fields.
	private var fieldsVisible: Bool { stopReason.map { !$0.wrappedValue.isEmpty } ?? true }
	/// Quantity only applies to fuel stops; other stop reasons (rest, food, etc.) don't add fuel.
	private var isFuelStop: Bool { stopReason.map { $0.wrappedValue == "Fuel" } ?? true }

	@ViewBuilder private func validatedField<Content: View>(_ valid: Bool, @ViewBuilder content: () -> Content) -> some View {
		content()
			.overlay(
				RoundedRectangle(cornerRadius: 7)
					.stroke(valid ? Color.clear : Color.red.opacity(0.6), lineWidth: valid ? 0 : 1)
			)
	}
	
	var body: some View {
		VStack {
				if let stopReason {
					let predefined: [String] = ["", "Fuel", "Rest", "Food", "Sightseeing", "Lodging", "Maintenance", "Weather"]
					let pickerSel = predefined.contains(stopReason.wrappedValue) ? stopReason.wrappedValue : "Other"
					HStack {
						Text("Stop Reason")
							.textLabelModified()
						Picker("", selection: Binding(
							get: { pickerSel },
							set: { val in
								if val == "Other" { stopReason.wrappedValue = "Other" }
								else { stopReason.wrappedValue = val }
								if val == "Fuel" { dataFuelLog = true }
							}
						)) {
							Text("Not Set").tag("")
							Text("Fuel").tag("Fuel")
							Text("Rest").tag("Rest")
							Text("Food").tag("Food")
							Text("Sightseeing").tag("Sightseeing")
							Text("Lodging").tag("Lodging")
							Text("Maintenance").tag("Maintenance")
							Text("Weather").tag("Weather")
							Text("Other").tag("Other")
						}
						.pickerStyle(.menu)
						.pickerModifier_Medium()
					}
					if pickerSel == "Other" {
						HStack {
							Text("  Specify")
								.bold()
							TextField("Describe stop", text: Binding(
								get: { stopReason.wrappedValue == "Other" ? "" : stopReason.wrappedValue },
								set: { stopReason.wrappedValue = $0.isEmpty ? "Other" : $0 }
							))
							.textFieldStyle(.roundedBorder)
						}
					}
				}
				if fieldsVisible {
				if let stopComment {
					HStack {
						Text("Comments")
							.bold()
						TextField("Stop notes", text: stopComment)
							.textFieldStyle(.roundedBorder)
					}
				}
				if fuelEntryValue == 0 {
				// only display fuel log option if new entry
				// edited entry would be > 0 so log already created
				Toggle(isOn: $dataFuelLog){
					Text("Create Fuel Log")
						.textLabelModified()
				}
				.accessibilityLabel("Create Fuel Log")
				.accessibilityHint("Enable to store this fuel stop as a separate log with price, odometer, and fluids")
				.onChange(of: dataFuelLog) { _, newValue in
					if newValue { stopReason?.wrappedValue = "Fuel" }
				}
			}
				LabelDataPicker_DateTime(label: "Date/Time                    ", data: $fuelDateTime)
				if let fuelExitTime {
					LabelDataPicker_DateTime(label: "Exit Time                    ", data: fuelExitTime)
				}
				LabelLocationTextview(label: "Location", data: $fuelLocation, autoFillOnAppear: false)
			HStack {
				if isFuelStop {
					Text("Qty\(label)")
						.textLabelModified()
					validatedField(isQuantityValid) {
						TextField("", value: $dataQuantity, formatter: functions.DoubleFormatter)
							.textViewModified_Medium()
#if !os(macOS)
							.selectAllTextOnBeginEditing()
							.keyboardType(.decimalPad)
#endif
							.accessibilityLabel("Fuel Quantity \(label)")
					}
					if !isQuantityValid {
						Text("Quantity cannot be negative")
							.font(.caption2)
							.foregroundStyle(.red)
					}
				}
				if dataFuelLog {
					Text("Price/\(label)")
						.textLabelModified()
					validatedField(isPriceValid) {
						TextField("", value: $dataPrice, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
							.textViewModified_Medium()
#if !os(macOS)
							.selectAllTextOnBeginEditing()
							.keyboardType(.decimalPad)
#endif
							.accessibilityLabel("Fuel Price per \(label)")
					}
					if !isPriceValid {
						Text("Price cannot be negative")
							.font(.caption2)
							.foregroundStyle(.red)
					}
				}
			}
					
			if dataFuelLog {
				HStack {
					Text("Odometer")
						.textLabelModified()
					validatedField(isOdometerValid) {
						TextField("", value: $fuelOdometer, formatter: functions.FloatFormatter)
							.textViewModified_Medium()
#if !os(macOS)
							.selectAllTextOnBeginEditing()
							.keyboardType(.numberPad)
#endif
							.accessibilityLabel("Fuel Odometer")
					}
					if !isOdometerValid {
						Text("Odometer cannot be negative")
							.font(.caption2)
							.foregroundStyle(.red)
					}
					Text("Eng Hours")
						.textLabelModified()
					validatedField(isEngHoursValid) {
						TextField("", value: $fuelEngHours, formatter: functions.FloatFormatter)
							.textViewModified_Medium()
#if !os(macOS)
							.selectAllTextOnBeginEditing()
							.keyboardType(.numberPad)
#endif
							.accessibilityLabel("Fuel Engine Hours")
					}
					if !isEngHoursValid {
						Text("Engine hours cannot be negative")
							.font(.caption2)
							.foregroundStyle(.red)
					}
				}
				VStack {
					HStack(alignment: .center) {
						Text("--------- Fluids Added ---------")
					}
					HStack {
						Text("Oil \(labelOil)")
							.textLabelModified()
						validatedField(isOilValid) {
							TextField("", value: $oilAdded, formatter: functions.FloatFormatter)
								.textViewModified_Medium()
#if !os(macOS)
								.selectAllTextOnBeginEditing()
								.keyboardType(.decimalPad)
#endif
								.accessibilityLabel("Oil Added \(labelOil)")
						}
						if !isOilValid {
							Text("Oil cannot be negative")
								.font(.caption2)
								.foregroundStyle(.red)
						}
						Text("DEF \(labelDEF)")
							.textLabelModified()
						validatedField(isDEFValid) {
							TextField("", value: $defAdded, formatter: functions.FloatFormatter)
								.textViewModified_Medium()
#if !os(macOS)
								.selectAllTextOnBeginEditing()
								.keyboardType(.decimalPad)
#endif
								.accessibilityLabel("DEF Added \(labelDEF)")
						}
						if !isDEFValid {
							Text("DEF cannot be negative")
								.font(.caption2)
								.foregroundStyle(.red)
						}
					}
					HStack {
						Button {
							showFluidChecks = true
						} label: {
							Label("Fluid Checks", systemImage: "drop.circle")
						}
						.buttonStyle(.bordered)
						Spacer()
					}
					.sheet(isPresented: $showFluidChecks) {
						FluidCheckSheet(
						oilChecked: $oilChecked,
						engineCoolantChecked: $engineCoolantChecked,
						secondaryCoolantChecked: $secondaryCoolantChecked,
						powerSteeringChecked: $powerSteeringChecked,
						brakeFluidChecked: $brakeFluidChecked,
						transmissionFluidChecked: $transmissionFluidChecked,
						rearAxleChecked: $rearAxleChecked,
						frontAxleChecked: $frontAxleChecked,
						fuelWaterSeparatorChecked: $fuelWaterSeparatorChecked,
						airSystemWaterBleedChecked: $airSystemWaterBleedChecked,
					)
					}
				}
				HStack {
					
					CardView {
						TextFieldNote_FullWidth_3lines(sectionText: "FUEL LOG NOTES", prompt: "Enter notes...", data: $fuelNotes)
					}
					.onChange(of: fuelNotes) { _, _ in
						onUpdate?()
					}
					.onSubmit {
						onUpdate?()
					}
					.onDisappear {
						onUpdate?()
					}
//
//					Text("Notes")
//						.textLabelModified()
//					TextField("", text: $fuelNotes, prompt: Text("Enter fuel notes"))
//						.textViewModified()
//						.accessibilityLabel("Fuel Notes")
//						.accessibilityHint("Optional notes about this fuel stop")
//						.onChange(of: fuelNotes) { _, _ in
//							onUpdate?()
//						}
//						.onSubmit {
//							onUpdate?()
//						}
//						.onDisappear {
//							onUpdate?()
//						}
				}
				HStack(spacing: 8) {
					FuelStop_ImagePicker(imageData: $fuelImage1)
					FuelStop_ImagePicker(imageData: $fuelImage2)
					FuelStop_ImagePicker(imageData: $fuelImage3)
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

struct SafeArea_Title_Modifier: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
			.font(.title2.bold())
			.foregroundStyle(.secondary)
			.shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
			.padding(.vertical, 2)
			.frame(maxWidth: .infinity, alignment: .leading)
	}
}
struct SafeArea_TitleNoGraphic_Modifier: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
			.font(.title2.bold())
			.foregroundStyle(.secondary)
			.shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
			.padding(.vertical, 2)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(.ultraThinMaterial)
			.overlay(Divider(), alignment: .bottom)
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
	func safeArea_Title_Modifier(with radius: CGFloat = 5) -> some View {
		self.modifier(SafeArea_Title_Modifier(corner: radius))}
	func safeArea_TitleNoGraphic_Modifier(with radius: CGFloat = 5) -> some View {
		self.modifier(SafeArea_TitleNoGraphic_Modifier(corner: radius))}
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

// MARK: - Fluid Check Sheet
struct FluidCheckSheet: View {
	@Environment(\.dismiss) private var dismiss

	@Query(filter: #Predicate<Settings1> { $0.userName == "primary1" })
	private var settingsQuery: [Settings1]
	private var s: Settings1? { settingsQuery.first }

	var oilChecked: Binding<Bool>? = nil
	var engineCoolantChecked: Binding<Bool>? = nil
	var secondaryCoolantChecked: Binding<Bool>? = nil
	var powerSteeringChecked: Binding<Bool>? = nil
	var brakeFluidChecked: Binding<Bool>? = nil
	var transmissionFluidChecked: Binding<Bool>? = nil
	var rearAxleChecked: Binding<Bool>? = nil
	var frontAxleChecked: Binding<Bool>? = nil
	var fuelWaterSeparatorChecked: Binding<Bool>? = nil
	var airSystemWaterBleedChecked: Binding<Bool>? = nil

	var body: some View {
		NavigationStack {
			Form {
				Section {
					if let b = oilChecked, s?.fluidChk_engineOil ?? true { Toggle("Engine Oil", isOn: b) }
					if let b = engineCoolantChecked, s?.fluidChk_engineCoolant ?? true { Toggle("Engine Coolant", isOn: b) }
					if let b = secondaryCoolantChecked, s?.fluidChk_secondaryCoolant ?? true { Toggle("Secondary Coolant", isOn: b) }
					if let b = powerSteeringChecked, s?.fluidChk_powerSteering ?? true { Toggle("Power Steering", isOn: b) }
					if let b = brakeFluidChecked, s?.fluidChk_brake ?? true { Toggle("Brake", isOn: b) }
					if let b = transmissionFluidChecked, s?.fluidChk_transmission ?? true { Toggle("Transmission", isOn: b) }
					if let b = rearAxleChecked, s?.fluidChk_rearAxle ?? true { Toggle("Rear Axle", isOn: b) }
					if let b = frontAxleChecked, s?.fluidChk_frontAxle ?? true { Toggle("Front Axle", isOn: b) }
					if let b = fuelWaterSeparatorChecked, s?.fluidChk_fuelWaterSep ?? true { Toggle("Fuel/Water Separator", isOn: b) }
					if let b = airSystemWaterBleedChecked, s?.fluidChk_airWaterBleed ?? true { Toggle("Air System Water Bleed", isOn: b) }
				} header: {
					Text("Mark fluids checked at this stop")
				}
			}
			.navigationTitle("Fluid Checks")
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
				}
			}
		}
	}
}
