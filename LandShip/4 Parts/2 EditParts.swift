/**
 EditParts.swift
 LandShip
 
 A SwiftUI view for viewing and editing a single `MxParts1` record (a stored part in inventory).
 
 Overview
 --------
 `EditParts` presents two primary modes:
 - Details mode (read-only): Displays the current values from the bound `MxParts1` model.
 - Edit mode: Allows the user to modify fields, select related models (vehicle, system, vendor), and attach images.
 
 Persistence
 -----------
 This view uses SwiftData via `@Environment(\.modelContext)` to persist changes. The `updateItem()` function writes the in-memory state back to `dataSet` and saves the context. Destructive actions are supported via:
 - `DeleteRecord()` which removes the model object and saves the context.
 - `makeInactive()` which flags the record as inactive and persists that change.
 
 Related Models
 --------------
 - `Vehicle8`: Used to scope parts to a particular vehicle.
 - `VehicleSystems1`: Used to scope parts to a particular system for a selected vehicle.
 - `Vendors1`: Used to represent the supplier/source of a part.
 
 UI Notes
 --------
 - Sectioned cards group related fields (General, Part Details, Part Costs, Part Source, and Graphics).
 - Model pickers are used to select related objects from the data store with optional filtering and sorting.
 - The toolbar provides Edit/Cancel/Save controls in edit mode and a Delete/Make Inactive confirmation in details mode.
 
 Previews
 --------
 The preview builds an in-memory `ModelContainer`, seeds related models (vehicle, system, vendor), and inserts a sample `MxParts1` record so both modes are representative.
 
 Maintenance
 -----------
 - Keep `updateItem()` synchronized with new properties added to `MxParts1`.
 - Consider surfacing save errors to the user with alerts where appropriate.
 - The view dismisses after destructive actions; adjust if the flow should differ.
 */

import SwiftUI
import SwiftData

/// A detail-and-edit view for a single `MxParts1` part record.
///
/// Displays a read-only summary by default and toggles into edit mode when requested.
/// Edits are staged in local `@State` and committed to the model via `updateItem()`.
///
/// - Parameters:
///   - mxParts: The `MxParts1` instance to view and edit.
///   - startEditing: If `true`, the view starts in edit mode.
struct EditParts: View {
	@State private var dataSet: MxParts1

	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) private var dismiss
	let functions: Functions = Functions()
	// Access settings (units) without storing them in @State
	let prefsFunc: PrefsFunctions = PrefsFunctions()

	@State private var isPresentingConfirm: Bool = false
	@State private var isEditing: Bool = false

	// Controls presentation of the rename-cascade confirmation dialog, shown when saving
	// a part name change that would otherwise orphan records that reference it by name.
	@State private var showingRenameChoice: Bool = false

	@State private var createdAt = Date()
	@State private var updatedAt = Date()
	@State private var vehicleId = ""
	@State private var vehicleSystem = ""
	@State private var partName = ""
	@State private var partNumber = ""
	@State private var partManufacture = ""
	@State private var partDescription = ""
	@State private var Notes = ""
	@State private var costPerUnit: Float = 0.0
	@State private var partUnit = ""
	@State private var partSource = ""
	@State private var partQuantity = 0
	@State private var partLocation = ""
	@State private var partStatus = ""
	@State private var inactive: Bool = false
//	@State private var partImage = ""
	@State private var partSupplier = ""
	@State private var supplierWebsite = ""
	@State private var inventoryTracked: Bool = false
	@State private var inventoryQuantityOnHand: Float = 0
	@State private var inventoryReorderPoint: Float = 0
	@State private var inventoryReorderQuantity: Float = 0
	/// Transient input for adding a brand-new supplier inline. Not mirrored from `dataSet` —
	/// it exists only to spawn a `Vendors1` record on save; the persisted link is `partSupplier`.
	@State private var newSupplierName = ""
	@State private var image1: Data?
	@State private var image2: Data?
	@State private var image3: Data?
	@State private var image1Description: String = ""
	@State private var image2Description: String = ""
	@State private var image3Description: String = ""

	@State private var selectedVehicle: Vehicle8?
	@State private var selectedVendor: Vendors1?

	@Query private var vehicles: [Vehicle8]
	@Query private var vendors: [Vendors1]

	/// Creates a new `EditParts` view.
	///
	/// Copies values from the provided `mxParts` into local `@State` so edits can be staged
	/// without immediately mutating the persisted model. Optionally starts in edit mode.
	///
	/// - Parameters:
	///   - mxParts: The source model to display and edit.
	///   - startEditing: If `true`, the view begins in edit mode.
	init(mxParts: MxParts1, startEditing: Bool = false) {
		self.dataSet = mxParts

		self._createdAt = State(initialValue: mxParts.createdAt)
		self._updatedAt = State(initialValue: mxParts.updatedAt)
		self._vehicleId = State(initialValue: mxParts.vehicleId)
		self._vehicleSystem = State(initialValue: mxParts.vehicleSystem)
		self._partName = State(initialValue: mxParts.partName)
		self._partNumber = State(initialValue: mxParts.partNumber)
		self._partManufacture = State(initialValue: mxParts.partManufacture)
		self._partDescription = State(initialValue: mxParts.partDescription)
		self._Notes = State(initialValue: mxParts.Notes)
		self._costPerUnit = State(initialValue: mxParts.costPerUnit)
		self._partUnit = State(initialValue: mxParts.partUnit)
		self._partSource = State(initialValue: mxParts.partSource)
		self._partQuantity = State(initialValue: mxParts.partQuantity)
		self._partLocation = State(initialValue: mxParts.partLocation)
		self._partStatus = State(initialValue: mxParts.partStatus)
		self._inactive = State(initialValue: mxParts.inactive)
		self._partSupplier = State(initialValue: mxParts.partSupplier)
		self._inventoryTracked = State(initialValue: mxParts.inventoryTracked)
		self._inventoryQuantityOnHand = State(initialValue: mxParts.inventoryQuantityOnHand)
		self._inventoryReorderPoint = State(initialValue: mxParts.inventoryReorderPoint)
		self._inventoryReorderQuantity = State(initialValue: mxParts.inventoryReorderQuantity)
		self._image1 = State(initialValue: mxParts.image1)
		self._image2 = State(initialValue: mxParts.image2)
		self._image3 = State(initialValue: mxParts.image3)
		self._image1Description = State(initialValue: mxParts.image1Description)
		self._image2Description = State(initialValue: mxParts.image2Description)
		self._image3Description = State(initialValue: mxParts.image3Description)

		// Start in edit mode if requested
		self._isEditing = State(initialValue: startEditing)
	}
	
	var body: some View {
		if isEditing {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "GENERAL")

						LabeledContent {
							ModelPicker<Vehicle8>(
								selection: $selectedVehicle,
								title: Vertical.current.assetSingular,
								includeEmptyChoice: true,
								emptyChoiceLabel: FleetScope.allDisplayLabel,
								autoSelectFirst: false,
								sort: [SortDescriptor(\.name, order: .forward)],
								labelProvider: { v in "\(v.year) \(v.displayName)"},
								thumbnailData: { $0.image1 },
								onSelectionChanged: { sel in
									vehicleId = sel?.name ?? "All Vehicles"
								}
							)
							.fixedSize(horizontal: true, vertical: true)
						} label: {
							Text(Vertical.current.assetSingular)
								.textLabelModified()
						}

						Picker_VehicleSystem(label: "\(Vertical.current.assetSingular) System", data: $vehicleSystem)
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "PART DETAILS")
						
						HStack{LabelDataTextview(label: "Part Name", data: $partName)}
						Text("Renaming this part offers to update any records that reference it by name.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .trailing)
						HStack{LabelDataTextview(label: "Part #", data: $partNumber)}
						HStack{LabelDataTextview(label: "Manufacturer", data: $partManufacture)}
						HStack{LabelDataTextview(label: "Description", data: $partDescription)}
					}
				}
				
				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "PART NOTES", prompt: "Enter notes...", data: $Notes)
				}

				CardView {
					VStack {
						SectionText(label: "INVENTORY TRACKING")
						HStack{LabelDataToggle(label: "Track Inventory for this Part", data: $inventoryTracked)}
						if inventoryTracked {
							HStack{LabelDataTextview_Numberpad_Float(label: "Quantity On Hand (\(partUnit))", data: $inventoryQuantityOnHand)}
							HStack{LabelDataTextview_Numberpad_Float(label: "Reorder Point (\(partUnit))", data: $inventoryReorderPoint)}
							HStack{LabelDataTextview_Numberpad_Float(label: "Reorder Quantity (\(partUnit))", data: $inventoryReorderQuantity)}
							Text("When this part is consumed on a service record or item, the quantity on hand is automatically reduced. A low-stock alert appears once the quantity on hand falls to or below the reorder point.")
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "PART COSTS")

						HStack{LabelDataTextview_Numberpad_Currency(label: "Cost/Unit", data: $costPerUnit)}
						Picker_PartsUnit(label: "Unit", data: $partUnit)
						HStack{LabelDataTextview_Numberpad_Int(label: "Quantity Used/Repair", data: $partQuantity)}
					}
				}

				CardView {
					VStack {
						SectionText(label: "PART SOURCE")
						LabeledContent {
							ModelPicker<Vendors1>(
								selection: $selectedVendor,
								title: "Supplier",
								includeEmptyChoice: true,
								emptyChoiceLabel: "—",
								autoSelectFirst: false,
								sort: [SortDescriptor(\.vendorName, order: .forward)],
								labelProvider: { v in v.vendorName },
								onSelectionChanged: { sel in
									partSupplier = sel?.vendorName ?? ""
									supplierWebsite = sel?.vendorWebsite ?? ""
									// Picking an existing supplier supersedes any in-progress "new supplier" entry.
									if sel != nil { newSupplierName = "" }
								}
							)
							.fixedSize(horizontal: true, vertical: true)
						} label: {
							Text("Supplier")
								.textLabelModified()
						}

						HStack{LabelDataTextview(label: "New Supplier", data: $newSupplierName)}
						Text("Not in the list above? Type a name here to add it as a new supplier when you save.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .trailing)
						HStack{LabelDataTextview(label: "Website", data: $supplierWebsite)}
						HStack{LabelDataTextview(label: "Source", data: $partSource)}
						HStack{LabelDataTextview(label: "Location", data: $partLocation)}
						HStack{LabelDataTextview(label: "Status", data: $partStatus)}
					}
				}
				
				CardView {
					VStack {
#if os(macOS)
						SectionText(label: "PARTS GRAPHICS")
#elseif os(iOS)
						SectionText(label: "  PARTS GRAPHICS\n(Click Image to Change)")
#endif
						HStack {Image_Edit(label: "1", imageData: $image1, imageDescription: $image1Description)}
						HStack {Image_Edit(label: "2", imageData: $image2, imageDescription: $image2Description)}
						HStack {Image_Edit(label: "3", imageData: $image3, imageDescription: $image3Description)}
					}
				}
				CardView {
					VStack {
						SectionText(label: "STATUS")
						HStack{LabelDataToggle(label: "Deactivate Parts Record", data: $inactive)}
						Text("When selected, this record is marked as inactive. It will be hidden in lists and pickers, but its data remains available for viewing and editing, and can be un-hidden by selecting 'View Inactive' on the 'Settings' screen.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
				}

			}// end of scroll

			.onAppear {
				// Preselect the Vehicle picker from the current vehicleId when possible.
				if vehicleId.isEmpty || vehicleId == "All Vehicles" {
					selectedVehicle = nil
				} else {
					selectedVehicle = vehicles.first(where: { $0.name == vehicleId })
				}

				// Preselect the Vendor picker from the current partSupplier when possible.
				// Source is a separate, independent field and is intentionally never used
				// to infer or auto-create a supplier.
				if !partSupplier.isEmpty {
					selectedVendor = vendors.first(where: { $0.vendorName == partSupplier })
					supplierWebsite = selectedVendor?.vendorWebsite ?? ""
				} else {
					selectedVendor = nil
					supplierWebsite = ""
				}
				newSupplierName = ""
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			// title area
			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "edit",
					dbRecord: "part")
			}

			.toolbar {
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "Cancel" : "Edit") {
						isEditing.toggle()
					}
					.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("Save") {
						let trimmedName = trimmed(partName)
						let oldName = dataSet.partName
						if oldName != trimmedName && hasLinkedRecords(oldName) {
							showingRenameChoice = true
						} else {
							updateItem()
							isEditing.toggle()
						}
					}
					.buttonStyle(GrowingButton(buttonColor: Color.red))
					.confirmationDialog(
						"Part Name Changed",
						isPresented: $showingRenameChoice,
						titleVisibility: .visible
					) {
						Button("Update Linked Records") {
							renameLinkedRecords(from: dataSet.partName, to: trimmed(partName))
							updateItem()
							isEditing.toggle()
						}
						Button("Save Without Updating Links", role: .destructive) {
							updateItem()
							isEditing.toggle()
						}
						Button("Cancel", role: .cancel) { }
					} message: {
						Text("Renaming \"\(dataSet.partName)\" to \"\(trimmed(partName))\" will break its links to other records unless they're updated to the new name. Update them now?")
					}
				}
			}

		} else {
			
			// display data
			ScrollView {
				VStack{CreatedUpdatedText(created: createdAt, updated: updatedAt)}
				
				CardView {
					VStack{
						SectionText(label: "GENERAL")
						HStack{LabelDataText(label: Vertical.current.assetSingular, data: Functions().getVehicleDisplayName(vehicleId: dataSet.vehicleId, context: modelContext))}
						HStack{LabelDataText(label: "\(Vertical.current.assetSingular) System", data: functions.cleanOptional(inputString: dataSet.vehicleSystem))}
						HStack{LabelDataText(label: "Status", data: dataSet.inactive ? "Inactive" : "Active")}
					}
				}
				
				CardView {
					VStack{
						SectionText(label: "PART DETAILS")
						HStack{LabelDataText(label: "Name", data: functions.cleanOptional(inputString: dataSet.partName))}
						if dataSet.partDescription != "" {
							HStack{LabelDataText(label: "Description", data: functions.cleanOptional(inputString: dataSet.partDescription))}
						}
						if dataSet.vehicleSystem != "" {
							HStack{LabelDataText(label: "System", data: functions.cleanOptional(inputString: dataSet.vehicleSystem))}
						}
						if dataSet.partNumber != "" {
							HStack{LabelDataText(label: "Part #", data: functions.cleanOptional(inputString: dataSet.partNumber))}
						}
						if dataSet.partManufacture != "" {
							HStack{LabelDataText(label: "Manufacturer", data: functions.cleanOptional(inputString: dataSet.partManufacture))}
						}
					}
				}
				
				if dataSet.Notes != "" {CardView {
					TextNoteDisplay_FullWidth(sectionText: "PART NOTES", data: dataSet.Notes)}
				}

				// Hidden unless this part is inventory-tracked
				if dataSet.inventoryTracked {
					CardView {
					VStack{
						SectionText(label: "INVENTORY TRACKING")
						let isLowStock = dataSet.inventoryQuantityOnHand <= dataSet.inventoryReorderPoint
						HStack{LabelDataText(label: "Quantity On Hand", data: "\(dataSet.inventoryQuantityOnHand.formatted(.number.precision(.fractionLength(0...2)))) \(dataSet.partUnit)")}
							.foregroundColor(isLowStock ? .red : .primary)
						if dataSet.inventoryReorderPoint != 0 {
							HStack{LabelDataText(label: "Reorder Point", data: "\(dataSet.inventoryReorderPoint.formatted(.number.precision(.fractionLength(0...2)))) \(dataSet.partUnit)")}
						}
						if dataSet.inventoryReorderQuantity != 0 {
							HStack{LabelDataText(label: "Reorder Quantity", data: "\(dataSet.inventoryReorderQuantity.formatted(.number.precision(.fractionLength(0...2)))) \(dataSet.partUnit)")}
						}
						if isLowStock {
							Text("Low stock — quantity on hand is at or below the reorder point.")
								.font(.caption)
								.foregroundStyle(.red)
								.frame(maxWidth: .infinity, alignment: .leading)
						}
					}
					}
				}

				// Hidden when no cost fields have data
				if hasPartCosts {
					CardView {
					VStack{
						SectionText(label: "PART COSTS")
						if dataSet.costPerUnit != 0 {
							HStack{LabelDataText(label: "Cost/Unit", data: "\(functions.formatCurrency(dollars: dataSet.costPerUnit)) / \(dataSet.partUnit)")}
						}
						if dataSet.partUnit != "" {
							HStack{LabelDataText(label: "Unit Type", data: functions.cleanOptional(inputString: dataSet.partUnit))}
						}
						if dataSet.partQuantity != 0 {
							HStack{LabelDataText(label: "Quantity Used/Repair", data: "\(dataSet.partQuantity) \(dataSet.partUnit)")}
						}
					}
					}
				}

				// Hidden when no source fields have data
				if hasPartSource {
					CardView {
					VStack{
						SectionText(label: "PART SOURCE")
						if dataSet.partSource != "" {
							HStack{LabelDataText(label: "Source", data: functions.cleanOptional(inputString: dataSet.partSource))}
						}
						if dataSet.partLocation != "" {
							HStack{LabelDataText(label: "Location", data: functions.cleanOptional(inputString: dataSet.partLocation))}
						}
						if dataSet.partStatus != "" {
							HStack{LabelDataText(label: "Status", data: functions.cleanOptional(inputString: dataSet.partStatus))}
						}
					}
					}
				}

				// Full supplier record details, shown only when the part's Supplier
				// matches a known `Vendors1` record — so all its saved contact info and a
				// hyperlinked website are visible without leaving the part. The Supplier
				// name itself leads this card rather than the Part Source one above, since
				// it belongs to the vendor record, not the part.
				if let supplier = matchedSupplier {
					CardView {
					VStack {
						SectionText(label: "SUPPLIER DETAILS")
						HStack{LabelDataText(label: "Supplier", data: supplier.vendorName)}
						if supplier.vendorType != "" {
							HStack{LabelDataText(label: "Vendor Type", data: supplier.vendorType)}
						}
						if supplier.vendorContact1 != "" {
							HStack{LabelDataText(label: "Contact 1", data: supplier.vendorContact1)}
						}
						if supplier.vendorContact2 != "" {
							HStack{LabelDataText(label: "Contact 2", data: supplier.vendorContact2)}
						}
						if supplier.vendorContact3 != "" {
							HStack{LabelDataText(label: "Contact 3", data: supplier.vendorContact3)}
						}
						if supplier.vendorAddress != "" {
							HStack{LabelDataText(label: "Address", data: supplier.vendorAddress)}
						}
						if supplier.vendorCity != "" {
							HStack{LabelDataText(label: "City", data: supplier.vendorCity)}
						}
						if supplier.vendorState != "" {
							HStack{LabelDataText(label: "State", data: supplier.vendorState)}
						}
						if supplier.vendorZip != "" {
							HStack{LabelDataText(label: "Zip Code", data: supplier.vendorZip)}
						}
						if supplier.vendorPhone != "" {
							HStack{LabelDataText(label: "Phone", data: supplier.vendorPhone)}
						}
						if supplier.vendorEmail != "" {
							HStack{LabelDataText(label: "Email", data: supplier.vendorEmail)}
						}
						if supplier.vendorWebsite != "" {
							HStack{LabelDataLink(label: "Website", data: supplier.vendorWebsite)}
						}
						if supplier.vendorNotes != "" {
							HStack{LabelDataText(label: "Notes", data: supplier.vendorNotes)}
						}
					}
					}
				}

				// Hidden when no images are attached
				if hasGraphics {
					CardView {
					VStack {
						SectionText(label: "PARTS GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
					}
					}
				}
			}
			.listStyle(.automatic)
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			// title area
			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "details",
					dbRecord: "part")
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
		}
	}
	// MARK: - Details section visibility
	// Card sections in Details mode are only rendered when at least one of their
	// fields holds data, so a section title never appears above an empty card.

	/// True when any cost field has data.
	private var hasPartCosts: Bool {
		dataSet.costPerUnit != 0 || !dataSet.partUnit.isEmpty || dataSet.partQuantity != 0
	}

	/// True when any source field has data. Supplier isn't counted here — it's now
	/// displayed as the lead line of the separate "Supplier Details" card.
	private var hasPartSource: Bool {
		!(dataSet.partSource.isEmpty
		  && dataSet.partLocation.isEmpty
		  && dataSet.partStatus.isEmpty)
	}

	/// True when at least one image is attached.
	private var hasGraphics: Bool {
		dataSet.image1 != nil || dataSet.image2 != nil || dataSet.image3 != nil
	}

	/// Looks up the `Vendors1` record matching the part's current supplier, so Details mode
	/// can surface the full supplier record — including a hyperlinked website — without
	/// duplicating that data on `MxParts1`. Source is a separate field and is never used here;
	/// Supplier and Source represent two distinct concepts and shouldn't be conflated.
	private var matchedSupplier: Vendors1? {
		guard !dataSet.partSupplier.isEmpty else { return nil }
		return vendors.first(where: { $0.vendorName == dataSet.partSupplier })
	}

	/// Commits staged edits from local `@State` back to `dataSet` and saves the context.
	///
	/// This method mirrors all editable properties from the view's state to the
	/// underlying `MxParts1` instance, updates the `updatedAt` timestamp, and attempts
	/// to persist the changes using the SwiftData `modelContext`.
	///
	/// - Note: Consider surfacing save failures to the user with an alert.
	private func updateItem() {
		// Synchronize all fields from view state back into the persisted model.
		dataSet.inactive = inactive
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.vehicleId = vehicleId
		dataSet.vehicleSystem = vehicleSystem
		dataSet.partName = trimmed(partName)
		dataSet.partNumber = partNumber
		dataSet.partManufacture = partManufacture
		dataSet.partDescription = partDescription
		dataSet.Notes = Notes
		dataSet.costPerUnit = costPerUnit
		dataSet.partUnit = partUnit
		dataSet.partSource = partSource
		dataSet.partQuantity = partQuantity
		dataSet.partLocation = partLocation
		dataSet.partStatus = partStatus
		dataSet.inventoryTracked = inventoryTracked
		dataSet.inventoryQuantityOnHand = inventoryQuantityOnHand
		dataSet.inventoryReorderPoint = inventoryReorderPoint
		dataSet.inventoryReorderQuantity = inventoryReorderQuantity
		dataSet.image1 = image1
		dataSet.image2 = image2
		dataSet.image3 = image3
		dataSet.image1Description = image1Description
		dataSet.image2Description = image2Description
		dataSet.image3Description = image3Description

		createSystemIfNeeded()
		// Resolve the Supplier — creating/updating the Vendors1 record as needed — and stamp
		// the resolved name onto the part. Source (dataSet.partSource, above) is unrelated.
		partSupplier = resolveAndSyncSupplier()
		dataSet.partSupplier = partSupplier
		newSupplierName = ""

		// Attempt to persist all changes to the model context.
		do {
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
	}

	/// If the user typed a vehicle system name that doesn't already exist for this
	/// vehicle, create a new `VehicleSystems1` record so it's available for future selection.
	private func createSystemIfNeeded() {
		let name = vehicleSystem.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !name.isEmpty else { return }
		let vId = vehicleId
		let fetch = FetchDescriptor<VehicleSystems1>(predicate: #Predicate<VehicleSystems1> {
			$0.systemName == name && $0.vehicleId == vId
		})
		let exists = (try? modelContext.fetch(fetch))?.isEmpty == false
		guard !exists else { return }
		let newSystem = VehicleSystems1(
			vehicleId: vId,
			systemName: name,
			systemDescription: "",
			systemType: "",
			systemManufacturer: "",
			systemModel: "",
			systemSerialNumber: "",
			systemPartNumber: "",
			systemLocation: "",
			systemStatus: "",
			systemNotes: "",
			systemImage: nil
		)
		modelContext.insert(newSystem)
	}

	/// Resolves the part's Supplier and persists that choice into the `Vendors1` database,
	/// then returns the name that should be stamped onto `dataSet.partSupplier`.
	/// - If the "New Supplier" field has text, that takes priority: a new `Vendors1` record is
	///   created (or, if the name already exists, updated) with the current Website value.
	/// - Otherwise, if a supplier was picked from the Supplier dropdown, that record's website
	///   is updated directly.
	/// - Otherwise the existing `partSupplier` value (if any) is left as-is; a plain, unmatched
	///   name is not auto-vivified into a new vendor record.
	private func resolveAndSyncSupplier() -> String {
		let website = normalizeURL(trimmed(supplierWebsite))
		let newName = trimmed(newSupplierName)

		if !newName.isEmpty {
			let fetch = FetchDescriptor<Vendors1>(predicate: #Predicate<Vendors1> {
				$0.vendorName == newName
			})
			if let existing = (try? modelContext.fetch(fetch))?.first {
				existing.vendorWebsite = website
				existing.updatedAt = Date()
			} else {
				let newVendor = Vendors1(
					createdAt: Date(),
					updatedAt: Date(),
					vendorName: newName,
					vendorType: "",
					vendorContact1: "",
					vendorContact2: "",
					vendorContact3: "",
					vendorAddress: "",
					vendorCity: "",
					vendorState: "",
					vendorZip: "",
					vendorPhone: "",
					vendorEmail: "",
					vendorWebsite: website,
					vendorNotes: ""
				)
				modelContext.insert(newVendor)
			}
			return newName
		}

		if let vendor = selectedVendor {
			vendor.vendorWebsite = website
			vendor.updatedAt = Date()
			return vendor.vendorName
		}

		return partSupplier
	}

	/// Permanently deletes the current `MxParts1` record and dismisses the view.
	///
	/// Removes `dataSet` from the `modelContext` and saves. If saving fails, the error
	/// is printed to the console. The view is dismissed after the operation.
	private func DeleteRecord(){
		// Remove the object from the context and persist the deletion.
		do {
			modelContext.delete(dataSet)
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
		// Close the view after deletion to return to the previous screen.
		dismiss()
	}
	/// Marks the current `MxParts1` record as inactive and persists the change.
	///
	/// This helper sets both the underlying model (`dataSet`) and the view's local
	/// state (`inactive`) to `true`, updates the `updatedAt` timestamp, and then
	/// attempts to save the change to the SwiftData `modelContext`. If saving
	/// succeeds, the view is dismissed. If saving fails, an error is printed to the
	/// console and the view is still dismissed to keep the flow consistent with the
	/// destructive action.
	///
	/// Behavior details:
	/// - Sets `dataSet.inactive` to `true` so the persisted record is marked inactive.
	/// - Mirrors that value to the view state `inactive` so the UI reflects the change immediately.
	/// - Updates `dataSet.updatedAt` to the current time to reflect the modification.
	/// - Saves the context to persist the change.
	/// - Dismisses the sheet/view regardless of save outcome (you can adjust this
	///   if you prefer to keep the view open on failure).
	///
	/// Side effects:
	/// - Persists changes to the model context.
	/// - Dismisses the current view using `@Environment(\.dismiss)`.
	///
	/// - Note: Consider surfacing save failures to the user with an alert if needed.
	private func makeInactive() {
		// Mark the underlying model as inactive so the persisted record reflects the change.
		dataSet.inactive = true

		// Keep the view's local state in sync so any UI bound to `inactive` updates immediately.
		inactive = true

		// Record the modification time for auditing/sorting purposes.
		dataSet.updatedAt = Date()

		// Attempt to persist the change to the SwiftData model context.
		do {
			try modelContext.save()
		} catch {
			// In production, consider presenting a user-facing alert instead of just printing.
			print("Failed to mark inactive: \(error.localizedDescription)")
		}

		// Close the current view regardless of save success to maintain a consistent flow
		// after a destructive or terminal action. Adjust if you prefer to remain on screen
		// when persistence fails.
		dismiss()
	}

	/// True if any other record references `name` by part name. Used to decide whether the
	/// rename-cascade dialog is worth showing — a brand-new or never-referenced part has
	/// nothing to break, so saving proceeds silently.
	private func hasLinkedRecords(_ name: String) -> Bool {
		guard !name.isEmpty else { return false }
		func exists<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> Bool {
			var fd = descriptor
			fd.fetchLimit = 1
			return ((try? modelContext.fetch(fd)) ?? []).isEmpty == false
		}
		if exists(FetchDescriptor<ServiceRecords1>(predicate: #Predicate {
			$0.part1 == name || $0.part2 == name || $0.part3 == name || $0.part4 == name || $0.part5 == name
		})) { return true }
		if exists(FetchDescriptor<MxItems3>(predicate: #Predicate {
			$0.part1 == name || $0.part2 == name || $0.part3 == name || $0.part4 == name || $0.part5 == name
		})) { return true }
		if exists(FetchDescriptor<ProjectList>(predicate: #Predicate {
			$0.part1 == name || $0.part2 == name || $0.part3 == name || $0.part4 == name || $0.part5 == name
		})) { return true }
		return false
	}

	/// Updates every other record type that references this part by name (LandShip's
	/// string-based linking convention — the same one used for vendor and vehicle renames),
	/// so existing links survive a part rename instead of silently orphaning.
	private func renameLinkedRecords(from oldName: String, to newName: String) {
		guard !oldName.isEmpty, oldName != newName else { return }

		func rename<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, _ apply: (T) -> Void) {
			guard let records = try? modelContext.fetch(descriptor), !records.isEmpty else { return }
			records.forEach(apply)
		}

		rename(FetchDescriptor<ServiceRecords1>(predicate: #Predicate { $0.part1 == oldName })) { $0.part1 = newName }
		rename(FetchDescriptor<ServiceRecords1>(predicate: #Predicate { $0.part2 == oldName })) { $0.part2 = newName }
		rename(FetchDescriptor<ServiceRecords1>(predicate: #Predicate { $0.part3 == oldName })) { $0.part3 = newName }
		rename(FetchDescriptor<ServiceRecords1>(predicate: #Predicate { $0.part4 == oldName })) { $0.part4 = newName }
		rename(FetchDescriptor<ServiceRecords1>(predicate: #Predicate { $0.part5 == oldName })) { $0.part5 = newName }
		rename(FetchDescriptor<MxItems3>(predicate: #Predicate { $0.part1 == oldName })) { $0.part1 = newName }
		rename(FetchDescriptor<MxItems3>(predicate: #Predicate { $0.part2 == oldName })) { $0.part2 = newName }
		rename(FetchDescriptor<MxItems3>(predicate: #Predicate { $0.part3 == oldName })) { $0.part3 = newName }
		rename(FetchDescriptor<MxItems3>(predicate: #Predicate { $0.part4 == oldName })) { $0.part4 = newName }
		rename(FetchDescriptor<MxItems3>(predicate: #Predicate { $0.part5 == oldName })) { $0.part5 = newName }
		rename(FetchDescriptor<ProjectList>(predicate: #Predicate { $0.part1 == oldName })) { $0.part1 = newName }
		rename(FetchDescriptor<ProjectList>(predicate: #Predicate { $0.part2 == oldName })) { $0.part2 = newName }
		rename(FetchDescriptor<ProjectList>(predicate: #Predicate { $0.part3 == oldName })) { $0.part3 = newName }
		rename(FetchDescriptor<ProjectList>(predicate: #Predicate { $0.part4 == oldName })) { $0.part4 = newName }
		rename(FetchDescriptor<ProjectList>(predicate: #Predicate { $0.part5 == oldName })) { $0.part5 = newName }

		do {
			try modelContext.save()
		} catch {
			print("Failed to update linked records after part rename: \(error.localizedDescription)")
		}
	}
}

// MARK: - Normalization helpers
private extension EditParts {
	/// Trims leading and trailing whitespace/newlines from the provided string.
	func trimmed(_ s: String) -> String {
		s.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	/// Ensures the provided URL string has an explicit scheme.
	/// - If the string is empty, returns it as-is.
	/// - If no `http://` or `https://` prefix is found, prefixes with `https://`.
	func normalizeURL(_ s: String) -> String {
		guard !s.isEmpty else { return s }
		let lower = s.lowercased()
		if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
			return s
		}
		return "https://\(s)"
	}
}

#Preview("EditParts Preview with sample MxParts1") {
	makeEditPartsPreview()
}

/// Builds an in-memory model container and seeds related data for previews.
///
/// Inserts a vehicle, system, vendor, and a sample `MxParts1` record so both the
/// read-only and edit experiences can be exercised in Xcode previews.
@MainActor private func makeEditPartsPreview() -> some View {
	// In-memory container with related models available for pickers if you toggle Edit.
	let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(
		for: Vehicle8.self,
				VehicleSystems1.self,
				Vendors1.self,
				MxParts1.self,
				configurations: configuration
	)

	// Seed some related data so pickers have items
	let vehicle = Vehicle8(
		name: "Truck 1500",
		year: 2020,
		mileage: 42000,
		mileageVirtual: 0,
		engHours: 1234.5,
		fuelType: "Gasoline",
		fuelCapacity: 26,
		notes: "",
		vin: "",
		licensePlate: "",
		image1: nil,
		image1Description: "",
		image2: nil,
		image2Description: "",
		image3: nil,
		image3Description: ""
	)
	let system = VehicleSystems1(
		createdAt: Date(),
		updatedAt: Date(),
		vehicleId: vehicle.name,
		systemName: "Engine",
		systemDescription: "",
		systemType: "",
		systemManufacturer: "",
		systemModel: "",
		systemSerialNumber: "",
		systemPartNumber: "",
		systemLocation: "",
		systemStatus: "",
		systemNotes: "",
		systemImage: nil,
		image1: nil,
		image1Description: "",
		image2: nil,
		image2Description: "",
		image3: nil,
		image3Description: ""
	)
	let vendor = Vendors1(
		createdAt: Date(),
		updatedAt: Date(),
		vendorName: "Main Warehouse",
		vendorType: "",
		vendorContact1: "",
		vendorContact2: "",
		vendorContact3: "",
		vendorAddress: "",
		vendorCity: "",
		vendorState: "",
		vendorZip: "",
		vendorPhone: "",
		vendorEmail: "",
		vendorWebsite: "",
		vendorNotes: "",
		image1: nil,
		image1Description: "",
		image2: nil,
		image2Description: "",
		image3: nil,
		image3Description: ""
	)
	container.mainContext.insert(vehicle)
	container.mainContext.insert(system)
	container.mainContext.insert(vendor)

	// Seed a sample part
	let sample = MxParts1(
		createdAt: Date().addingTimeInterval(-86400),
		updatedAt: Date(),
		vehicleId: vehicle.name,
		vehicleSystem: system.systemName,
		partName: "Oil Filter",
		partNumber: "OF-9876",
		partManufacture: "FilterCo",
		partDescription: "High performance oil filter compatible with V8 engines.",
		Notes: "Replace every 5,000 miles.",
		costPerUnit: 12.99,
		partUnit: "each",
		partSource: "Aisle 3",
		partQuantity: 4,
		partLocation: "Bin B",
		partStatus: "In Stock",
		partImage: nil,
		partSupplier: vendor.vendorName,
		image1: nil,
		image1Description: "Box front",
		image2: nil,
		image2Description: "Filter element",
		image3: nil,
		image3Description: "Installed view"
	)
	container.mainContext.insert(sample)

	return EditParts(mxParts: sample)
		.modelContainer(container)
}

