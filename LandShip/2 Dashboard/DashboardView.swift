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
	// Live query of the saved dashboard configuration scheme (card order/visibility, vehicle scope).
	@Query(filter: #Predicate<Settings1> { $0.userName == "primary1" }) private var settingsRows: [Settings1]
	private var settings: Settings1? { settingsRows.first }
	// Utility formatters/helpers (dates, currency, etc.).
	let functions: Functions = Functions()
	// Utility for loading user/unit preferences.
	let prefsFunc: PrefsFunctions = PrefsFunctions()
	// Lets embedded cards (e.g. Quick Actions, "Vehicle: X" taps) request a sidebar navigation
	// change, optionally scoping the destination list to one vehicle. Nil when the Dashboard is
	// shown somewhere that has no sidebar to drive (e.g. a preview).
	var onQuickAction: ((SidebarItem, String?) -> Void)? = nil

	// Cards enabled by the user's saved scheme, in display order. Falls back to the original hardcoded set.
	var enabledCards: [DashboardCard] { settings?.dashCards ?? DashboardCard.defaultOrder }

	// Vehicle scope for dashboard aggregates. The toolbar's single-vehicle picker always wins over the
	// saved subset (drilling into one vehicle is an explicit, temporary override).
	// nil means "no restriction — include every vehicle".
	var scopeIds: [String]? {
		if trackVehicleSelected != "All Vehicles" && !trackVehicleSelected.isEmpty {
			return [trackVehicleSelected]
		}
		let configured = settings?.dashVehicleScopeRaw ?? []
		return configured.isEmpty ? nil : configured
	}
	func includesVehicle(_ vehicleId: String) -> Bool {
		guard let ids = scopeIds else { return true }
		return ids.contains(vehicleId)
	}
	var scopedVehicles: [Vehicle8] { vehicles.filter { includesVehicle($0.name) } }
	// Builds a vehicleId -> display-name lookup once from the already-fetched `vehicles` query,
	// so per-row card/detail views can look a name up in O(1) instead of each issuing its own
	// SwiftData fetch (see Functions.getVehicleDisplayName) for every visible row.
	func buildVehicleDisplayNameLookup() -> (String) -> String {
		let dict = Dictionary(uniqueKeysWithValues: vehicles.map { ($0.name, $0.displayName.isEmpty ? $0.name : $0.displayName) })
		return { id in
			guard id != "All Vehicles" && !id.isEmpty else { return id }
			return dict[id] ?? id
		}
	}
	// True when a saved vehicle subset (not the toolbar picker) is limiting the "All Vehicles" totals.
	var isVehicleScopeLimited: Bool {
		trackVehicleSelected == "All Vehicles" || trackVehicleSelected.isEmpty
			? !(settings?.dashVehicleScopeRaw ?? []).isEmpty
			: false
	}

	// Vehicle filter state
	// - `trackVehicleSelected` is a human-readable label persisted in state ("All Vehicles" or a vehicle name).
	// - `selectedVehicle` is the model selection used by the toolbar picker. The two are kept in sync via onChange handlers.
	@State var trackVehicleSelected: String = "All Vehicles"
	@State private var selectedVehicle: Vehicle8? = nil
	// Units/preferences
	// Loaded on appear from user preferences; `unit(_:)` safely indexes into the array to avoid out-of-bounds.
	@State private var units: [String] = Array(repeating: "", count: 13)
	private func unit(_ index: Int) -> String { units.indices.contains(index) ? units[index] : "" }

	// Cards lay out in a 2-column grid on iPad only; other platforms keep the single-column stack.
	private var isPadLayout: Bool {
#if os(iOS)
		return UIDevice.current.userInterfaceIdiom == .pad
#else
		return false
#endif
	}

	// Backing state for each dashboard card. These are derived/aggregated values computed in `refreshAll()`.
	@State var nextTwoDue: [UpcomingDue] = []
	@State var dueSummary: DueSummary = DueSummary()
	@State var recentServices: [RecentService] = []
	@State var insuranceAlerts: [InsuranceAlert] = []
	@State var recurringCosts: [RecurringCost] = []
	@State var fleetSnapshot: FleetSnapshot = FleetSnapshot()
	@State var usageSinceLast: [UsageSinceLast] = []
	@State var costSnapshot: CostSnapshot = CostSnapshot()
	@State var systemHotlist: [SystemHot] = []
	@State var vehicleMaintenanceStatuses: [VehicleMaintenanceStatus] = []
	@State var additionsCostByCategory: [AdditionsCategoryCost] = []
	@State var warrantyAlerts: [WarrantyAlert] = []
	@State var tripGroups: [TripGroupSummary] = []
	@State var inventoryAlerts: [InventoryAlert] = []

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
	@State private var showingConfigSheet = false

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

	// MARK: - Additions Cost Summary (by model category / subcategory)
	struct AdditionsCategoryCost: Identifiable {
        let id = UUID()
        let vehicleId: String
        let category: String
        let subcategory: String
        let total: Double
	}

	/// Computes aggregated costs for "Additions" grouped by model category and subcategory
	/// This function expects ServiceRecords1 (or similar) to store category/subcategory and cost fields.
	/// It scopes by the current vehicle filter if one is selected.
	func computeAdditionsCategoryCosts() {
	    // Use only strongly-typed properties defined on Additions (no KVC/reflection).
	    var buckets: [String: Double] = [:]

	    if let additions = try? modelContext.fetch(FetchDescriptor<Additions>()) {
	        // Apply vehicle scope: toolbar single-vehicle pick or the saved vehicle scheme.
	        let filtered = additions.filter { includesVehicle($0.vehicleId) }

	        for add in filtered {
	            // Category/subcategory straight from model
	            let category = add.category.isEmpty ? "Unspecified" : add.category
	            let subcategory = add.subCategory.isEmpty ? "—" : add.subCategory

	            // Cost straight from model
	            let cost = Double(add.itemCost)
	            guard cost > 0 else { continue }

	            let key = add.vehicleId + "\u{0001}" + category + "\u{0001}" + subcategory
	            buckets[key, default: 0] += cost
	        }
	    }

	    // Map to view models and sort by total descending
	    let rows: [AdditionsCategoryCost] = buckets.map { key, total in
	        let parts = key.split(separator: "\u{0001}").map(String.init)
	        let vehicleId = parts.indices.contains(0) ? parts[0] : ""
	        let category = parts.indices.contains(1) ? parts[1] : "Unspecified"
	        let subcategory = parts.indices.contains(2) ? parts[2] : "—"
	        return AdditionsCategoryCost(vehicleId: vehicleId, category: category, subcategory: subcategory, total: total)
	    }
	    .sorted {
	        if $0.vehicleId == $1.vehicleId {
	            if $0.category == $1.category { return $0.total > $1.total }
	            return $0.category < $1.category
	        }
	        return $0.vehicleId < $1.vehicleId
	    }

	    self.additionsCostByCategory = rows
	}

	var body: some View {
		// Main content stack: background gradient + scrollable list of cards.
		ZStack {
			backgroundGradient
				.ignoresSafeArea()

			ScrollView {
				VStack(spacing: 12) {
					infoCard
					if isPadLayout {
						LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
							ForEach(enabledCards) { card in
								cardView(for: card)
							}
						}
					} else {
						ForEach(enabledCards) { card in
							cardView(for: card)
						}
					}
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
				Button {
					showingConfigSheet = true
				} label: {
					Image(systemName: "slider.horizontal.3")
				}
				.accessibilityLabel("Customize Dashboard")
			}
			ToolbarItem(placement: .navigationBarTrailing) {
				LabeledContent {
					ModelPicker(
						selection: $selectedVehicle,
						title: Vertical.current.assetSingular,
						includeEmptyChoice: true,
						emptyChoiceLabel: FleetScope.allDisplayLabel,
						autoSelectFirst: false,
						sort: [SortDescriptor(\.name, order: .forward)],
						labelProvider: { $0.displayName },
						thumbnailData: { $0.image1 }
					)
					.fixedSize(horizontal: true, vertical: true)
				} label: {
					Text(Vertical.current.assetSingular)
						.textLabelModified()
				}
			}
		}
		#else
		.toolbar {
			ToolbarItem(placement: .automatic) {
				Button {
					showingConfigSheet = true
				} label: {
					Image(systemName: "slider.horizontal.3")
				}
				.accessibilityLabel("Customize Dashboard")
			}
			ToolbarItem(placement: .automatic) {
				LabeledContent {
					ModelPicker(
						selection: $selectedVehicle,
						title: Vertical.current.assetSingular,
						includeEmptyChoice: true,
						emptyChoiceLabel: FleetScope.allDisplayLabel,
						autoSelectFirst: false,
						sort: [SortDescriptor(\.name, order: .forward)],
						labelProvider: { $0.displayName },
						thumbnailData: { $0.image1 }
					)
					.fixedSize(horizontal: true, vertical: true)
				} label: {
					Text(Vertical.current.assetSingular)
						.textLabelModified()
				}
			}
		}
		#endif
		.onAppear {
			units = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1")
				?? Array(repeating: "", count: 13)
			if trackVehicleSelected == "All Vehicles" || trackVehicleSelected.isEmpty {
				selectedVehicle = nil
			} else {
				selectedVehicle = vehicles.first(where: { $0.name == trackVehicleSelected })
			}
			refreshAll()
		}
		.onChange(of: trackVehicleSelected) { _, _ in
			refreshAll()
		}
		.onChange(of: selectedVehicle) { _, newVehicle in
			trackVehicleSelected = newVehicle?.name ?? "All Vehicles"
		}
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
		.sheet(isPresented: $showingConfigSheet, onDismiss: { refreshAll() }) {
			DashboardConfigView()
		}
	}

	// MARK: - Card Views

	@ViewBuilder private var infoCard: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack(alignment: .top, spacing: 8) {
				Image(systemName: "info.circle")
					.font(.headline)
					.foregroundStyle(.secondary)
				Text("This dashboard summarizes your fleet's status. Tap a card to open a detailed view. Tap \(Image(systemName: "slider.horizontal.3")) to customize which cards are shown and which \(Vertical.current.assetPlural.lowercased()) count toward totals.")
					.font(.caption)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			if isVehicleScopeLimited {
				let count = (settings?.dashVehicleScopeRaw ?? []).count
				HStack(alignment: .top, spacing: 8) {
					Image(systemName: "line.3.horizontal.decrease.circle")
						.font(.caption)
						.foregroundStyle(.blue)
					Text("Totals limited to \(count) of \(vehicles.count) \(Vertical.current.assetPlural.lowercased()).")
						.font(.caption2)
						.foregroundStyle(.blue)
				}
			}
		}
		.padding(12)
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
		)
	}

	@ViewBuilder private var maintenanceStatusCard: some View {
		NavigationLink {
			MaintenanceStatusDetailView(
				vehicleStatuses: vehicleMaintenanceStatuses,
				nextDue: nextTwoDue,
				dueSummary: dueSummary,
				systemHotlist: systemHotlist,
				onTapSystem: { sys in
					let label = sys.isEmpty ? "Unspecified" : sys
					filterTitle = "System: " + label
					filterDetails = "Would navigate to items overdue for this system."
					showingFilterSheet = true
				}
			)
		} label: {
			MaintenanceStatusCard(
				vehicleStatuses: vehicleMaintenanceStatuses,
				nextDue: nextTwoDue,
				recentServices: recentServices,
				dueSummary: dueSummary,
				distanceUnit: unit(UnitIndex.distance),
				formatDate: { functions.formatDate_DDMMMyy(date: $0) }
			)
		}
		.buttonStyle(.plain)
	}

	@ViewBuilder private var nextServiceDueCard: some View {
		let vehicleDisplayName = buildVehicleDisplayNameLookup()
		NavigationLink {
			NextServiceDueDetailView(
				vehicleScope: trackVehicleSelected,
				distanceUnit: unit(UnitIndex.distance),
				formatDate: { functions.formatDate_DDMMMyy(date: $0) },
				vehicleDisplayName: vehicleDisplayName
			)
		} label: {
			NextServiceDueCard(
				nextTwoDue: nextTwoDue,
				distanceUnit: unit(UnitIndex.distance),
				formatDate: { functions.formatDate_DDMMMyy(date: $0) },
				vehicleDisplayName: vehicleDisplayName
			)
		}
		.buttonStyle(.plain)
	}

	@ViewBuilder private var fleetSnapshotCard: some View {
		NavigationLink {
			FleetSnapshotDetailView(
				fleetSnapshot: fleetSnapshot,
				distanceUnit: unit(UnitIndex.distance),
				cost: costSnapshot,
				formatCurrency: { functions.formatCurrency(dollars: Float($0)) },
				onTapRange: { title, details in
					filterTitle = title
					filterDetails = details
					showingFilterSheet = true
				},
				onTapTopItem: { name in
					filterTitle = "Top Item: " + name
					filterDetails = "Records filtered to " + name + " (last 90 days)."
					showingFilterSheet = true
				}
			)
		} label: {
			FleetSnapshotCard(
				fleetSnapshot: fleetSnapshot,
				distanceUnit: unit(UnitIndex.distance),
				cost: costSnapshot,
				formatCurrency: { functions.formatCurrency(dollars: Float($0)) },
				onTapRange: { title, details in
					filterTitle = title
					filterDetails = details
					showingFilterSheet = true
				},
				onTapTopItem: { name in
					filterTitle = "Top Item: " + name
					filterDetails = "Records filtered to " + name + " (last 90 days)."
					showingFilterSheet = true
				}
			)
		}
		.buttonStyle(.plain)
	}

	@ViewBuilder private var insuranceCard: some View {
		NavigationLink {
			InsuranceExpirationsDetailView(
				alerts: insuranceAlerts,
				recurringCosts: recurringCosts,
				formatDate: { functions.formatDate_DDMMMyy(date: $0) },
				formatCurrency: { functions.formatCurrency(dollars: Float($0)) }
			)
		} label: {
			InsuranceExpirationsCard(
				alerts: insuranceAlerts,
				recurringCosts: recurringCosts,
				formatDate: { functions.formatDate_DDMMMyy(date: $0) },
				formatCurrency: { functions.formatCurrency(dollars: Float($0)) }
			)
		}
		.buttonStyle(.plain)
	}

	@ViewBuilder private var warrantyCard: some View {
		WarrantyCard(
			alerts: warrantyAlerts,
			formatDate: { functions.formatDate_DDMMMyy(date: $0) }
		)
	}

	@ViewBuilder private var tripGroupsCard: some View {
		NavigationLink {
			TripGroupsDetailView(
				groups: tripGroups,
				distanceUnit: unit(UnitIndex.distance),
				fuelUnit: unit(UnitIndex.fuel),
				formatDate: { functions.formatDate_DDMMMyy(date: $0) }
			)
		} label: {
			TripGroupsCard(
				groups: tripGroups,
				distanceUnit: unit(UnitIndex.distance),
				fuelUnit: unit(UnitIndex.fuel),
				formatDate: { functions.formatDate_DDMMMyy(date: $0) }
			)
		}
		.buttonStyle(.plain)
	}

	@ViewBuilder private var recentServiceCard: some View {
		let vehicleDisplayName = buildVehicleDisplayNameLookup()
		NavigationLink {
			RecentServiceDetailView(
				vehicleScope: trackVehicleSelected,
				distanceUnit: unit(UnitIndex.distance),
				formatDate: { functions.formatDate_DDMMMyy(date: $0) },
				vehicleDisplayName: vehicleDisplayName
			)
		} label: {
			RecentServiceCard(
				recentServices: recentServices,
				distanceUnit: unit(UnitIndex.distance),
				formatDate: { functions.formatDate_DDMMMyy(date: $0) },
				vehicleDisplayName: vehicleDisplayName
			)
		}
		.buttonStyle(.plain)
	}

	@ViewBuilder private var usageSinceLastCard: some View {
		NavigationLink {
			UsageSinceLastDetailView(
				rows: usageSinceLast,
				distanceUnit: unit(UnitIndex.distance),
				formatDate: { functions.formatDate_DDMMMyy(date: $0) },
				onTapVehicle: { name in
					onQuickAction?(.records, name)
				}
			)
		} label: {
			UsageSinceLastCard(
				rows: usageSinceLast,
				distanceUnit: unit(UnitIndex.distance),
				formatDate: { functions.formatDate_DDMMMyy(date: $0) },
				onTapVehicle: { name in
					onQuickAction?(.records, name)
				}
			)
		}
		.buttonStyle(.plain)
	}

	@ViewBuilder private var systemHotlistCard: some View {
		SystemHotlistCard(
			systems: systemHotlist,
			onTapSystem: { sys in
				let label = sys.isEmpty ? "Unspecified" : sys
				filterTitle = "System: " + label
				filterDetails = "Would navigate to items overdue for this system."
				showingFilterSheet = true
			}
		)
	}

	@ViewBuilder private var costSnapshotCard: some View {
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
					filterTitle = "Top Item: " + name
					filterDetails = "Records filtered to " + name + " (last 90 days)."
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
					filterTitle = "Top Item: " + name
					filterDetails = "Records filtered to " + name + " (last 90 days)."
					showingFilterSheet = true
				}
			)
		}
		.buttonStyle(.plain)
	}

	@ViewBuilder private var additionsCostCard: some View {
		NavigationLink {
			AdditionsCostDetailView(
				rows: additionsCostByCategory,
				formatCurrency: { functions.formatCurrency(dollars: Float($0)) }
			)
		} label: {
			AdditionsCostCard(
				rows: additionsCostByCategory,
				formatCurrency: { functions.formatCurrency(dollars: Float($0)) }
			)
		}
		.buttonStyle(.plain)
	}

	@ViewBuilder private var inventoryStatusCard: some View {
		let vehicleDisplayName = buildVehicleDisplayNameLookup()
		NavigationLink {
			InventoryStatusDetailView(
				alerts: inventoryAlerts,
				vehicleDisplayName: vehicleDisplayName
			)
		} label: {
			InventoryStatusCard(
				alerts: inventoryAlerts,
				vehicleDisplayName: vehicleDisplayName
			)
		}
		.buttonStyle(.plain)
	}

	@ViewBuilder private func cardView(for card: DashboardCard) -> some View {
		switch card {
		case .maintenanceStatus: maintenanceStatusCard
		case .nextServiceDue: nextServiceDueCard
		case .tripGroups: tripGroupsCard
		case .fleetSnapshot: fleetSnapshotCard
		case .insurance: insuranceCard
		case .warranty: warrantyCard
		case .quickActions: QuickActionsCard(onNavigate: { section in onQuickAction?(section, nil) })
		case .recentService: recentServiceCard
		case .usageSinceLast: usageSinceLastCard
		case .systemHotlist: systemHotlistCard
		case .costSnapshot: costSnapshotCard
		case .additionsCost: additionsCostCard
		case .inventoryStatus: inventoryStatusCard
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
		computeRecurringCosts()
		computeFleetSnapshot()
		computeUsageSinceLastService()
		computeCostSnapshot()
		computeAdditionsCategoryCosts()
		computeWarrantyAlerts()
		computeTripGroups()
		computeInventoryStatus()
	}
}
#Preview("Dashboard – Seeded Data") {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: Vehicle8.self, MxItems3.self, ServiceRecords1.self, Additions.self, configurations: config)
	NavigationStack {
		DashboardView()
			.onAppear {
				let ctx = container.mainContext

				// Jeepster — OVERDUE: oil change 7,000 mi since last, interval 5,000
				let v1 = Vehicle8()
				v1.name = "Jeepster"; v1.displayName = "Jeepster"
				v1.year = 2018; v1.manufacturer = "Jeep"; v1.model = "Wrangler"
				v1.mileage = 22000; v1.engHours = 700
				ctx.insert(v1)
				ctx.insert(MxItems3(createdAt: Date(), updatedAt: Date(), vehicleId: "Jeepster", vehicleSystem: "Engine", mxName: "Oil & Filter Change", mxDescription: "", Notes: "", vendor: "", laborCost: 0, intervalMonths: 0, intervalMiles: 5000, intervalHours: 0, part1: "", part1Id: "", part1Qty: 0, part1cost: 0, part1Unit: "", part2: "", part2Id: "", part2Qty: 0, part2cost: 0, part2Unit: "", part3: "", part3Id: "", part3Qty: 0, part3cost: 0, part3Unit: "", part4: "", part4Id: "", part4Qty: 0, part4cost: 0, part4Unit: "", part5: "", part5Id: "", part5Qty: 0, part5cost: 0, part5Unit: ""))
				ctx.insert(MxItems3(createdAt: Date(), updatedAt: Date(), vehicleId: "Jeepster", vehicleSystem: "Suspension", mxName: "Tire Rotation", mxDescription: "", Notes: "", vendor: "", laborCost: 0, intervalMonths: 0, intervalMiles: 7500, intervalHours: 0, part1: "", part1Id: "", part1Qty: 0, part1cost: 0, part1Unit: "", part2: "", part2Id: "", part2Qty: 0, part2cost: 0, part2Unit: "", part3: "", part3Id: "", part3Qty: 0, part3cost: 0, part3Unit: "", part4: "", part4Id: "", part4Qty: 0, part4cost: 0, part4Unit: "", part5: "", part5Id: "", part5Qty: 0, part5cost: 0, part5Unit: ""))
				ctx.insert(ServiceRecords1(mxDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!, vehicleId: "Jeepster", Miles: 15000, mxName: "Oil & Filter Change"))
				ctx.insert(ServiceRecords1(mxDate: Calendar.current.date(byAdding: .month, value: -2, to: Date())!, vehicleId: "Jeepster", Miles: 18500, mxName: "Tire Rotation"))
				ctx.insert(ServiceRecords1(mxDate: Calendar.current.date(byAdding: .day, value: -10, to: Date())!, vehicleId: "Jeepster", Miles: 21500, mxName: "Brake Inspection"))

				// GMC Truck — DUE SOON: coolant flush 23 months done, interval 24
				let v2 = Vehicle8()
				v2.name = "GMC Truck"; v2.displayName = "GMC Truck"
				v2.year = 2021; v2.manufacturer = "GMC"; v2.model = "Sierra"
				v2.mileage = 38000; v2.engHours = 420
				ctx.insert(v2)
				ctx.insert(MxItems3(createdAt: Date(), updatedAt: Date(), vehicleId: "GMC Truck", vehicleSystem: "Cooling", mxName: "Coolant Flush", mxDescription: "", Notes: "", vendor: "", laborCost: 0, intervalMonths: 24, intervalMiles: 0, intervalHours: 0, part1: "", part1Id: "", part1Qty: 0, part1cost: 0, part1Unit: "", part2: "", part2Id: "", part2Qty: 0, part2cost: 0, part2Unit: "", part3: "", part3Id: "", part3Qty: 0, part3cost: 0, part3Unit: "", part4: "", part4Id: "", part4Qty: 0, part4cost: 0, part4Unit: "", part5: "", part5Id: "", part5Qty: 0, part5cost: 0, part5Unit: ""))
				ctx.insert(MxItems3(createdAt: Date(), updatedAt: Date(), vehicleId: "GMC Truck", vehicleSystem: "Engine", mxName: "Spark Plugs", mxDescription: "", Notes: "", vendor: "", laborCost: 0, intervalMonths: 0, intervalMiles: 30000, intervalHours: 0, part1: "", part1Id: "", part1Qty: 0, part1cost: 0, part1Unit: "", part2: "", part2Id: "", part2Qty: 0, part2cost: 0, part2Unit: "", part3: "", part3Id: "", part3Qty: 0, part3cost: 0, part3Unit: "", part4: "", part4Id: "", part4Qty: 0, part4cost: 0, part4Unit: "", part5: "", part5Id: "", part5Qty: 0, part5cost: 0, part5Unit: ""))
				ctx.insert(ServiceRecords1(mxDate: Calendar.current.date(byAdding: .month, value: -23, to: Date())!, vehicleId: "GMC Truck", Miles: 15000, mxName: "Coolant Flush"))
				ctx.insert(ServiceRecords1(mxDate: Calendar.current.date(byAdding: .year, value: -2, to: Date())!, vehicleId: "GMC Truck", Miles: 10000, mxName: "Spark Plugs"))
				ctx.insert(ServiceRecords1(mxDate: Calendar.current.date(byAdding: .day, value: -21, to: Date())!, vehicleId: "GMC Truck", Miles: 37800, mxName: "Air Filter"))

				// Cargo Trailer — OK: wheel bearings 3,500 mi since, interval 10,000
				let v3 = Vehicle8()
				v3.name = "Trailer"; v3.displayName = "Cargo Trailer"
				v3.year = 2020; v3.manufacturer = "PJ"; v3.model = "Utility"
				v3.mileage = 4500; v3.engHours = 0
				ctx.insert(v3)
				ctx.insert(MxItems3(createdAt: Date(), updatedAt: Date(), vehicleId: "Trailer", vehicleSystem: "Axle", mxName: "Wheel Bearing Grease", mxDescription: "", Notes: "", vendor: "", laborCost: 0, intervalMonths: 0, intervalMiles: 10000, intervalHours: 0, part1: "", part1Id: "", part1Qty: 0, part1cost: 0, part1Unit: "", part2: "", part2Id: "", part2Qty: 0, part2cost: 0, part2Unit: "", part3: "", part3Id: "", part3Qty: 0, part3cost: 0, part3Unit: "", part4: "", part4Id: "", part4Qty: 0, part4cost: 0, part4Unit: "", part5: "", part5Id: "", part5Qty: 0, part5cost: 0, part5Unit: ""))
				ctx.insert(ServiceRecords1(mxDate: Calendar.current.date(byAdding: .month, value: -4, to: Date())!, vehicleId: "Trailer", Miles: 1000, mxName: "Wheel Bearing Grease"))
			}
	}
	.modelContainer(container)
}


