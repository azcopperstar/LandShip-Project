//
//  SettingsEditor.swift
//  LandShip
//
//  Created by JP on 10/2/25.
//

import SwiftUI
import SwiftData

struct SettingsEditorView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss
	
	// Fetch the primary settings if it exists
	@Query(filter: #Predicate<Settings1> { $0.userName == "primary1" })
	private var fetched: [Settings1]
	
	// Hold a reference to the editable model (created if missing)
	@State private var settings: Settings1?
	
	// App-wide onboarding completion flag (shared with ContentView)
	@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
	@State private var showResetOnboardingConfirm: Bool = false

	// App-wide vehicle list preference moved here from ChooseVehicle
	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false
	
	// Create-or-load on appear
	private func ensureSettings() {
		if let first = fetched.first {
			settings = first
			return
		}
		// Create a new primary1 record if none exists
		let newPrimary = Settings1(
			userName: "primary1",
			unitVolumeFuel: "",
			unitVolumeOil: "",
			unitVolumeDEF: "",
			unitTemp: "",
			unitSpeed: "",
			unitPressure: "",
			unitMass: "",
			unitLength: "",
			unitWidth: "",
			unitHeight: "",
			unitWheelBase: ""
		)
		modelContext.insert(newPrimary)
		do { try modelContext.save() } catch { print("Failed to seed Settings1: \(error)") }
		settings = newPrimary
	}
	
	// Small helper to bind to optional reference type fields safely
	private func bind(_ keyPath: ReferenceWritableKeyPath<Settings1, String>) -> Binding<String> {
		Binding(
			get: { settings?[keyPath: keyPath] ?? "" },
			set: { newValue in
				if settings == nil { ensureSettings() }
				settings?[keyPath: keyPath] = newValue
			}
		)
	}
	
	// Reusable content so we can present it in Form (iOS) or ScrollView/VStack (macOS)
	@ViewBuilder
	private var formContent: some View {
		Section("Vehicles") {
			Toggle(isOn: $showInactiveVehicles) {
				Label("Show Inactive in Lists", systemImage: showInactiveVehicles ? "eye" : "eye.slash")
			}
			.toggleStyle(.switch)
			.accessibilityLabel("Show inactive vehicles in lists")
		}

		Section("Units of Measure") {
			Picker_Volume(label: "Fuel/Water", data: bind(\.unitVolumeFuel))
			Picker_Volume(label: "Oil", data: bind(\.unitVolumeOil))
			Picker_Volume(label: "DEF", data: bind(\.unitVolumeDEF))
			Picker_Temp(label: "Temp", data: bind(\.unitTemp))
			Picker_Speed(label: "Speed", data: bind(\.unitSpeed))
			Picker_Press(label: "Pressure", data: bind(\.unitPressure))
			Picker_Mass(label: "Mass", data: bind(\.unitMass))
			Picker_Dist(label: "Distance", data: bind(\.unitDistance))
			Picker_Area(label: "Area", data: bind(\.unitArea))
			Picker_LWH(label: "Length", data: bind(\.unitLength))
			Picker_LWH(label: "Width", data: bind(\.unitWidth))
			Picker_LWH(label: "Height", data: bind(\.unitHeight))
			Picker_LWH(label: "Wheelbase", data: bind(\.unitWheelBase))
		}
		
		Section {
			Button(role: .destructive) {
				showResetOnboardingConfirm = true
			} label: {
				Label("Reset Startup Screens…", systemImage: "arrow.counterclockwise")
			}
		} header: {
			Text("Onboarding")
		} footer: {
			Text("Resets the app’s first-run onboarding so it will be shown again on next launch.")
		}
	}
	
	// Cross-platform content that we can attach navigation/toolbar to
	@ViewBuilder
	private var content: some View {
		#if os(macOS)
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				formContent
			}
			.padding()
		}
		.frame(minWidth: 520)
		#else
		Form {
			formContent
		}
		#endif
	}
	
	var body: some View {
		NavigationStack {
			content
				.navigationTitle("Edit Settings")
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						Button("Cancel") { dismiss() }
					}
					ToolbarItem(placement: .confirmationAction) {
						Button("Save") {
							do { try modelContext.save() } catch {
								print("Failed to save Settings1: \(error)")
							}
							dismiss()
						}
					}
				}
		}
		.alert("Reset Onboarding?", isPresented: $showResetOnboardingConfirm) {
			Button("Reset", role: .destructive) {
				hasCompletedOnboarding = false
			}
			Button("Cancel", role: .cancel) { }
		} message: {
			Text("This will mark onboarding as incomplete so it shows again on next launch.")
		}
		.onAppear { ensureSettings() }
	}
}

// Cross-platform, availability-safe text entry styling for the username field
private extension View {
	@ViewBuilder
	func userNameTextEntryStyle() -> some View {
		#if os(iOS)
		if #available(iOS 15.0, *) {
			self
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled(true)
		} else {
			self
				.autocapitalization(.none)
				.disableAutocorrection(true)
		}
		#else
		self
		#endif
	}
}

#Preview {
	// In-memory SwiftData container for previews
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: Settings1.self, configurations: config)
	let context = container.mainContext
	
	// Seed a sample Settings1 record matching app queries (userName == "primary1")
	let sample = Settings1(
		userName: "primary1",
		unitVolumeFuel: "gal",
		unitVolumeOil: "qt",
		unitVolumeDEF: "gal",
		unitTemp: "F",
		unitSpeed: "mph",
		unitPressure: "PSI",
		unitMass: "lb",
		unitLength: "ft",
		unitWidth: "ft",
		unitHeight: "ft",
		unitWheelBase: "in"
	)
	context.insert(sample)
	try? context.save()
	
	return SettingsEditorView()
		.modelContainer(container)
}

