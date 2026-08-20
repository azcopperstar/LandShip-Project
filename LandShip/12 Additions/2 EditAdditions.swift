//
//  EditMxRecord.swift
//  LandShip
//
//  Created by JP on 7/20/25.
//

import SwiftUI
import SwiftData

struct EditAdditions: View {
	// The record being edited or displayed.
	// Kept in @State to drive the UI; changes are written back on Save.
	@State private var dataSet: Additions

	// SwiftData environment context for fetching/saving/deleting.
	@Environment(\.modelContext) var modelContext

	// Dismiss handler for closing the view (e.g., after delete).
	@Environment(\.dismiss) private var dismiss

	// App-wide helper functions (formatting, fetch helpers, etc.).
	let functions: Functions = Functions()

	// Preferences accessor for units; loaded once on appear.
	let prefsFunc: PrefsFunctions = PrefsFunctions()
	@State private var units: [String] = Array(repeating: "", count: 13)
	private func unit(_ index: Int) -> String {
		// Safe unit accessor
		units.indices.contains(index) ? units[index] : ""
	}

	// UI state flags
	@State private var isPresentingConfirm: Bool = false  // Controls delete confirmation dialog
	@State private var isEditing: Bool = false            // Toggles between Edit and Details modes
	
	// Core fields mirrored from ServiceRecords1.
	// These are edited in Edit mode and written back to dataSet on Save.
	@State private var inactive: Bool = false
	@State private var createdAt = Date()
	@State private var updatedAt = Date()
	@State private var vehicleId = ""
	@State private var miles: Int = 0
	@State private var engHours: Float = 0
	@State private var itemName: String = ""
	@State private var itemDescription: String = ""
	@State private var itemNotes: String = ""
	@State private var itemVendor: String = ""
	@State private var category: String = ""
	@State private var subCategory: String = ""
	@State private var allCategories: [String] = []  // <-- Inserted array to hold all categories
	@State private var allSubCategories: [String] = []  // <-- Inserted array to hold all subcategories
    @State private var allVendors: [String] = []  // Holds all vendor names for picker
	@State private var itemCost: Float = 0

	// Optional images and captions for the record
	@State private var image1: Data?
	@State private var image2: Data?
	@State private var image3: Data?
	@State private var image4: Data?
	@State private var image5: Data?
	@State private var image1Description: String = ""
	@State private var image2Description: String = ""
	@State private var image3Description: String = ""
	@State private var image4Description: String = ""
	@State private var image5Description: String = ""

//	// Running costs (computed)
//	@State private var trackPartsCost1: Double = 0.0
//	@State private var trackPartsCost2: Double = 0.0
//	@State private var trackPartsCost3: Double = 0.0
//	@State private var trackPartsCost4: Double = 0.0
//	@State private var trackPartsCost5: Double = 0.0
//	@State private var trackPartsCostTotal: Double = 0.0
//	@State private var trackAllCostTotal: Double = 0.0
//
//	// Statistics derived from parts and totals
//	@State private var partsLinesCount: Int = 0
//	@State private var totalPartsQuantity: Int = 0
//	@State private var avgCostPerPartUnit: Double = 0.0
//	@State private var costPerMile: Double = 0.0
//	@State private var costPerEngineHour: Double = 0.0

	// Vehicle current stats and deltas since the service
	@State private var vehicleCurrentMiles: Int = 0
	@State private var vehicleCurrentEngHours: Float = 0.0
	@State private var milesSinceService: Int = 0
	@State private var hoursSinceService: Float = 0.0
	
	// Service item intervals (from MxItems3 template) and remaining values
	@State private var itemIntervalMiles: Int = 0
	@State private var itemIntervalMonths: Int = 0
	@State private var itemIntervalHours: Float = 0.0
	@State private var milesRemainingToDue: Int = 0
	@State private var hoursRemainingToDue: Float = 0.0
	@State private var daysRemainingToDue: Int = 0
	@State private var nextDueDate: Date? = nil

//	// Selections for generic pickers (ModelPicker<T>)
//	@State private var selectedServiceItem: MxItems3? = nil
	@State private var selectedVendor: Vendors1? = nil
//	@State private var selectedPart1: MxParts1? = nil
//	@State private var selectedPart2: MxParts1? = nil
//	@State private var selectedPart3: MxParts1? = nil
//	@State private var selectedPart4: MxParts1? = nil
//	@State private var selectedPart5: MxParts1? = nil
	@State private var selectedVehicle: Vehicle8? = nil

	// Initializer
	// Seeds all local @State fields from the incoming ServiceRecords1 record so the edit UI
	// can be fully controlled by local state. The Save action writes these back to dataSet.
	init(Records: Additions, startEditing: Bool = false) {
		self.dataSet = Records
		vehicleId = dataSet.vehicleId

		self._inactive = State.init(initialValue: dataSet.inactive)
		self._createdAt = State.init(initialValue: dataSet.createdAt)
		self._updatedAt = State.init(initialValue: dataSet.updatedAt)
		self._vehicleId = State.init(initialValue: dataSet.vehicleId)
		self._miles = State.init(initialValue: dataSet.miles)
		self._engHours = State.init(initialValue: dataSet.engHours)
		self._itemName = State.init(initialValue: dataSet.itemName)
		self._itemDescription = State .init(initialValue: dataSet.itemDescription)
		self._itemNotes = State.init(initialValue: dataSet.itemNotes)
		self._itemVendor = State.init(initialValue: dataSet.itemVendor)
		self._category = State.init(initialValue: dataSet.category)
		self._subCategory = State.init(initialValue: dataSet.subCategory)
		self._itemCost = State.init(initialValue: dataSet.itemCost)
		self._image1 = State.init(initialValue: dataSet.image1)
		self._image2 = State.init(initialValue: dataSet.image2)
		self._image3 = State.init(initialValue: dataSet.image3)
		self._image4 = State.init(initialValue: dataSet.image4)
		self._image5 = State.init(initialValue: dataSet.image5)
		self._image1Description = State.init(initialValue: dataSet.image1Description)
		self._image2Description = State.init(initialValue: dataSet.image2Description)
		self._image3Description = State.init(initialValue: dataSet.image3Description)
		self._image4Description = State.init(initialValue: dataSet.image4Description)
		self._image5Description = State.init(initialValue: dataSet.image5Description)

		// Start in edit mode if requested
		self._isEditing = State(initialValue: startEditing)
	}
	
	var body: some View {
		// The UI is split into Edit (interactive) and Details (read-only) modes.
		if isEditing {
			// EDIT MODE
			ScrollView {
				// GENERAL
				CardView {
					VStack {
						SectionText(label: "GENERAL")
						HStack{
							Text("Vehicle")
								.textLabelModified()

							ModelPicker(
								selection: $selectedVehicle,
								title: "Vehicle",
								includeEmptyChoice: false,
								emptyChoiceLabel: "—",
								autoSelectFirst: false,
								filter: nil,
								sort: [SortDescriptor(\.name, order: .forward)],
								labelProvider: { $0.displayName }
							)
							.frame(maxWidth: .infinity, alignment: .trailing)
							.onChange(of: selectedVehicle) { _, newVehicle in
								let name = newVehicle?.name ?? ""
								vehicleId = name
								dataSet.vehicleId = name
								refreshVehicleDetails()
								recomputeTotals()
							}
						}
//						// Service date
//						HStack{LabelDataPicker_Date(label: "Service Date", data: $mxDate)}
						// Inactive toggle
					}
				}
				
				// SERVICE ITEM DETAILS
				CardView {
					VStack {
						SectionText(label: "IMPROVEMENT DETAILS")
						
						// Manual overrides for the service item and descriptions
						TextFieldNote_FullWidth_3lines(sectionText: "Improvement Item Name", prompt: "Enter Item...", data: $itemName)
//						HStack{LabelDataTextview(label: "Improvement Item", data: $itemName)}

						// Multiline Description
						VStack(alignment: .leading, spacing: 6) {
							TextFieldNote_FullWidth_3lines(sectionText: "Improvement Item Description", prompt: "Enter Description...", data: $itemDescription)

							TextFieldNote_FullWidth_3lines(sectionText: "Improvement Item Notes", prompt: "Enter Notes...", data: $itemNotes)

							HStack{LabelDataTextview_Numberpad_Currency(label: "Item Cost", data: $itemCost)}
								.onChange(of: itemCost) { _, _ in recomputeTotals() }
							
						}

						// Vendor selection (free text + menu)
						// Free text entry + menu of existing vendors
						HStack(spacing: 8) {
								Menu {
										Button("—") { itemVendor = ""; dataSet.itemVendor = "" }
										ForEach(allVendors, id: \.self) { name in
												Button(name) {
														itemVendor = name
														dataSet.itemVendor = name
												}
										}
								} label: {
										Label("Vendor", systemImage: "line.3.horizontal.decrease.circle")
								}
								.menuStyle(.borderlessButton)
							TextField("Enter or pick a vendor", text: $itemVendor)
								.textFieldStyle(.roundedBorder)
								.onChange(of: itemVendor) { _, newValue in
									dataSet.itemVendor = newValue
								}
							
						}
						.frame(maxWidth: .infinity, alignment: .trailing)
						.onAppear {
								// Seed from model and load vendor names
								itemVendor = dataSet.itemVendor
								loadAllVendors()
						}

						// Category entry with suggestions
						VStack(alignment: .leading, spacing: 8) {
								HStack(spacing: 8) {
										// Picker of existing categories
										Menu {
												// Show a clear option
												Button("—") { category = ""; dataSet.category = ""; loadAllSubCategories() }
												// List all known categories
												ForEach(allCategories, id: \.self) { cat in
														Button(cat) {
																category = cat
																dataSet.category = cat
																loadAllSubCategories()
														}
												}
										} label: {
												Label("Category", systemImage: "line.3.horizontal.decrease.circle")
										}
										.menuStyle(.borderlessButton)
									// Free text entry
									TextField("Enter or pick a category", text: $category)
										.textFieldStyle(.roundedBorder)
										.onChange(of: category) { _, newValue in
											dataSet.category = newValue
											loadAllSubCategories()
										}
								}
								.frame(maxWidth: .infinity, alignment: .leading)
								.onAppear {
										// Seed from model on first appear
										if category.isEmpty { category = dataSet.category }
								}
						}

						// subCategory entry with suggestions
						VStack(alignment: .leading, spacing: 8) {
							HStack(spacing: 8) {
								// Picker of existing subcategories
								Menu {
									// Show a clear option
									Button("—") { subCategory = ""; dataSet.subCategory = "" }
									// List all known categories
									ForEach(allSubCategories, id: \.self) { subcat in
										Button(subcat) {
											subCategory = subcat
											dataSet.subCategory = subcat
										}
									}
								} label: {
									Label("Sub-Category", systemImage: "line.3.horizontal.decrease.circle")
								}
								.menuStyle(.borderlessButton)
								// Free text entry
								TextField("Enter or pick a sub-category", text: $subCategory)
									.textFieldStyle(.roundedBorder)
									.onChange(of: subCategory) { _, newValue in
										dataSet.subCategory = newValue
									}
							}
							.frame(maxWidth: .infinity, alignment: .leading)
							.onAppear {
								// Seed from model on first appear
								if subCategory.isEmpty { subCategory = dataSet.subCategory }
								loadAllSubCategories()
							}
						}
					}
				}
				
				// SERVICE COMPLETED AT
				CardView {
					VStack {
						SectionText(label: "ITEM INSTALLED / PURCHASED")
						// Mileage and engine hours at the time of service
						HStack{LabelDataTextview_Numberpad_Int(label: "Distance (\(unit(UnitIndex.distance)))", data: $miles)}
							.onChange(of: miles) { _, _ in recomputeTotals() }
						HStack{LabelDataTextview_Numberpad_Float(label: "Engine Hours", data: $engHours)}
							.onChange(of: engHours) { _, _ in recomputeTotals() }
					}
				}
				
				CardView {
					VStack {
#if os(macOS)
						SectionText(label: "RECORDS GRAPHICS")
#elseif os(iOS)
						SectionText(label: "  ITEM GRAPHICS\n(Click Image to Change)")
#endif
						HStack {Image_Edit(label: "1", imageData: $image1, imageDescription: $image1Description)}
						HStack {Image_Edit(label: "2", imageData: $image2, imageDescription: $image2Description)}
						HStack {Image_Edit(label: "3", imageData: $image3, imageDescription: $image3Description)}
						HStack {Image_Edit(label: "4", imageData: $image4, imageDescription: $image4Description)}
						HStack {Image_Edit(label: "5", imageData: $image5, imageDescription: $image5Description)}
					}
				}
				CardView {
					VStack {
						SectionText(label: "STATUS")
						HStack{LabelDataToggle(label: "Deactivate Item Record", data: $inactive)}
						Text("When selected, this record is marked as inactive. It will be hidden in lists and pickers, but its data remains available for viewing and editing, and can be un-hidden by selecting 'View Inactive' on the 'Settings' screen.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
				}

				
			}// end of edit scroll view

			.frame(maxWidth: .infinity, maxHeight: .infinity)

			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "edit",
					dbRecord: "item")
			}

			.onAppear {
				// Load display units (e.g., miles vs km), vehicle stats, and intervals.
				// Seed pickers from existing model values.
				loadUnits()
				refreshVehicleDetails()
//				loadItemIntervalsIfNeeded()
				recomputeTotals()

				// Seed the vehicle picker from existing vehicleId if present
				if selectedVehicle == nil, !vehicleId.isEmpty {
					let name = vehicleId
					var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == name })
					fd.fetchLimit = 1
					if let v = try? modelContext.fetch(fd).first {
						selectedVehicle = v
					}
				}

				// Seed vendor selection if needed
				if selectedVendor == nil, !dataSet.itemVendor.isEmpty {
					let name = dataSet.itemVendor
					var fdV = FetchDescriptor<Vendors1>(predicate: #Predicate { $0.vendorName == name })
					fdV.fetchLimit = 1
					if let v = try? modelContext.fetch(fdV).first {
						selectedVendor = v
					}
				}
                
				// Load all categories from saved records
				loadAllCategories()
				if category.isEmpty { category = dataSet.category }

				// Load all subcategories from saved records
				loadAllSubCategories()
				if subCategory.isEmpty { subCategory = dataSet.subCategory }

				// Load all vendors
				loadAllVendors()
			}
			.toolbar {
				// Edit mode toolbar: label, Cancel toggle, Save
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "Cancel" : "Edit") {isEditing.toggle()}
						.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("Save") {
						// Tapping Save writes all local state back into dataSet and persists it.
						isEditing.toggle()
						updateItem()
					}
					.buttonStyle(GrowingButton(buttonColor: Color.red))
				}
			}

		} else {

			// DETAILS MODE (read-only, formatted)
			ScrollView {
				// Created/Updated timestamps
				VStack{CreatedUpdatedText(created: createdAt, updated: updatedAt)}

				// GENERAL
				CardView {
					VStack {
						SectionText(label: "GENERAL")
						HStack{LabelDataText(label: "Vehicle", data: Functions().getVehicleDisplayName(vehicleId: dataSet.vehicleId, context: modelContext))}
						HStack{LabelDataText(label: "Status", data: dataSet.inactive ? "INACTIVE" : "ACTIVE")}
						HStack{LabelDataCurrency(label: "Cost", data: Float(itemCost), unit: "")}
					}
				}
				
				// SERVICE ITEM DETAILS
				CardView {
					VStack {
						SectionText(label: "")
						if dataSet.itemName != "" {CardView {
							TextNoteDisplay_FullWidth(sectionText: "ITEM NAME", data: dataSet.itemName)}
						}

						if dataSet.itemDescription != "" {CardView {
							TextNoteDisplay_FullWidth(sectionText: "ITEM DESCRIPTION", data: dataSet.itemDescription)}
						}

						if dataSet.itemVendor != "" {CardView {
							TextNoteDisplay_FullWidth(sectionText: "VENDOR", data: dataSet.itemVendor)}
						}
						if dataSet.category != "" {CardView {
							TextNoteDisplay_FullWidth(sectionText: "CATEGORY", data: dataSet.category)}
						}
						if dataSet.subCategory != "" {CardView {
							TextNoteDisplay_FullWidth(sectionText: "SUB-CATEGORY", data: dataSet.subCategory)}
						}
					}
				}
				
				if dataSet.itemNotes != "" {CardView {
					TextNoteDisplay_FullWidth(sectionText: "IMPROVEMENT ITEM NOTES", data: dataSet.itemNotes)}
				}
				
				// SERVICE COMPLETED AT
				CardView {
					VStack {
						SectionText(label: "PURCHASED / INSTALLED")
						if dataSet.miles > 0 {
							HStack{LabelDataText(label: "Distance", data: "\(dataSet.miles) \(unit(UnitIndex.distance))")}
						}
						if dataSet.engHours > 0 {
							HStack{LabelDataNumber(label: "Engine Hours", data: Float(dataSet.engHours), fractionalLength: 1)}
						}
					}
				}
				
				// SERVICE RECORDS GRAPHICS (read-only images)
				CardView {
					VStack {
						SectionText(label: "IMPROVEMENT GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
						Image_View_Details(label:"4", imageData: dataSet.image4, imageDescription: dataSet.image4Description)
						Image_View_Details(label:"5", imageData: dataSet.image5, imageDescription: dataSet.image5Description)
					}
				}

			}//end of details scroll view
			
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "details",
					dbRecord: "item")
			}

			.onAppear {
				// Keep derived values up-to-date when entering details mode
				loadUnits()
				refreshVehicleDetails()
//				loadItemIntervalsIfNeeded()
				recomputeTotals()
			}

			.toolbar {
				// Details toolbar: label, Edit toggle, Delete
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

	// Deletes the current record from SwiftData and dismisses the view.
	private func DeleteRecord(){
		do {
			modelContext.delete(dataSet)
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
		dismiss()
	}

	// Marks the record inactive and saves it.
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

	// Persists changes from local @State back to the SwiftData model, then
	// updates related Vehicle8 odometer/hours if needed, and refreshes derived values.
	private func updateItem() {
		// Copy all edited values back into the model
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.inactive = inactive
		dataSet.vehicleId = vehicleId
		dataSet.miles = miles
		dataSet.engHours = engHours
		dataSet.itemName = itemName
		dataSet.itemDescription = itemDescription
		dataSet.itemNotes = itemNotes
		dataSet.itemVendor = itemVendor
		dataSet.category = category
		dataSet.subCategory = subCategory
		dataSet.itemCost = itemCost
		dataSet.image1 = image1
		dataSet.image2 = image2
		dataSet.image3 = image3
		dataSet.image4 = image4
		dataSet.image5 = image5
		dataSet.image1Description = image1Description
		dataSet.image2Description = image2Description
		dataSet.image3Description = image3Description
		dataSet.image4Description = image4Description
		dataSet.image5Description = image5Description

		// Save the record
		do {
			try modelContext.save()
			
			
			// Ensure the vendor exists in Vendors1 if a new name was entered
			let name = itemVendor.trimmingCharacters(in: .whitespacesAndNewlines)
			if !name.isEmpty {
				var fdV = FetchDescriptor<Vendors1>(predicate: #Predicate { $0.vendorName == name })
				fdV.fetchLimit = 1
				let existing: Vendors1? = try modelContext.fetch(fdV).first
				if existing == nil {
					makeNewVendor(vendorName: name)
					loadAllVendors()
				}
			}
		} catch {
			print(error.localizedDescription)
		}

		
//		// Update the related vehicle's odometer and engine hours if the service record exceeds current values
//		var fetchDescriptor = FetchDescriptor<Vehicle8>(
//			predicate: #Predicate { $0.name == vehicleId }
//		)
//		fetchDescriptor.fetchLimit = 1
//		do {
//			if let vehicleRecord = try modelContext.fetch(fetchDescriptor).first {
//				if miles > vehicleRecord.mileage {
//					vehicleRecord.mileage = miles
//					vehicleRecord.updatedAt = Date()
//				}
//				if engHours > vehicleRecord.engHours {
//					vehicleRecord.engHours = engHours
//				}
//				try? modelContext.save()
//			}
//		} catch {
//			print("Failed to update vehicle: \(error.localizedDescription)")
//		}
		// Refresh derived info after save
		refreshVehicleDetails()
		recomputeTotals()
	}

	// MARK: - Helpers

	// Loads user-preference units from Settings1 via PrefsFunctions.
	private func loadUnits() {
		if let arr = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1") {
			self.units = arr
		}
	}

	@discardableResult
	private func makeNewVendor(vendorName: String) -> Vendors1 {
	    let vendor = Vendors1(
	        inactive: false, createdAt: Date(),
	        updatedAt: Date(),
	        vendorName: vendorName,
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
	    modelContext.insert(vendor)
	    do {
	        try modelContext.save()
	    } catch {
	        print("Failed to save new vendor: \(error.localizedDescription)")
	    }
	    return vendor
	}

	// Looks up the current vehicle's odometer and engine hours for display and deltas.
	private func refreshVehicleDetails() {
		if let details = functions.loadVehicleDetails(context: modelContext, vehicleId: vehicleId.isEmpty ? dataSet.vehicleId : vehicleId) {
			vehicleCurrentMiles = details.mileage
			vehicleCurrentEngHours = details.engHours
		} else {
			vehicleCurrentMiles = 0
			vehicleCurrentEngHours = 0
		}
	}

    // Loads distinct categories from all saved Additions records
    private func loadAllCategories() {
			let fd = FetchDescriptor<Additions>()
        do {
            let records = try modelContext.fetch(fd)
            let set = Set(records.map { $0.category }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            self.allCategories = set.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        } catch {
            self.allCategories = []
        }
    }
	// Loads distinct categories from all saved Additions records
	private func loadAllSubCategories() {
		let fd = FetchDescriptor<Additions>()
		do {
			let records = try modelContext.fetch(fd)
			let set = Set(records.map { $0.subCategory }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
			self.allSubCategories = set.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
		} catch {
			self.allSubCategories = []
		}
	}
    
    // Loads distinct vendor names from Vendors1 (preferred) falling back to Additions if needed
    private func loadAllVendors() {
        // First try Vendors1 model for canonical list
        do {
					let fdVendors = FetchDescriptor<Vendors1>(predicate: #Predicate { $0.inactive == false })
            let vendors = try modelContext.fetch(fdVendors)
            var names = vendors.map { $0.vendorName }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if names.isEmpty {
                // Fallback: derive from Additions records
							let fdAdds = FetchDescriptor<Additions>()
                let adds = try modelContext.fetch(fdAdds)
                names = adds.map { $0.itemVendor }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            }
            let set = Set(names)
            self.allVendors = set.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        } catch {
            self.allVendors = []
        }
    }

//	// Loads interval values (miles, months, hours) from an MxItems3 template matching mxName.
//	// Avoids capturing dataSet in #Predicate closure.
//	private func loadItemIntervalsIfNeeded() {
//		let name = mxName
//		guard !name.isEmpty else { return }
//		var fd = FetchDescriptor<MxItems3>(predicate: #Predicate { $0.mxName == name })
//		fd.fetchLimit = 1
//		do {
//			if let item = try modelContext.fetch(fd).first {
//				itemIntervalMiles = item.intervalMiles
//				itemIntervalMonths = item.intervalMonths
//				itemIntervalHours = item.intervalHours
//			}
//		} catch {}
//	}

//	// Sync selectedPart1...5 from the current part name strings.
//	// Useful when a template is chosen or when seeding from an existing record.
//	private func syncPartSelectionsFromNames(p1: String, p2: String, p3: String, p4: String, p5: String) {
//		func fetchPart(named name: String) -> MxParts1? {
//			guard !name.isEmpty else { return nil }
//			var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == name })
//			fd.fetchLimit = 1
//			return try? modelContext.fetch(fd).first
//		}
//		selectedPart1 = fetchPart(named: p1)
//		selectedPart2 = fetchPart(named: p2)
//		selectedPart3 = fetchPart(named: p3)
//		selectedPart4 = fetchPart(named: p4)
//		selectedPart5 = fetchPart(named: p5)
//	}

//	// Centralized updater for part fields (both local state and dataSet) by index.
//	// Called when a ModelPicker<MxParts1> selection changes.
//	private func setPart(index: Int, from part: MxParts1?) {
//		let name = part?.partName ?? ""
//		let cost = part?.costPerUnit ?? 0
//		let unit = part?.partUnit ?? ""
//		let qty  = part?.partQuantity ?? 0
//
//		switch index {
//		case 1:
//			part1 = name; part1cost = cost; part1Unit = unit; part1Quantity = qty
//			dataSet.part1 = name; dataSet.part1cost = cost; dataSet.part1Unit = unit; dataSet.part1Quantity = qty
//		case 2:
//			part2 = name; part2cost = cost; part2Unit = unit; part2Quantity = qty
//			dataSet.part2 = name; dataSet.part2cost = cost; dataSet.part2Unit = unit; dataSet.part2Quantity = qty
//		case 3:
//			part3 = name; part3cost = cost; part3Unit = unit; part3Quantity = qty
//			dataSet.part3 = name; dataSet.part3cost = cost; dataSet.part3Unit = unit; dataSet.part3Quantity = qty
//		case 4:
//			part4 = name; part4cost = cost; part4Unit = unit; part4Quantity = qty
//			dataSet.part4 = name; dataSet.part4cost = cost; dataSet.part4Unit = unit; dataSet.part4Quantity = qty
//		case 5:
//			part5 = name; part5cost = cost; part5Unit = unit; part5Quantity = qty
//			dataSet.part5 = name; dataSet.part5cost = cost; dataSet.part5Unit = unit; dataSet.part5Quantity = qty
//		default:
//			break
//		}
//		recomputeTotals()
//	}

//	// Helper to read the current part name from the record for seeding ModelPicker.
//	private func getPartNameFromDataSet(index: Int) -> String {
//		switch index {
//		case 1: return dataSet.part1
//		case 2: return dataSet.part2
//		case 3: return dataSet.part3
//		case 4: return dataSet.part4
//		case 5: return dataSet.part5
//		default: return ""
//		}
//	}

	// Recomputes all totals, statistics, deltas, and due intervals.
	// This is called whenever relevant inputs change (miles, hours, labor, parts, selections).
	private func recomputeTotals() {
//		// Costs per part line and subtotals
//		trackPartsCost1 = Double(part1Quantity) * Double(part1cost)
//		trackPartsCost2 = Double(part2Quantity) * Double(part2cost)
//		trackPartsCost3 = Double(part3Quantity) * Double(part3cost)
//		trackPartsCost4 = Double(part4Quantity) * Double(part4cost)
//		trackPartsCost5 = Double(part5Quantity) * Double(part5cost)
//		trackPartsCostTotal = trackPartsCost1 + trackPartsCost2 + trackPartsCost3 + trackPartsCost4 + trackPartsCost5
//		trackAllCostTotal = trackPartsCostTotal + Double(laborCost)
//
//		// Lines and quantities
//		let line1 = (!part1.isEmpty && part1Quantity > 0) ? 1 : 0
//		let line2 = (!part2.isEmpty && part2Quantity > 0) ? 1 : 0
//		let line3 = (!part3.isEmpty && part3Quantity > 0) ? 1 : 0
//		let line4 = (!part4.isEmpty && part4Quantity > 0) ? 1 : 0
//		let line5 = (!part5.isEmpty && part5Quantity > 0) ? 1 : 0
//		partsLinesCount = line1 + line2 + line3 + line4 + line5
//
//		totalPartsQuantity = max(0, part1Quantity) + max(0, part2Quantity) + max(0, part3Quantity) + max(0, part4Quantity) + max(0, part5Quantity)
//
//		if totalPartsQuantity > 0 {
//			avgCostPerPartUnit = trackPartsCostTotal / Double(totalPartsQuantity)
//		} else {
//			avgCostPerPartUnit = 0.0
//		}
//
//		// Choose bases: prefer local edits if present; otherwise fall back to model values
//		let milesBase = Miles > 0 ? Miles : dataSet.Miles
//		let hoursBase = engHours > 0 ? engHours : dataSet.engHours
//
//		// Cost per mile and per engine hour
//		if milesBase > 0 {
//			costPerMile = trackAllCostTotal / Double(milesBase)
//		} else {
//			costPerMile = 0.0
//		}
//
//		if hoursBase > 0 {
//			costPerEngineHour = trackAllCostTotal / Double(hoursBase)
//		} else {
//			costPerEngineHour = 0.0
//		}
//
//		// Vehicle deltas (since the service)
//		let currentMiles = vehicleCurrentMiles
//		let currentHours = vehicleCurrentEngHours
//		milesSinceService = max(0, currentMiles - milesBase)
//		hoursSinceService = max(0, currentHours - hoursBase)
//
//		// Remaining to due (based on intervals)
//		if itemIntervalMiles > 0 {
//			milesRemainingToDue = max(0, itemIntervalMiles - milesSinceService)
//		} else {
//			milesRemainingToDue = 0
//		}
//		if itemIntervalHours > 0 {
//			hoursRemainingToDue = max(0, itemIntervalHours - hoursSinceService)
//		} else {
//			hoursRemainingToDue = 0
//		}
//		// Time interval: compute next due date by adding months to mxDate, and days remaining from now.
//		if itemIntervalMonths > 0 {
//			if let due = Calendar(identifier: .gregorian).date(byAdding: .month, value: itemIntervalMonths, to: mxDate) {
//				nextDueDate = due
//				let days = Calendar(identifier: .gregorian).dateComponents([.day], from: Date(), to: due).day ?? 0
//				daysRemainingToDue = days
//			} else {
//				nextDueDate = nil
//				daysRemainingToDue = 0
//			}
//		} else {
//			nextDueDate = nil
//			daysRemainingToDue = 0
//		}
	}
}

// Safe index helper for arrays to avoid out-of-bounds if settings are missing
private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}

#Preview("EditRecord - Populated Sample") {
	// In-memory container to preview a fully populated record
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(
		for: Vehicle8.self,
				 ServiceRecords1.self,
				 MxItems3.self,
				 MxParts1.self,
				 Vendors1.self,
				 Settings1.self,
				 configurations: config
	)

	// Seed a vehicle (useful if you toggle into Edit mode and use pickers)
	let vehicle = Vehicle8(name: "Preview Vehicle", year: 2022, mileage: 42000, engHours: 123.4, fuelType: "Gasoline")
	container.mainContext.insert(vehicle)

	// Seed a service item template to provide intervals
	let item = MxItems3(
		createdAt: Date(), updatedAt: Date(),
		vehicleId: vehicle.name, vehicleSystem: "Engine",
		mxName: "Oil and Filter Change",
		mxDescription: "Change oil and filter",
		Notes: "", vendor: "Local Auto Shop",
		laborCost: 95.0,
		intervalMonths: 6, intervalMiles: 5000, intervalHours: 200.0,
		part1: "Engine Oil", part1Id: "", part1Qty: 6, part1cost: 8.99, part1Unit: "qt",
		part2: "Oil Filter", part2Id: "", part2Qty: 1, part2cost: 12.49, part2Unit: "Each",
		part3: "", part3Id: "", part3Qty: 0, part3cost: 0, part3Unit: "",
		part4: "", part4Id: "", part4Qty: 0, part4cost: 0, part4Unit: "",
		part5: "", part5Id: "", part5Qty: 0, part5cost: 0, part5Unit: ""
	)
	container.mainContext.insert(item)

	// Seed a populated service record
	let record = ServiceRecords1(
		createdAt: Date().addingTimeInterval(-86400 * 10),
		updatedAt: Date().addingTimeInterval(-86400 * 1),
		mxDate: Date().addingTimeInterval(-86400 * 60),
		vehicleId: vehicle.name,
		Miles: 38000,
		engHours: 100.0,
		mxName: "Oil and Filter Change",
		mxItemId: "Oil and Filter Change",
		mxDescription: "Changed engine oil and filter",
		Notes: "Used full synthetic",
		vendor: "Local Auto Shop",
		laborCost: 95.0,
		part1: "Engine Oil",
		part1cost: 8.99,
		part1Unit: "qt",
		part1Quantity: 6,
		part2: "Oil Filter",
		part2cost: 12.49,
		part2Unit: "Each",
		part2Quantity: 1,
		part3: "",
		part3cost: 0,
		part3Unit: "",
		part3Quantity: 0,
		part4: "",
		part4cost: 0,
		part4Unit: "",
		part4Quantity: 0,
		part5: "",
		part5cost: 0,
		part5Unit: "",
		part5Quantity: 0
	)
	container.mainContext.insert(record)

	return NavigationStack {
		EditRecord(serviceRecords1: record)
	}
	.modelContainer(container)
}

#Preview("EditRecord - Empty Sample") {
	// In-memory container to preview a mostly empty/new record
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(
		for: Vehicle8.self,
				 ServiceRecords1.self,
				 MxItems3.self,
				 MxParts1.self,
				 Vendors1.self,
				 Settings1.self,
				 configurations: config
	)

	// Minimal vehicle (optional, helps if you toggle to Edit)
	let vehicle = Vehicle8(name: "Blank Vehicle", year: 2024)
	container.mainContext.insert(vehicle)

	// Blank/new service record (uses defaults)
	let record = ServiceRecords1(
		mxDate: Date(),
		vehicleId: vehicle.name
	)
	container.mainContext.insert(record)

	return NavigationStack {
		EditRecord(serviceRecords1: record)
	}
	.modelContainer(container)
}

#Preview("EditAdditions – Populated Additions (Details)") {
    @MainActor
    func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Vehicle8.self, Additions.self, Vendors1.self, Settings1.self, configurations: config)
    }
    let container = makeContainer()
    let context = container.mainContext

    // Seed vehicle
    let vehicle = Vehicle8(name: "Preview Vehicle", year: 2022, mileage: 15000, engHours: 150.5, fuelType: "Gasoline", fuelCapacity: 20)
    context.insert(vehicle)

    // Seed settings (units)
    let settings = Settings1(userName: "primary1", unitVolumeFuel: "gal", unitVolumeOil: "qt", unitVolumeDEF: "gal", unitTemp: "°F", unitSpeed: "mph", unitPressure: "PSI", unitMass: "lb", unitLength: "ft", unitWidth: "ft", unitHeight: "ft", unitWheelBase: "in")
    settings.unitDistance = "mi"
    context.insert(settings)

    // Seed vendor
    let vendor = Vendors1(inactive: false, createdAt: Date(), updatedAt: Date(), vendorName: "Local Auto Shop", vendorType: "", vendorContact1: "", vendorContact2: "", vendorContact3: "", vendorAddress: "", vendorCity: "", vendorState: "", vendorZip: "", vendorPhone: "", vendorEmail: "", vendorWebsite: "", vendorNotes: "", image1: nil, image1Description: "", image2: nil, image2Description: "", image3: nil, image3Description: "")
    context.insert(vendor)

    // Seed additions record
    let add = Additions(
        inactive: false,
        createdAt: Date().addingTimeInterval(-86400 * 5),
        updatedAt: Date().addingTimeInterval(-86400 * 1),
        vehicleId: vehicle.name,
        miles: 14800,
        engHours: 149.9,
        itemName: "Dash Cam",
        itemDescription: "Front 4K recording",
        itemNotes: "Hardwired kit installed",
        itemVendor: vendor.vendorName,
        category: "Electronics",
        subCategory: "Cameras",
        itemCost: 179.99,
        image1: nil,
        image1Description: "",
        image2: nil,
        image2Description: "",
        image3: nil,
        image3Description: "",
        image4: nil,
        image4Description: "",
        image5: nil,
        image5Description: ""
    )
    context.insert(add)

    try? context.save()

    return NavigationStack {
        EditAdditions(Records: add, startEditing: false)
            .modelContainer(container)
            .navigationTitle("Edit Additions")
    }
}

#Preview("EditAdditions – Populated Additions (Edit Mode)") {
    @MainActor
    func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Vehicle8.self, Additions.self, Vendors1.self, Settings1.self, configurations: config)
    }

    let container = makeContainer()
    let context = container.mainContext

    // Seed vehicle
    let vehicle = Vehicle8(name: "Preview Vehicle", year: 2022, mileage: 15000, engHours: 150.5, fuelType: "Gasoline", fuelCapacity: 20)
    context.insert(vehicle)

    // Seed settings (units)
    let settings = Settings1(userName: "primary1", unitVolumeFuel: "gal", unitVolumeOil: "qt", unitVolumeDEF: "gal", unitTemp: "°F", unitSpeed: "mph", unitPressure: "PSI", unitMass: "lb", unitLength: "ft", unitWidth: "ft", unitHeight: "ft", unitWheelBase: "in")
    settings.unitDistance = "mi"
    context.insert(settings)

    // Seed vendor
    let vendor = Vendors1(inactive: false, createdAt: Date(), updatedAt: Date(), vendorName: "Local Auto Shop", vendorType: "", vendorContact1: "", vendorContact2: "", vendorContact3: "", vendorAddress: "", vendorCity: "", vendorState: "", vendorZip: "", vendorPhone: "", vendorEmail: "", vendorWebsite: "", vendorNotes: "", image1: nil, image1Description: "", image2: nil, image2Description: "", image3: nil, image3Description: "")
    context.insert(vendor)

    // Seed additions record
    let add = Additions(
        inactive: false,
        createdAt: Date().addingTimeInterval(-86400 * 5),
        updatedAt: Date().addingTimeInterval(-86400 * 1),
        vehicleId: vehicle.name,
        miles: 14800,
        engHours: 149.9,
        itemName: "Dash Cam",
        itemDescription: "Front 4K recording",
        itemNotes: "Hardwired kit installed",
        itemVendor: vendor.vendorName,
        category: "Electronics",
        subCategory: "Cameras",
        itemCost: 179.99,
        image1: nil,
        image1Description: "",
        image2: nil,
        image2Description: "",
        image3: nil,
        image3Description: "",
        image4: nil,
        image4Description: "",
        image5: nil,
        image5Description: ""
    )
    context.insert(add)

    try? context.save()

    return NavigationStack {
        EditAdditions(Records: add, startEditing: true)
            .modelContainer(container)
            .navigationTitle("Edit Additions")
    }
}



