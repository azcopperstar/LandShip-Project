//
//  EditSubscriptions.swift
//  LandShip
//
//  Created by JP on 7/20/25.
//

import SwiftUI
import SwiftData

struct EditProjectList: View {
	// The record being edited or displayed.
	// Kept in @State to drive the UI; changes are written back on Save.
	@State private var dataSet: ProjectList

	// SwiftData environment context for fetching/saving/deleting.
	@Environment(\.modelContext) var modelContext
	@Environment(\.entitlements) private var entitlements

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
	@State private var itemCompleted: Bool = false
	@State private var completedAt = Date()
	@State private var saveInLogbook: Bool = false
	@State private var priority: Int = 3
	@State private var savedToLogbook: Bool = false
	@State private var allCategories: [String] = []  // <-- Inserted array to hold all categories
	@State private var allSubCategories: [String] = []  // <-- Inserted array to hold all subcategories
    @State private var allVendors: [String] = []  // Holds all vendor names for picker
    @State private var allPartNames: [String] = []  // Holds distinct part names from MxParts1
	@State private var itemCost: Float = 0
	@State private var laborCost: Float = 0
	@State private var part1: String = ""
	@State private var part1cost: Float = 0
	@State private var part1Unit: String = "Each"
	@State private var part1Quantity: Int = 0
	@State private var part2: String = ""
	@State private var part2cost: Float = 0
	@State private var part2Unit: String = "Each"
	@State private var part2Quantity: Int = 0
	@State private var part3: String = ""
	@State private var part3cost: Float = 0
	@State private var part3Unit: String = "Each"
	@State private var part3Quantity: Int = 0
	@State private var part4: String = ""
	@State private var part4cost: Float = 0
	@State private var part4Unit: String = "Each"
	@State private var part4Quantity: Int = 0
	@State private var part5: String = ""
	@State private var part5cost: Float = 0
	@State private var part5Unit: String = "Each"
	@State private var part5Quantity: Int = 0

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
	@State private var trackPartsCost1: Double = 0.0
	@State private var trackPartsCost2: Double = 0.0
	@State private var trackPartsCost3: Double = 0.0
	@State private var trackPartsCost4: Double = 0.0
	@State private var trackPartsCost5: Double = 0.0
	@State private var trackPartsCostTotal: Double = 0.0
	@State private var trackAllCostTotal: Double = 0.0
//
//	// Statistics derived from parts and totals
	@State private var partsLinesCount: Int = 0
	@State private var totalPartsQuantity: Int = 0
	@State private var avgCostPerPartUnit: Double = 0.0
	@State private var costPerMile: Double = 0.0
	@State private var costPerEngineHour: Double = 0.0

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
	@State private var selectedServiceItem: MxItems3? = nil
	@State private var selectedVendor: Vendors1? = nil
	@State private var selectedPart1: MxParts1? = nil
	@State private var selectedPart2: MxParts1? = nil
	@State private var selectedPart3: MxParts1? = nil
	@State private var selectedPart4: MxParts1? = nil
	@State private var selectedPart5: MxParts1? = nil
	@State private var selectedVehicle: Vehicle8? = nil

	@State private var additionsLinkId: String = ""
	@State private var showAdditionsTransferSheet: Bool = false
	@State private var transferCategory: String = ""
	@State private var transferSubCategory: String = ""
	@State private var allAdditionsCategories: [String] = []
	@State private var allAdditionsSubCategories: [String] = []
	@State private var linkedAdditionsCount: Int = 0

	// Initializer
	// Seeds all local @State fields from the incoming ServiceRecords1 record so the edit UI
	// can be fully controlled by local state. The Save action writes these back to dataSet.
	init(Records: ProjectList, startEditing: Bool = false) {
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
		self._itemCompleted = State.init(initialValue: dataSet.itemCompleted)
		self._completedAt = State.init(initialValue: dataSet.completedAt)
		self._saveInLogbook = State.init(initialValue: dataSet.saveInLogbook)
		self._priority = State.init(initialValue: dataSet.priority)
		self._savedToLogbook = State.init(initialValue: dataSet.savedToLogbook)
		self._itemCost = State.init(initialValue: dataSet.itemCost)
		self._laborCost = State.init(initialValue: dataSet.laborCost)
		self._part1 = State.init(initialValue: dataSet.part1)
		self._part1cost = State.init(initialValue: dataSet.part1cost)
		self._part1Unit = State.init(initialValue: dataSet.part1Unit)
		self._part1Quantity = State.init(initialValue: dataSet.part1Quantity)
		self._part2 = State.init(initialValue: dataSet.part2)
		self._part2cost = State.init(initialValue: dataSet.part2cost)
		self._part2Unit = State.init(initialValue: dataSet.part2Unit)
		self._part2Quantity = State.init(initialValue: dataSet.part2Quantity)
		self._part3 = State.init(initialValue: dataSet.part3)
		self._part3cost = State.init(initialValue: dataSet.part3cost)
		self._part3Unit = State.init(initialValue: dataSet.part3Unit)
		self._part3Quantity = State.init(initialValue: dataSet.part3Quantity)
		self._part4 = State.init(initialValue: dataSet.part4)
		self._part4cost = State.init(initialValue: dataSet.part4cost)
		self._part4Unit = State.init(initialValue: dataSet.part4Unit)
		self._part4Quantity = State.init(initialValue: dataSet.part4Quantity)
		self._part5 = State.init(initialValue: dataSet.part5)
		self._part5cost = State.init(initialValue: dataSet.part5cost)
		self._part5Unit = State.init(initialValue: dataSet.part5Unit)
		self._part5Quantity = State.init(initialValue: dataSet.part5Quantity)
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
		self._additionsLinkId = State.init(initialValue: Records.additionsLinkId)
	}
	
	var body: some View {
		// The UI is split into Edit (interactive) and Details (read-only) modes.
		if isEditing {
			// EDIT MODE
			ScrollView {
				// GENERAL
				CardView {
					VStack {
//						SectionText(label: "")
						HStack{
							Text(Vertical.current.assetSingular)
								.textLabelModified()
							ModelPicker(
								selection: $selectedVehicle,
								title: Vertical.current.assetSingular,
								includeEmptyChoice: false,
								emptyChoiceLabel: "—",
								autoSelectFirst: false,
								filter: nil,
								sort: [SortDescriptor(\.name, order: .forward)],
								labelProvider: { $0.displayName },
								thumbnailData: { $0.image1 }
							)
							.frame(maxWidth: .infinity, alignment: .trailing)
							.onChange(of: selectedVehicle) { _, newVehicle in
								let name = newVehicle?.name ?? ""
								vehicleId = name
								dataSet.vehicleId = name
								refreshVehicleDetails()
								loadAllPartNames() // refresh part menus when vehicle changes
							}
						}
						
						
						HStack(spacing: 8) {
							Text("Priority")
								.textLabelModified()
							Picker("Priority", selection: $priority) {
								ForEach(1...5, id: \.self) { value in
									Text(String(value)).tag(value)
								}
							}
							.pickerStyle(.segmented)
							.onChange(of: priority) { _, newValue in
								dataSet.priority = newValue
							}
						}

						
						// Category entry with suggestions
						HStack(spacing: 8) {
							Text("Category")
								.textLabelModified()
							HStack(spacing: 6) {
								TextField("Category", text: $category, prompt: Text("e.g., Upgrades, Repairs"))
									.textFieldStyle(.roundedBorder)
									.onChange(of: category) { _, newValue in
										dataSet.category = newValue
										loadAllSubCategories()
									}
								Menu {
									Button("—") { category = ""; dataSet.category = ""; loadAllSubCategories() }
									ForEach(allCategories, id: \.self) { cat in
										Button(cat) {
											category = cat
											dataSet.category = cat
											loadAllSubCategories()
										}
									}
								} label: {
									Image(systemName: "text.badge.plus")
								}
								.accessibilityLabel("Category suggestions")
							}
						}
						.onAppear {
							if category.isEmpty { category = dataSet.category }
						}

						// Subcategory entry with suggestions
						HStack(spacing: 8) {
							Text("Subcategory")
								.textLabelModified()
							HStack(spacing: 6) {
								TextField("Subcategory", text: $subCategory, prompt: Text("Optional project subcategory"))
									.textFieldStyle(.roundedBorder)
									.onChange(of: subCategory) { _, newValue in
										dataSet.subCategory = newValue
									}
								Menu {
									Button("—") { subCategory = ""; dataSet.subCategory = "" }
									ForEach(allSubCategories, id: \.self) { subcat in
										Button(subcat) {
											subCategory = subcat
											dataSet.subCategory = subcat
										}
									}
								} label: {
									Image(systemName: "text.badge.plus")
								}
								.accessibilityLabel("Subcategory suggestions")
							}
						}
						.onAppear {
							if subCategory.isEmpty { subCategory = dataSet.subCategory }
							loadAllSubCategories()
						}
				
						HStack{LabelDataTextview(label: "Project Item Name", data: $itemName)}
						
						HStack{LabelDataToggle(label: "Item Completed?", data: $itemCompleted)}
						if itemCompleted {
							HStack{LabelDataPicker_Date(label: "Completed Date   ", data: $completedAt)}
							HStack{LabelDataToggle(label: "Create Logbook Entry?", data: $saveInLogbook)}
						}


						HStack{LabelDataTextview_Numberpad_Currency(label: "Project Labor Cost", data: $laborCost)}
					}
					
				}

				CardView {
					VStack {
//						SectionText(label: "PROJECT ITEM")
						VStack(alignment: .leading, spacing: 6) {
							TextFieldNote_FullWidth_3lines(sectionText: "Project Item Description", prompt: "Enter Description...", data: $itemDescription)

							TextFieldNote_FullWidth_3lines(sectionText: "Project Item Notes", prompt: "Enter Notes...", data: $itemNotes)
						}
						
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
					}
				}
				
				// Inserted PARTS QUICK PICK card here BEFORE "SERVICE COMPLETED AT"
                CardView {
                    VStack {
                        SectionText(label: "PARTS QUICK PICK")

                        // Part 1
                        HStack(spacing: 8) {
                            Menu {
                                Button("—") {
                                    part1 = ""; dataSet.part1 = ""
                                }
                                ForEach(allPartNames, id: \.self) { name in
                                    Button(name) {
                                        part1 = name
                                        dataSet.part1 = name
                                    }
                                }
                            } label: {
                                Label("Part 1", systemImage: "line.3.horizontal.decrease.circle")
                            }
                            .menuStyle(.borderlessButton)

                            TextField("Enter or pick a part", text: $part1)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: part1) { _, newValue in
                                    dataSet.part1 = newValue
                                }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Part 1 details (cost, unit, quantity) shown when a part is chosen or typed
                        if !part1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { LabelDataTextview_Numberpad_Currency(label: "Part 1 Cost", data: $part1cost) }
                                HStack {
                                    // Unit entry keeps same pattern as other unit fields in file
                                    TextField("Unit (e.g., Each)", text: $part1Unit)
                                        .textFieldStyle(.roundedBorder)
                                        .onChange(of: part1Unit) { _, newValue in
                                            dataSet.part1Unit = newValue
                                        }
                                }
                                HStack { LabelDataTextview_Numberpad_Int(label: "Part 1 Quantity", data: $part1Quantity) }
                            }
                            .onAppear {
                                // Seed from model if local state is empty/out-of-sync
                                if part1cost == 0 { part1cost = dataSet.part1cost }
                                if part1Unit.isEmpty { part1Unit = dataSet.part1Unit }
                                if part1Quantity == 0 { part1Quantity = dataSet.part1Quantity }
                            }
                            .onChange(of: part1cost) { _, newValue in dataSet.part1cost = newValue }
                            .onChange(of: part1Quantity) { _, newValue in dataSet.part1Quantity = newValue }
                        }

                        // Part 2
                        HStack(spacing: 8) {
                            Menu {
                                Button("—") {
                                    part2 = ""; dataSet.part2 = ""
                                }
                                ForEach(allPartNames, id: \.self) { name in
                                    Button(name) {
                                        part2 = name
                                        dataSet.part2 = name
                                    }
                                }
                            } label: {
                                Label("Part 2", systemImage: "line.3.horizontal.decrease.circle")
                            }
                            .menuStyle(.borderlessButton)

                            TextField("Enter or pick a part", text: $part2)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: part2) { _, newValue in
                                    dataSet.part2 = newValue
                                }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Part 2 details (cost, unit, quantity) shown when a part is chosen or typed
                        if !part2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { LabelDataTextview_Numberpad_Currency(label: "Part 2 Cost", data: $part2cost) }
                                HStack {
                                    TextField("Unit (e.g., Each)", text: $part2Unit)
                                        .textFieldStyle(.roundedBorder)
                                        .onChange(of: part2Unit) { _, newValue in
                                            dataSet.part2Unit = newValue
                                        }
                                }
                                HStack { LabelDataTextview_Numberpad_Int(label: "Part 2 Quantity", data: $part2Quantity) }
                            }
                            .onAppear {
                                if part2cost == 0 { part2cost = dataSet.part2cost }
                                if part2Unit.isEmpty { part2Unit = dataSet.part2Unit }
                                if part2Quantity == 0 { part2Quantity = dataSet.part2Quantity }
                            }
                            .onChange(of: part2cost) { _, newValue in dataSet.part2cost = newValue }
                            .onChange(of: part2Quantity) { _, newValue in dataSet.part2Quantity = newValue }
                        }

                        // Part 3
                        HStack(spacing: 8) {
                            Menu {
                                Button("—") {
                                    part3 = ""; dataSet.part3 = ""
                                }
                                ForEach(allPartNames, id: \.self) { name in
                                    Button(name) {
                                        part3 = name
                                        dataSet.part3 = name
                                    }
                                }
                            } label: {
                                Label("Part 3", systemImage: "line.3.horizontal.decrease.circle")
                            }
                            .menuStyle(.borderlessButton)

                            TextField("Enter or pick a part", text: $part3)
                                .textFieldStyle(.roundedBorder)
								.onChange(of: part3) { _, newValue in
                                    dataSet.part3 = newValue
                                }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Part 3 details (cost, unit, quantity) shown when a part is chosen or typed
                        if !part3.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { LabelDataTextview_Numberpad_Currency(label: "Part 3 Cost", data: $part3cost) }
                                HStack {
                                    TextField("Unit (e.g., Each)", text: $part3Unit)
                                        .textFieldStyle(.roundedBorder)
                                        .onChange(of: part3Unit) { _, newValue in
                                            dataSet.part3Unit = newValue
                                        }
                                }
                                HStack { LabelDataTextview_Numberpad_Int(label: "Part 3 Quantity", data: $part3Quantity) }
                            }
                            .onAppear {
                                if part3cost == 0 { part3cost = dataSet.part3cost }
                                if part3Unit.isEmpty { part3Unit = dataSet.part3Unit }
                                if part3Quantity == 0 { part3Quantity = dataSet.part3Quantity }
                            }
                            .onChange(of: part3cost) { _, newValue in dataSet.part3cost = newValue }
                            .onChange(of: part3Quantity) { _, newValue in dataSet.part3Quantity = newValue }
                        }

                        // Part 4
                        HStack(spacing: 8) {
                            Menu {
                                Button("—") {
                                    part4 = ""; dataSet.part4 = ""
                                }
                                ForEach(allPartNames, id: \.self) { name in
                                    Button(name) {
                                        part4 = name
                                        dataSet.part4 = name
                                    }
                                }
                            } label: {
                                Label("Part 4", systemImage: "line.3.horizontal.decrease.circle")
                            }
                            .menuStyle(.borderlessButton)

                            TextField("Enter or pick a part", text: $part4)
                                .textFieldStyle(.roundedBorder)
								.onChange(of: part4) { _, newValue in
                                    dataSet.part4 = newValue
                                }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Part 4 details (cost, unit, quantity) shown when a part is chosen or typed
                        if !part4.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { LabelDataTextview_Numberpad_Currency(label: "Part 4 Cost", data: $part4cost) }
                                HStack {
                                    TextField("Unit (e.g., Each)", text: $part4Unit)
                                        .textFieldStyle(.roundedBorder)
                                        .onChange(of: part4Unit) { _, newValue in
                                            dataSet.part4Unit = newValue
                                        }
                                }
                                HStack { LabelDataTextview_Numberpad_Int(label: "Part 4 Quantity", data: $part4Quantity) }
                            }
                            .onAppear {
                                if part4cost == 0 { part4cost = dataSet.part4cost }
                                if part4Unit.isEmpty { part4Unit = dataSet.part4Unit }
                                if part4Quantity == 0 { part4Quantity = dataSet.part4Quantity }
                            }
                            .onChange(of: part4cost) { _, newValue in dataSet.part4cost = newValue }
                            .onChange(of: part4Quantity) { _, newValue in dataSet.part4Quantity = newValue }
                        }

                        // Part 5
                        HStack(spacing: 8) {
                            Menu {
                                Button("—") {
                                    part5 = ""; dataSet.part5 = ""
                                }
                                ForEach(allPartNames, id: \.self) { name in
                                    Button(name) {
                                        part5 = name
                                        dataSet.part5 = name
                                    }
                                }
                            } label: {
                                Label("Part 5", systemImage: "line.3.horizontal.decrease.circle")
                            }
                            .menuStyle(.borderlessButton)

                            TextField("Enter or pick a part", text: $part5)
                                .textFieldStyle(.roundedBorder)
								.onChange(of: part5) { _, newValue in
                                    dataSet.part5 = newValue
                                }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Part 5 details (cost, unit, quantity) shown when a part is chosen or typed
                        if !part5.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { LabelDataTextview_Numberpad_Currency(label: "Part 5 Cost", data: $part5cost) }
                                HStack {
                                    TextField("Unit (e.g., Each)", text: $part5Unit)
                                        .textFieldStyle(.roundedBorder)
                                        .onChange(of: part5Unit) { _, newValue in
                                            dataSet.part5Unit = newValue
                                        }
                                }
                                HStack { LabelDataTextview_Numberpad_Int(label: "Part 5 Quantity", data: $part5Quantity) }
                            }
                            .onAppear {
                                if part5cost == 0 { part5cost = dataSet.part5cost }
                                if part5Unit.isEmpty { part5Unit = dataSet.part5Unit }
                                if part5Quantity == 0 { part5Quantity = dataSet.part5Quantity }
                            }
                            .onChange(of: part5cost) { _, newValue in dataSet.part5cost = newValue }
                            .onChange(of: part5Quantity) { _, newValue in dataSet.part5Quantity = newValue }
                        }
                    }
                }
                .onAppear {
                    // Seed from model on first appear and load part names
                    if part1.isEmpty { part1 = dataSet.part1 }
                    if part2.isEmpty { part2 = dataSet.part2 }
                    if part3.isEmpty { part3 = dataSet.part3 }
                    if part4.isEmpty { part4 = dataSet.part4 }
                    if part5.isEmpty { part5 = dataSet.part5 }
                    loadAllPartNames()
                }

				
				// LINK TO ADDITIONS
				CardView {
					VStack {
						SectionText(label: "LINK TO ADDITIONS")
						if additionsLinkId.isEmpty {
							Text("Transfer parts and labor costs from this project item into the Additions tracker as individual line items.")
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
							Button {
								loadAdditionsCategories()
								showAdditionsTransferSheet = true
							} label: {
								Label("Transfer to Additions", systemImage: "arrow.right.circle")
							}
							.buttonStyle(.borderedProminent)
						} else {
							HStack { LabelDataText(label: "Category", data: transferCategory) }
							if !transferSubCategory.isEmpty {
								HStack { LabelDataText(label: "Sub-Category", data: transferSubCategory) }
							}
							HStack { LabelDataText(label: "Linked Items", data: "\(linkedAdditionsCount)") }
							Button("Unlink All from Additions", role: .destructive) {
								unlinkFromAdditions()
							}
							.buttonStyle(.bordered)
							.tint(.gray)
						}
					}
				}
				.sheet(isPresented: $showAdditionsTransferSheet) {
					AdditionsTransferSheet(
						existingCategories: allAdditionsCategories,
						existingSubCategories: allAdditionsSubCategories,
						lineItems: buildTransferLineItems()
					) { cat, subCat in
						transferToAdditions(category: cat, subCategory: subCat)
					}
				}

				// SERVICE COMPLETED AT
				CardView {
					VStack {
						SectionText(label: "PROJECT DETAILS")
						HStack{LabelDataTextview_Numberpad_Int(label: "Distance (\(unit(UnitIndex.distance)))", data: $miles)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Engine Hours", data: $engHours)}
					}
				}
				
				CardView {
					VStack {
#if os(macOS)
						SectionText(label: "RECORDS GRAPHICS")
#elseif os(iOS)
						SectionText(label: "  PROJECT ITEM GRAPHICS\n(Click Image to Change)")
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
						HStack{LabelDataToggle(label: "Deactivate Record", data: $inactive)}
						Text("When selected, this record is marked as inactive. It will be hidden in lists and pickers, but its data remains available for viewing and editing, and can be un-hidden by selecting 'View Inactive' on the 'Settings' screen.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
				}
			}// end of edit scroll view

			.frame(maxWidth: .infinity, maxHeight: .infinity)

			.safeAreaInset(edge: .top) {
				PageTitle_Col2_NoPhoto(label: "PROJECT ITEM")
//					.frame(maxWidth: .infinity, alignment: .leading)
			}
//			.safeAreaInset(edge: .top) {
//				PageTitle_Col3_Photo(
//					label: "",
//					action: "edit",
//					dbRecord: "project item")
//			}

			.onAppear {
				// Load display units (e.g., miles vs km), vehicle stats, and intervals.
				// Seed pickers from existing model values.
				loadUnits()
				refreshVehicleDetails()

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
				
				// Load all part names
				loadAllPartNames()
				additionsLinkId = dataSet.additionsLinkId
				loadAdditionsCategories()
				if !additionsLinkId.isEmpty { loadAdditionsLinkState() }
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
//						SectionText(label: "GENERAL")
						HStack{LabelDataText(label: "Item Name", data: dataSet.itemName)}

						
						
						CardView {
							VStack {
								HStack{LabelDataText(label: Vertical.current.assetSingular, data: Functions().getVehicleDisplayName(vehicleId: dataSet.vehicleId, context: modelContext))}
								HStack{LabelDataText(label: "Category", data: dataSet.category)}
								HStack{LabelDataText(label: "Project Name", data: dataSet.subCategory)}
								HStack {
									Text("Priority")
										.textLabelModified()
									PriorityBadge(value: max(1, min(5, dataSet.priority)))
								}
								if dataSet.inactive{
									HStack{LabelDataText(label: "Status", data: dataSet.inactive ? "Inactive" : "Active")}
								}
							}
						}
						CardView {
							VStack {
								HStack{LabelDataText(label: "Completed", data: dataSet.itemCompleted ? "Yes" : "No")}
								if itemCompleted {
									HStack{LabelDataText(label: "Date Completed", data: "\(functions.formatDate_DDMMMyy(date: completedAt))")}
									if savedToLogbook {
										HStack{LabelDataText(label: "Logbook Entry Created", data: "Yes")}
									}
								}
							}
						}
					}
				}
				
				VStack {
					if dataSet.itemDescription != "" {CardView {
						TextNoteDisplay_FullWidth(sectionText: "ITEM DESCRIPTION", data: dataSet.itemDescription)}
					}
					if dataSet.itemNotes != "" {CardView {
						TextNoteDisplay_FullWidth(sectionText: "ITEM NOTES", data: dataSet.itemNotes)}
					}
				}
				
				VStack {
//					SectionText(label: "PROJECT ITEM DETAILS")
					if dataSet.miles > 0 {
						CardView {
							HStack{LabelDataText(label: "Distance", data: "\(dataSet.miles) \(unit(UnitIndex.distance))")}
						}
					}
					if dataSet.engHours > 0 {
						CardView {
							HStack{LabelDataNumber(label: "Engine Hours", data: Float(dataSet.engHours), fractionalLength: 1)}
						}
					}
				}
				
				// Display entered parts summary
				CardView {
					VStack(alignment: .leading, spacing: 8) {
						// Title only appears when at least one part line was entered
						if hasPartsEntered {
							SectionText(label: "PARTS ENTERED")
						}
						
						// Part 1 line
						if !part1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
							CardView {
								VStack(alignment: .leading, spacing: 4) {
									HStack{LabelDataText(label: "Part Name", data: "\(part1)")}
									HStack{LabelDataText(label: "Quantity", data: "\(part1Quantity) \(part1Unit)")}
									HStack{LabelDataCurrency(label: "Cost/Unit", data: Float(part1cost), unit: "/ \(part1Unit)")}
									HStack{LabelDataCurrency(label: "Part Total", data: Float(Double(part1Quantity) * Double(part1cost)), unit: "")}
								}
							}
						}
						
						// Part 2 line
						if !part2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
							CardView {
								VStack(alignment: .leading, spacing: 4) {
									HStack{LabelDataText(label: "Part Name", data: "\(part2)")}
									HStack{LabelDataText(label: "Quantity", data: "\(part2Quantity) \(part2Unit)")}
									HStack{LabelDataCurrency(label: "Cost/Unit", data: Float(part2cost), unit: "/ \(part2Unit)")}
									HStack{LabelDataCurrency(label: "Part Total", data: Float(Double(part2Quantity) * Double(part2cost)), unit: "")}
								}
							}
						}
						
						// Part 3 line
						if !part3.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
							CardView {
								VStack(alignment: .leading, spacing: 4) {
									HStack{LabelDataText(label: "Part Name", data: "\(part3)")}
									HStack{LabelDataText(label: "Quantity", data: "\(part3Quantity) \(part3Unit)")}
									HStack{LabelDataCurrency(label: "Cost/Unit", data: Float(part3cost), unit: "/ \(part3Unit)")}
									HStack{LabelDataCurrency(label: "Part Total", data: Float(Double(part3Quantity) * Double(part3cost)), unit: "")}
								}
							}
						}
						
						// Part 4 line
						if !part4.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
							CardView {
								VStack(alignment: .leading, spacing: 4) {
									HStack{LabelDataText(label: "Part Name", data: "\(part4)")}
									HStack{LabelDataText(label: "Quantity", data: "\(part4Quantity) \(part4Unit)")}
									HStack{LabelDataCurrency(label: "Cost/Unit", data: Float(part4cost), unit: "/ \(part4Unit)")}
									HStack{LabelDataCurrency(label: "Part Total", data: Float(Double(part4Quantity) * Double(part4cost)), unit: "")}
								}
							}
						}
						
						// Part 5 line
						if !part5.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
							CardView {
								VStack(alignment: .leading, spacing: 4) {
									HStack{LabelDataText(label: "Part Name", data: "\(part5)")}
									HStack{LabelDataText(label: "Quantity", data: "\(part5Quantity) \(part5Unit)")}
									HStack{LabelDataCurrency(label: "Cost/Unit", data: Float(part5cost), unit: "/ \(part5Unit)")}
									HStack{LabelDataCurrency(label: "Part Total", data: Float(Double(part5Quantity) * Double(part5cost)), unit: "")}
								}
							}
						}

						// Parts cost total across all entered parts
						CardView {
							VStack {
								HStack {
									let total = (Double(part1Quantity) * Double(part1cost)) +
									(Double(part2Quantity) * Double(part2cost)) +
									(Double(part3Quantity) * Double(part3cost)) +
									(Double(part4Quantity) * Double(part4cost)) +
									(Double(part5Quantity) * Double(part5cost))
									LabelDataCurrency(label: "Parts Cost", data: Float(total), unit: "")
								}
								HStack{LabelDataText(label: "Shop", data: dataSet.itemVendor)}
								HStack{LabelDataCurrency(label: "Labor Cost", data: Float(laborCost), unit: "")}
								// Total cost including parts and labor
								HStack {
									let partsTotal = (Double(part1Quantity) * Double(part1cost)) +
									                 (Double(part2Quantity) * Double(part2cost)) +
									                 (Double(part3Quantity) * Double(part3cost)) +
									                 (Double(part4Quantity) * Double(part4cost)) +
									                 (Double(part5Quantity) * Double(part5cost))
									let grandTotal = partsTotal + Double(laborCost)
									LabelDataCurrency(label: "Total Costs", data: Float(grandTotal), unit: "")
								}
							}
						}
					}
				}

				// LINKED TO ADDITIONS (read-only)
				if !dataSet.additionsLinkId.isEmpty {
					CardView {
						VStack {
							SectionText(label: "LINKED TO ADDITIONS")
							HStack { LabelDataText(label: "Category", data: transferCategory) }
							if !transferSubCategory.isEmpty {
								HStack { LabelDataText(label: "Sub-Category", data: transferSubCategory) }
							}
							HStack { LabelDataText(label: "Linked Items", data: "\(linkedAdditionsCount)") }
						}
					}
				}

				// SERVICE RECORDS GRAPHICS (read-only images) — hidden when none attached
				if hasGraphics {
					CardView {
					VStack {
//						SectionText(label: "PROJECT ITEM GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
						Image_View_Details(label:"4", imageData: dataSet.image4, imageDescription: dataSet.image4Description)
						Image_View_Details(label:"5", imageData: dataSet.image5, imageDescription: dataSet.image5Description)
					}
					}
				}

			}//end of details scroll view
			
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.safeAreaInset(edge: .top) {
				PageTitle_Col2_NoPhoto(label: "PROJECT ITEM")
			}
//			.safeAreaInset(edge: .top) {
//				PageTitle_Col3_Photo(
//					label: "",
//					action: "details",
//					dbRecord: "project item")
//			}

			.onAppear {
				// Keep derived values up-to-date when entering details mode
				loadUnits()
				refreshVehicleDetails()
				additionsLinkId = dataSet.additionsLinkId
				if !additionsLinkId.isEmpty { loadAdditionsLinkState() }
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
						Text("Confirm either deletion or deactivation of this record.  Deactivated records will still be available for reference, but will not be included in any reports or calculations.")
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
		dataSet.itemCompleted = itemCompleted
		dataSet.completedAt = completedAt
		dataSet.saveInLogbook = saveInLogbook
		dataSet.priority = priority
		dataSet.savedToLogbook = saveInLogbook
		dataSet.itemCost = itemCost
		dataSet.laborCost = laborCost
		dataSet.part1 = part1
		dataSet.part1cost = part1cost
		dataSet.part1Unit = part1Unit
		dataSet.part1Quantity = part1Quantity
		dataSet.part2 = part2
		dataSet.part2cost = part2cost
		dataSet.part2Unit = part2Unit
		dataSet.part2Quantity = part2Quantity
		dataSet.part3 = part3
		dataSet.part3cost = part3cost
		dataSet.part3Unit = part3Unit
		dataSet.part3Quantity = part3Quantity
		dataSet.part4 = part4
		dataSet.part4cost = part4cost
		dataSet.part4Unit = part4Unit
		dataSet.part4Quantity = part4Quantity
		dataSet.part5 = part5
		dataSet.part5cost = part5cost
		dataSet.part5Unit = part5Unit
		dataSet.part5Quantity = part5Quantity
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

		// Ensure manually entered parts are present in MxParts1 for this vehicle
		_ = ensurePartExists(part1)
		_ = ensurePartExists(part2)
		_ = ensurePartExists(part3)
		_ = ensurePartExists(part4)
		_ = ensurePartExists(part5)

		// Save the record
		do {
			try modelContext.save()
			
			// make a new service record if item completed and indicated to do so, only created once, not edited
			if saveInLogbook && !savedToLogbook {
				makeNewServiceRecord()
			}
			
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
		if !additionsLinkId.isEmpty { syncLinkedAddition() }
		dataSet.additionsLinkId = additionsLinkId
		refreshVehicleDetails()
	}

	// MARK: - Details section visibility
	// Card sections in Details mode only show their title when the section holds data,
	// so a section title never appears above an empty card.

	/// True when at least one part line was entered.
	private var hasPartsEntered: Bool {
		![part1, part2, part3, part4, part5]
			.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
	}

	/// True when at least one image is attached.
	private var hasGraphics: Bool {
		dataSet.image1 != nil || dataSet.image2 != nil || dataSet.image3 != nil
			|| dataSet.image4 != nil || dataSet.image5 != nil
	}

	// MARK: - Helpers

	private func loadAdditionsCategories() {
		if let results = try? modelContext.fetch(FetchDescriptor<Additions>()) {
			let cats = results.filter { !$0.category.isEmpty }.map { $0.category }
			allAdditionsCategories = Array(Set(cats)).sorted()
			let subs = results.filter { !$0.subCategory.isEmpty }.map { $0.subCategory }
			allAdditionsSubCategories = Array(Set(subs)).sorted()
		}
	}

	private func loadAdditionsLinkState() {
		let lid = additionsLinkId
		guard !lid.isEmpty else { return }
		let fd = FetchDescriptor<Additions>(predicate: #Predicate { $0.serviceRecordLinkId == lid })
		if let additions = try? modelContext.fetch(fd), !additions.isEmpty {
			transferCategory = additions[0].category
			transferSubCategory = additions[0].subCategory
			linkedAdditionsCount = additions.count
		}
	}

	private func buildTransferLineItems() -> [(name: String, cost: Float)] {
		var items: [(name: String, cost: Float)] = []
		if laborCost > 0 { items.append((name: "Labor", cost: laborCost)) }
		let parts: [(String, Float, Int)] = [
			(part1, part1cost, part1Quantity),
			(part2, part2cost, part2Quantity),
			(part3, part3cost, part3Quantity),
			(part4, part4cost, part4Quantity),
			(part5, part5cost, part5Quantity),
		]
		for (name, cost, qty) in parts where !name.isEmpty {
			items.append((name: name, cost: Float(Double(qty) * Double(cost))))
		}
		return items
	}

	private func transferToAdditions(category: String, subCategory: String) {
		let parts: [(String, Float, Int)] = [
			(part1, part1cost, part1Quantity), (part2, part2cost, part2Quantity),
			(part3, part3cost, part3Quantity), (part4, part4cost, part4Quantity),
			(part5, part5cost, part5Quantity)
		]
		let willCreate = (laborCost > 0 ? 1 : 0) + parts.filter { !$0.0.isEmpty }.count
		guard willCreate > 0 else { return }
		guard entitlements.requestCreate(Additions.self, count: willCreate, in: modelContext) else { return }

		let linkId = UUID().uuidString
		let vId = vehicleId.isEmpty ? dataSet.vehicleId : vehicleId
		let projectName = itemName.isEmpty ? dataSet.itemName : itemName
		let vend = itemVendor.isEmpty ? dataSet.itemVendor : itemVendor
		var count = 0
		if laborCost > 0 {
			let entry = Additions(vehicleId: vId, miles: miles, engHours: engHours,
				itemName: "Labor", itemDescription: projectName,
				itemVendor: vend, category: category, subCategory: subCategory, itemCost: laborCost)
			entry.serviceRecordLinkId = linkId
			modelContext.insert(entry); count += 1
		}
		for (pName, pCost, pQty) in parts where !pName.isEmpty {
			let entry = Additions(vehicleId: vId, miles: miles, engHours: engHours,
				itemName: pName, itemDescription: projectName,
				itemVendor: vend, category: category, subCategory: subCategory,
				itemCost: Float(Double(pQty) * Double(pCost)))
			entry.serviceRecordLinkId = linkId
			modelContext.insert(entry); count += 1
		}
		dataSet.additionsLinkId = linkId
		additionsLinkId = linkId
		transferCategory = category; transferSubCategory = subCategory
		linkedAdditionsCount = count
		try? modelContext.save()
	}

	private func unlinkFromAdditions() {
		let lid = additionsLinkId
		let fd = FetchDescriptor<Additions>(predicate: #Predicate { $0.serviceRecordLinkId == lid })
		if let additions = try? modelContext.fetch(fd) {
			for addition in additions { addition.serviceRecordLinkId = "" }
		}
		dataSet.additionsLinkId = ""; additionsLinkId = ""
		transferCategory = ""; transferSubCategory = ""
		linkedAdditionsCount = 0
		try? modelContext.save()
	}

	private func syncLinkedAddition() {
		let lid = additionsLinkId
		guard !lid.isEmpty else { return }
		let fd = FetchDescriptor<Additions>(predicate: #Predicate { $0.serviceRecordLinkId == lid })
		guard let additions = try? modelContext.fetch(fd), !additions.isEmpty else { return }
		let projectName = itemName.isEmpty ? dataSet.itemName : itemName
		let vend = itemVendor.isEmpty ? dataSet.itemVendor : itemVendor
		for addition in additions {
			addition.itemDescription = projectName; addition.itemVendor = vend; addition.updatedAt = Date()
			if addition.itemName == "Labor" { addition.itemCost = laborCost }
			else if addition.itemName == part1 { addition.itemCost = Float(Double(part1Quantity) * Double(part1cost)) }
			else if addition.itemName == part2 { addition.itemCost = Float(Double(part2Quantity) * Double(part2cost)) }
			else if addition.itemName == part3 { addition.itemCost = Float(Double(part3Quantity) * Double(part3cost)) }
			else if addition.itemName == part4 { addition.itemCost = Float(Double(part4Quantity) * Double(part4cost)) }
			else if addition.itemName == part5 { addition.itemCost = Float(Double(part5Quantity) * Double(part5cost)) }
		}
		try? modelContext.save()
		transferCategory = additions[0].category; transferSubCategory = additions[0].subCategory
		linkedAdditionsCount = additions.count
	}

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

	@discardableResult
	private func makeNewServiceRecord() -> ServiceRecords1 {
		let record = ServiceRecords1(
			inactive: false,
			createdAt: Date(),
			updatedAt: Date(),
			mxDate: Date(),
			vehicleId: vehicleId,
			Miles: miles,
			engHours: engHours,
			mxName: itemName,
			mxItemId: "",
			mxDescription: "Auto entry created from project (" + subCategory + "), completed item (" + itemName + "): " + itemDescription,
			Notes: itemNotes,
			vendor: itemVendor,
			laborCost: laborCost,
			part1: part1,
			part1cost: part1cost,
			part1Unit: part1Unit,
			part1Quantity: part1Quantity,
			part2: part2,
			part2cost: part2cost,
			part2Unit: part2Unit,
			part2Quantity: part2Quantity,
			part3: part3,
			part3cost: part3cost,
			part3Unit: part3Unit,
			part3Quantity: part3Quantity,
			part4: part4,
			part4cost: part4cost,
			part4Unit: part4Unit,
			part4Quantity: part4Quantity,
			part5: part5,
			part5cost: part5cost,
			part5Unit: part5Unit,
			part5Quantity: part5Quantity,

			image: nil,
			image1: image1,
			image1Description: image1Description,
			image2: image2,
			image2Description: image2Description,
			image3: image3,
			image3Description: image3Description
		)
		modelContext.insert(record)
		do {
			try modelContext.save()
		} catch {
			print("Failed to save new service record: \(error.localizedDescription)")
		}
		return record
	}

	/// Ensures a part with the given name exists in MxParts1 for the current vehicle.
	/// If it doesn't exist, creates it with sensible defaults and saves the context.
	@discardableResult
	private func ensurePartExists(_ name: String) -> MxParts1? {
	    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
	    guard !trimmed.isEmpty else { return nil }
	    let currentVehicle = vehicleId.isEmpty ? dataSet.vehicleId : vehicleId

	    do {
	        // Look for an existing part with same name and vehicle
	        let targetName = trimmed
	        let targetVehicle = currentVehicle
	        var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { p in
	            p.partName == targetName && p.vehicleId == targetVehicle
	        })
	        fd.fetchLimit = 1
	        if let existing = try modelContext.fetch(fd).first {
	            return existing
	        }

	        // Create a new part with defaults
	        let part = MxParts1(
	            inactive: false,
	            createdAt: Date(),
	            updatedAt: Date(),
	            vehicleId: currentVehicle,
	            vehicleSystem: "",
	            partName: trimmed,
	            partNumber: "",
	            partManufacture: "",
	            partDescription: "",
	            Notes: "",
	            costPerUnit: 0,
	            partUnit: "Each",
	            partSource: "",
	            partQuantity: 0,
	            partLocation: "",
	            partStatus: "",
	            partImage: nil,
	            partSupplier: "",
	            image1: nil,
	            image1Description: "",
	            image2: nil,
	            image2Description: "",
	            image3: nil,
	            image3Description: ""
	        )
	        modelContext.insert(part)
	        try modelContext.save()
	        // Refresh menus so the new part appears immediately
	        loadAllPartNames()
	        return part
	    } catch {
	        print("Failed to ensure part exists: \(error.localizedDescription)")
	        return nil
	    }
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
        let fd = FetchDescriptor<ProjectList>()
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
		let fd = FetchDescriptor<ProjectList>()
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
    
    // Loads distinct part names from MxParts1, optionally filtered by current vehicleId
    private func loadAllPartNames() {
        do {
            let currentVehicle = vehicleId.isEmpty ? dataSet.vehicleId : vehicleId
            let records: [MxParts1]
            if !currentVehicle.isEmpty {
                let v = currentVehicle
                let empty = ""
                let fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.vehicleId == v || $0.vehicleId == empty })
                records = try modelContext.fetch(fd)
            } else {
                let fd = FetchDescriptor<MxParts1>()
                records = try modelContext.fetch(fd)
            }
            let names = records
                .map { $0.partName }
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let set = Set(names)
            self.allPartNames = set.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        } catch {
            self.allPartNames = []
        }
    }
}

// Sheet for choosing Additions category before transferring project costs
private struct AdditionsTransferSheet: View {
    let existingCategories: [String]
    let existingSubCategories: [String]
    let lineItems: [(name: String, cost: Float)]
    let onTransfer: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String = ""
    @State private var newCategoryName: String = ""
    @State private var useNewCategory: Bool = false
    @State private var selectedSubCategory: String = ""
    @State private var newSubCategoryName: String = ""
    @State private var useNewSubCategory: Bool = false
    var chosenCategory: String { useNewCategory ? newCategoryName : selectedCategory }
    var chosenSubCategory: String { (useNewSubCategory || existingSubCategories.isEmpty) ? newSubCategoryName : selectedSubCategory }
    var canTransfer: Bool { !chosenCategory.trimmingCharacters(in: .whitespaces).isEmpty }
    var totalCost: Float { lineItems.reduce(0) { $0 + $1.cost } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Items to Transfer") {
                    ForEach(lineItems, id: \.name) { item in
                        LabeledContent(item.name) {
                            Text(item.cost, format: .currency(code: "USD"))
                        }
                    }
                    LabeledContent("Total") {
                        Text(totalCost, format: .currency(code: "USD")).bold()
                    }
                }
                Section("Category") {
                    if !existingCategories.isEmpty {
                        Toggle("Create new category", isOn: $useNewCategory)
                    }
                    if useNewCategory || existingCategories.isEmpty {
                        TextField("New category name", text: $newCategoryName)
                    } else {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(existingCategories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                        .onAppear {
                            if selectedCategory.isEmpty, let first = existingCategories.first {
                                selectedCategory = first
                            }
                        }
                    }
                }
                Section("Sub-Category (optional)") {
                    if !existingSubCategories.isEmpty {
                        Toggle("Use Existing Sub-Category", isOn: Binding(
                            get: { !useNewSubCategory },
                            set: { useNewSubCategory = !$0 }
                        ))
                    }
                    if !useNewSubCategory && !existingSubCategories.isEmpty {
                        Picker("Sub-Category", selection: $selectedSubCategory) {
                            Text("— None —").tag("")
                            ForEach(existingSubCategories, id: \.self) { sub in
                                Text(sub).tag(sub)
                            }
                        }
                    } else {
                        TextField("New Sub-Category Name", text: $newSubCategoryName)
                    }
                }
            }
            .navigationTitle("Transfer to Additions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Transfer") {
                        onTransfer(chosenCategory.trimmingCharacters(in: .whitespaces), chosenSubCategory)
                        dismiss()
                    }
                    .disabled(!canTransfer)
                }
            }
            .onAppear {
                if existingCategories.isEmpty { useNewCategory = true }
            }
        }
    }
}

// Helper view for priority badge
private struct PriorityBadge: View {
    let value: Int
    private func color(for v: Int) -> Color {
        switch v {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        default: return .blue
        }
    }
    private func textColor(for v: Int) -> Color {
        switch v {
        case 1: return .white      // red background -> white text
        case 2: return .black      // orange background -> black text
        case 3: return .black      // yellow background -> black text
        case 4: return .white      // green background -> white text
        default: return .white     // blue background -> white text
        }
    }
    var body: some View {
        ZStack {
            Circle()
                .fill(color(for: value))
                .frame(width: 24, height: 24)
            Text("\(value)")
                .font(.caption).bold()
                .foregroundStyle(textColor(for: value))
        }
        .accessibilityLabel("Priority \(value)")
    }
}


#Preview("EditRecord - Populated Sample") {
}

