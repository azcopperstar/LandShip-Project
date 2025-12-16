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

	// MARK: - Fuel Log Fields (@State mirrors FuelLog1)

	@State private var vehicleId: String = ""
	@State private var logName: String = ""
	@State private var fuelNotes: String = ""
	@State private var createdAt: Date = Date()
	@State private var updatedAt: Date = Date()
	@State private var fuelDateTime: Date = Date()
	@State private var odometer: Int = 0
	@State private var location: String = ""
	@State private var engHours: Float = 0.0
	@State private var fuelQuantityStart: Float = 0.0
	@State private var fuelQuantityEnd: Float = 0.0
	@State private var fuelAdded: Float = 0.0
	@State private var defAdded: Float = 0.0
	@State private var oilAdded: Float = 0.0
	@State private var oilChecked: Bool = false
	@State private var fuelLevelStart1: Float = 0.0
	@State private var fuelLevelEnd1: Float = 0.0
	@State private var fuelLevelStartFraction: String = ""
	@State private var fuelLevelEndFraction: String = ""
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

	// MARK: - Computed Statistics

	// Fuel statistics state
	@State private var hasPreviousFill: Bool = false
	@State private var distanceSinceLast: Int = 0
	@State private var daysSinceLast: Int = 0
	@State private var fuelEconomySince: Float = 0.0
	@State private var costPerDistanceSince: Float = 0.0
	@State private var priceChangePerUnit: Float = 0.0

	@State private var totalDistance: Int = 0
	@State private var totalFuel: Float = 0.0
	@State private var totalCost: Float = 0.0
	@State private var avgEconomy: Float = 0.0
	@State private var avgPricePerUnit: Float = 0.0

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
		self._odometer = State.init(initialValue: dataSet.odometer)
		self._location = State.init(initialValue: dataSet.location)
		self._engHours = State.init(initialValue: dataSet.engHours)
		self._fuelQuantityStart = State.init(initialValue: dataSet.fuelQuantityStart)
		self._fuelQuantityEnd = State.init(initialValue: dataSet.fuelQuantityEnd)
		self._fuelAdded = State.init(initialValue: dataSet.fuelAdded)
		self._defAdded = State.init(initialValue: dataSet.defAdded)
		self._oilAdded = State.init(initialValue: dataSet.oilAdded)
		self._oilChecked = State.init(initialValue: dataSet.oilChecked)
		self._fuelLevelStart1 = State.init(initialValue: dataSet.fuelLevelStart1)
		self._fuelLevelEnd1 = State.init(initialValue: dataSet.fuelLevelEnd1)
		self._fuelLevelStartFraction = State.init(initialValue: dataSet.fuelLevelStartFraction)
		self._fuelLevelEndFraction = State.init(initialValue: dataSet.fuelLevelEndFraction)
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
								title: "Vehicle",
								includeEmptyChoice: false,
								emptyChoiceLabel: "—",
								autoSelectFirst: false,
								filter: nil,
								sort: [SortDescriptor(\.name, order: .forward)],
								labelProvider: { $0.name }
							)
							.onChange(of: selectedVehicle) { _, newVehicle in
								let name = newVehicle?.name ?? ""
								vehicleId = name
								// keep dataSet in sync while editing so detail calculations reflect the change
								dataSet.vehicleId = name
								refreshVehicleDetails()
								recomputeFuelQuantities()
								computeFuelStats()
							}
							.fixedSize(horizontal: true, vertical: true)
						} label: {
							Text("Vehicle")
								.textLabelModified()
						}

						HStack{
							LabelDataPicker_DateTime(label: "Date/Time                    ", data: $fuelDateTime)
							// Prime units, vehicle details, and initial stats when the edit view appears.
								.onAppear {
									loadUnitsIfNeeded()
									refreshVehicleDetails()
									recomputeFuelQuantities()
									fuelLevelStartFraction = functions.getFuelLevel(unit: fuelLevelStart1)
									computeFuelStats()
								}
							// Recompute statistics when the fueling date/time changes.
								.onChange(of: fuelDateTime) { _, _ in
									computeFuelStats()
								}
						}
						
						HStack{LabelDataTextview(label: "Log Name", data: $logName)}
						
						HStack{LabelLocationTextview(label: "Location", data: $location)}
						
						HStack{LabelDataTextview_Numberpad_Int(label: "Odometer", data: $odometer)}
						// Keep distance/economy up to date when odometer changes.
							.onChange(of: odometer) { _, _ in
								computeFuelStats()
							}
						HStack{LabelDataTextview_Numberpad_Float(label: "Engine Hours", data: $engHours)}
						HStack{
							Text("Fuel Type")
								.textLabelModified()
							Picker("", selection: $fuelType) {
								Text("Gasoline").tag("Gasoline")
								Text("Diesel").tag("Diesel")
								Text("EV").tag("EV")
								Text("Hybrid").tag("Hybrid")
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						
						HStack{
							Picker_FuelLevel1(label: "Fuel Level Start", data: $fuelLevelStart1, data1: Float(vehicleDetails?.fuelCapacity ?? 0))
						}
						// Update fractional label and derived quantities when start level changes.
						.onChange(of: fuelLevelStart1) {_, _ in
							fuelLevelStartFraction = functions.getFuelLevel(unit: fuelLevelStart1)
							recomputeFuelQuantities()
						}
						HStack{
							Picker_FuelLevel1(label: "Fuel Level End", data: $fuelLevelEnd1, data1: Float(vehicleDetails?.fuelCapacity ?? 0))
						}
						// Update fractional label and derived quantities when end level changes.
						.onChange(of: fuelLevelEnd1) {_, _ in
							fuelLevelEndFraction = functions.getFuelLevel(unit: fuelLevelEnd1)
							recomputeFuelQuantities()
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
							LabelDataTextview_Numberpad_Float(label: "Fuel Added (\(unit(UnitIndex.fuel)))", data: $fuelAdded)
							// Maintain total cost and dependent stats as quantity added changes.
								.onChange(of: fuelAdded) {_, _ in
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
						HStack{LabelDataTextview_Numberpad_Float(label: "Oil Added (\(unit(UnitIndex.oil)))", data: $oilAdded)}
						if fuelType == "Diesel" {
							HStack{LabelDataTextview_Numberpad_Float(label: "DEF Added (\(unit(UnitIndex.def)))", data: $defAdded)}
						}
						HStack{
							Toggle(isOn: $oilChecked) {
								Text("Oil Checked")
									.textLabelModified()
							}
							.accessibilityLabel("Oil Checked")
							.accessibilityHint("Indicates whether oil level was checked during this fuel stop")
						}

						CardView {
							TextFieldNote_FullWidth_3lines(sectionText: "FUEL LOG NOTES", prompt: "Enter notes...", data: $fuelNotes)
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
				recomputeFuelQuantities()
				computeFuelStats()
			}
			.toolbar {
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "Cancel" : "Edit") {isEditing.toggle()}
						.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("Save") {
						isEditing.toggle()
						updateItem()
					}
					.buttonStyle(GrowingButton(buttonColor: Color.red))
				}
			}

		} else {

			ScrollView {
				VStack{CreatedUpdatedText(created: createdAt, updated: updatedAt)}
				CardView {
					VStack {
						SectionText(label: "VEHICLE / LOCATION DETAILS")
							.onAppear {
								loadUnitsIfNeeded()
								refreshVehicleDetails()
								computeFuelStats()
							}
						HStack{LabelDataText(label: "Vehicle", data: dataSet.vehicleId)}
						HStack{LabelDataText(label: "Date/Time", data: "\(functions.formatDate_DDMMMyy_HHmm(date:dataSet.fuelDateTime))")}
						HStack{LabelDataText(label: "Log Name", data: "\(dataSet.logName)")}
						if dataSet.location != "" {
							HStack{LabelDataText(label: "Location", data: "\(dataSet.location)")}
						}
						HStack{LabelDataText(label: "Odometer", data: "\(dataSet.odometer) \(unit(UnitIndex.distance))")}
						if dataSet.engHours > 0 {
							HStack{LabelDataNumber(label: "Engine Hours:", data: dataSet.engHours, fractionalLength: 1)}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "FUELING DETAILS")
						HStack{LabelDataText(label: "Fuel Type", data: "\(dataSet.fuelType)")}
						if dataSet.fuelLevelStartFraction != "" {
							HStack{LabelDataText(label: "Fuel Level Start", data: "\((Float(vehicleDetails?.fuelCapacity ?? 0) * dataSet.fuelLevelStart1)) \(unit(UnitIndex.fuel)) \(dataSet.fuelLevelStartFraction)")}
						}
						if dataSet.fuelLevelEndFraction != "" {
							HStack{LabelDataText(label: "Fuel Level End", data: "\(Float(vehicleDetails?.fuelCapacity ?? 0) * dataSet.fuelLevelEnd1) \(unit(UnitIndex.fuel)) \(dataSet.fuelLevelEndFraction)")}
						}
						HStack{LabelDataCurrency(label: "Price/\(unit(UnitIndex.fuel))", data: dataSet.fuelPrice, unit: "/ \(unit(UnitIndex.fuel))")}
						HStack{LabelDataNumber(label: "Fuel Added (\(unit(UnitIndex.fuel)))", data: dataSet.fuelAdded, fractionalLength: 1)}
						HStack{LabelDataCurrency(label: "Cost", data: dataSet.fuelCost, unit: "")}
						if dataSet.oilAdded > 0.0 {
							HStack{LabelDataNumber(label: "Oil Added (\(unit(UnitIndex.oil)))", data: dataSet.oilAdded, fractionalLength: 1)}
						}
						if dataSet.defAdded > 0.0 {
							HStack{LabelDataNumber(label: "DEF Added (\(unit(UnitIndex.def)))", data: dataSet.defAdded, fractionalLength: 1)}
						}
						if dataSet.oilChecked {
							HStack{LabelDataText(label: "Oil Checked", data: "Yes")}
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
						} else {
							HStack{LabelDataText(label: "Distance", data: "N/A")}
							HStack{LabelDataNumber(label: "Fuel Used (\(unit(UnitIndex.fuel)))", data: dataSet.fuelAdded, fractionalLength: 1)}
							let ecoSince = dataSet.fuelAdded > 0 ? 0.0 : 0.0
							HStack{LabelDataText(label: "Fuel Economy \(unit(UnitIndex.distance))/\(unit(UnitIndex.fuel))", data: "\(ecoSince.formatted(.number.precision(.fractionLength(1))))")}
						}

						// Totals up to this record for this vehicle
						SectionText(label: "VEHICLE TOTALS")
						Text("Totals are calculated from all fuel logs that have been created for this vehicle up to and including the current fuel log.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .center)
						HStack{LabelDataText(label: "Distance (\(unit(UnitIndex.distance)))", data: "\(max(0,totalDistance))")}
						HStack{LabelDataNumber(label: "Fuel (\(unit(UnitIndex.fuel)))", data: totalFuel, fractionalLength: 1)}
						let avgEco = avgEconomy
						HStack{LabelDataText(label: "Average \(unit(UnitIndex.distance))/\(unit(UnitIndex.fuel))", data: "\(avgEco.formatted(.number.precision(.fractionLength(1))))")}
						HStack{LabelDataCurrency(label: "Fuel Cost", data: totalCost, unit: "")}
						HStack{LabelDataCurrency(label: "Avg Price/\(unit(UnitIndex.fuel))", data: avgPricePerUnit, unit: "")}
					}
				}

				CardView {
					VStack {
						SectionText(label: "FUEL GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
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

	/// Recomputes fuelQuantityStart and fuelQuantityEnd based on the vehicle's capacity
	/// and the selected fractional start/end levels.
	private func recomputeFuelQuantities() {
		let capacity = Float(vehicleDetails?.fuelCapacity ?? 0)
		fuelQuantityStart = capacity * fuelLevelStart1
		fuelQuantityEnd = capacity * fuelLevelEnd1
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

		// 1) Previous fill-up for "since last"
		do {
			// Break down the predicate to help the compiler
			let currentDate = fuelDateTime
			let currentVehicle = vid
			
			var prevFetch = FetchDescriptor<FuelLog1>(
				predicate: #Predicate<FuelLog1> { log in
					log.vehicleId == currentVehicle &&
					log.fuelDateTime < currentDate &&
					log.fuelAdded > 0
				},
				sortBy: [SortDescriptor(\.fuelDateTime, order: .reverse)]
			)
			prevFetch.fetchLimit = 1
			let prev = try modelContext.fetch(prevFetch).first
			if let prev {
				hasPreviousFill = true
				let dist = max(0, odometer - prev.odometer)
				distanceSinceLast = dist

				// days since previous
				let cal = Calendar.current
				let comps = cal.dateComponents([.day], from: prev.fuelDateTime, to: fuelDateTime)
				daysSinceLast = max(0, comps.day ?? 0)

				// economy since
				fuelEconomySince = fuelAdded > 0 ? Float(dist) / fuelAdded : 0.0

				// cost per distance
				costPerDistanceSince = dist > 0 ? (fuelCost / Float(dist)) : 0.0

				// price change per unit of fuel
				priceChangePerUnit = fuelPrice - prev.fuelPrice

				// New: capture previous odometer and date
				lastFillOdometer = prev.odometer
				lastFillDate = prev.fuelDateTime
			} else {
				hasPreviousFill = false
				distanceSinceLast = 0
				daysSinceLast = 0
				fuelEconomySince = 0
				costPerDistanceSince = 0
				priceChangePerUnit = 0
				lastFillOdometer = 0
				lastFillDate = nil
			}
		} catch {
			print("Prev fetch error: \(error.localizedDescription)")
			hasPreviousFill = false
			lastFillOdometer = 0
			lastFillDate = nil
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
		lastFillOdometer = 0
		lastFillDate = nil
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
	private func updateItem() {
		dataSet.inactive = inactive
		dataSet.vehicleId = vehicleId
		dataSet.logName = logName
		dataSet.fuelNotes = fuelNotes
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.fuelDateTime = fuelDateTime
		dataSet.odometer = odometer
		dataSet.location = location
		dataSet.engHours = engHours
		dataSet.fuelQuantityStart = fuelQuantityStart
		dataSet.fuelQuantityEnd = fuelQuantityEnd
		dataSet.fuelAdded = fuelAdded
		dataSet.defAdded = defAdded
		dataSet.oilAdded = oilAdded
		dataSet.oilChecked = oilChecked
		dataSet.fuelLevelStart1 = fuelLevelStart1
		dataSet.fuelLevelEnd1 = fuelLevelEnd1
		dataSet.fuelLevelStartFraction = fuelLevelStartFraction
		dataSet.fuelLevelEndFraction = fuelLevelEndFraction
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
		var fetchDescriptor = FetchDescriptor<Vehicle8>(
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

// MARK: - Safe Collection Helpers

private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
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

