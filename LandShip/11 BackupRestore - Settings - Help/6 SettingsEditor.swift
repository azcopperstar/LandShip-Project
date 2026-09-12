//
//  SettingsEditor.swift
//  LandShip
//
//  Created by JP on 10/2/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct SettingsEditorView: View {
	// Called when the user picks "Restore" on an entry in Manage Auto-Backups.
	// ContentView supplies this to dismiss Settings and hand off to its own
	// restore confirmation flow, which already handles the iCloud-aware choice
	// and post-restore restart enforcement — kept in one place rather than
	// duplicated here.
	var onRestoreRequested: (URL) -> Void = { _ in }

	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss
	@Environment(\.entitlements) private var entitlements
	@State private var restoreOutcome: RestoreOutcome?
	@State private var restoreInFlight = false

	// Fetch the primary settings if it exists
	@Query(filter: #Predicate<Settings1> { $0.userName == "primary1" })
	private var fetched: [Settings1]

	// Hold a reference to the editable model (created if missing)
	@State private var settings: Settings1?

	// Home location capture — a throwaway LocationProvider just for this one button, mirroring
	// LabelLocationTextview's usage elsewhere.
	@StateObject private var homeLocationProvider = LocationProvider()
	@State private var isCapturingHomeLocation = false

	// App-wide onboarding completion flag (shared with ContentView)
	@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
	@State private var showResetOnboardingConfirm: Bool = false

	// App-wide vehicle list preference moved here from ChooseVehicle
	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false
	@AppStorage(StorageKey.launchScreen) private var launchScreen: String = "dashboard"
	@AppStorage(StorageKey.appearanceMode) private var appearanceModeRaw: String = AppearanceMode.system.rawValue

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
	
	/// Signed decimal degrees with N/S, E/W suffixes, e.g. "39.8600°N, 75.2010°W" — same
	/// format as LabelLocationTextview's lat/lon caption, kept as a separate copy since that
	/// one is private to its own struct.
	private static func homeCoordinateString(latitude: Double, longitude: Double) -> String {
		let latDirection = latitude >= 0 ? "N" : "S"
		let lonDirection = longitude >= 0 ? "E" : "W"
		return String(format: "%.4f°%@, %.4f°%@", abs(latitude), latDirection, abs(longitude), lonDirection)
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

	/// The vertical's full fluid-check item list, in catalog declaration order — land isn't
	/// represented here since it uses the fixed fluidChk_* Bools via bindBool instead.
	private var currentVerticalFluidCheckLabels: [String] {
		switch Vertical.current.id {
			case .land: return []
			case .aviation: return AviationFluidCheckItem.allCases.map(\.rawValue)
			case .marine: return MarineFluidCheckItem.allCases.map(\.rawValue)
		}
	}

	/// Binds one aviation/marine fluid-check item's enabled state, re-sorting the backing
	/// array into catalog order on every write so Set iteration order never leaks into
	/// storage — mirrors FuelTypesConfigView.save().
	private func bindFluidCheckItem(_ label: String) -> Binding<Bool> {
		Binding(
			get: {
				switch Vertical.current.id {
					case .land: return true
					case .aviation:
						guard let item = AviationFluidCheckItem(rawValue: label) else { return true }
						return settings?.enabledAviationFluidCheckItems.contains(item) ?? true
					case .marine:
						guard let item = MarineFluidCheckItem(rawValue: label) else { return true }
						return settings?.enabledMarineFluidCheckItems.contains(item) ?? true
				}
			},
			set: { newValue in
				if settings == nil { ensureSettings() }
				guard let s = settings else { return }
				switch Vertical.current.id {
					case .land: break
					case .aviation:
						guard let item = AviationFluidCheckItem(rawValue: label) else { return }
						var current = Set(s.enabledAviationFluidCheckItems)
						if newValue { current.insert(item) } else { current.remove(item) }
						s.enabledAviationFluidCheckItems = AviationFluidCheckItem.allCases.filter { current.contains($0) }
					case .marine:
						guard let item = MarineFluidCheckItem(rawValue: label) else { return }
						var current = Set(s.enabledMarineFluidCheckItems)
						if newValue { current.insert(item) } else { current.remove(item) }
						s.enabledMarineFluidCheckItems = MarineFluidCheckItem.allCases.filter { current.contains($0) }
				}
			}
		)
	}

	// Reusable content so we can present it in Form (iOS) or ScrollView/VStack (macOS)
	@ViewBuilder
	private var formContent: some View {
		Section(Vertical.current.assetPlural) {
			Toggle(isOn: $showInactiveVehicles) {
				Label("Show Inactive in Lists", systemImage: showInactiveVehicles ? "eye" : "eye.slash")
			}
			.toggleStyle(.switch)
			.accessibilityLabel("Show inactive \(Vertical.current.assetPlural.lowercased()) in lists")
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
		
		Section("Appearance") {
			Picker("Appearance", selection: $appearanceModeRaw) {
				ForEach(AppearanceMode.allCases) { mode in
					Text(mode.label).tag(mode.rawValue)
				}
			}
			.pickerStyle(.segmented)
		}

		Section("App Behaviour") {
			Picker("Launch Screen", selection: $launchScreen) {
				Text("Dashboard").tag("dashboard")
				Text(Vertical.current.assetPlural).tag("vehicles")
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
			LabeledContent("Status", value: entitlements.isFullVersion ? PaywallCopy.Settings.unlockedCaption : PaywallCopy.Settings.trialCaption)
			if !entitlements.isFullVersion {
				Button(PaywallCopy.Settings.unlockButtonLabel) {
					entitlements.paywallContext = .sidebar
				}
			}
			Button {
				restoreInFlight = true
				Task {
					restoreOutcome = await entitlements.restorePurchases()
					restoreInFlight = false
				}
			} label: {
				if restoreInFlight {
					ProgressView()
				} else {
					Text(PaywallCopy.Settings.restoreButtonLabel)
				}
			}
			.disabled(restoreInFlight)
		} header: {
			Text(PaywallCopy.Settings.sectionTitle)
		}

		Section {
			if !entitlements.isFullVersion {
				Button {
					entitlements.paywallContext = .autoBackup
				} label: {
					Label("Full version required for automatic backups", systemImage: "lock.fill")
						.font(.caption)
						.foregroundStyle(.orange)
				}
				.buttonStyle(.plain)
			}
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

		if Vertical.current.id == .aviation {
			Section {
				NavigationLink("Configure Fuel Types…") {
					FuelTypesConfigView()
				}
			} header: {
				Text("Fuel Types")
			} footer: {
				Text("Choose which fuel types (100LL, Jet A, JP-8, SAF, etc.) appear in the Fuel Type picker when editing an aircraft or fuel log entry.")
			}
		}

		if Vertical.current.id == .marine {
			Section {
				NavigationLink("Configure Fuel Types…") {
					MarineFuelTypesConfigView()
				}
			} header: {
				Text("Fuel Types")
			} footer: {
				Text("Choose which fuel types (marine gasoline, LSMGO, VLSFO, LNG, etc.) appear in the Fuel Type picker when editing a vessel or fuel log entry.")
			}
		}

		if Vertical.current.id == .land {
			Section {
				NavigationLink("Configure Fuel Types…") {
					LandFuelTypesConfigView()
				}
			} header: {
				Text("Fuel Types")
			} footer: {
				Text("Choose which fuel types (gasoline grades, ethanol blends, diesel, EV charging, etc.) appear in the Fuel Type picker when editing a vehicle or fuel log entry.")
			}
		}

		if Vertical.current.id == .aviation {
			Section {
				NavigationLink("Configure Hydraulic Fluid Types…") {
					HydraulicFluidTypesConfigView()
				}
			} header: {
				Text("Hydraulic Fluid Types")
			} footer: {
				Text("Choose which hydraulic fluid types (MIL-PRF-5606, Skydrol, HyJet, etc.) appear in the Hydraulic Fluid Type picker when editing an aircraft.")
			}
		}

		if Vertical.current.id == .marine {
			Section {
				NavigationLink("Configure Hydraulic Fluid Types…") {
					MarineHydraulicFluidTypesConfigView()
				}
			} header: {
				Text("Hydraulic Fluid Types")
			} footer: {
				Text("Choose which hydraulic fluid types (tilt/trim fluid, AW hydraulic oil, Dexron III, etc.) appear in the Hydraulic Fluid Type picker when editing a vessel.")
			}
		}

		if Vertical.current.id == .land {
			Section {
				NavigationLink("Configure Hydraulic Fluid Types…") {
					LandHydraulicFluidTypesConfigView()
				}
			} header: {
				Text("Hydraulic Fluid Types")
			} footer: {
				Text("Choose which hydraulic fluid types (AW hydraulic oil, automatic transmission fluid, tractor/equipment brand fluids, etc.) appear in the Hydraulic Fluid Type picker when editing a vehicle.")
			}
		}

		if Vertical.current.id == .land {
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
		} else {
			Section("Fuel Log — Fluid Checks") {
				Text("Choose which fluid checks appear in the Fluid Checks popup when editing a fuel log or enroute stop.")
					.font(.caption).foregroundStyle(.secondary)
				ForEach(currentVerticalFluidCheckLabels, id: \.self) { label in
					Toggle(label, isOn: bindFluidCheckItem(label))
				}
			}
		}

		Section {
			if let settings, let lat = settings.homeLatitude, let lon = settings.homeLongitude {
				Text(Self.homeCoordinateString(latitude: lat, longitude: lon))
					.font(.callout)
					.foregroundStyle(.secondary)
				Button(role: .destructive) {
					settings.homeLatitude = nil
					settings.homeLongitude = nil
				} label: {
					Label("Clear Home Location", systemImage: "trash")
				}
			} else {
				Text("Not set.")
					.font(.callout)
					.foregroundStyle(.secondary)
			}
			Button {
				Task {
					if settings == nil { ensureSettings() }
					isCapturingHomeLocation = true
					await homeLocationProvider.refreshLocationContext()
					if let location = homeLocationProvider.lastLocation {
						settings?.homeLatitude = location.coordinate.latitude
						settings?.homeLongitude = location.coordinate.longitude
					}
					isCapturingHomeLocation = false
				}
			} label: {
				if isCapturingHomeLocation {
					HStack {
						ProgressView()
						Text("Locating…")
					}
				} else {
					Label("Use Current Location", systemImage: "location.fill")
				}
			}
			.disabled(isCapturingHomeLocation)
		} header: {
			Text("Home Location")
		} footer: {
			Text("Sets \u{201C}Home\u{201D} as a quick \u{201C}Use\u{201D} choice on Fuel Log/Travel Log location fields when it\u{2019}s the closest match to your current position.")
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
		.alert(restoreAlertTitle, isPresented: Binding(
			get: { restoreOutcome != nil },
			set: { if !$0 { restoreOutcome = nil } }
		)) {
			Button("OK") { restoreOutcome = nil }
		} message: {
			Text(restoreAlertMessage)
		}
	}

	private var restoreAlertTitle: String {
		switch restoreOutcome {
			case .restored: return PaywallCopy.Restore.restoredTitle
			case .nothingToRestore: return PaywallCopy.Restore.nothingTitle
			case .failed: return PaywallCopy.Restore.failedTitle
			case nil: return ""
		}
	}

	private var restoreAlertMessage: String {
		switch restoreOutcome {
			case .restored: return PaywallCopy.Restore.restoredMessage
			case .nothingToRestore: return PaywallCopy.Restore.nothingMessage
			case .failed(let message): return message
			case nil: return ""
		}
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

