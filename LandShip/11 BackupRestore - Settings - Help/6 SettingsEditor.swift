//
//  SettingsEditor.swift
//  LandShip
//
//  Created by JP on 10/2/25.
//

import SwiftUI
import SwiftData

struct SettingsEditorView: View {
	// Called when the user picks "Restore" on an entry in Manage Auto-Backups.
	// ContentView supplies this to dismiss Settings and hand off to its own
	// restore confirmation flow, which already handles the iCloud-aware choice
	// and post-restore restart enforcement — kept in one place rather than
	// duplicated here.
	var onRestoreRequested: (URL) -> Void = { _ in }

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
	@AppStorage(StorageKey.launchScreen) private var launchScreen: String = "dashboard"

	// Automatic backup preferences
	@AppStorage(StorageKey.autoBackupInterval) private var autoBackupIntervalRaw: String = AutoBackupInterval.off.rawValue
	@AppStorage(StorageKey.autoBackupRetentionCount) private var autoBackupRetentionCount: Int = 5
	private var autoBackupInterval: AutoBackupInterval {
		AutoBackupInterval(rawValue: autoBackupIntervalRaw) ?? .off
	}
	// Create-or-load on appear; deduplicates if CloudKit synced multiple records
	private func ensureSettings() {
		if fetched.isEmpty {
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
			return
		}
		// Deterministic deduplication: sort by persistentModelID, which is the same
		// CloudKit record ID on every device — all devices independently keep the same winner
		let enc = JSONEncoder()
		func idData(_ m: Settings1) -> Data { (try? enc.encode(m.persistentModelID)) ?? Data() }
		let sorted = fetched.sorted { idData($0).lexicographicallyPrecedes(idData($1)) }
		if fetched.count > 1 {
			for duplicate in sorted.dropFirst() {
				modelContext.delete(duplicate)
			}
			try? modelContext.save()
		}
		settings = sorted.first
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
	
	private func bindBool(_ keyPath: ReferenceWritableKeyPath<Settings1, Bool>) -> Binding<Bool> {
		Binding(
			get: { settings?[keyPath: keyPath] ?? true },
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
		
		Section("App Behaviour") {
			Picker("Launch Screen", selection: $launchScreen) {
				Text("Dashboard").tag("dashboard")
				Text("Vehicles").tag("vehicles")
				Text("Fuel Log").tag("fuelLog")
				Text("Travel Log").tag("tripLog")
				Text("Service Records").tag("records")
				Text("Improvements").tag("additions")
				Text("Expenditures").tag("subscriptions")
				Text("Projects").tag("projectList")
				Text("Checklists").tag("displayChecklist")
				Text("Last Section Open").tag("lastSection")
			}
		}

		Section {
			Picker("Frequency", selection: $autoBackupIntervalRaw) {
				ForEach(AutoBackupInterval.allCases) { interval in
					Text(interval.label).tag(interval.rawValue)
				}
			}
			if autoBackupInterval != .off {
				Stepper(value: $autoBackupRetentionCount, in: 1...20) {
					Text("Keep last \(autoBackupRetentionCount) backup\(autoBackupRetentionCount == 1 ? "" : "s")")
				}
			}
			NavigationLink("Manage Auto-Backups…") {
				ManageAutoBackupsView(onRestoreRequested: onRestoreRequested)
			}
		} header: {
			Text("Automatic Backups")
		} footer: {
			Text("When enabled, \(AppInfo.displayName) creates a backup automatically the next time you open the app after the chosen interval has passed — no file picker needed. Automatic backups are stored in the app's own Documents folder and pruned to the number kept above; use \u{201C}Manage Auto-Backups…\u{201D} to restore, share a copy elsewhere, or delete one.")
		}

		Section("Fuel Log — Fluid Checks") {
			Text("Choose which fluid checks appear in the Fluid Checks popup when editing a fuel log or enroute stop.")
				.font(.caption).foregroundStyle(.secondary)
			Toggle("Engine Oil", isOn: bindBool(\.fluidChk_engineOil))
			Toggle("Engine Coolant", isOn: bindBool(\.fluidChk_engineCoolant))
			Toggle("Secondary Coolant", isOn: bindBool(\.fluidChk_secondaryCoolant))
			Toggle("Power Steering", isOn: bindBool(\.fluidChk_powerSteering))
			Toggle("Brake", isOn: bindBool(\.fluidChk_brake))
			Toggle("Transmission", isOn: bindBool(\.fluidChk_transmission))
			Toggle("Rear Axle", isOn: bindBool(\.fluidChk_rearAxle))
			Toggle("Front Axle", isOn: bindBool(\.fluidChk_frontAxle))
			Toggle("Fuel/Water Separator", isOn: bindBool(\.fluidChk_fuelWaterSep))
			Toggle("Air System Water Bleed", isOn: bindBool(\.fluidChk_airWaterBleed))
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

