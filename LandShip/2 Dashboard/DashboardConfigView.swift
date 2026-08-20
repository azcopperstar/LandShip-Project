// DashboardConfigView.swift
//
// Lets the user choose which dashboard cards are shown (and in what order) and
// which vehicles count toward the dashboard's "All Vehicles" totals. Saved to
// the CloudKit-synced Settings1 singleton, so the scheme follows the user
// across devices — mirrors the persistence pattern used for unit preferences
// in SettingsEditorView.

import SwiftUI
import SwiftData

struct DashboardConfigView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	@Query(filter: #Predicate<Settings1> { $0.userName == "primary1" }) private var fetched: [Settings1]
	@Query(sort: [SortDescriptor(\Vehicle8.name, order: .forward)]) private var vehicles: [Vehicle8]

	@State private var settings: Settings1?
	@State private var shownCards: [DashboardCard] = DashboardCard.defaultOrder
	@State private var hiddenCards: [DashboardCard] = DashboardCard.allCases.filter { !DashboardCard.defaultOrder.contains($0) }
	@State private var includedVehicleNames: Set<String> = []

	// Create-or-load on appear; deduplicates if CloudKit synced multiple records.
	// Mirrors ensureSettings() in SettingsEditorView.
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
		shownCards = s.dashCards
		hiddenCards = DashboardCard.allCases.filter { !shownCards.contains($0) }
		let configured = Set(s.dashVehicleScopeRaw)
		includedVehicleNames = configured.isEmpty ? Set(vehicles.map(\.name)) : configured
	}

	private func hide(_ card: DashboardCard) {
		shownCards.removeAll { $0 == card }
		hiddenCards.append(card)
	}
	private func show(_ card: DashboardCard) {
		hiddenCards.removeAll { $0 == card }
		shownCards.append(card)
	}

	private func toggleVehicle(_ name: String) {
		if includedVehicleNames.contains(name) {
			includedVehicleNames.remove(name)
		} else {
			includedVehicleNames.insert(name)
		}
	}

	private func restoreDefaults() {
		shownCards = DashboardCard.defaultOrder
		hiddenCards = DashboardCard.allCases.filter { !DashboardCard.defaultOrder.contains($0) }
		includedVehicleNames = Set(vehicles.map(\.name))
	}

	private func save() {
		guard let s = settings else { return }
		s.dashCards = shownCards
		let allNames = Set(vehicles.map(\.name))
		// Store an explicit subset only when it differs from "everyone" — keeps
		// newly added vehicles included by default instead of silently excluded.
		s.dashVehicleScopeRaw = includedVehicleNames == allNames ? [] : Array(includedVehicleNames)
		do { try modelContext.save() } catch { print("Failed to save dashboard scheme: \(error)") }
	}

	// Note: the row itself is NOT a Button. On macOS, List reordering is driven by dragging
	// the row directly (there's no separate system drag handle like iOS's edit-mode grip), so
	// a whole-row Button would swallow the mouse-down before List's drag gesture can start.
	// Only the trailing show/hide icon is tappable; the rest of the row stays free to drag.
	@ViewBuilder
	private func cardRow(_ card: DashboardCard, isShown: Bool) -> some View {
		HStack(spacing: 10) {
			#if os(macOS)
			Image(systemName: "line.3.horizontal")
				.foregroundStyle(.tertiary)
				.font(.caption)
			#endif
			Image(systemName: card.icon)
				.foregroundStyle(.blue)
				.frame(width: 22)
			VStack(alignment: .leading, spacing: 2) {
				Text(card.displayName)
					.foregroundStyle(.primary)
				Text(card.summary)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			Spacer()
			Button {
				if isShown { hide(card) } else { show(card) }
			} label: {
				Image(systemName: isShown ? "minus.circle" : "plus.circle")
					.foregroundStyle(isShown ? .red : .green)
			}
			.buttonStyle(.plain)
		}
	}

	private var content: some View {
		List {
			Section {
				Text("Choose which cards appear on your dashboard and drag to reorder them. Choose which vehicles count toward \"All Vehicles\" totals. This is saved to your account and applies on every device.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Section("Shown — drag to reorder") {
				if shownCards.isEmpty {
					Text("No cards shown.")
						.font(.caption)
						.foregroundStyle(.secondary)
				} else {
					ForEach(shownCards) { card in
						cardRow(card, isShown: true)
					}
					.onMove { source, destination in
						shownCards.move(fromOffsets: source, toOffset: destination)
					}
				}
			}

			Section("Hidden") {
				if hiddenCards.isEmpty {
					Text("All cards are shown.")
						.font(.caption)
						.foregroundStyle(.secondary)
				} else {
					ForEach(hiddenCards) { card in
						cardRow(card, isShown: false)
					}
				}
			}

			Section {
				Button("Include All Vehicles") {
					includedVehicleNames = Set(vehicles.map(\.name))
				}
				ForEach(vehicles, id: \.persistentModelID) { v in
					let name = v.name
					let label = v.displayName.isEmpty ? name : v.displayName
					Button {
						toggleVehicle(name)
					} label: {
						HStack {
							Text(label)
								.foregroundStyle(.primary)
							if v.inactive {
								Text("Inactive")
									.font(.caption2)
									.foregroundStyle(.secondary)
							}
							Spacer()
							if includedVehicleNames.contains(name) {
								Image(systemName: "checkmark")
									.foregroundStyle(.blue)
									.imageScale(.large)
							}
						}
						.contentShape(Rectangle())
					}
					.buttonStyle(.plain)
				}
			} header: {
				Text("Vehicles in Dashboard Totals")
			} footer: {
				Text("Unchecked vehicles are excluded from \"All Vehicles\" totals across every card. Picking a specific vehicle from the dashboard's Vehicle picker always shows that vehicle's data regardless of this list.")
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
				.navigationTitle("Customize Dashboard")
				.toolbar {
					#if os(iOS)
					ToolbarItem(placement: .navigationBarLeading) {
						EditButton()
					}
					#endif
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
	let container = try! ModelContainer(for: Settings1.self, Vehicle8.self, configurations: config)
	let ctx = container.mainContext
	let v1 = Vehicle8(); v1.name = "Jeepster"; v1.displayName = "Jeepster"; ctx.insert(v1)
	let v2 = Vehicle8(); v2.name = "GMC Truck"; v2.displayName = "GMC Truck"; ctx.insert(v2)
	return DashboardConfigView()
		.modelContainer(container)
}
