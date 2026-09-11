// MarineHydraulicFluidTypesConfigView.swift
//
// Lets the user choose which hydraulic fluid types appear in the Hydraulic Fluid Type
// picker on Edit Vehicle. Marine vertical (tilt/trim fluid, AW hydraulic oil, Dexron III, ...).
// Saved to the CloudKit-synced Settings1 singleton, so the selection follows the user
// across devices — mirrors FuelTypesConfigView / HydraulicFluidTypesConfigView (aviation).

import SwiftUI
import SwiftData

struct MarineHydraulicFluidTypesConfigView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	@Query(filter: #Predicate<Settings1> { $0.userName == "primary1" }) private var fetched: [Settings1]

	@State private var settings: Settings1?
	@State private var enabledFluids: Set<MarineHydraulicFluidType> = Set(MarineHydraulicFluidType.defaultEnabled)

	// Create-or-load on appear; deduplicates if CloudKit synced multiple records.
	// Mirrors ensureSettings() in SettingsEditorView / DashboardConfigView.
	private func ensureSettings() {
		if fetched.isEmpty {
			let newPrimary = Settings1(userName: "primary1")
			modelContext.insert(newPrimary)
			do { try modelContext.save() } catch { print("Failed to seed Settings1: \(error)") }
			settings = newPrimary
			return
		}
		let enc = JSONEncoder()
		func idData(_ m: Settings1) -> Data { (try? enc.encode(m.persistentModelID)) ?? Data() }
		let sorted = fetched.sorted { idData($0).lexicographicallyPrecedes(idData($1)) }
		if fetched.count > 1 {
			for duplicate in sorted.dropFirst() { modelContext.delete(duplicate) }
			try? modelContext.save()
		}
		settings = sorted.first
	}

	private func loadFromSettings() {
		ensureSettings()
		guard let s = settings else { return }
		enabledFluids = Set(s.enabledMarineHydraulicFluidTypes)
	}

	private func toggle(_ fluid: MarineHydraulicFluidType) {
		if enabledFluids.contains(fluid) {
			enabledFluids.remove(fluid)
		} else {
			enabledFluids.insert(fluid)
		}
	}

	private func restoreDefaults() {
		enabledFluids = Set(MarineHydraulicFluidType.defaultEnabled)
	}

	private func save() {
		guard let s = settings else { return }
		// Keep catalog declaration order within each category rather than Set's arbitrary order.
		s.enabledMarineHydraulicFluidTypes = MarineHydraulicFluidType.allCases.filter { enabledFluids.contains($0) }
		do { try modelContext.save() } catch { print("Failed to save marine hydraulic fluid type scheme: \(error)") }
	}

	@ViewBuilder
	private func fluidRow(_ fluid: MarineHydraulicFluidType) -> some View {
		Button {
			toggle(fluid)
		} label: {
			HStack {
				VStack(alignment: .leading, spacing: 2) {
					Text(fluid.rawValue)
						.foregroundStyle(.primary)
					Text(fluid.summary)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				Spacer()
				if enabledFluids.contains(fluid) {
					Image(systemName: "checkmark")
						.foregroundStyle(.blue)
						.imageScale(.large)
				}
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}

	private var content: some View {
		List {
			Section {
				Text("Choose which hydraulic fluid types appear in the Hydraulic Fluid Type picker when editing a \(Vertical.current.assetSingular.lowercased()). This is saved to your account and applies on every device.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			ForEach(MarineHydraulicFluidType.Category.allCases, id: \.self) { category in
				Section(category.rawValue) {
					ForEach(MarineHydraulicFluidType.allCases.filter { $0.category == category }) { fluid in
						fluidRow(fluid)
					}
				}
			}

			Section {
				Button(role: .destructive) {
					restoreDefaults()
				} label: {
					Label("Restore Defaults", systemImage: "arrow.counterclockwise")
				}
			}
		}
	}

	var body: some View {
		NavigationStack {
			content
				.navigationTitle("Hydraulic Fluid Types")
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						Button("Cancel") { dismiss() }
					}
					ToolbarItem(placement: .confirmationAction) {
						Button("Done") {
							save()
							dismiss()
						}
					}
				}
		}
		#if os(macOS)
		.frame(minWidth: 480, minHeight: 560)
		#endif
		.onAppear { loadFromSettings() }
	}
}

#Preview {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: Settings1.self, configurations: config)
	return MarineHydraulicFluidTypesConfigView()
		.modelContainer(container)
}
