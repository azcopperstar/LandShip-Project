/*
 DashboardView.swift
 
 Overview
 --------
 The DashboardView is the entry point for a high-level, glanceable summary of the fleet. It composes several "card"-style subviews, each backed by derived data that is computed when the view appears or when the selected vehicle filter changes.
 
 Responsibilities
 - Present a cohesive dashboard of fleet status using lightweight, tappable cards.
 - Provide a vehicle filter ("All Vehicles" or a specific vehicle) that propagates to card-level queries/derivations.
 - Coordinate navigation to detail views for each card using NavigationLink.
 - Maintain a set of computed/derived models (e.g., nextTwoDue, dueSummary, recentServices) that feed the cards.
 - Synchronize a string-based selection (trackVehicleSelected) with a model-based selection (selectedVehicle) for the toolbar picker.
 
 Data Flow
 - SwiftData is used to fetch live model data via @Query for vehicles and via helper/compute functions for other data displayed in the cards.
 - User preferences (for units and formatting) are loaded on appear. The unit helper returns a safe string for each unit index.
 - When the vehicle filter changes, `refreshAll()` recomputes all card data to reflect the current scope.
 
 Navigation
 - Each card is wrapped in a NavigationLink to a corresponding detail view. Some cards also expose inline tap targets that open a lightweight sheet to illustrate filtered navigation.
 
 Platform Notes
 - The toolbar placement differs between iOS and other platforms to match platform conventions.
 
 Performance Considerations
 - `refreshAll()` computes multiple datasets. If recomputation becomes expensive with large stores, consider debouncing, moving work to background tasks, or incremental recompute per affected card.
 
 Accessibility
 - Cards use plain button style and system materials. Ensure adequate contrast in cards and that labels convey meaning when VoiceOver is enabled.
 
 Threading
 - SwiftUI state updates occur on the main thread. Any heavy computation inside the recompute helpers should be dispatched off the main thread and then published back to the main actor.
 
 TODO / Future Enhancements
 - Persist the last-selected vehicle in user preferences.
 - Add loading/progress indicators if recomputations are asynchronous.
 - Provide real navigation for the filter sheet tap targets once routes are defined.
*/ 

/// A compositional dashboard composed of multiple summary cards with a vehicle filter.
/// This view owns lightweight state for card inputs and coordinates navigation to details.
import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
	// SwiftData model context used for fetching and persisting app data.
	@Environment(\.modelContext) var modelContext
	// Live query of all vehicles; used to populate the toolbar picker and sync filter state.
	@Query var vehicles: [Vehicle8]
	// Utility formatters/helpers (dates, currency, etc.).
	let functions: Functions = Functions()
	// Utility for loading user/unit preferences.
	let prefsFunc: PrefsFunctions = PrefsFunctions()

	// Vehicle filter state
	// - `trackVehicleSelected` is a human-readable label persisted in state ("All Vehicles" or a vehicle name).
	// - `selectedVehicle` is the model selection used by the toolbar picker. The two are kept in sync via onChange handlers.
	@State var trackVehicleSelected: String = "All Vehicles"
	@State private var selectedVehicle: Vehicle8? = nil
	// Units/preferences
	// Loaded on appear from user preferences; `unit(_:)` safely indexes into the array to avoid out-of-bounds.
	@State private var units: [String] = Array(repeating: "", count: 13)
	private func unit(_ index: Int) -> String { units.indices.contains(index) ? units[index] : "" }

	// Backing state for each dashboard card. These are derived/aggregated values computed in `refreshAll()`.
	@State var nextTwoDue: [UpcomingDue] = []
	@State var dueSummary: DueSummary = DueSummary()
	@State var recentServices: [RecentService] = []
	@State var insuranceAlerts: [InsuranceAlert] = []
	@State var fleetSnapshot: FleetSnapshot = FleetSnapshot()
	@State var usageSinceLast: [UsageSinceLast] = []
	@State var costSnapshot: CostSnapshot = CostSnapshot()
	@State var systemHotlist: [SystemHot] = []

	// Thresholds that define what counts as "due soon" across various dimensions.
	let dueSoonFraction: Double = 0.10 // within 10% of interval
	let milesWindow: Int = 200
	let hoursWindow: Float = 10.0
	let daysWindow: Int = 15

	// Lightweight routing for demo filter actions.
	// Some cards expose tap targets that would normally navigate to filtered lists.
	// For now, these open a sheet summarizing what would be filtered.
	@State private var showingFilterSheet = false
	@State private var filterTitle = ""
	@State private var filterDetails = ""

	/// Subtle background gradient to give the dashboard depth without overpowering content.
	/// Uses system-friendly colors with low opacity to work across light/dark modes.
	private var backgroundGradient: LinearGradient {
		LinearGradient(
			colors: [
				Color.blue.opacity(0.12),
				Color.teal.opacity(0.08),
				Color.indigo.opacity(0.06)
			],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		)
	}

	var body: some View {
		// Main content stack: background gradient + scrollable list of cards.
		ZStack {
			backgroundGradient
				.ignoresSafeArea()

			ScrollView {
				VStack(spacing: 12) {
					// Contextual explanation: helps new users understand what the dashboard shows.
					HStack(alignment: .top, spacing: 8) {
						Image(systemName: "info.circle")
							.font(.headline)
							.foregroundStyle(.secondary)
						VStack(alignment: .leading, spacing: 4) {
//							Text("Dashboard")
//								.font(.subheadline).bold()
							Text("This dashboard summarizes your fleet’s status. Tap a card to open a detailed view.")
								.font(.caption)
								.foregroundStyle(.secondary)
								.fixedSize(horizontal: false, vertical: true)
						}
						.frame(maxWidth: .infinity, alignment: .leading)
					}
					.padding(12)
					.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
					.overlay(
						RoundedRectangle(cornerRadius: 12, style: .continuous)
							.strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
					)

					// Card: Next Service Due — shows next two upcoming items across the selected scope.
					NavigationLink {
						NextServiceDueDetailView(
							vehicleScope: trackVehicleSelected,
							distanceUnit: unit(UnitIndex.distance),
							formatDate: { functions.formatDate_DDMMMyy(date: $0) }
						)
					} label: {
						NextServiceDueCard(
							nextTwoDue: nextTwoDue,
							distanceUnit: unit(UnitIndex.distance),
							formatDate: { functions.formatDate_DDMMMyy(date: $0) }
						)
					}
					.buttonStyle(.plain)

					// Card: Maintenance Status — summary counts and a "system hotlist" of problem areas.
					NavigationLink {
						MaintenanceStatusDetailView(
							dueSummary: dueSummary,
							systemHotlist: systemHotlist,
							onTapSystem: { sys in
								filterTitle = "System • \(sys.isEmpty ? "Unspecified" : sys)"
								filterDetails = "Would navigate to items overdue for this system."
								showingFilterSheet = true
							}
						)
					} label: {
						MaintenanceStatusCard(dueSummary: dueSummary)
					}
					.buttonStyle(.plain)

					// Card: Recent Service — latest completed services for awareness and audit trail.
					NavigationLink {
						RecentServiceDetailView(
							vehicleScope: trackVehicleSelected,
							distanceUnit: unit(UnitIndex.distance),
							formatDate: { functions.formatDate_DDMMMyy(date: $0) }
						)
					} label: {
						RecentServiceCard(
							recentServices: recentServices,
							distanceUnit: unit(UnitIndex.distance),
							formatDate: { functions.formatDate_DDMMMyy(date: $0) }
						)
					}
					.buttonStyle(.plain)


					// Card: Fleet Snapshot — overall fleet metrics (e.g., active vehicles, utilization, etc.).
					NavigationLink {
						FleetSnapshotDetailView(
							fleetSnapshot: fleetSnapshot,
							distanceUnit: unit(UnitIndex.distance)
						)
					} label: {
						FleetSnapshotCard(
							fleetSnapshot: fleetSnapshot,
							distanceUnit: unit(UnitIndex.distance)
						)
					}
					.buttonStyle(.plain)

					// Card: Usage Since Last — distance/hours since last service per vehicle.
					NavigationLink {
						UsageSinceLastDetailView(
							rows: usageSinceLast,
							distanceUnit: unit(UnitIndex.distance),
							formatDate: { functions.formatDate_DDMMMyy(date: $0) },
							onTapVehicle: { name in
								filterTitle = "Usage • \(name)"
								filterDetails = "Would navigate to vehicle detail with usage since last service."
								showingFilterSheet = true
							}
						)
					} label: {
						UsageSinceLastCard(
							rows: usageSinceLast,
							distanceUnit: unit(UnitIndex.distance),
							formatDate: { functions.formatDate_DDMMMyy(date: $0) },
							onTapVehicle: { name in
								filterTitle = "Usage • \(name)"
								filterDetails = "Would navigate to vehicle detail with usage since last service."
								showingFilterSheet = true
							}
						)
					}
					.buttonStyle(.plain)

					// Card: Cost Snapshot — recent spend overview and top cost drivers.
					NavigationLink {
						CostSnapshotDetailView(
							cost: costSnapshot,
							formatCurrency: { functions.formatCurrency(dollars: Float($0)) },
							onTapRange: { title, details in
								filterTitle = title
								filterDetails = details
								showingFilterSheet = true
							},
							onTapTopItem: { name in
								filterTitle = "Top Item • \(name)"
								filterDetails = "Would navigate to records filtered to \(name) in last 90 days."
								showingFilterSheet = true
							}
						)
					} label: {
						CostSnapshotCard(
							cost: costSnapshot,
							formatCurrency: { functions.formatCurrency(dollars: Float($0)) },
							onTapRange: { title, details in
								filterTitle = title
								filterDetails = details
								showingFilterSheet = true
							},
							onTapTopItem: { name in
								filterTitle = "Top Item • \(name)"
								filterDetails = "Would navigate to records filtered to \(name) in last 90 days."
								showingFilterSheet = true
							}
						)
					}
					.buttonStyle(.plain)

					// Card: System Hotlist — systems with the most overdue or frequent issues.
					NavigationLink {
						SystemHotlistDetailView(
							systems: systemHotlist,
							onTapSystem: { sys in
								filterTitle = "System • \(sys.isEmpty ? "Unspecified" : sys)"
								filterDetails = "Would navigate to items overdue for this system."
								showingFilterSheet = true
							}
						)
					} label: {
						SystemHotlistCard(
							systems: systemHotlist,
							onTapSystem: { sys in
								filterTitle = "System • \(sys.isEmpty ? "Unspecified" : sys)"
								filterDetails = "Would navigate to items overdue for this system."
								showingFilterSheet = true
							}
						)
					}
					.buttonStyle(.plain)

					// Card: Insurance Expirations — upcoming expirations to help avoid coverage gaps.
					NavigationLink {
						InsuranceExpirationsDetailView(
							alerts: insuranceAlerts,
							formatDate: { functions.formatDate_DDMMMyy(date: $0) }
						)
					} label: {
						InsuranceExpirationsCard(
							alerts: insuranceAlerts,
							formatDate: { functions.formatDate_DDMMMyy(date: $0) }
						)
					}
					.buttonStyle(.plain)

					// Quick actions — optional shortcuts to common tasks.
					QuickActionsCard()
				}
				.padding(.horizontal)
			}
		}
		// Toolbar: platform-specific placement for the vehicle picker.
		#if os(iOS)
		.navigationBarTitleDisplayMode(.inline)

		.safeAreaInset(edge: .top) {
			PageTitle_Col2_NoPhoto(label: "DASHBOARD")
		}

		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				// Model-based picker bound to `selectedVehicle`; includes an "All Vehicles" empty choice.
				LabeledContent {
					ModelPicker(
						selection: $selectedVehicle,
						title: "Vehicle",
						includeEmptyChoice: true,
						emptyChoiceLabel: "All Vehicles",
						autoSelectFirst: false,
						sort: [SortDescriptor(\.name, order: .forward)],
						labelProvider: { $0.name }
					)
					.fixedSize(horizontal: true, vertical: true)
				} label: {
					Text("Vehicle")
						.textLabelModified()
				}
			}
		}
		#else
		.toolbar {
			ToolbarItem(placement: .automatic) {
				// Model-based picker bound to `selectedVehicle`; includes an "All Vehicles" empty choice.
				LabeledContent {
					ModelPicker(
						selection: $selectedVehicle,
						title: "Vehicle",
						includeEmptyChoice: true,
						emptyChoiceLabel: "All Vehicles",
						autoSelectFirst: false,
						sort: [SortDescriptor(\.name, order: .forward)],
						labelProvider: { $0.name }
					)
					.fixedSize(horizontal: true, vertical: true)
				} label: {
					Text("Vehicle")
						.textLabelModified()
				}
			}
		}
		#endif
		.onAppear {
			// Load unit preferences; fall back to empty strings if unavailable.
			units = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1")
			?? Array(repeating: "", count: 13)

			// Initialize picker selection based on the string filter from prior sessions.
			if trackVehicleSelected == "All Vehicles" || trackVehicleSelected.isEmpty {
				selectedVehicle = nil
			} else {
				selectedVehicle = vehicles.first(where: { $0.name == trackVehicleSelected })
			}

			// Compute all dashboard card inputs for the initial render.
			refreshAll()
		}
		// Recompute all card inputs whenever the string-based vehicle filter changes.
		.onChange(of: trackVehicleSelected) { _, _ in
			refreshAll()
		}
		// Keep string filter in sync with the model-based picker selection.
		.onChange(of: selectedVehicle) { _, newVehicle in
			trackVehicleSelected = newVehicle?.name ?? "All Vehicles"
		}
		// Keep the model-based picker in sync when the string filter changes externally.
		.onChange(of: trackVehicleSelected) { _, newValue in
			if newValue == "All Vehicles" || newValue.isEmpty {
				selectedVehicle = nil
			} else if let v = vehicles.first(where: { $0.name == newValue }) {
				if selectedVehicle?.persistentModelID != v.persistentModelID {
					selectedVehicle = v
				}
			} else {
				selectedVehicle = nil
			}
		}
		// Informational sheet used by card-level tap targets to describe hypothetical filters/routes.
		.sheet(isPresented: $showingFilterSheet) {
			VStack(spacing: 12) {
				Text(filterTitle).font(.headline)
				Text(filterDetails).font(.caption).foregroundStyle(.secondary)
				Button("Close") { showingFilterSheet = false }
					.buttonStyle(GrowingButton(buttonColor: .blue))
			}
			.padding()
			.presentationDetents([.medium])
		}
	}

	/// Recomputes all derived inputs that feed the dashboard cards.
	/// Call this when the selected vehicle scope changes or when underlying data mutates.
	/// If performance becomes an issue, consider:
	/// - Debouncing rapid changes
	/// - Moving heavy work to background tasks and updating on the main actor
	/// - Splitting into per-card recomputation triggered by more targeted changes
	private func refreshAll() {
		recomputeNextDue()
		recomputeDueSummaryAndSystemHotlist()
		fetchRecentServices()
		computeInsuranceAlerts()
		computeFleetSnapshot()
		computeUsageSinceLastService()
		computeCostSnapshot()
	}
}

#Preview {
	// Preview uses an in-memory model container for fast iteration without persistent side effects.
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: Vehicle8.self, MxItems3.self, ServiceRecords1.self, configurations: config)
	return NavigationStack {
		DashboardView()
	}
	.modelContainer(container)
}

