/**
 EditFuelLog.swift
 LandShip
 
 A SwiftUI view for creating, viewing, and editing a single FuelLog1 record.
 
 Responsibilities
 - Presents two primary modes: Details (read-only) and Edit (form inputs).
 - Binds to a FuelLog1 model instance and keeps local @State in sync for editing.
 - Computes fuel-related statistics such as distance and economy since previous fill-up,
   as well as vehicle totals up to and including the current record.
 - Persists changes using SwiftData's ModelContext and updates related Vehicle8 metadata
   (mileage and engine hours) when appropriate.
 
 Key Behaviors
 - Vehicle selection drives unit conversions and capacity-based derived values.
 - Edits remain in local state until Save is tapped, then committed to the model.
 - Deletion and deactivation are supported, with deactivated records excluded from
   calculations unless showInactiveVehicles is enabled.
 
 Dependencies
 - SwiftUI and SwiftData for UI and persistence.
 - Functions and PrefsFunctions utility types for formatting, settings, and lookups.
 - Vehicle8 and FuelLog1 model types.
 
 Data Flow
 - Local @State mirrors fields of FuelLog1 to allow cancelable editing.
 - On Save, state is written back to the bound FuelLog1 and persisted.
 - Helper methods fetch related data (vehicle details, other fuel logs) to compute
   statistics and derived values.
 
 Threading / Performance
 - All operations occur on the main actor via SwiftUI. Fetches are small and scoped
   with predicates and sort descriptors. Heavy work should remain minimal in the UI.
 
 Testing / Preview
 - A preview configuration seeds an in-memory container with a demo vehicle and fuel log
   to exercise both Details and Edit flows.
 
 Modification History
 - Created by JP on 7/20/25.
 - Documentation header and inline comments added to improve maintainability.
 */

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// A view that displays and edits a FuelLog1 entry, including computed statistics
/// derived from other logs of the same vehicle. The view toggles between a read-only
/// details mode and an editable form mode.
struct EditFuelLog: View {
	// MARK: - Model & Environment

	@State private var dataSet: FuelLog1
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) private var dismiss
	let functions: Functions = Functions()
	let prefsFunc: PrefsFunctions = PrefsFunctions()

	// MARK: - User Preferences & Units

	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false

	// Cache settings (units) once; keep access helper simple and safe.
	@State private var units: [String] = Array(repeating: "", count: 13)
	private func unit(_ index: Int) -> String {
		units.indices.contains(index) ? units[index] : ""
	}

	// MARK: - UI State

	@State private var isPresentingConfirm: Bool = false /// for confirmation dialog
	@State private var isEditing: Bool = false
	@State private var showFluidChecks: Bool = false

	// Fuel operations sub-editor sheets. Uplift is unconditional (every vertical); the
	// rest are gated by Vertical.enabledFeatures.fuelOperations — see the launcher cards
	// below. All write directly to `dataSet`, which is Observable via the @Model macro,
	// so cards reading `dataSet.*` update automatically without a manual refresh; only
	// the Uplift sheet's onDismiss recomputes fuel stats, since fillTypeRaw feeds them.
	/// Diverts Save into a rename-cascade confirmation when `logName` changed and
	/// attachments are linked to it by name — see hasLinkedRecords/renameLinkedRecords.
	@State private var showingRenameChoice = false
	@State private var showingUpliftSheet = false
	@State private var showingCostSheet = false
	@State private var showingQualitySheet = false
	@State private var showingPerformanceSheet = false
	@State private var showingLinkageSheet = false

	// MARK: - Fuel Log Fields (@State mirrors FuelLog1)

	@State private var vehicleId: String = ""
	@State private var logName: String = ""
	@State private var fuelNotes: String = ""
	@State private var createdAt: Date = Date()
	@State private var updatedAt: Date = Date()
	@State private var fuelDateTime: Date = Date()
	@State private var fuelExitTime: Date = Date()
	/// "trip name — Stop n" when a travel log links to this record; empty when nothing does.
	@State private var linkedTravelLog: String = ""
	@State private var odometer: Int = 0
	@State private var location: String = ""
	@State private var engHours: Float = 0.0
	@State private var fuelQuantityStart: Float = 0.0
	@State private var fuelQuantityEnd: Float = 0.0
	@State private var fuelAdded: Float = 0.0
	@State private var defAdded: Float = 0.0
	@State private var defPrice: Float = 0.0
	@State private var defLevel1: Float = 0.0
	@State private var defLevelFraction: String = ""
	@State private var defQuantity: Float = 0.0
	@State private var defLevelStart1: Float = 0.0
	@State private var defLevelStartFraction: String = ""
	@State private var defQuantityStart: Float = 0.0
	@State private var oilAdded: Float = 0.0
	// Aviation only — oil added per engine, replacing the single `oilAdded` field above.
	// See `engineComponents` and `oilAddedEngineBinding(slot:)`.
	@State private var oilAddedEngine1: Float = 0.0
	@State private var oilAddedEngine2: Float = 0.0
	@State private var oilAddedEngine3: Float = 0.0
	@State private var oilAddedEngine4: Float = 0.0
	@State private var oilAddedEngine5: Float = 0.0
	@State private var oilAddedEngine6: Float = 0.0
	@State private var deiceFluidAdded: Float = 0.0
	@State private var hydraulicFluidAdded: Float = 0.0
	@State private var brakeFluidAdded: Float = 0.0
	/// This vehicle's `ComponentTimes` engine rows (componentType == "Engine"), ascending by
	/// slot number — see `syncEngineSlots` in EditVehicle.swift for how these are created.
	/// Aviation only; empty on land/marine, which never populate `ComponentTimes`.
	@State private var engineComponents: [ComponentTimes] = []
	@State private var oilChecked: Bool = false
	@State private var engineCoolantChecked: Bool = false
	@State private var secondaryCoolantChecked: Bool = false
	@State private var powerSteeringChecked: Bool = false
	@State private var brakeFluidChecked: Bool = false
	@State private var transmissionFluidChecked: Bool = false
	@State private var rearAxleChecked: Bool = false
	@State private var frontAxleChecked: Bool = false
	@State private var fuelWaterSeparatorChecked: Bool = false
	@State private var airSystemWaterBleedChecked: Bool = false
	/// Aviation/marine fluid checks — see FluidCheckList in 11 Enums.swift. Unused on land.
	@State private var checkedFluidItems: Set<String> = []
	@State private var fuelLevelStart1: Float = 0.0
	@State private var fuelLevelEnd1: Float = 0.0
	@State private var fuelLevelStartFraction: String = ""
	@State private var fuelLevelEndFraction: String = ""
	// Aviation, multi-tank aircraft only — per-tank start/stop level+quantity and fuel
	// added, replacing the single fuelLevelStart1/fuelQuantityStart/fuelAdded/
	// fuelLevelEnd1/fuelQuantityEnd fields above when the vehicle has more than one tank
	// (see vehicleFuelTankCount). Those aggregate fields are then kept in sync as the sum
	// across tanks via recomputeAggregateFuelFromTanks(), so price/cost — which stay
	// single values — and every existing economy calc keep working unchanged.
	@State private var fuelTank1LevelStart1: Float = 0.0
	@State private var fuelTank2LevelStart1: Float = 0.0
	@State private var fuelTank3LevelStart1: Float = 0.0
	@State private var fuelTank4LevelStart1: Float = 0.0
	@State private var fuelTank5LevelStart1: Float = 0.0
	@State private var fuelTank6LevelStart1: Float = 0.0
	@State private var fuelTank1QuantityStart: Float = 0.0
	@State private var fuelTank2QuantityStart: Float = 0.0
	@State private var fuelTank3QuantityStart: Float = 0.0
	@State private var fuelTank4QuantityStart: Float = 0.0
	@State private var fuelTank5QuantityStart: Float = 0.0
	@State private var fuelTank6QuantityStart: Float = 0.0
	@State private var fuelTank1LevelEnd1: Float = 0.0
	@State private var fuelTank2LevelEnd1: Float = 0.0
	@State private var fuelTank3LevelEnd1: Float = 0.0
	@State private var fuelTank4LevelEnd1: Float = 0.0
	@State private var fuelTank5LevelEnd1: Float = 0.0
	@State private var fuelTank6LevelEnd1: Float = 0.0
	@State private var fuelTank1QuantityEnd: Float = 0.0
	@State private var fuelTank2QuantityEnd: Float = 0.0
	@State private var fuelTank3QuantityEnd: Float = 0.0
	@State private var fuelTank4QuantityEnd: Float = 0.0
	@State private var fuelTank5QuantityEnd: Float = 0.0
	@State private var fuelTank6QuantityEnd: Float = 0.0
	@State private var fuelTank1Added: Float = 0.0
	@State private var fuelTank2Added: Float = 0.0
	@State private var fuelTank3Added: Float = 0.0
	@State private var fuelTank4Added: Float = 0.0
	@State private var fuelTank5Added: Float = 0.0
	@State private var fuelTank6Added: Float = 0.0
	@State private var fuelPrice: Float = 0.0
	@State private var fuelCost: Float = 0.0
	@State private var fuelType: String = ""
	@State private var image1: Data?
	@State private var image2: Data?
	@State private var image3: Data?
	@State private var image1Description: String = ""
	@State private var image2Description: String = ""
	@State private var image3Description: String = ""
	@State private var inactive: Bool = false

	// MARK: - Vehicle Context

	// shared vehicle details accessible anywhere in this file
	@State private var vehicleDetails: VehicleDetails? = nil
	@State private var selectedVehicle: Vehicle8? = nil

	// MARK: - Details section visibility

	/// True when at least one image is attached; the graphics card is hidden otherwise
	/// so its section title never appears above an empty card.
	private var hasGraphics: Bool {
		dataSet.image1 != nil || dataSet.image2 != nil || dataSet.image3 != nil
	}

	// MARK: - Fuel operations card gating (edit + details mode share these)

	private var hasUpliftDetail: Bool {
		dataSet.upliftQuantity != 0 || !dataSet.fillTypeRaw.isEmpty || dataSet.density != 0
	}

	private var hasCostDetail: Bool {
		!(dataSet.ticketNumber.isEmpty && dataSet.supplierBrand.isEmpty && dataSet.airportIdentifier.isEmpty
		  && dataSet.fboName.isEmpty && dataSet.postedPricePerUnit == 0 && dataSet.contractPricePerUnit == 0
		  && dataSet.taxFederalExcise == 0 && dataSet.taxState == 0 && dataSet.taxLocal == 0 && dataSet.taxSales == 0
		  && dataSet.feeFlowage == 0 && dataSet.feeIntoPlane == 0 && dataSet.feeRamp == 0 && dataSet.feeHandling == 0
		  && dataSet.feeOvernight == 0 && dataSet.feeFacility == 0 && dataSet.feeAfterHours == 0 && dataSet.feeGPU == 0
		  && dataSet.feeLavService == 0 && dataSet.paymentMethodRaw.isEmpty)
	}

	private var hasQualityDetail: Bool {
		dataSet.sumpCheckPerformed || dataSet.fuelSampleRetained || dataSet.additiveFSII
			|| dataSet.additiveBiocide || dataSet.additiveStaticDissipator || dataSet.safBlendPercent != 0
	}

	private var hasPerformanceDetail: Bool {
		dataSet.plannedBurnKnown || dataSet.taxiFuel != 0 || dataSet.reserveAtLanding != 0
			|| dataSet.burnClimb != 0 || dataSet.burnCruise != 0 || dataSet.burnDescent != 0
	}

	private var hasLinkageDetail: Bool {
		!(dataSet.tripNumber.isEmpty && dataSet.costCenter.isEmpty && dataSet.clientName.isEmpty
		  && dataSet.operatingRuleRaw.isEmpty && !dataSet.billableToCustomer)
	}

	/// Renders fuel data-quality flags as a short caption — mirrors EditParts's
	/// flagsDescription idiom: a flag means the number differs from what a clean
	/// full-to-full reading would give, not that something is wrong.
	private func flagsDescription(_ flags: Set<FuelDataFlag>) -> String {
		var parts: [String] = []
		if flags.contains(.noPriorFullFill) {
			parts.append("No prior full fill found — economy is measured against the nearest available record.")
		}
		if flags.contains(.partialFillInInterval) {
			parts.append("Includes one or more partial fills since the last full tank.")
		}
		return parts.joined(separator: " ")
	}

	// MARK: - Computed Statistics

	// Fuel statistics state
	@State private var hasPreviousFill: Bool = false
	@State private var distanceSinceLast: Int = 0
	@State private var daysSinceLast: Int = 0
	@State private var fuelEconomySince: Float = 0.0
	@State private var costPerDistanceSince: Float = 0.0
	@State private var priceChangePerUnit: Float = 0.0
	/// Data-quality flags from the full-to-full economy gate — see FuelMath.interval.
	@State private var fuelStatsFlags: Set<FuelDataFlag> = []

	@State private var totalDistance: Int = 0
	@State private var totalFuel: Float = 0.0
	@State private var totalCost: Float = 0.0
	@State private var avgEconomy: Float = 0.0
	@State private var avgPricePerUnit: Float = 0.0
	@State private var totalDEFAdded: Float = 0.0
	@State private var totalDEFCost: Float = 0.0
	@State private var avgDEFPrice: Float = 0.0

	// MARK: - Previous Fill Metadata

	// New: last fill-up meta
	@State private var lastFillOdometer: Int = 0
	@State private var lastFillDate: Date? = nil
	
	/// Initializes the edit/detail view for a given FuelLog1 record.
	/// - Parameters:
	///   - dataSet: The backing model instance to display and edit.
	///   - startEditing: Whether the view should open directly in edit mode.
	init(dataSet: FuelLog1, startEditing: Bool = false) {
		// Properly initialize the @State wrapper for dataSet
		self._dataSet = State(initialValue: dataSet)
		
		self._vehicleId = State.init(initialValue: dataSet.vehicleId)
		self._logName = State.init(initialValue: dataSet.logName)
		self._fuelNotes = State.init(initialValue: dataSet.fuelNotes)
		self._createdAt = State.init(initialValue: dataSet.createdAt)
		self._updatedAt = State.init(initialValue: dataSet.updatedAt)
		self._fuelDateTime = State.init(initialValue: dataSet.fuelDateTime)
		self._fuelExitTime = State.init(initialValue: dataSet.fuelExitTime ?? dataSet.fuelDateTime)
		self._odometer = State.init(initialValue: dataSet.odometer)
		self._location = State.init(initialValue: dataSet.location)
		self._engHours = State.init(initialValue: dataSet.engHours)
		self._fuelQuantityStart = State.init(initialValue: dataSet.fuelQuantityStart)
		self._fuelQuantityEnd = State.init(initialValue: dataSet.fuelQuantityEnd)
		self._fuelAdded = State.init(initialValue: dataSet.fuelAdded)
		self._defAdded = State.init(initialValue: dataSet.defAdded)
		self._defPrice = State.init(initialValue: dataSet.defPrice)
		self._defLevel1 = State.init(initialValue: dataSet.defLevel1)
		self._defLevelFraction = State.init(initialValue: dataSet.defLevelFraction)
		self._defQuantity = State.init(initialValue: dataSet.defQuantity)
		self._defLevelStart1 = State.init(initialValue: dataSet.defLevelStart1)
		self._defLevelStartFraction = State.init(initialValue: dataSet.defLevelStartFraction)
		self._defQuantityStart = State.init(initialValue: dataSet.defQuantityStart)
		self._oilAdded = State.init(initialValue: dataSet.oilAdded)
		self._oilAddedEngine1 = State.init(initialValue: dataSet.oilAddedEngine1)
		self._oilAddedEngine2 = State.init(initialValue: dataSet.oilAddedEngine2)
		self._oilAddedEngine3 = State.init(initialValue: dataSet.oilAddedEngine3)
		self._oilAddedEngine4 = State.init(initialValue: dataSet.oilAddedEngine4)
		self._oilAddedEngine5 = State.init(initialValue: dataSet.oilAddedEngine5)
		self._oilAddedEngine6 = State.init(initialValue: dataSet.oilAddedEngine6)
		self._deiceFluidAdded = State.init(initialValue: dataSet.deiceFluidAdded)
		self._hydraulicFluidAdded = State.init(initialValue: dataSet.hydraulicFluidAdded)
		self._brakeFluidAdded = State.init(initialValue: dataSet.brakeFluidAdded)
		self._oilChecked = State.init(initialValue: dataSet.oilChecked)
		self._engineCoolantChecked = State.init(initialValue: dataSet.engineCoolantChecked)
		self._secondaryCoolantChecked = State.init(initialValue: dataSet.secondaryCoolantChecked)
		self._powerSteeringChecked = State.init(initialValue: dataSet.powerSteeringChecked)
		self._brakeFluidChecked = State.init(initialValue: dataSet.brakeFluidChecked)
		self._transmissionFluidChecked = State.init(initialValue: dataSet.transmissionFluidChecked)
		self._rearAxleChecked = State.init(initialValue: dataSet.rearAxleChecked)
		self._frontAxleChecked = State.init(initialValue: dataSet.frontAxleChecked)
		self._fuelWaterSeparatorChecked = State.init(initialValue: dataSet.fuelWaterSeparatorChecked)
		self._airSystemWaterBleedChecked = State.init(initialValue: dataSet.airSystemWaterBleedChecked)
		self._checkedFluidItems = State.init(initialValue: FluidCheckList.unpack(dataSet.checkedFluidItemsPacked))
		self._fuelLevelStart1 = State.init(initialValue: dataSet.fuelLevelStart1)
		self._fuelLevelEnd1 = State.init(initialValue: dataSet.fuelLevelEnd1)
		self._fuelLevelStartFraction = State.init(initialValue: dataSet.fuelLevelStartFraction)
		self._fuelLevelEndFraction = State.init(initialValue: dataSet.fuelLevelEndFraction)
		self._fuelTank1LevelStart1 = State.init(initialValue: dataSet.fuelTank1LevelStart1)
		self._fuelTank2LevelStart1 = State.init(initialValue: dataSet.fuelTank2LevelStart1)
		self._fuelTank3LevelStart1 = State.init(initialValue: dataSet.fuelTank3LevelStart1)
		self._fuelTank4LevelStart1 = State.init(initialValue: dataSet.fuelTank4LevelStart1)
		self._fuelTank5LevelStart1 = State.init(initialValue: dataSet.fuelTank5LevelStart1)
		self._fuelTank6LevelStart1 = State.init(initialValue: dataSet.fuelTank6LevelStart1)
		self._fuelTank1QuantityStart = State.init(initialValue: dataSet.fuelTank1QuantityStart)
		self._fuelTank2QuantityStart = State.init(initialValue: dataSet.fuelTank2QuantityStart)
		self._fuelTank3QuantityStart = State.init(initialValue: dataSet.fuelTank3QuantityStart)
		self._fuelTank4QuantityStart = State.init(initialValue: dataSet.fuelTank4QuantityStart)
		self._fuelTank5QuantityStart = State.init(initialValue: dataSet.fuelTank5QuantityStart)
		self._fuelTank6QuantityStart = State.init(initialValue: dataSet.fuelTank6QuantityStart)
		self._fuelTank1LevelEnd1 = State.init(initialValue: dataSet.fuelTank1LevelEnd1)
		self._fuelTank2LevelEnd1 = State.init(initialValue: dataSet.fuelTank2LevelEnd1)
		self._fuelTank3LevelEnd1 = State.init(initialValue: dataSet.fuelTank3LevelEnd1)
		self._fuelTank4LevelEnd1 = State.init(initialValue: dataSet.fuelTank4LevelEnd1)
		self._fuelTank5LevelEnd1 = State.init(initialValue: dataSet.fuelTank5LevelEnd1)
		self._fuelTank6LevelEnd1 = State.init(initialValue: dataSet.fuelTank6LevelEnd1)
		self._fuelTank1QuantityEnd = State.init(initialValue: dataSet.fuelTank1QuantityEnd)
		self._fuelTank2QuantityEnd = State.init(initialValue: dataSet.fuelTank2QuantityEnd)
		self._fuelTank3QuantityEnd = State.init(initialValue: dataSet.fuelTank3QuantityEnd)
		self._fuelTank4QuantityEnd = State.init(initialValue: dataSet.fuelTank4QuantityEnd)
		self._fuelTank5QuantityEnd = State.init(initialValue: dataSet.fuelTank5QuantityEnd)
		self._fuelTank6QuantityEnd = State.init(initialValue: dataSet.fuelTank6QuantityEnd)
		self._fuelTank1Added = State.init(initialValue: dataSet.fuelTank1Added)
		self._fuelTank2Added = State.init(initialValue: dataSet.fuelTank2Added)
		self._fuelTank3Added = State.init(initialValue: dataSet.fuelTank3Added)
		self._fuelTank4Added = State.init(initialValue: dataSet.fuelTank4Added)
		self._fuelTank5Added = State.init(initialValue: dataSet.fuelTank5Added)
		self._fuelTank6Added = State.init(initialValue: dataSet.fuelTank6Added)
		self._fuelPrice = State.init(initialValue: dataSet.fuelPrice)
		self._fuelCost = State.init(initialValue: dataSet.fuelCost)
		self._fuelType = State.init(initialValue: dataSet.fuelType)
		self._image1 = State.init(initialValue: dataSet.image1)
		self._image2 = State.init(initialValue: dataSet.image2)
		self._image3 = State.init(initialValue: dataSet.image3)
		self._image1Description = State.init(initialValue: dataSet.image1Description)
		self._image2Description = State.init(initialValue: dataSet.image2Description)
		self._image3Description = State.init(initialValue: dataSet.image3Description)
		// Inactive flag
		self._inactive = State.init(initialValue: dataSet.inactive)

		// Start in edit mode if requested
		self._isEditing = State(initialValue: startEditing)
	}
	
	/// The main view which conditionally presents either the edit form or the
	/// read-only details, including fuel statistics and images.
	var body: some View {
		if isEditing {
			ScrollView {
				CardView {
					VStack {

						LabeledContent {
							ModelPicker(
								selection: $selectedVehicle,
								title: Vertical.current.assetSingular,
								includeEmptyChoice: false,
								emptyChoiceLabel: "—",
								autoSelectFirst: false,
								filter: nil,
								sort: [SortDescriptor(\.displayName, order: .forward)],
								labelProvider: { v in "\(v.year) \(v.displayName)"},
								thumbnailData: { $0.image1 }
							)
							.onChange(of: selectedVehicle) { oldVehicle, newVehicle in
								let name = newVehicle?.name ?? ""
								vehicleId = name
								// keep dataSet in sync while editing so detail calculations reflect the change
								dataSet.vehicleId = name
								refreshVehicleDetails()
								loadEngineComponents()
								// Rescale the tanks only when the vehicle genuinely changed. Seeding this picker on
								// appear also fires this handler, and rescaling then would replace exact typed
								// quantities with their eighths equivalents.
								if let previous = oldVehicle, previous.name != name {
									recomputeFuelQuantities()
								}
								computeFuelStats()
							}
							.fixedSize(horizontal: true, vertical: true)
						} label: {
							Text(Vertical.current.assetSingular)
								.textLabelModified()
						}

						HStack{
							LabelDataPicker_DateTime(label: Vertical.current.id == .aviation ? "Arrival Time                 " : "Date/Time                    ", data: $fuelDateTime)
							// Prime units, vehicle details, and initial stats when the edit view appears.
								.onAppear {
									loadUnitsIfNeeded()
									refreshVehicleDetails()
									loadEngineComponents()
									syncFieldsFromRecord()
									backfillDefQuantity()
									// The stored quantities may be typed exact figures, so they are left as loaded.
									fuelLevelStartFraction = functions.getFuelLevel(unit: fuelLevelStart1)
									computeFuelStats()
								}
							// Recompute statistics when the fueling date/time changes.
								.onChange(of: fuelDateTime) { _, _ in
									computeFuelStats()
								}
						}
						
						HStack{LabelDataPicker_DateTime(label: Vertical.current.id == .aviation ? "Departure Time               " : "Exit Time                    ", data: $fuelExitTime, notEarlierThan: fuelDateTime)}

						HStack{LabelDataTextview(label: "Log Name", data: $logName)}
						
						HStack{LabelLocationTextview(label: "Location", data: $location)}
						
						if Vertical.current.visibleFieldGroups.contains(.odometer) {
							HStack{LabelDataTextview_Numberpad_Int(label: Vertical.current.distanceMeterLabel, data: $odometer)}
							// Keep distance/economy up to date when odometer changes.
								.onChange(of: odometer) { _, _ in
									computeFuelStats()
								}
						}
						HStack{LabelDataTextview_Numberpad_Float(label: Vertical.current.hoursMeterLabel, data: $engHours)}
						HStack{
							Text("Fuel Type")
								.textLabelModified()
							Picker("", selection: $fuelType) {
								FuelTypePickerOptions(currentValue: fuelType)
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						FuelTypePickerNote()
					}
					}

					CardView {
						VStack {
							SectionText(label: "FUEL ADDED & COST")
						if vehicleFuelTankCount > 1 {
							// Multi-tank aircraft — one Level Start/Added/Level End group per tank,
							// named from Edit Vehicle. The aggregate fuelQuantityStart/fuelQuantityEnd/
							// fuelAdded fields are kept in sync as the sum (recomputeAggregateFuelFromTanks),
							// so Price/Cost below stay single fields fed by that sum.
							ForEach(1...vehicleFuelTankCount, id: \.self) { tankNumber in
								VStack(alignment: .leading, spacing: 6) {
									Text(fuelTankName(tankNumber))
										.font(.subheadline).fontWeight(.semibold)
									HStack {
										Picker_FuelLevel1(label: "Level Start", data: tankLevelStartBinding(tankNumber), data1: fuelTankCapacity(tankNumber), quantity: tankQuantityStartBinding(tankNumber))
									}
									.onChange(of: tankLevelStartBinding(tankNumber).wrappedValue) { _, newFraction in
										tankQuantityStartBinding(tankNumber).wrappedValue = fuelTankCapacity(tankNumber) * newFraction
										recomputeAggregateFuelFromTanks()
									}
									.onChange(of: tankQuantityStartBinding(tankNumber).wrappedValue) { _, _ in
										recomputeAggregateFuelFromTanks()
									}
									HStack {
										LabelDataTextview_Numberpad_Float(label: "Added (\(unit(UnitIndex.fuel)))", data: tankAddedBinding(tankNumber))
									}
									.onChange(of: tankAddedBinding(tankNumber).wrappedValue) { _, _ in
										recomputeAggregateFuelFromTanks()
									}
									HStack {
										Picker_FuelLevel1(label: "Level End", data: tankLevelEndBinding(tankNumber), data1: fuelTankCapacity(tankNumber), quantity: tankQuantityEndBinding(tankNumber))
									}
									.onChange(of: tankLevelEndBinding(tankNumber).wrappedValue) { _, newFraction in
										tankQuantityEndBinding(tankNumber).wrappedValue = fuelTankCapacity(tankNumber) * newFraction
										recomputeAggregateFuelFromTanks()
									}
									.onChange(of: tankQuantityEndBinding(tankNumber).wrappedValue) { _, _ in
										recomputeAggregateFuelFromTanks()
									}
								}
								.padding(.vertical, 4)
							}
						} else {
							HStack{
								Picker_FuelLevel1(label: "Fuel Level Start", data: $fuelLevelStart1, data1: Float(vehicleDetails?.fuelCapacity ?? 0), quantity: $fuelQuantityStart)
							}
							// Choosing an eighth fills in the quantity; a typed quantity is left alone and
							// reconciled back to the nearest eighth on save.
							.onChange(of: fuelLevelStart1) {_, newFraction in
								fuelLevelStartFraction = functions.getFuelLevel(unit: newFraction)
								fuelQuantityStart = Float(vehicleDetails?.fuelCapacity ?? 0) * newFraction
								recalcFuelEndFromAdded()
							}
							HStack{
								LabelDataTextview_Numberpad_Float(label: "Fuel Added (\(unit(UnitIndex.fuel)))", data: $fuelAdded)
								// Maintain total cost, the end level, and dependent stats as the amount added changes.
									.onChange(of: fuelAdded) {_, _ in
										fuelCost = fuelPrice * fuelAdded
										recalcFuelEndFromAdded()
										computeFuelStats()
									}
							}
						}
						HStack{
							LabelDataTextview_Numberpad_Currency(label: "Price/\(unit(UnitIndex.fuel))", data: $fuelPrice)
							// Maintain total cost and dependent stats as price changes.
								.onChange(of: fuelPrice) {_, _ in
									fuelCost = fuelPrice * fuelAdded
									computeFuelStats()
								}
						}
						HStack{
							LabelDataTextview_Numberpad_Currency(label: "Cost", data: $fuelCost)
							// Update dependent stats when total cost changes.
								.onChange(of: fuelCost) { _, _ in
									computeFuelStats()
								}
						}
						if vehicleFuelTankCount <= 1 {
							HStack{
								Picker_FuelLevel1(label: "Fuel Level End", data: $fuelLevelEnd1, data1: Float(vehicleDetails?.fuelCapacity ?? 0), quantity: $fuelQuantityEnd)
							}
							.onChange(of: fuelLevelEnd1) {_, newFraction in
								fuelLevelEndFraction = functions.getFuelLevel(unit: newFraction)
								fuelQuantityEnd = Float(vehicleDetails?.fuelCapacity ?? 0) * newFraction
							}
						}
					}
					}

					CardView {
						VStack {
							SectionText(label: "FLUIDS ADDED")
						if Vertical.current.id == .aviation {
							if engineComponents.isEmpty {
								HStack{LabelDataTextview_Numberpad_Float(label: "Engine Oil Added (\(unit(UnitIndex.oil)))", data: $oilAddedEngine1)}
							} else {
								ForEach(Array(engineComponents.enumerated()), id: \.element.persistentModelID) { index, engine in
									let slot = engineSlotNumber(engine, fallback: index + 1)
									HStack{LabelDataTextview_Numberpad_Float(label: oilAddedLabel(for: engine), data: oilAddedEngineBinding(slot: slot))}
								}
							}
							HStack{LabelDataTextview_Numberpad_Float(label: "Deice Fluid Added (\(unit(UnitIndex.oil)))", data: $deiceFluidAdded)}
							HStack{LabelDataTextview_Numberpad_Float(label: "Hydraulic Fluid Added (\(unit(UnitIndex.oil)))", data: $hydraulicFluidAdded)}
							HStack{LabelDataTextview_Numberpad_Float(label: "Brake Fluid Added (\(unit(UnitIndex.oil)))", data: $brakeFluidAdded)}
						} else {
							HStack{LabelDataTextview_Numberpad_Float(label: "Oil Added (\(unit(UnitIndex.oil)))", data: $oilAdded)}
						}
						// DEF only applies to a diesel vehicle, so its fields stay hidden for anything else.
						if isDieselFamilyFuelType(fuelType) {
							HStack{
								Picker_FuelLevel1(label: "DEF Level Start", data: $defLevelStart1, data1: Float(vehicleDetails?.defCapacity ?? 0), quantity: $defQuantityStart)
									.onChange(of: defLevelStart1) { _, newFraction in
										defQuantityStart = Float(vehicleDetails?.defCapacity ?? 0) * newFraction
										defLevelStartFraction = functions.getFuelLevel(unit: newFraction)
										recalcDefEndFromAdded()
									}
							}
							HStack{
								LabelDataTextview_Numberpad_Float(label: "DEF Added (\(unit(UnitIndex.def)))", data: $defAdded)
									.onChange(of: defAdded) { _, _ in
										recalcDefEndFromAdded()
									}
							}
							HStack{LabelDataTextview_Numberpad_Currency(label: "DEF Price/\(unit(UnitIndex.def))", data: $defPrice)}
							HStack{
								Picker_FuelLevel1(label: "DEF Level End", data: $defLevel1, data1: Float(vehicleDetails?.defCapacity ?? 0), quantity: $defQuantity)
									.onChange(of: defLevel1) { _, newFraction in
										defQuantity = Float(vehicleDetails?.defCapacity ?? 0) * newFraction
										defLevelFraction = functions.getFuelLevel(unit: newFraction)
									}
							}
						}
						HStack {
							Button {
								showFluidChecks = true
							} label: {
								Label(fluidChecksTitle, systemImage: "drop.circle")
							}
							.buttonStyle(.bordered)
							Spacer()
						}
						.sheet(isPresented: $showFluidChecks) {
							if Vertical.current.id == .land {
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
									airSystemWaterBleedChecked: $airSystemWaterBleedChecked
								)
							} else {
								FluidCheckSheet(checkedItems: $checkedFluidItems)
							}
						}
						.sheet(isPresented: $showingUpliftSheet, onDismiss: computeFuelStats) {
							EditFuelUplift(log: dataSet)
						}
						.sheet(isPresented: $showingCostSheet) {
							EditFuelCost(log: dataSet)
						}
						.sheet(isPresented: $showingQualitySheet) {
							EditFuelQuality(log: dataSet)
						}
						.sheet(isPresented: $showingPerformanceSheet) {
							EditFuelPerformance(log: dataSet)
						}
						.sheet(isPresented: $showingLinkageSheet) {
							EditFuelLinkage(log: dataSet)
						}
					}
					}

					CardView {
						VStack {
						CardView {
							TextFieldNote_FullWidth_3lines(sectionText: "FUEL LOG NOTES", prompt: "Enter notes...", data: $fuelNotes)
						}

						// Uplift & units — unconditional across all verticals.
						CardView {
							VStack(alignment: .leading, spacing: 8) {
								HStack {
									SectionText(label: "UPLIFT & UNITS")
									Spacer()
									Button { showingUpliftSheet = true } label: { Image(systemName: "pencil.circle") }
										.buttonStyle(.plain)
								}
								if !hasUpliftDetail {
									Text("Not set.").font(.subheadline).foregroundStyle(.secondary)
								} else {
									if dataSet.upliftQuantity != 0 {
										HStack{LabelDataText(label: "Uplift", data: "\(dataSet.upliftQuantity.formatted(.number.precision(.fractionLength(1)))) \(dataSet.upliftUnitRaw)")}
									}
									if !dataSet.fillTypeRaw.isEmpty {
										HStack{LabelDataText(label: "Fill Type", data: dataSet.fillTypeRaw)}
									}
									if dataSet.density != 0 {
										HStack{LabelDataText(label: "Density", data: "\(dataSet.density.formatted(.number.precision(.fractionLength(2)))) \(dataSet.densityUnitRaw)")}
									}
								}
							}
						}

						// Cost stack, quality, performance, and linkage — AeroTrax only for now.
						if Vertical.current.enabledFeatures.contains(.fuelOperations) {
							CardView {
								VStack(alignment: .leading, spacing: 8) {
									HStack {
										SectionText(label: "COST & CONTRACT FUEL")
										Spacer()
										Button { showingCostSheet = true } label: { Image(systemName: "pencil.circle") }
											.buttonStyle(.plain)
									}
									if !hasCostDetail {
										Text("Not set.").font(.subheadline).foregroundStyle(.secondary)
									} else {
										if !dataSet.ticketNumber.isEmpty {
											HStack{LabelDataText(label: "Ticket Number", data: dataSet.ticketNumber)}
										}
										if !dataSet.supplierBrand.isEmpty {
											HStack{LabelDataText(label: "Supplier / Brand", data: dataSet.supplierBrand)}
										}
										if dataSet.contractPricePerUnit != 0 {
											HStack{LabelDataText(label: "Contract Release", data: dataSet.contractReleaseNumber)}
										}
									}
								}
							}

							CardView {
								VStack(alignment: .leading, spacing: 8) {
									HStack {
										SectionText(label: "FUEL QUALITY")
										Spacer()
										Button { showingQualitySheet = true } label: { Image(systemName: "pencil.circle") }
											.buttonStyle(.plain)
									}
									if !hasQualityDetail {
										Text("Not set.").font(.subheadline).foregroundStyle(.secondary)
									} else {
										if dataSet.sumpCheckPerformed {
											HStack{LabelDataText(label: "Sump Check", data: dataSet.sumpCheckResultRaw.isEmpty ? "Performed" : dataSet.sumpCheckResultRaw)}
										}
										if dataSet.safBlendPercent != 0 {
											HStack{LabelDataText(label: "SAF Blend", data: "\(dataSet.safBlendPercent.formatted(.number.precision(.fractionLength(0))))%")}
										}
									}
								}
							}

							CardView {
								VStack(alignment: .leading, spacing: 8) {
									HStack {
										SectionText(label: "PERFORMANCE")
										Spacer()
										Button { showingPerformanceSheet = true } label: { Image(systemName: "pencil.circle") }
											.buttonStyle(.plain)
									}
									if !hasPerformanceDetail {
										Text("Not set.").font(.subheadline).foregroundStyle(.secondary)
									} else {
										if dataSet.plannedBurnKnown {
											HStack{LabelDataText(label: "Planned Burn", data: "\(dataSet.plannedBurn.formatted(.number.precision(.fractionLength(1))))")}
										}
									}
								}
							}

							CardView {
								VStack(alignment: .leading, spacing: 8) {
									HStack {
										SectionText(label: "LINKAGE")
										Spacer()
										Button { showingLinkageSheet = true } label: { Image(systemName: "pencil.circle") }
											.buttonStyle(.plain)
									}
									if !hasLinkageDetail {
										Text("Not set.").font(.subheadline).foregroundStyle(.secondary)
									} else {
										if !dataSet.tripNumber.isEmpty {
											HStack{LabelDataText(label: "Trip / Mission Number", data: dataSet.tripNumber)}
										}
										if !dataSet.clientName.isEmpty {
											HStack{LabelDataText(label: "Client", data: dataSet.clientName)}
										}
									}
								}
							}
						}

						CardView {
							AttachmentsSection(ownerType: "FuelLog1", ownerKey: dataSet.logName)
						}

						CardView {
							VStack {
#if os(macOS)
								SectionText(label: "FUEL GRAPHICS")
#elseif os(iOS)
								SectionText(label: "  FUEL GRAPHICS\n(Click Image to Change)")
#endif
								HStack {Image_Edit(label: "1", imageData: $image1, imageDescription: $image1Description)}
								HStack {Image_Edit(label: "2", imageData: $image2, imageDescription: $image2Description)}
								HStack {Image_Edit(label: "3", imageData: $image3, imageDescription: $image3Description)}
							}
						}
						CardView {
							VStack {
								SectionText(label: "STATUS")
								HStack{LabelDataToggle(label: "Deactivate Fuel Log Record", data: $inactive)}
								Text("When selected, this record is marked as inactive. It will be hidden in lists and pickers, but its data remains available for viewing and editing, and can be un-hidden by selecting 'View Inactive' on the 'Settings' screen.")
									.font(.caption)
									.foregroundStyle(.secondary)
									.frame(maxWidth: .infinity, alignment: .leading)
							}
						}
					}
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			// title area
			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "edit",
					dbRecord: "fuel log")
			}

			.onAppear {
				loadUnitsIfNeeded()
				// Seed vehicle picker from existing vehicleId
				if selectedVehicle == nil, !vehicleId.isEmpty {
					let name = vehicleId
					var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == name })
					fd.fetchLimit = 1
					if let v = try? modelContext.fetch(fd).first {
						selectedVehicle = v
					}
				}
				refreshVehicleDetails()
				computeFuelStats()
			}
			.toolbar {
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "Cancel" : "Edit") {
						// Cancelling drops any in-progress edits, so reload from the record.
						if isEditing { syncFieldsFromRecord() }
						isEditing.toggle()
					}
						.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("Save") {
						// End editing so any field the user was still typing in writes its value to the
						// binding before it is read below.
						commitPendingTextEdits()
						// Give the field one run-loop turn to publish its committed value into @State,
						// then persist and leave edit mode.
						DispatchQueue.main.async {
							let oldName = dataSet.logName
							if oldName != logName && hasLinkedRecords(oldName) {
								showingRenameChoice = true
							} else {
								updateItem()
								isEditing = false
							}
						}
					}
					.buttonStyle(GrowingButton(buttonColor: Color.red))
					.confirmationDialog(
						"Fuel Log Name Changed",
						isPresented: $showingRenameChoice,
						titleVisibility: .visible
					) {
						Button("Update Linked Attachments") {
							renameLinkedRecords(from: dataSet.logName, to: logName)
							updateItem()
							isEditing = false
						}
						Button("Save Without Updating Links", role: .destructive) {
							updateItem()
							isEditing = false
						}
						Button("Cancel", role: .cancel) { }
					} message: {
						Text("Renaming \"\(dataSet.logName)\" to \"\(logName)\" will break its link to any attachments unless they're updated to the new name. Update them now?")
					}
				}
			}

		} else {

			ScrollView {
				VStack{CreatedUpdatedText(created: createdAt, updated: updatedAt)}
				CardView {
					VStack {
						SectionText(label: "\(Vertical.current.assetSingular.uppercased()) / LOCATION DETAILS")
							.onAppear {
								loadUnitsIfNeeded()
								// Needed for vehicleFuelTankCount/fuelTankName/fuelTankCapacity below —
								// details mode never touches the vehicle picker, so this doesn't get
								// seeded by its onChange handler the way edit mode's does.
								if selectedVehicle == nil, !vehicleId.isEmpty {
									let name = vehicleId
									var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == name })
									fd.fetchLimit = 1
									if let v = try? modelContext.fetch(fd).first {
										selectedVehicle = v
									}
								}
								refreshVehicleDetails()
								loadEngineComponents()
								computeFuelStats()
								linkedTravelLog = linkedTravelLogSummary()
							}
						HStack{LabelDataText(label: Vertical.current.assetSingular, data: Functions().getVehicleDisplayName(vehicleId: dataSet.vehicleId, context: modelContext))}
						HStack{LabelDataText(label: Vertical.current.id == .aviation ? "Arrival Time" : "Date/Time", data: "\(functions.formatDate_DDMMMyy_HHmm(date:dataSet.fuelDateTime))")}
						if let exit = dataSet.fuelExitTime, exit > dataSet.fuelDateTime {
							HStack{LabelDataText(label: Vertical.current.id == .aviation ? "Departure Time" : "Exit Time", data: "\(functions.formatDate_DDMMMyy_HHmm(date: exit))")}
						}
						HStack{LabelDataText(label: "Log Name", data: "\(dataSet.logName)")}
						if !linkedTravelLog.isEmpty {
							HStack{LabelDataText(label: "Travel Log", data: linkedTravelLog)}
						}
						if dataSet.location != "" {
							HStack{LabelDataText(label: "Location", data: "\(dataSet.location)")}
						}
						if Vertical.current.visibleFieldGroups.contains(.odometer) {
							HStack{LabelDataText(label: Vertical.current.distanceMeterLabel, data: "\(dataSet.odometer) \(unit(UnitIndex.distance))")}
						}
						if dataSet.engHours > 0 {
							HStack{LabelDataNumber(label: "\(Vertical.current.hoursMeterLabel):", data: dataSet.engHours, fractionalLength: 1)}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "FUELING DETAILS")
						HStack{LabelDataText(label: "Fuel Type", data: "\(dataSet.fuelType)")}
					}
				}

				CardView {
					VStack {
						SectionText(label: "FUEL ADDED & COST")
						if vehicleFuelTankCount > 1 {
							ForEach(1...vehicleFuelTankCount, id: \.self) { tankNumber in
								let capacity = fuelTankCapacity(tankNumber)
								let startQty = tankQuantityStartValue(tankNumber)
								let endQty = tankQuantityEndValue(tankNumber)
								let added = tankAddedValue(tankNumber)
								if capacity > 0 || startQty > 0 || endQty > 0 || added > 0 {
									VStack(alignment: .leading, spacing: 2) {
										Text(fuelTankName(tankNumber))
											.font(.subheadline).fontWeight(.semibold)
										HStack{LabelDataText(label: "Level Start", data: "\(startQty.formatted(.number.precision(.fractionLength(1)))) \(unit(UnitIndex.fuel)) \(functions.getFuelLevel(unit: tankLevelStartBinding(tankNumber).wrappedValue))")}
										if added > 0 {
											HStack{LabelDataNumber(label: "Added (\(unit(UnitIndex.fuel)))", data: added, fractionalLength: 1)}
										}
										HStack{LabelDataText(label: "Level End", data: "\(endQty.formatted(.number.precision(.fractionLength(1)))) \(unit(UnitIndex.fuel)) \(functions.getFuelLevel(unit: tankLevelEndBinding(tankNumber).wrappedValue))")}
									}
									.padding(.vertical, 2)
								}
							}
						} else {
							if dataSet.fuelLevelStartFraction != "" {
								HStack{LabelDataText(label: "Fuel Level Start", data: "\(fuelQuantityStartForDisplay.formatted(.number.precision(.fractionLength(1)))) \(unit(UnitIndex.fuel)) \(dataSet.fuelLevelStartFraction)")}
							}
							if dataSet.fuelLevelEndFraction != "" {
								HStack{LabelDataText(label: "Fuel Level End", data: "\(fuelQuantityEndForDisplay.formatted(.number.precision(.fractionLength(1)))) \(unit(UnitIndex.fuel)) \(dataSet.fuelLevelEndFraction)")}
							}
						}
						HStack{LabelDataCurrency(label: "Price/\(unit(UnitIndex.fuel))", data: dataSet.fuelPrice, unit: "/ \(unit(UnitIndex.fuel))")}
						HStack{LabelDataNumber(label: "Fuel Added (\(unit(UnitIndex.fuel)))", data: dataSet.fuelAdded, fractionalLength: 1)}
						HStack{LabelDataCurrency(label: "Cost", data: dataSet.fuelCost, unit: "")}
					}
				}

				CardView {
					VStack {
						SectionText(label: "FLUIDS ADDED")
						if Vertical.current.id == .aviation {
							if engineComponents.isEmpty {
								if dataSet.oilAddedEngine1 > 0.0 {
									HStack{LabelDataNumber(label: "Engine Oil Added (\(unit(UnitIndex.oil)))", data: dataSet.oilAddedEngine1, fractionalLength: 1)}
								}
							} else {
								ForEach(Array(engineComponents.enumerated()), id: \.element.persistentModelID) { index, engine in
									let slot = engineSlotNumber(engine, fallback: index + 1)
									let amount = oilAddedEngineValue(slot: slot)
									if amount > 0.0 {
										HStack{LabelDataNumber(label: oilAddedLabel(for: engine), data: amount, fractionalLength: 1)}
									}
								}
							}
							if dataSet.deiceFluidAdded > 0.0 {
								HStack{LabelDataNumber(label: "Deice Fluid Added (\(unit(UnitIndex.oil)))", data: dataSet.deiceFluidAdded, fractionalLength: 1)}
							}
							if dataSet.hydraulicFluidAdded > 0.0 {
								HStack{LabelDataNumber(label: "Hydraulic Fluid Added (\(unit(UnitIndex.oil)))", data: dataSet.hydraulicFluidAdded, fractionalLength: 1)}
							}
							if dataSet.brakeFluidAdded > 0.0 {
								HStack{LabelDataNumber(label: "Brake Fluid Added (\(unit(UnitIndex.oil)))", data: dataSet.brakeFluidAdded, fractionalLength: 1)}
							}
						} else if dataSet.oilAdded > 0.0 {
							HStack{LabelDataNumber(label: "Oil Added (\(unit(UnitIndex.oil)))", data: dataSet.oilAdded, fractionalLength: 1)}
						}
						if dataSet.defAdded > 0.0 {
							HStack{LabelDataNumber(label: "DEF Added (\(unit(UnitIndex.def)))", data: dataSet.defAdded, fractionalLength: 1)}
							if dataSet.defPrice > 0.0 {
								HStack{LabelDataCurrency(label: "DEF Price/\(unit(UnitIndex.def))", data: dataSet.defPrice, unit: "")}
								// DEF cost isn't stored — it's the amount added times its price, as fuel Cost is.
								HStack{LabelDataCurrency(label: "DEF Cost", data: dataSet.defAdded * dataSet.defPrice, unit: "")}
							}
						}
						if dataSet.defLevelStartFraction != "" {
							HStack{LabelDataText(label: "DEF Level Start", data: "\(defQuantityStartForDisplay.formatted(.number.precision(.fractionLength(1)))) \(unit(UnitIndex.def)) \(dataSet.defLevelStartFraction)")}
						}
						if dataSet.defLevelFraction != "" {
							HStack{LabelDataText(label: "DEF Level End", data: "\(defQuantityForDisplay.formatted(.number.precision(.fractionLength(1)))) \(unit(UnitIndex.def)) \(dataSet.defLevelFraction)")}
						}
					}
				}

				let checkedFluidNames: [String] = Vertical.current.id == .land
					? [
						("Engine Oil", dataSet.oilChecked),
						("Engine Coolant", dataSet.engineCoolantChecked),
						("Secondary Coolant", dataSet.secondaryCoolantChecked),
						("Power Steering", dataSet.powerSteeringChecked),
						("Brake", dataSet.brakeFluidChecked),
						("Transmission", dataSet.transmissionFluidChecked),
						("Rear Axle", dataSet.rearAxleChecked),
						("Front Axle", dataSet.frontAxleChecked),
						("Fuel/Water Separator", dataSet.fuelWaterSeparatorChecked),
						("Air System Water Bleed", dataSet.airSystemWaterBleedChecked)
					].filter { $0.1 }.map { $0.0 }
					: FluidCheckList.currentLabels.filter { FluidCheckList.unpack(dataSet.checkedFluidItemsPacked).contains($0) }
				if !checkedFluidNames.isEmpty {
					CardView {
						VStack {
							SectionText(label: "FLUID CHECKS")
							ForEach(checkedFluidNames, id: \.self) { name in
								HStack { LabelDataText(label: name, data: "Checked") }
							}
						}
					}
				}

				if dataSet.fuelNotes != "" {CardView {
					TextNoteDisplay_FullWidth(sectionText: "FUEL LOG NOTES", data: dataSet.fuelNotes)}
				}

				CardView {
					VStack {
						SectionText(label: "STATISTICS SINCE PREVIOUS FUELING")
							.onAppear {
								computeFuelStats()
							}

						// Since last fill-up
						if hasPreviousFill {
							// New rows: previous odometer and date
							if let lastDate = lastFillDate {
								HStack{LabelDataText(label: "Previous Date", data: "\(functions.formatDate_DDMMMyy_HHmm(date: lastDate))")}
								HStack{LabelDataText(label: "Days Since Previous", data: "\(daysSinceLast)")}
							}
							HStack{LabelDataText(label: "Current Odometer", data: "\(dataSet.odometer)")}
							HStack{LabelDataText(label: "Previous Odometer", data: "\(lastFillOdometer)")}
							HStack{LabelDataText(label: "Distance (\(unit(UnitIndex.distance)))", data: "\(distanceSinceLast)")}
							HStack{LabelDataNumber(label: "Fuel Used (\(unit(UnitIndex.fuel)))", data: dataSet.fuelAdded, fractionalLength: 1)}
							let ecoSince = fuelEconomySince
							HStack{LabelDataText(label: "Fuel Economy (\(unit(UnitIndex.distance))/\(unit(UnitIndex.fuel)))", data: "\(ecoSince.formatted(.number.precision(.fractionLength(1))))")}
							HStack{LabelDataCurrency(label: "Cost per \(unit(UnitIndex.distance))", data: costPerDistanceSince, unit: "")}
							HStack{LabelDataCurrency(label: "Price Change", data: priceChangePerUnit, unit: "")}
							if !fuelStatsFlags.isEmpty {
								Text(flagsDescription(fuelStatsFlags))
									.font(.caption)
									.foregroundStyle(.orange)
									.frame(maxWidth: .infinity, alignment: .leading)
							}
						} else {
							HStack{LabelDataText(label: "Distance", data: "N/A")}
							HStack{LabelDataNumber(label: "Fuel Used (\(unit(UnitIndex.fuel)))", data: dataSet.fuelAdded, fractionalLength: 1)}
							let ecoSince = dataSet.fuelAdded > 0 ? 0.0 : 0.0
							HStack{LabelDataText(label: "Fuel Economy \(unit(UnitIndex.distance))/\(unit(UnitIndex.fuel))", data: "\(ecoSince.formatted(.number.precision(.fractionLength(1))))")}
						}

						// Totals up to this record for this vehicle
						SectionText(label: "\(Vertical.current.assetSingular.uppercased()) TOTALS")
						Text("Totals are calculated from all fuel logs that have been created for this \(Vertical.current.assetSingular.lowercased()) up to and including the current fuel log.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .center)
						HStack{LabelDataText(label: "Distance (\(unit(UnitIndex.distance)))", data: "\(max(0,totalDistance))")}
						HStack{LabelDataNumber(label: "Fuel (\(unit(UnitIndex.fuel)))", data: totalFuel, fractionalLength: 1)}
						let avgEco = avgEconomy
						HStack{LabelDataText(label: "Average \(unit(UnitIndex.distance))/\(unit(UnitIndex.fuel))", data: "\(avgEco.formatted(.number.precision(.fractionLength(1))))")}
						HStack{LabelDataCurrency(label: "Fuel Cost", data: totalCost, unit: "")}
						HStack{LabelDataCurrency(label: "Avg Price/\(unit(UnitIndex.fuel))", data: avgPricePerUnit, unit: "")}
						if isDieselFamilyFuelType(dataSet.fuelType) {
							HStack{LabelDataNumber(label: "DEF Total (\(unit(UnitIndex.def)))", data: totalDEFAdded, fractionalLength: 1)}
							HStack{LabelDataCurrency(label: "DEF Cost", data: totalDEFCost, unit: "")}
							HStack{LabelDataCurrency(label: "Avg DEF Price/\(unit(UnitIndex.def))", data: avgDEFPrice, unit: "")}
						}
					}
				}

				// Fuel operations summary — hidden when nothing has been recorded, mirroring
				// how the compliance cards in EditParts.swift behave in display mode.
				if hasUpliftDetail {
					CardView {
						VStack {
							SectionText(label: "UPLIFT & UNITS")
							if dataSet.upliftQuantity != 0 {
								HStack{LabelDataText(label: "Uplift", data: "\(dataSet.upliftQuantity.formatted(.number.precision(.fractionLength(1)))) \(dataSet.upliftUnitRaw)")}
							}
							if !dataSet.fillTypeRaw.isEmpty {
								HStack{LabelDataText(label: "Fill Type", data: dataSet.fillTypeRaw)}
							}
							if dataSet.density != 0 {
								HStack{LabelDataText(label: "Density", data: "\(dataSet.density.formatted(.number.precision(.fractionLength(2)))) \(dataSet.densityUnitRaw)")}
							}
							if dataSet.fobBeforeKnown {
								HStack{LabelDataText(label: "FOB Before", data: "\(dataSet.fobBefore.formatted(.number.precision(.fractionLength(1)))) \(dataSet.fobUnitRaw)")}
							}
							if dataSet.fobAfterKnown {
								HStack{LabelDataText(label: "FOB After", data: "\(dataSet.fobAfter.formatted(.number.precision(.fractionLength(1)))) \(dataSet.fobUnitRaw)")}
							}
						}
					}
				}

				if Vertical.current.enabledFeatures.contains(.fuelOperations) {
					if hasCostDetail {
						CardView {
							VStack {
								SectionText(label: "COST & CONTRACT FUEL")
								if !dataSet.ticketNumber.isEmpty {
									HStack{LabelDataText(label: "Ticket Number", data: dataSet.ticketNumber)}
								}
								if !dataSet.supplierBrand.isEmpty {
									HStack{LabelDataText(label: "Supplier / Brand", data: dataSet.supplierBrand)}
								}
								if !dataSet.airportIdentifier.isEmpty {
									HStack{LabelDataText(label: "Airport", data: dataSet.airportIdentifier)}
								}
								if !dataSet.fboName.isEmpty {
									HStack{LabelDataText(label: "FBO", data: dataSet.fboName)}
								}
								if dataSet.postedPricePerUnit != 0 {
									HStack{LabelDataCurrency(label: "Posted Price", data: dataSet.postedPricePerUnit, unit: "")}
								}
								if dataSet.contractPricePerUnit != 0 {
									HStack{LabelDataCurrency(label: "Contract Price", data: dataSet.contractPricePerUnit, unit: "")}
									let savings = FuelMath.costBreakdown(dataSet).contractSavings
									if savings > 0 {
										HStack{LabelDataCurrency(label: "Contract Savings", data: savings, unit: "")}
									}
								}
								let breakdown = FuelMath.costBreakdown(dataSet)
								if breakdown.totalTaxes != 0 {
									HStack{LabelDataCurrency(label: "Total Taxes", data: breakdown.totalTaxes, unit: "")}
								}
								if breakdown.totalFees != 0 {
									HStack{LabelDataCurrency(label: "Total Fees", data: breakdown.totalFees, unit: "")}
								}
								if breakdown.allInCost != 0 {
									HStack{LabelDataCurrency(label: "All-In Cost", data: breakdown.allInCost, unit: "")}
								}
								if dataSet.feeWaiverThresholdQuantity > 0, !dataSet.feeWaiverAchieved {
									Text("Fee waiver missed on this fill.")
										.font(.caption)
										.foregroundStyle(.orange)
										.frame(maxWidth: .infinity, alignment: .leading)
								}
							}
						}
					}

					if hasQualityDetail {
						CardView {
							VStack {
								SectionText(label: "FUEL QUALITY")
								if dataSet.sumpCheckPerformed {
									HStack{LabelDataText(label: "Sump Check", data: dataSet.sumpCheckResultRaw.isEmpty ? "Performed" : dataSet.sumpCheckResultRaw)}
								}
								if dataSet.fuelSampleRetained {
									HStack{LabelDataText(label: "Fuel Sample", data: "Retained")}
								}
								if dataSet.additiveFSII {
									HStack{LabelDataText(label: "FSII / Prist", data: "Added")}
								}
								if dataSet.safBlendPercent != 0 {
									HStack{LabelDataText(label: "SAF Blend", data: "\(dataSet.safBlendPercent.formatted(.number.precision(.fractionLength(0))))%")}
								}
							}
						}
					}

					if hasPerformanceDetail {
						CardView {
							VStack {
								SectionText(label: "PERFORMANCE")
								if dataSet.plannedBurnKnown {
									HStack{LabelDataNumber(label: "Planned Burn", data: dataSet.plannedBurn, fractionalLength: 1)}
								}
								if dataSet.taxiFuel != 0 {
									HStack{LabelDataNumber(label: "Taxi Fuel", data: dataSet.taxiFuel, fractionalLength: 1)}
								}
								if dataSet.reserveAtLanding != 0 {
									HStack{LabelDataNumber(label: "Reserve at Landing", data: dataSet.reserveAtLanding, fractionalLength: 1)}
								}
							}
						}
					}

					if hasLinkageDetail {
						CardView {
							VStack {
								SectionText(label: "LINKAGE")
								if !dataSet.tripNumber.isEmpty {
									HStack{LabelDataText(label: "Trip / Mission Number", data: dataSet.tripNumber)}
								}
								if !dataSet.costCenter.isEmpty {
									HStack{LabelDataText(label: "Cost Center", data: dataSet.costCenter)}
								}
								if !dataSet.clientName.isEmpty {
									HStack{LabelDataText(label: "Client", data: dataSet.clientName)}
								}
								if !dataSet.operatingRuleRaw.isEmpty {
									HStack{LabelDataText(label: "Operating Rule", data: dataSet.operatingRuleRaw)}
								}
							}
						}
					}
				}

				CardView {
					AttachmentsSection(ownerType: "FuelLog1", ownerKey: dataSet.logName)
				}

				// Hidden when no images are attached
				if hasGraphics {
					CardView {
					VStack {
						SectionText(label: "FUEL GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
					}
					}
				}

			}//end of list
			
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "details",
					dbRecord: "fuel log")
			}

			.toolbar {
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "Cancel" : "Edit") {
						// Load the form from the record on the way in. The detail view reads the model
						// directly, while the form holds its own @State copies seeded back in `init` — so
						// without this a value written since (by a travel log's enroute stop, say) would
						// show correctly in details but the form would edit and re-save the stale one.
						if !isEditing { syncFieldsFromRecord() }
						isEditing.toggle()
					}
					.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("Delete", role: .destructive) {
						isPresentingConfirm = true
					}
					.confirmationDialog("Confirm action", isPresented: $isPresentingConfirm) {
						Button("Delete record?", role: .destructive) {
							DeleteRecord()
						}
						Button("Make Inactive") {
							makeInactive()
						}
					} message: {
						Text("Confirm either deletion or deactivation of this service record.  Deactivated records will still be available for reference, but will not be included in any reports or calculations.")
					}
					.buttonStyle(GrowingButton(buttonColor: Color.gray))
				}
			}
			.onAppear {
				loadUnitsIfNeeded()
				refreshVehicleDetails()
				computeFuelStats()
			}
		}
	}

	/// Loads vehicle-specific details (e.g., fuel capacity) for the selected vehicle.
	/// Keeps vehicleDetails in sync for use across the view.
	private func refreshVehicleDetails() {
		self.vehicleDetails = functions.loadVehicleDetails(context: modelContext, vehicleId: vehicleId)
	}

	/// Loads this vehicle's `ComponentTimes` engine rows for the per-engine Oil Added
	/// fields. Aviation only — land/marine never populate `ComponentTimes`.
	private func loadEngineComponents() {
		guard Vertical.current.id == .aviation else { return }
		let vid = vehicleId
		let fd = FetchDescriptor<ComponentTimes>(
			predicate: #Predicate { $0.vehicleId == vid && $0.componentType == "Engine" },
			sortBy: [SortDescriptor(\.componentName, order: .forward)]
		)
		engineComponents = (try? modelContext.fetch(fd)) ?? []
	}

	/// The engine's slot number (1-6) parsed from its `componentName` ("Engine 3" → 3, as
	/// created by `syncEngineSlots` in EditVehicle.swift), falling back to array position
	/// if that ever doesn't parse.
	private func engineSlotNumber(_ engine: ComponentTimes, fallback: Int) -> Int {
		if let last = engine.componentName.split(separator: " ").last, let n = Int(last), (1...6).contains(n) {
			return n
		}
		return fallback
	}

	/// "Engine 1 (Lycoming O-360) Oil Added (qt)" — falls back to just the slot name when
	/// the engine's make hasn't been entered yet on Edit Vehicle.
	private func oilAddedLabel(for engine: ComponentTimes) -> String {
		let suffix = engine.make.isEmpty ? "" : " (\(engine.make))"
		return "\(engine.componentName)\(suffix) Oil Added (\(unit(UnitIndex.oil)))"
	}

	private func oilAddedEngineBinding(slot: Int) -> Binding<Float> {
		switch slot {
		case 1: return $oilAddedEngine1
		case 2: return $oilAddedEngine2
		case 3: return $oilAddedEngine3
		case 4: return $oilAddedEngine4
		case 5: return $oilAddedEngine5
		default: return $oilAddedEngine6
		}
	}

	private func oilAddedEngineValue(slot: Int) -> Float {
		switch slot {
		case 1: return dataSet.oilAddedEngine1
		case 2: return dataSet.oilAddedEngine2
		case 3: return dataSet.oilAddedEngine3
		case 4: return dataSet.oilAddedEngine4
		case 5: return dataSet.oilAddedEngine5
		default: return dataSet.oilAddedEngine6
		}
	}

	// MARK: - Per-tank fuel (aviation)

	/// The vehicle's configured tank count (1-6) — 1 (and every non-aviation vehicle) keeps
	/// today's single aggregate Fuel Level Start/Added/End fields; only a genuinely
	/// multi-tank aircraft shows the per-tank breakdown.
	private var vehicleFuelTankCount: Int {
		guard Vertical.current.id == .aviation else { return 1 }
		return max(1, min(6, selectedVehicle?.numberOfFuelTanks ?? 1))
	}

	/// Falls back to "Tank N" when the vehicle hasn't named that tank yet on Edit Vehicle.
	private func fuelTankName(_ tankNumber: Int) -> String {
		let raw: String
		switch tankNumber {
		case 1: raw = selectedVehicle?.fuelTank1Name ?? ""
		case 2: raw = selectedVehicle?.fuelTank2Name ?? ""
		case 3: raw = selectedVehicle?.fuelTank3Name ?? ""
		case 4: raw = selectedVehicle?.fuelTank4Name ?? ""
		case 5: raw = selectedVehicle?.fuelTank5Name ?? ""
		default: raw = selectedVehicle?.fuelTank6Name ?? ""
		}
		return raw.isEmpty ? "Tank \(tankNumber)" : raw
	}

	private func fuelTankCapacity(_ tankNumber: Int) -> Float {
		switch tankNumber {
		case 1: return Float(selectedVehicle?.fuelTank1Capacity ?? 0)
		case 2: return Float(selectedVehicle?.fuelTank2Capacity ?? 0)
		case 3: return Float(selectedVehicle?.fuelTank3Capacity ?? 0)
		case 4: return Float(selectedVehicle?.fuelTank4Capacity ?? 0)
		case 5: return Float(selectedVehicle?.fuelTank5Capacity ?? 0)
		default: return Float(selectedVehicle?.fuelTank6Capacity ?? 0)
		}
	}

	private func tankLevelStartBinding(_ tankNumber: Int) -> Binding<Float> {
		switch tankNumber {
		case 1: return $fuelTank1LevelStart1
		case 2: return $fuelTank2LevelStart1
		case 3: return $fuelTank3LevelStart1
		case 4: return $fuelTank4LevelStart1
		case 5: return $fuelTank5LevelStart1
		default: return $fuelTank6LevelStart1
		}
	}

	private func tankQuantityStartBinding(_ tankNumber: Int) -> Binding<Float> {
		switch tankNumber {
		case 1: return $fuelTank1QuantityStart
		case 2: return $fuelTank2QuantityStart
		case 3: return $fuelTank3QuantityStart
		case 4: return $fuelTank4QuantityStart
		case 5: return $fuelTank5QuantityStart
		default: return $fuelTank6QuantityStart
		}
	}

	private func tankLevelEndBinding(_ tankNumber: Int) -> Binding<Float> {
		switch tankNumber {
		case 1: return $fuelTank1LevelEnd1
		case 2: return $fuelTank2LevelEnd1
		case 3: return $fuelTank3LevelEnd1
		case 4: return $fuelTank4LevelEnd1
		case 5: return $fuelTank5LevelEnd1
		default: return $fuelTank6LevelEnd1
		}
	}

	private func tankQuantityEndBinding(_ tankNumber: Int) -> Binding<Float> {
		switch tankNumber {
		case 1: return $fuelTank1QuantityEnd
		case 2: return $fuelTank2QuantityEnd
		case 3: return $fuelTank3QuantityEnd
		case 4: return $fuelTank4QuantityEnd
		case 5: return $fuelTank5QuantityEnd
		default: return $fuelTank6QuantityEnd
		}
	}

	private func tankAddedBinding(_ tankNumber: Int) -> Binding<Float> {
		switch tankNumber {
		case 1: return $fuelTank1Added
		case 2: return $fuelTank2Added
		case 3: return $fuelTank3Added
		case 4: return $fuelTank4Added
		case 5: return $fuelTank5Added
		default: return $fuelTank6Added
		}
	}

	private func tankQuantityStartValue(_ tankNumber: Int) -> Float {
		switch tankNumber {
		case 1: return dataSet.fuelTank1QuantityStart
		case 2: return dataSet.fuelTank2QuantityStart
		case 3: return dataSet.fuelTank3QuantityStart
		case 4: return dataSet.fuelTank4QuantityStart
		case 5: return dataSet.fuelTank5QuantityStart
		default: return dataSet.fuelTank6QuantityStart
		}
	}

	private func tankQuantityEndValue(_ tankNumber: Int) -> Float {
		switch tankNumber {
		case 1: return dataSet.fuelTank1QuantityEnd
		case 2: return dataSet.fuelTank2QuantityEnd
		case 3: return dataSet.fuelTank3QuantityEnd
		case 4: return dataSet.fuelTank4QuantityEnd
		case 5: return dataSet.fuelTank5QuantityEnd
		default: return dataSet.fuelTank6QuantityEnd
		}
	}

	private func tankAddedValue(_ tankNumber: Int) -> Float {
		switch tankNumber {
		case 1: return dataSet.fuelTank1Added
		case 2: return dataSet.fuelTank2Added
		case 3: return dataSet.fuelTank3Added
		case 4: return dataSet.fuelTank4Added
		case 5: return dataSet.fuelTank5Added
		default: return dataSet.fuelTank6Added
		}
	}

	/// Keeps the whole-aircraft `fuelQuantityStart`/`fuelQuantityEnd`/`fuelAdded` totals in
	/// sync as the sum across configured tanks, so price/cost (which stay single values)
	/// and every existing economy calc that reads the aggregate fields keep working
	/// unchanged for a multi-tank aircraft.
	private func recomputeAggregateFuelFromTanks() {
		guard vehicleFuelTankCount > 1 else { return }
		let tanks = 1...vehicleFuelTankCount
		fuelQuantityStart = tanks.reduce(0) { $0 + tankQuantityStartBinding($1).wrappedValue }
		fuelQuantityEnd = tanks.reduce(0) { $0 + tankQuantityEndBinding($1).wrappedValue }
		fuelAdded = tanks.reduce(0) { $0 + tankAddedBinding($1).wrappedValue }
		fuelCost = fuelPrice * fuelAdded
		computeFuelStats()
	}

	/// Recomputes the fuel and DEF quantities from the vehicle's capacities and the selected
	/// fractional levels.
	///
	/// Only called when the vehicle changes, since the capacities the quantities derive from
	/// change with it. Not called on appear, where a typed exact quantity must survive.
	private func recomputeFuelQuantities() {
		let capacity = Float(vehicleDetails?.fuelCapacity ?? 0)
		fuelQuantityStart = capacity * fuelLevelStart1
		fuelQuantityEnd = capacity * fuelLevelEnd1
		defQuantity = Float(vehicleDetails?.defCapacity ?? 0) * defLevel1
		defQuantityStart = Float(vehicleDetails?.defCapacity ?? 0) * defLevelStart1
	}

	/// Stored fuel quantities, which hold a typed exact figure when one was entered and the
	/// dropdown's derived amount otherwise. Records saved before quantities were tracked fall
	/// back to the eighths estimate.
	private var fuelQuantityStartForDisplay: Float {
		dataSet.fuelQuantityStart > 0
			? dataSet.fuelQuantityStart
			: dataSet.fuelLevelStart1 * Float(vehicleDetails?.fuelCapacity ?? 0)
	}
	
	private var fuelQuantityEndForDisplay: Float {
		dataSet.fuelQuantityEnd > 0
			? dataSet.fuelQuantityEnd
			: dataSet.fuelLevelEnd1 * Float(vehicleDetails?.fuelCapacity ?? 0)
	}
	
	/// Stored DEF quantity before adding, falling back to the eighths estimate for records
	/// saved before the field existed.
	private var defQuantityStartForDisplay: Float {
		dataSet.defQuantityStart > 0
			? dataSet.defQuantityStart
			: dataSet.defLevelStart1 * Float(vehicleDetails?.defCapacity ?? 0)
	}
	
	/// Stored DEF quantity, falling back to the eighths estimate for records saved before
	/// the quantity field existed.
	private var defQuantityForDisplay: Float {
		dataSet.defQuantity > 0
			? dataSet.defQuantity
			: dataSet.defLevel1 * Float(vehicleDetails?.defCapacity ?? 0)
	}
	
	/// Derives a DEF quantity for a record saved before the field existed, so the editable
	/// field doesn't read zero next to a dropdown saying "1/2 Tank".
	private func backfillDefQuantity() {
		let capacity = Float(vehicleDetails?.defCapacity ?? 0)
		guard capacity > 0 else { return }
		if defQuantity == 0, defLevel1 > 0 { defQuantity = capacity * defLevel1 }
		if defQuantityStart == 0, defLevelStart1 > 0 { defQuantityStart = capacity * defLevelStart1 }
	}
	
	/// Re-reads the record's stored values into the form.
	///
	/// `@State` is seeded in `init`, which SwiftUI only honours the first time a given view
	/// instance appears. Re-seeding on appear means a record changed elsewhere — a travel
	/// log's enroute stop writing to its linked fuel log — shows its current values here.
	private func syncFieldsFromRecord() {
		vehicleId = dataSet.vehicleId
		logName = dataSet.logName
		fuelNotes = dataSet.fuelNotes
		fuelDateTime = dataSet.fuelDateTime
		fuelExitTime = dataSet.fuelExitTime ?? dataSet.fuelDateTime
		odometer = dataSet.odometer
		location = dataSet.location
		engHours = dataSet.engHours
		fuelQuantityStart = dataSet.fuelQuantityStart
		fuelQuantityEnd = dataSet.fuelQuantityEnd
		fuelAdded = dataSet.fuelAdded
		defAdded = dataSet.defAdded
		defPrice = dataSet.defPrice
		defLevel1 = dataSet.defLevel1
		defLevelFraction = dataSet.defLevelFraction
		defQuantity = dataSet.defQuantity
		defLevelStart1 = dataSet.defLevelStart1
		defLevelStartFraction = dataSet.defLevelStartFraction
		defQuantityStart = dataSet.defQuantityStart
		oilAdded = dataSet.oilAdded
		oilAddedEngine1 = dataSet.oilAddedEngine1
		oilAddedEngine2 = dataSet.oilAddedEngine2
		oilAddedEngine3 = dataSet.oilAddedEngine3
		oilAddedEngine4 = dataSet.oilAddedEngine4
		oilAddedEngine5 = dataSet.oilAddedEngine5
		oilAddedEngine6 = dataSet.oilAddedEngine6
		deiceFluidAdded = dataSet.deiceFluidAdded
		hydraulicFluidAdded = dataSet.hydraulicFluidAdded
		brakeFluidAdded = dataSet.brakeFluidAdded
		oilChecked = dataSet.oilChecked
		engineCoolantChecked = dataSet.engineCoolantChecked
		secondaryCoolantChecked = dataSet.secondaryCoolantChecked
		powerSteeringChecked = dataSet.powerSteeringChecked
		brakeFluidChecked = dataSet.brakeFluidChecked
		transmissionFluidChecked = dataSet.transmissionFluidChecked
		rearAxleChecked = dataSet.rearAxleChecked
		frontAxleChecked = dataSet.frontAxleChecked
		fuelWaterSeparatorChecked = dataSet.fuelWaterSeparatorChecked
		airSystemWaterBleedChecked = dataSet.airSystemWaterBleedChecked
		checkedFluidItems = FluidCheckList.unpack(dataSet.checkedFluidItemsPacked)
		fuelLevelStart1 = dataSet.fuelLevelStart1
		fuelLevelEnd1 = dataSet.fuelLevelEnd1
		fuelLevelStartFraction = dataSet.fuelLevelStartFraction
		fuelLevelEndFraction = dataSet.fuelLevelEndFraction
		fuelTank1LevelStart1 = dataSet.fuelTank1LevelStart1
		fuelTank2LevelStart1 = dataSet.fuelTank2LevelStart1
		fuelTank3LevelStart1 = dataSet.fuelTank3LevelStart1
		fuelTank4LevelStart1 = dataSet.fuelTank4LevelStart1
		fuelTank5LevelStart1 = dataSet.fuelTank5LevelStart1
		fuelTank6LevelStart1 = dataSet.fuelTank6LevelStart1
		fuelTank1QuantityStart = dataSet.fuelTank1QuantityStart
		fuelTank2QuantityStart = dataSet.fuelTank2QuantityStart
		fuelTank3QuantityStart = dataSet.fuelTank3QuantityStart
		fuelTank4QuantityStart = dataSet.fuelTank4QuantityStart
		fuelTank5QuantityStart = dataSet.fuelTank5QuantityStart
		fuelTank6QuantityStart = dataSet.fuelTank6QuantityStart
		fuelTank1LevelEnd1 = dataSet.fuelTank1LevelEnd1
		fuelTank2LevelEnd1 = dataSet.fuelTank2LevelEnd1
		fuelTank3LevelEnd1 = dataSet.fuelTank3LevelEnd1
		fuelTank4LevelEnd1 = dataSet.fuelTank4LevelEnd1
		fuelTank5LevelEnd1 = dataSet.fuelTank5LevelEnd1
		fuelTank6LevelEnd1 = dataSet.fuelTank6LevelEnd1
		fuelTank1QuantityEnd = dataSet.fuelTank1QuantityEnd
		fuelTank2QuantityEnd = dataSet.fuelTank2QuantityEnd
		fuelTank3QuantityEnd = dataSet.fuelTank3QuantityEnd
		fuelTank4QuantityEnd = dataSet.fuelTank4QuantityEnd
		fuelTank5QuantityEnd = dataSet.fuelTank5QuantityEnd
		fuelTank6QuantityEnd = dataSet.fuelTank6QuantityEnd
		fuelTank1Added = dataSet.fuelTank1Added
		fuelTank2Added = dataSet.fuelTank2Added
		fuelTank3Added = dataSet.fuelTank3Added
		fuelTank4Added = dataSet.fuelTank4Added
		fuelTank5Added = dataSet.fuelTank5Added
		fuelTank6Added = dataSet.fuelTank6Added
		fuelPrice = dataSet.fuelPrice
		fuelCost = dataSet.fuelCost
		fuelType = dataSet.fuelType
		image1 = dataSet.image1
		image2 = dataSet.image2
		image3 = dataSet.image3
		image1Description = dataSet.image1Description
		image2Description = dataSet.image2Description
		image3Description = dataSet.image3Description
		inactive = dataSet.inactive
	}
	
	/// Ends text editing so an in-flight field commits its value to its binding.
	///
	/// `TextField(value:format:)` — used by the price, cost and DEF price fields — only
	/// writes to its binding when it loses focus. Tapping Save while such a field is still
	/// focused would otherwise read the previous value and appear to discard the edit.
	private func commitPendingTextEdits() {
#if os(iOS)
		UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#elseif os(macOS)
		NSApp.keyWindow?.makeFirstResponder(nil)
#endif
	}
	
	/// "Fluid Checks" with a running count, so the button says how many were done without
	/// having to open the sheet.
	private var fluidChecksTitle: String {
		let done: Int
		if Vertical.current.id == .land {
			done = [oilChecked, engineCoolantChecked, secondaryCoolantChecked, powerSteeringChecked,
				 brakeFluidChecked, transmissionFluidChecked, rearAxleChecked, frontAxleChecked,
				 fuelWaterSeparatorChecked, airSystemWaterBleedChecked].filter { $0 }.count
		} else {
			done = checkedFluidItems.count
		}
		return "Fluid Checks (\(done) completed)"
	}
	
	/// Fills the end fuel quantity in from the level before fuelling plus the amount added.
	///
	/// Sets only the quantity, not the eighths dropdown — writing the fraction would trip its
	/// own `onChange` and overwrite the computed amount with the nearest eighth. The dropdown
	/// is reconciled from the quantity on save.
	private func recalcFuelEndFromAdded() {
		let capacity = Float(vehicleDetails?.fuelCapacity ?? 0)
		guard capacity > 0 else { return }
		fuelQuantityEnd = min(capacity, max(0, fuelQuantityStart + fuelAdded))
	}
	
	/// Fills the end DEF quantity in from the level before adding plus the amount added.
	private func recalcDefEndFromAdded() {
		let capacity = Float(vehicleDetails?.defCapacity ?? 0)
		guard capacity > 0 else { return }
		defQuantity = min(capacity, max(0, defQuantityStart + defAdded))
	}
	
	/// Snaps a 0...1 tank ratio to the nearest eighth, matching the dropdown's choices.
	/// - Note: `Functions.getFuelLevel(unit:)` only labels exact eighths, so a raw ratio
	///   has to be snapped before it can be turned into a fraction label.
	private func nearestFuelEighth(_ ratio: Float) -> Float {
		let clamped = min(1, max(0, ratio))
		return (clamped * 8).rounded() / 8
	}
	
	/// Loads unit preferences once and caches them for safe, fast access in the view.
	private func loadUnitsIfNeeded() {
		if let arr = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1") {
			self.units = arr
		}
	}

	/// Computes statistics for the current record and vehicle, including:
	/// - Since-previous metrics (distance, days, economy, price change)
	/// - Totals up to and including this record (distance, fuel, cost, averages)
	/// Applies filters based on showInactiveVehicles.
	/// Only considers records where fuelAdded > 0 to exclude oil-only or DEF-only logs.
	private func computeFuelStats() {
		// Guard vehicle
		let vid = vehicleId.isEmpty ? dataSet.vehicleId : vehicleId
		guard !vid.isEmpty else {
			resetStats()
			return
		}

		// 1) Previous fill-up for "since last" — full-to-full gated, see FuelMath.interval.
		// Only records with fuelAdded > 0 count as a fill-up, excluding oil-only/DEF-only logs.
		// Unset fillTypeRaw (every record predating this feature) defaults to "full", so this
		// reproduces the old immediate-previous-fill numbers exactly for historical data.
		let priorPoints = functions.loadPriorFuelLogs(context: modelContext, vehicleId: vid, before: fuelDateTime)
			.filter { $0.fuelAdded > 0 }
			.map(FuelLogPoint.init(model:))
		let currentPoint = FuelLogPoint(
			date: fuelDateTime, odometer: odometer, fuelAdded: fuelAdded, fuelCost: fuelCost,
			fuelPrice: fuelPrice, fillType: FuelFillType(rawValue: dataSet.fillTypeRaw)
		)
		let stats = FuelMath.interval(current: currentPoint, priorAscending: priorPoints)
		hasPreviousFill = stats.hasPreviousFill
		distanceSinceLast = stats.distance
		daysSinceLast = stats.daysSinceLast
		fuelEconomySince = stats.economy
		costPerDistanceSince = stats.costPerDistance
		priceChangePerUnit = stats.hasPreviousFill ? fuelPrice - stats.previousFuelPrice : 0
		lastFillOdometer = stats.previousOdometer
		lastFillDate = stats.previousDate
		fuelStatsFlags = stats.flags

		// 3) DEF totals — separate fetch includes ALL records (not filtered by fuelAdded > 0)
		do {
			let defVid = vid
			let defDate = fuelDateTime
			let defFetch: FetchDescriptor<FuelLog1>
			if showInactiveVehicles {
				defFetch = FetchDescriptor<FuelLog1>(
					predicate: #Predicate { log in log.vehicleId == defVid && log.fuelDateTime <= defDate },
					sortBy: [SortDescriptor(\.fuelDateTime, order: .forward)]
				)
			} else {
				defFetch = FetchDescriptor<FuelLog1>(
					predicate: #Predicate { log in log.vehicleId == defVid && log.fuelDateTime <= defDate && log.inactive == false },
					sortBy: [SortDescriptor(\.fuelDateTime, order: .forward)]
				)
			}
			let defLogs = try modelContext.fetch(defFetch)
			let defCurrentID = dataSet.id
			let otherDefLogs = defLogs.filter { $0.id != defCurrentID }
			totalDEFAdded = otherDefLogs.reduce(Float(0)) { $0 + $1.defAdded } + defAdded
			totalDEFCost = otherDefLogs.reduce(Float(0)) { $0 + ($1.defAdded * $1.defPrice) } + (defAdded * defPrice)
			avgDEFPrice = totalDEFAdded > 0 ? (totalDEFCost / totalDEFAdded) : 0.0
		} catch {
			totalDEFAdded = 0
			totalDEFCost = 0
			avgDEFPrice = 0
		}

		// 2) Totals up to (and including) this record
		do {
			let upToFetch: FetchDescriptor<FuelLog1>
			if showInactiveVehicles {
				// The body must be a single inline expression for macro #Predicate.
				upToFetch = FetchDescriptor<FuelLog1>(
					predicate: #Predicate { log in log.vehicleId == vid && log.fuelDateTime <= fuelDateTime && log.fuelAdded > 0 },
					sortBy: [SortDescriptor(\.fuelDateTime, order: .forward)]
				)
			} else {
				// The body must be a single inline expression for macro #Predicate.
				upToFetch = FetchDescriptor<FuelLog1>(
					predicate: #Predicate { log in log.vehicleId == vid && log.fuelDateTime <= fuelDateTime && log.inactive == false && log.fuelAdded > 0 },
					sortBy: [SortDescriptor(\.fuelDateTime, order: .forward)]
				)
			}
			let logsUpTo = try modelContext.fetch(upToFetch)
			if logsUpTo.isEmpty {
				totalDistance = 0
				totalFuel = 0
				totalCost = 0
				avgEconomy = 0
				avgPricePerUnit = 0
				return
			}

			// Distance from first odometer to current record's odometer
			let firstOdo = logsUpTo.first?.odometer ?? 0
			let currentOdo = odometer
			totalDistance = max(0, currentOdo - firstOdo)

			// Totals (fuel and cost) up to this record - only from records with fuelAdded > 0
			totalFuel = logsUpTo.reduce(0) { $0 + $1.fuelAdded }
			totalCost = logsUpTo.reduce(0) { $0 + $1.fuelCost }

			// Averages based on totals up to this record
			avgEconomy = totalFuel > 0 ? Float(totalDistance) / totalFuel : 0.0
			avgPricePerUnit = totalFuel > 0 ? (totalCost / totalFuel) : 0.0

		} catch {
			print("Up-to fetch error: \(error.localizedDescription)")
			totalDistance = 0
			totalFuel = 0
			totalCost = 0
			avgEconomy = 0
			avgPricePerUnit = 0
		}
	}

	/// Resets all computed statistic fields to safe defaults.
	private func resetStats() {
		hasPreviousFill = false
		distanceSinceLast = 0
		daysSinceLast = 0
		fuelEconomySince = 0
		costPerDistanceSince = 0
		priceChangePerUnit = 0
		totalDistance = 0
		totalFuel = 0
		totalCost = 0
		avgEconomy = 0
		avgPricePerUnit = 0
		totalDEFAdded = 0
		totalDEFCost = 0
		avgDEFPrice = 0
		lastFillOdometer = 0
		lastFillDate = nil
		fuelStatsFlags = []
	}

	/// Permanently deletes the current FuelLog1 record and dismisses the view.
	private func DeleteRecord(){
		do {
			modelContext.delete(dataSet)
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
		dismiss()
	}
	/// Marks the current FuelLog1 record as inactive, saves, and dismisses the view.
	private func makeInactive() {
		dataSet.inactive = true
		inactive = true
		dataSet.updatedAt = Date()
		do {
			try modelContext.save()
		} catch {
			print("Failed to mark inactive: \(error.localizedDescription)")
		}
		dismiss()
	}

	/// Writes all edited @State values back to the FuelLog1 model and persists changes.
	/// Also updates the associated Vehicle8 with newer odometer/engine hours if needed.
	/// Finds the travel log whose enroute stop links to this fuel log.
	///
	/// The link is held on `TripLog2` — one of its six `fuelAdded#Log` fields stores this
	/// record's `logId`. `FuelLog1` has no back-reference, so the trips are searched instead.
	/// - Returns: A "trip name — Stop n" summary, or an empty string when no trip links here.
	private func linkedTravelLogSummary() -> String {
		let id = dataSet.logId
		guard !id.isEmpty else { return "" }
		var fd = FetchDescriptor<TripLog2>(
			predicate: #Predicate {
				$0.fuelAdded1Log == id || $0.fuelAdded2Log == id || $0.fuelAdded3Log == id
					|| $0.fuelAdded4Log == id || $0.fuelAdded5Log == id || $0.fuelAdded6Log == id
			}
		)
		fd.fetchLimit = 1
		guard let trip = try? modelContext.fetch(fd).first else { return "" }
		let name = trip.logName.isEmpty ? "(unnamed travel log)" : trip.logName
		let stopLogIds = [trip.fuelAdded1Log, trip.fuelAdded2Log, trip.fuelAdded3Log,
			trip.fuelAdded4Log, trip.fuelAdded5Log, trip.fuelAdded6Log]
		guard let stopIndex = stopLogIds.firstIndex(of: id) else { return name }
		return "\(name) — Stop \(stopIndex + 1)"
	}

	/// Whether any RecordAttachment is linked to this fuel log by name — the only
	/// name-linked child now that AttachmentsSection uses `logName` as its ownerKey.
	private func hasLinkedRecords(_ name: String) -> Bool {
		guard !name.isEmpty else { return false }
		var fd = FetchDescriptor<RecordAttachment>(predicate: #Predicate { $0.ownerType == "FuelLog1" && $0.ownerKey == name })
		fd.fetchLimit = 1
		return ((try? modelContext.fetch(fd)) ?? []).isEmpty == false
	}

	/// Updates attachments that reference this fuel log by name (LandShip's string-based
	/// linking convention) so they survive a logName rename instead of silently orphaning.
	private func renameLinkedRecords(from oldName: String, to newName: String) {
		guard !oldName.isEmpty, oldName != newName else { return }
		let fd = FetchDescriptor<RecordAttachment>(predicate: #Predicate { $0.ownerType == "FuelLog1" && $0.ownerKey == oldName })
		guard let records = try? modelContext.fetch(fd), !records.isEmpty else { return }
		records.forEach { $0.ownerKey = newName }
		do {
			try modelContext.save()
		} catch {
			print("Failed to update linked attachments after fuel log rename: \(error.localizedDescription)")
		}
	}

	private func updateItem() {
		dataSet.inactive = inactive
		dataSet.vehicleId = vehicleId
		dataSet.logName = logName
		dataSet.fuelNotes = fuelNotes
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.fuelDateTime = fuelDateTime
		dataSet.fuelExitTime = max(fuelExitTime, fuelDateTime)
		dataSet.odometer = odometer
		dataSet.location = location
		dataSet.engHours = engHours
		// Multi-tank aircraft: bring each tank's own eighths dropdown back into line with its
		// quantity (same reasoning as the aggregate reconciliation below), then re-sum the
		// tanks into the aggregate fields so the reconciliation below sees final numbers.
		if vehicleFuelTankCount > 1 {
			for tankNumber in 1...vehicleFuelTankCount {
				let capacity = fuelTankCapacity(tankNumber)
				guard capacity > 0 else { continue }
				tankLevelStartBinding(tankNumber).wrappedValue = nearestFuelEighth(tankQuantityStartBinding(tankNumber).wrappedValue / capacity)
				tankLevelEndBinding(tankNumber).wrappedValue = nearestFuelEighth(tankQuantityEndBinding(tankNumber).wrappedValue / capacity)
			}
			recomputeAggregateFuelFromTanks()
		}
		// The quantity fields are authoritative — a digital readout can be typed straight in.
		// Bring each eighths dropdown and fraction label back into line with its quantity.
		var levelStartFraction = fuelLevelStart1
		var levelEndFraction = fuelLevelEnd1
		var levelStartText = fuelLevelStartFraction
		var levelEndText = fuelLevelEndFraction
		let tankCapacity = Float(vehicleDetails?.fuelCapacity ?? 0)
		if tankCapacity > 0 {
			levelStartFraction = nearestFuelEighth(fuelQuantityStart / tankCapacity)
			levelEndFraction = nearestFuelEighth(fuelQuantityEnd / tankCapacity)
			levelStartText = functions.getFuelLevel(unit: levelStartFraction)
			levelEndText = functions.getFuelLevel(unit: levelEndFraction)
		}
		var defFraction = defLevel1
		var defText = defLevelFraction
		var defStartFraction = defLevelStart1
		var defStartText = defLevelStartFraction
		let defTankCapacity = Float(vehicleDetails?.defCapacity ?? 0)
		if defTankCapacity > 0 {
			defFraction = nearestFuelEighth(defQuantity / defTankCapacity)
			defText = functions.getFuelLevel(unit: defFraction)
			defStartFraction = nearestFuelEighth(defQuantityStart / defTankCapacity)
			defStartText = functions.getFuelLevel(unit: defStartFraction)
		}
		fuelLevelStart1 = levelStartFraction
		fuelLevelEnd1 = levelEndFraction
		fuelLevelStartFraction = levelStartText
		fuelLevelEndFraction = levelEndText
		defLevel1 = defFraction
		defLevelFraction = defText
		defLevelStart1 = defStartFraction
		defLevelStartFraction = defStartText

		dataSet.fuelQuantityStart = fuelQuantityStart
		dataSet.fuelQuantityEnd = fuelQuantityEnd
		dataSet.fuelAdded = fuelAdded
		dataSet.defAdded = defAdded
		dataSet.defPrice = defPrice
		dataSet.defLevel1 = defFraction
		dataSet.defLevelFraction = defText
		dataSet.defQuantity = defQuantity
		dataSet.defLevelStart1 = defStartFraction
		dataSet.defLevelStartFraction = defStartText
		dataSet.defQuantityStart = defQuantityStart
		dataSet.oilAdded = oilAdded
		dataSet.oilAddedEngine1 = oilAddedEngine1
		dataSet.oilAddedEngine2 = oilAddedEngine2
		dataSet.oilAddedEngine3 = oilAddedEngine3
		dataSet.oilAddedEngine4 = oilAddedEngine4
		dataSet.oilAddedEngine5 = oilAddedEngine5
		dataSet.oilAddedEngine6 = oilAddedEngine6
		dataSet.deiceFluidAdded = deiceFluidAdded
		dataSet.hydraulicFluidAdded = hydraulicFluidAdded
		dataSet.brakeFluidAdded = brakeFluidAdded
		dataSet.oilChecked = oilChecked
		dataSet.engineCoolantChecked = engineCoolantChecked
		dataSet.secondaryCoolantChecked = secondaryCoolantChecked
		dataSet.powerSteeringChecked = powerSteeringChecked
		dataSet.brakeFluidChecked = brakeFluidChecked
		dataSet.transmissionFluidChecked = transmissionFluidChecked
		dataSet.rearAxleChecked = rearAxleChecked
		dataSet.frontAxleChecked = frontAxleChecked
		dataSet.fuelWaterSeparatorChecked = fuelWaterSeparatorChecked
		dataSet.airSystemWaterBleedChecked = airSystemWaterBleedChecked
		// Re-sorted into catalog declaration order so Set iteration order never leaks into
		// storage — mirrors FuelTypesConfigView.save(). `[]` on land, which doesn't use this.
		dataSet.checkedFluidItemsPacked = FluidCheckList.pack(FluidCheckList.currentLabels.filter { checkedFluidItems.contains($0) })
		dataSet.fuelLevelStart1 = fuelLevelStart1
		dataSet.fuelLevelEnd1 = fuelLevelEnd1
		dataSet.fuelLevelStartFraction = fuelLevelStartFraction
		dataSet.fuelLevelEndFraction = fuelLevelEndFraction
		dataSet.fuelTank1LevelStart1 = fuelTank1LevelStart1
		dataSet.fuelTank2LevelStart1 = fuelTank2LevelStart1
		dataSet.fuelTank3LevelStart1 = fuelTank3LevelStart1
		dataSet.fuelTank4LevelStart1 = fuelTank4LevelStart1
		dataSet.fuelTank5LevelStart1 = fuelTank5LevelStart1
		dataSet.fuelTank6LevelStart1 = fuelTank6LevelStart1
		dataSet.fuelTank1QuantityStart = fuelTank1QuantityStart
		dataSet.fuelTank2QuantityStart = fuelTank2QuantityStart
		dataSet.fuelTank3QuantityStart = fuelTank3QuantityStart
		dataSet.fuelTank4QuantityStart = fuelTank4QuantityStart
		dataSet.fuelTank5QuantityStart = fuelTank5QuantityStart
		dataSet.fuelTank6QuantityStart = fuelTank6QuantityStart
		dataSet.fuelTank1LevelEnd1 = fuelTank1LevelEnd1
		dataSet.fuelTank2LevelEnd1 = fuelTank2LevelEnd1
		dataSet.fuelTank3LevelEnd1 = fuelTank3LevelEnd1
		dataSet.fuelTank4LevelEnd1 = fuelTank4LevelEnd1
		dataSet.fuelTank5LevelEnd1 = fuelTank5LevelEnd1
		dataSet.fuelTank6LevelEnd1 = fuelTank6LevelEnd1
		dataSet.fuelTank1QuantityEnd = fuelTank1QuantityEnd
		dataSet.fuelTank2QuantityEnd = fuelTank2QuantityEnd
		dataSet.fuelTank3QuantityEnd = fuelTank3QuantityEnd
		dataSet.fuelTank4QuantityEnd = fuelTank4QuantityEnd
		dataSet.fuelTank5QuantityEnd = fuelTank5QuantityEnd
		dataSet.fuelTank6QuantityEnd = fuelTank6QuantityEnd
		dataSet.fuelTank1Added = fuelTank1Added
		dataSet.fuelTank2Added = fuelTank2Added
		dataSet.fuelTank3Added = fuelTank3Added
		dataSet.fuelTank4Added = fuelTank4Added
		dataSet.fuelTank5Added = fuelTank5Added
		dataSet.fuelTank6Added = fuelTank6Added
		dataSet.fuelPrice = fuelPrice
		dataSet.fuelCost = fuelCost
		dataSet.fuelType = fuelType
		dataSet.inactive = inactive
		dataSet.image1 = image1
		dataSet.image2 = image2
		dataSet.image3 = image3
		dataSet.image1Description = image1Description
		dataSet.image2Description = image2Description
		dataSet.image3Description = image3Description

		// update the record
		do {
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}

		// Update the primary vehicle with newer odometer/engHours if greater
		let fetchDescriptor = FetchDescriptor<Vehicle8>(
			predicate: #Predicate { fetchModel in fetchModel.name == vehicleId })
		do {
			let vehicleDataSet: [Vehicle8] = try modelContext.fetch(fetchDescriptor)
			if !vehicleDataSet.isEmpty {
				for vehicleRecord in vehicleDataSet {
					if odometer > vehicleRecord.mileage {
						vehicleRecord.updatedAt = Date()
						vehicleRecord.mileage = odometer
					}
					if engHours > vehicleRecord.engHours {
						vehicleRecord.engHours = engHours
					}
					do {
						try modelContext.save()
					} catch {}
					break
				}
			}
		} catch {}
	}
}

// MARK: - Preview

#Preview {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: Vehicle8.self, FuelLog1.self, configurations: config)
	
	// Seed preview data
	let context = container.mainContext
	let vehicle = Vehicle8(
		name: "Demo Truck",
		year: 2020,
		mileage: 45210,
		engHours: 1234.5,
		fuelType: "Diesel",
		fuelCapacity: 100
	)
	context.insert(vehicle)
	
	let fuel = FuelLog1(
		logId: "preview-001",
		vehicleId: vehicle.name,
		logName: "Pilot Travel Center",
		fuelNotes: "Filled up before trip.",
		createdAt: Date(),
		updatedAt: Date(),
		fuelDateTime: Date().addingTimeInterval(-3600),
		odometer: vehicle.mileage,
		location: "Springfield, IL",
		engHours: vehicle.engHours,
		fuelQuantityStart: 15,
		fuelQuantityEnd: 95,
		fuelAdded: 80,
		defAdded: 2,
		oilAdded: 0.5,
		oilChecked: true,
		fuelLevelStart1: 0.15,
		fuelLevelEnd1: 0.95,
		fuelLevelStart: "Low",
		fuelLevelEnd: "Near Full",
		fuelPrice: 3.79,
		fuelCost: 3.79 * 80,
		fuelType: vehicle.fuelType
	)
	context.insert(fuel)
	
	return EditFuelLog(dataSet: fuel)
		.modelContainer(container)
}

