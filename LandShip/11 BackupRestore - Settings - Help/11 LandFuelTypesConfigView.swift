// LandFuelTypesConfigView.swift
//
// Lets the user choose which fuel types appear in the Fuel Type picker on Edit
// Vehicle / Edit Fuel Log. Only relevant to the land vertical, where the picker now
// spans regional gasoline grades, ethanol blends, diesel grades, biodiesel/renewable
// diesel, gaseous fuels, EV charging types, and specialty/historic fuels instead of a
// fixed four-option list. Saved to the CloudKit-synced Settings1 singleton, so the
// selection follows the user across devices — mirrors FuelTypesConfigView (aviation)
// and MarineFuelTypesConfigView (marine).

import SwiftUI
import SwiftData

struct LandFuelTypesConfigView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	@Query(filter: #Predicate<Settings1> { $0.userName == "primary1" }) private var fetched: [Settings1]

	@State private var settings: Settings1?
	@State private var enabledFuels: Set<LandFuelType> = Set(LandFuelType.defaultEnabled)

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
		enabledFuels = Set(s.enabledLandFuelTypes)
	}

	private func toggle(_ fuel: LandFuelType) {
		if enabledFuels.contains(fuel) {
			enabledFuels.remove(fuel)
		} else {
			enabledFuels.insert(fuel)
		}
	}

	private func restoreDefaults() {
		enabledFuels = Set(LandFuelType.defaultEnabled)
	}

	private func save() {
		guard let s = settings else { return }
		// Keep catalog declaration order within each category rather than Set's arbitrary order.
		s.enabledLandFuelTypes = LandFuelType.allCases.filter { enabledFuels.contains($0) }
		do { try modelContext.save() } catch { print("Failed to save land fuel type scheme: \(error)") }
	}

	@ViewBuilder
	private func fuelRow(_ fuel: LandFuelType) -> some View {
		Button {
			toggle(fuel)
		} label: {
			HStack {
				VStack(alignment: .leading, spacing: 2) {
					Text(fuel.rawValue)
						.foregroundStyle(.primary)
					Text(fuel.summary)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				Spacer()
				if enabledFuels.contains(fuel) {
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
				Text("Choose which fuel types appear in the Fuel Type picker when editing a \(Vertical.current.assetSingular.lowercased()) or fuel log entry. This is saved to your account and applies on every device.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			ForEach(LandFuelType.Category.allCases, id: \.self) { category in
				Section(category.rawValue) {
					ForEach(LandFuelType.allCases.filter { $0.category == category }) { fuel in
						fuelRow(fuel)
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
				.navigationTitle("Fuel Types")
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
	return LandFuelTypesConfigView()
		.modelContainer(container)
}
