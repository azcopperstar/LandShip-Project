import SwiftUI
import SwiftData

struct LivePunchListView: View {
    // Filters
    @State private var selectedVehicle: String = "All Vehicles"
    @State private var selectedSubcategory: String = "All Projects"
    @State private var showOnlyOpen: Bool = true
    
    @State private var editingItemID: PersistentIdentifier? = nil
    @State private var showPDFReport = false
    @FocusState private var isEditingName: Bool

    // Data
    @Environment(\.modelContext) private var modelContext
    @Environment(\.entitlements) private var entitlements

    // Dynamic query backing store – we will reconstruct via init based on filters
    @Query private var items: [ProjectList]

    init(vehicle: String? = nil, subcategory: String? = nil) {
        // Defaults
        let vehicleValue = vehicle ?? "All Vehicles"
        let subcatRaw = (subcategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let subcatValue = subcatRaw.isEmpty ? "All Projects" : subcatRaw

        _selectedVehicle = State(initialValue: vehicleValue)
        _selectedSubcategory = State(initialValue: subcatValue)

        // Provide a permissive initial query; actual filtering is handled by derived @Query below via a static predicate.
        // We'll start with a simple always-true predicate and sorted order.
        let sortCreatedDesc = SortDescriptor(\ProjectList.createdAt, order: .reverse)
        let predicate: Predicate<ProjectList> = #Predicate { _ in true }
        self._items = Query(filter: predicate, sort: [sortCreatedDesc])
    }

    var body: some View {
        VStack(spacing: 0) {
            contentList
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $showPDFReport) {
            NavigationStack {
                pdfReportPunchList(trackVehicleSelected: selectedVehicle, projectSubcategory: selectedSubcategory)
            }
        }
    }

    // MARK: - Views
    private var filtersBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text("Select a vehicle and project to add items")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
    }

    private var vehiclePicker: some View {
        // Pull vehicles from current items set to offer choices; fallback to explicit 'All Vehicles'
        let vehicles = uniqueVehicles()
        return Menu {
            Button(FleetScope.allDisplayLabel) { selectedVehicle = FleetScope.allSentinel }
            ForEach(vehicles, id: \.self) { v in
                Button(v) { selectedVehicle = v }
            }
        } label: {
            Label(selectedVehicle, systemImage: "car")
                .labelStyle(.titleAndIcon)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).stroke(.separator))
        }
        .accessibilityLabel("\(Vertical.current.assetSingular) Filter")
    }

    private var subcategoryPicker: some View {
        let subs = uniqueSubcategories()
        return Menu {
            Button("All Projects") { selectedSubcategory = "All Projects" }
            ForEach(subs, id: \.self) { s in
                Button(s) { selectedSubcategory = s }
            }
        } label: {
            Label(selectedSubcategory, systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(.titleAndIcon)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).stroke(.separator))
        }
        .accessibilityLabel("Projects Filter")
    }

    private var contentList: some View {
        let currentItems = filteredItems()
        return Group {
            if currentItems.isEmpty {
                ContentUnavailableView("No items", systemImage: "checklist", description: Text("Try changing filters or creating new items."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section(header: headerView(count: currentItems.count)) {
                        ForEach(currentItems) { item in
                            rowView(item)
                        }
                        .onDelete(perform: delete)
                    }
                }
								.safeAreaInset(edge: .top) {
									VStack(spacing: 0) {
										PageTitle_Col2_NoPhoto(label: "PROJECT PUNCHLISTS")
										tipsView
											.frame(maxWidth: .infinity, alignment: .leading)
									}
								}

#if os(iOS)
                .listStyle(.insetGrouped)
#else
                .listStyle(.inset)
#endif
            }
        }
    }

    private func headerView(count: Int) -> some View {
			VStack(alignment: .leading, spacing: 0) {
					tipRow(icon: "hand.tap", text: "Tap chevron to expand/collapse item details")

					VStack(alignment: .leading, spacing: 1) {
						if selectedSubcategory != "All Projects" {
							tipRowChecklist(icon: "checklist", text: "\(selectedSubcategory)")
						} else {
							tipRowChecklist(icon: "checklist", text: "All Projects")
						}
						tipRowVehicle(icon: Vertical.current.assetIcon, text: "\(selectedVehicle)")
					}
			}
    }
    
    // MARK: - Tips View
    
    private var tipsView: some View {
        VStack(alignment: .leading, spacing: 1) {
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .font(.caption2)
                .frame(width: 14)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.blue)
        }
    }
	private func tipRowVehicle(icon: String, text: String) -> some View {
		HStack(spacing: 2) {
			Image(systemName: icon)
				.font(.title2)
				.frame(width: 40)
			Text(text)
				.font(.headline)
		}
		.foregroundStyle(.blue)
	}
	private func tipRowChecklist(icon: String, text: String) -> some View {
		HStack(spacing: 2) {
			Image(systemName: icon)
				.font(.title2)
				.frame(width: 40)
			Text(text)
				.font(.headline)
				.bold()
		}
		.foregroundStyle(.blue)
	}

    private func rowView(_ item: ProjectList) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Toggle(isOn: binding(for: item)) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            // If completed, show checkmark ball; otherwise show priority ball with number
                            if item.itemCompleted {
                                ZStack {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            } else if item.priority > 0 {
                                ZStack {
                                    Circle()
                                        .fill(priorityColor(item.priority))
                                        .frame(width: 24, height: 24)
                                    Text("\(item.priority)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                            
                            if editingItemID == item.persistentModelID {
                                TextField("Item Name", text: Binding(
                                    get: { item.itemName },
                                    set: { newValue in
                                        item.itemName = newValue
                                        item.updatedAt = Date()
                                        try? modelContext.save()
                                    }
                                ))
                                .font(.headline)
                                .focused($isEditingName)
                                .onAppear { isEditingName = true }
                                .onSubmit {
                                    editingItemID = nil
                                    isEditingName = false
                                }
                            } else {
                                Text(item.itemName)
                                    .font(.headline)
                            }
                            Spacer()
                            Button {
                                withAnimation { toggleRowExpanded(item) }
                            } label: {
                                Image(systemName: isRowExpanded(item) ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isRowExpanded(item) ? "Collapse Editor" : "Expand Editor")
                        }

                        if !item.itemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(item.itemDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if !item.itemNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(item.itemNotes)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let parts = partsSummary(item), !parts.isEmpty {
                            Text(parts)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
#if os(macOS)
                .toggleStyle(.checkbox)
#else
                .toggleStyle(.switch)
#endif
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) { delete(item) } label: { Label("Delete", systemImage: "trash") }
                Button { toggleCompletion(item) } label: { Label(item.itemCompleted ? "Reopen" : "Complete", systemImage: item.itemCompleted ? "arrow.uturn.left" : "checkmark") }
                    .tint(item.itemCompleted ? .orange : .green)
            }
            .contextMenu {
                Button("Edit Name") {
                    editingItemID = item.persistentModelID
                    isEditingName = true
                }
            }

            if isRowExpanded(item) {
                // Expanded inline editor for all fields
                VStack(alignment: .leading, spacing: 12) {
                    Group {
                        LabeledContent("Item Name:") {
                            HStack(spacing: 6) {
                                // Break out the binding to help the compiler
                                let nameBinding: Binding<String> = Binding<String>(
                                    get: { item.itemName },
                                    set: { v in item.itemName = v; persistChange(for: item) }
                                )
                                TextField("Item Name", text: nameBinding)
                                ItemNameSuggestionsMenu(names: uniqueItemNames()) { selected in
                                    item.itemName = selected
                                    persistChange(for: item)
                                }
                                .accessibilityLabel("Item name suggestions")
                            }
                        }
                        LabeledContent("\(Vertical.current.assetSingular):") {
                            HStack(spacing: 6) {
                                let vehicleBinding: Binding<String> = Binding<String>(
                                    get: { item.vehicleId },
                                    set: { v in item.vehicleId = v; persistChange(for: item) }
                                )
                                TextField("\(Vertical.current.assetSingular) ID", text: vehicleBinding)
#if os(iOS)
    .disableAutocorrection(true)
    .textInputAutocapitalization(.never)
#endif
                                Menu {
                                    ForEach(uniqueVehicles(), id: \.self) { v in
                                        Button(v) { item.vehicleId = v; persistChange(for: item) }
                                    }
                                } label: {
                                    Image(systemName: "text.badge.plus")
                                }
                                .accessibilityLabel("\(Vertical.current.assetSingular) suggestions")
                            }
                        }
                        LabeledContent("Project:") {
                            HStack(spacing: 6) {
                                let subCategoryBinding: Binding<String> = Binding<String>(
                                    get: { item.subCategory },
                                    set: { v in item.subCategory = v; persistChange(for: item) }
                                )
                                TextField("Subcategory", text: subCategoryBinding)
                                Menu {
                                    ForEach(uniqueSubcategories(), id: \.self) { s in
                                        Button(s) { item.subCategory = s; persistChange(for: item) }
                                    }
                                } label: {
                                    Image(systemName: "text.badge.plus")
                                }
                                .accessibilityLabel("Project suggestions")
                            }
                        }
                        LabeledContent("Category:") {
                            HStack(spacing: 6) {
                                let categoryBinding: Binding<String> = Binding<String>(
                                    get: { item.category },
                                    set: { v in item.category = v; persistChange(for: item) }
                                )
                                TextField("Category", text: categoryBinding)
                                Menu {
                                    ForEach(uniqueCategories(), id: \.self) { c in
                                        Button(c) { item.category = c; persistChange(for: item) }
                                    }
                                } label: {
                                    Image(systemName: "text.badge.plus")
                                }
                                .accessibilityLabel("Category suggestions")
                            }
                        }
                        LabeledContent("Priority:") {
                            Picker("Priority", selection: Binding<Int>(
                                get: { item.priority },
                                set: { v in item.priority = v; persistChange(for: item) }
                            )) {
                                Text("None").tag(0)
                                HStack {
                                    Circle().fill(.red).frame(width: 10, height: 10)
                                    Text("1 - High")
                                }.tag(1)
                                HStack {
                                    Circle().fill(.orange).frame(width: 10, height: 10)
                                    Text("2")
                                }.tag(2)
                                HStack {
                                    Circle().fill(.yellow).frame(width: 10, height: 10)
                                    Text("3 - Medium")
                                }.tag(3)
                                HStack {
                                    Circle().fill(.green).frame(width: 10, height: 10)
                                    Text("4")
                                }.tag(4)
                                HStack {
                                    Circle().fill(.blue).frame(width: 10, height: 10)
                                    Text("5 - Low")
                                }.tag(5)
                            }
#if os(iOS)
                            .pickerStyle(.menu)
#endif
                        }
                    }

                    Group {
                        LabeledContent("Description:") {
                            TextField("Description", text: Binding<String>(
                                get: { item.itemDescription },
                                set: { v in item.itemDescription = v; persistChange(for: item) }
                            ))
                        }
                        LabeledContent("Notes:") {
                            TextEditor(text: Binding<String>(
                                get: { item.itemNotes },
                                set: { v in item.itemNotes = v; persistChange(for: item) }
                            ))
                            .frame(minHeight: 60)
                        }
                        LabeledContent("Vendor:") {
                            HStack(spacing: 6) {
                                let vendorBinding: Binding<String> = Binding<String>(
                                    get: { item.itemVendor },
                                    set: { v in item.itemVendor = v; persistChange(for: item) }
                                )
                                TextField("Vendor", text: vendorBinding)
                                Menu {
                                    ForEach(uniqueVendors(), id: \.self) { v in
                                        Button(v) { item.itemVendor = v; persistChange(for: item) }
                                    }
                                } label: {
                                    Image(systemName: "text.badge.plus")
                                }
                                .accessibilityLabel("Vendor suggestions")
                            }
                        }
                    }

                    Group {
                        HStack {
                            LabeledContent("Odom:") {
                                TextField("0", value: Binding<Int>(
                                    get: { item.miles },
                                    set: { v in item.miles = v; persistChange(for: item) }
                                ), formatter: NumberFormatter())
#if os(iOS)
                                .keyboardType(.numberPad)
#endif
                            }
                            LabeledContent("Hours:") {
                                TextField("0", value: Binding<Int>(
																	get: { Int(item.engHours) },
																	set: { v in item.engHours = Float(v); persistChange(for: item) }
                                ), formatter: NumberFormatter())
#if os(iOS)
                                .keyboardType(.numberPad)
#endif
                            }
                        }
                        HStack {
//                            LabeledContent("Item Cost") {
//                                TextField("0", value: Binding(
//                                    get: { item.itemCost },
//                                    set: { v in item.itemCost = v; persistChange(for: item) }
//                                ), formatter: NumberFormatter())
//                                .keyboardType(.decimalPad)
//                            }
                            LabeledContent("Labor Cost:") {
                                TextField("0.00", value: Binding<Double>(
																	get: { Double(item.laborCost) },
																	set: { v in item.laborCost = Float(v); persistChange(for: item) }
                                ), formatter: currencyFormatter)
#if os(iOS)
                                .keyboardType(.decimalPad)
#endif
                            }
                        }
                    }

//                    Group {
//                        Toggle("Create New Service Record", isOn: Binding(
//                            get: { item.saveInLogbook },
//                            set: { v in item.saveInLogbook = v; persistChange(for: item) }
//                        ))
//                        Toggle("Saved To Logbook", isOn: Binding(
//                            get: { item.savedToLogbook },
//                            set: { v in item.savedToLogbook = v; persistChange(for: item) }
//                        ))
//                    }

                    Group {
                        Text("Parts")
                            .font(.headline)
                            .foregroundStyle(.blue)
                        partRow(title: "Part 1", name: Binding(
                            get: { item.part1 }, set: { v in item.part1 = v; persistChange(for: item) }
                        ), unit: Binding(
                            get: { item.part1Unit }, set: { v in item.part1Unit = v; persistChange(for: item) }
                        ), qty: Binding(
                            get: { item.part1Quantity }, set: { v in item.part1Quantity = v; persistChange(for: item) }
                        ), cost: Binding(
													get: { Double(item.part1cost) }, set: { v in item.part1cost = Float(v); persistChange(for: item) }
                        ))

                        // Additional parts if they exist on the model (optional safe bindings using KeyPaths not available here); replicate pattern if needed.
                        // If your model defines part2..part5, you can add similar rows. We'll include common ones seen in preview.
                        partRow(title: "Part 2", name: Binding(
                            get: { item.part2 }, set: { v in item.part2 = v; persistChange(for: item) }
                        ), unit: Binding(
                            get: { item.part2Unit }, set: { v in item.part2Unit = v; persistChange(for: item) }
                        ), qty: Binding(
                            get: { item.part2Quantity }, set: { v in item.part2Quantity = v; persistChange(for: item) }
                        ), cost: Binding(
													get: { Double(item.part2cost) }, set: { v in item.part2cost = Float(v); persistChange(for: item) }
                        ))

                        partRow(title: "Part 3", name: Binding(
                            get: { item.part3 }, set: { v in item.part3 = v; persistChange(for: item) }
                        ), unit: Binding(
                            get: { item.part3Unit }, set: { v in item.part3Unit = v; persistChange(for: item) }
                        ), qty: Binding(
                            get: { item.part3Quantity }, set: { v in item.part3Quantity = v; persistChange(for: item) }
                        ), cost: Binding(
													get: { Double(item.part3cost) }, set: { v in item.part3cost = Float(v); persistChange(for: item) }
                        ))

                        partRow(title: "Part 4", name: Binding(
                            get: { item.part4 }, set: { v in item.part4 = v; persistChange(for: item) }
                        ), unit: Binding(
                            get: { item.part4Unit }, set: { v in item.part4Unit = v; persistChange(for: item) }
                        ), qty: Binding(
                            get: { item.part4Quantity }, set: { v in item.part4Quantity = v; persistChange(for: item) }
                        ), cost: Binding(
													get: { Double(item.part4cost) }, set: { v in item.part4cost = Float(v); persistChange(for: item) }
                        ))

                        partRow(title: "Part 5", name: Binding(
                            get: { item.part5 }, set: { v in item.part5 = v; persistChange(for: item) }
                        ), unit: Binding(
                            get: { item.part5Unit }, set: { v in item.part5Unit = v; persistChange(for: item) }
                        ), qty: Binding(
                            get: { item.part5Quantity }, set: { v in item.part5Quantity = v; persistChange(for: item) }
                        ), cost: Binding(
													get: { Double(item.part5cost) }, set: { v in item.part5cost = Float(v); persistChange(for: item) }
                        ))
                    }

                    Group {
//                        LabeledContent("Created") {
//                            DatePicker("", selection: Binding(
//                                get: { item.createdAt },
//                                set: { v in item.createdAt = v; persistChange(for: item) }
//                            ), displayedComponents: [.date, .hourAndMinute])
//                                .labelsHidden()
//                        }
//                        LabeledContent("Updated") {
//                            DatePicker("", selection: Binding(
//                                get: { item.updatedAt },
//                                set: { v in item.updatedAt = v; persistChange(for: item) }
//                            ), displayedComponents: [.date, .hourAndMinute])
//                                .labelsHidden()
//                        }
                        if item.itemCompleted {
                            LabeledContent("Completed") {
                                DatePicker("", selection: Binding(
                                    get: { item.completedAt },
                                    set: { v in item.completedAt = v; persistChange(for: item) }
                                ), displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                            }
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.2)))
            }
        }
    }

    // Expanded row state storage keyed by PersistentIdentifier
    @State private var expandedRows: Set<PersistentIdentifier> = []

    private func isRowExpanded(_ item: ProjectList) -> Bool {
        expandedRows.contains(item.persistentModelID)
    }

    private func toggleRowExpanded(_ item: ProjectList) {
        let id = item.persistentModelID
        if expandedRows.contains(id) { expandedRows.remove(id) } else { expandedRows.insert(id) }
    }

    private func persistChange(for item: ProjectList) {
        item.updatedAt = Date()
        try? modelContext.save()
    }

    @ViewBuilder
    private func partRow(title: String, name: Binding<String>, unit: Binding<String>, qty: Binding<Int>, cost: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.blue)

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.blue)
                HStack(spacing: 6) {
                    TextField("Part name", text: name)
                    Menu {
                        ForEach(uniquePartNames(), id: \.self) { p in
                            Button(p) { name.wrappedValue = p }
                        }
                    } label: { Image(systemName: "text.badge.plus") }
                    .accessibilityLabel("Part name suggestions")
                }
            }

            // Unit
            VStack(alignment: .leading, spacing: 4) {
                Text("Unit")
                    .font(.caption)
                    .foregroundStyle(.blue)
                HStack(spacing: 6) {
                    TextField("Unit (ea, qt, ft, etc.)", text: unit)
                    Menu {
                        ForEach(uniquePartUnits(), id: \.self) { u in
                            Button(u) { unit.wrappedValue = u }
                        }
                    } label: { Image(systemName: "text.badge.plus") }
                    .accessibilityLabel("Part unit suggestions")
                }
            }

            // Quantity and Cost
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quantity")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    TextField("0", value: qty, formatter: NumberFormatter())
                        .frame(minWidth: 60)
#if os(iOS)
                        .keyboardType(.numberPad)
#endif
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cost")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    TextField("0.00", value: cost, formatter: currencyFormatter)
                        .frame(minWidth: 80)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                }
            }
        }
    }

    private var toolbarContent: some ToolbarContent {
#if os(macOS)
    ToolbarItemGroup(placement: .automatic) {
        Button { showPDFReport = true } label: {
            Image(systemName: "doc.text")
        }
        .help("PDF Report")
        .accessibilityLabel("PDF Report")
        vehiclePicker
        subcategoryPicker
        Toggle(isOn: $showOnlyOpen) {
            Image(systemName: showOnlyOpen ? "eye" : "eye.slash")
        }
        .toggleStyle(.button)
        .help("View Only Open Items")
        .accessibilityLabel("View Only Open Items")
        Button { newItem() } label: {
            Image(systemName: "plus")
        }
            .disabled(!canCreateItem)
            .help("New")
            .accessibilityLabel("New")
    }
#else
    ToolbarItemGroup(placement: .topBarTrailing) {
        Button { showPDFReport = true } label: {
            Label("PDF Report", systemImage: "doc.text")
        }
        Menu {
            Button(FleetScope.allDisplayLabel) { selectedVehicle = FleetScope.allSentinel }
            ForEach(uniqueVehicles(), id: \.self) { v in
                Button(v) { selectedVehicle = v }
            }
        } label: {
            Image(systemName: "car")
        }
        .accessibilityLabel("\(Vertical.current.assetSingular) Filter")
        Menu {
            Button("All Projects") { selectedSubcategory = "All Projects" }
            ForEach(uniqueSubcategories(), id: \.self) { s in
                Button(s) { selectedSubcategory = s }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Projects Filter")
        Toggle(isOn: $showOnlyOpen) {
            Image(systemName: showOnlyOpen ? "eye" : "eye.slash")
        }
        .toggleStyle(.button)
        Button { newItem() } label: {
            Image(systemName: "plus")
        }
        .disabled(!canCreateItem)
    }
#endif
    }

    // MARK: - Helpers
    private var canCreateItem: Bool {
        let hasVehicle = selectedVehicle != "All Vehicles" && !selectedVehicle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasSubcategory = selectedSubcategory != "All Projects" && !selectedSubcategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasVehicle && hasSubcategory
    }

    private var queryIdentity: String {
        // Changing this forces NavigationStack to rebuild and @Query to refetch in a predictable way
        "\(selectedVehicle)|\(selectedSubcategory)|\(showOnlyOpen)"
    }

    private func filteredItems() -> [ProjectList] {
        items.filter { item in
            // Vehicle filter
            let vehiclePass = (selectedVehicle == "All Vehicles") || (item.vehicleId == selectedVehicle)
            // Subcategory filter
            let subcatPass: Bool = {
                if selectedSubcategory == "All Projects" { return true }
                let sRaw = selectedSubcategory.trimmingCharacters(in: .whitespacesAndNewlines)
                let s = sRaw.isEmpty ? "General" : sRaw
                return item.subCategory == s
            }()
            // Open/Closed filter
            let openPass = showOnlyOpen ? (item.itemCompleted == false) : true
            return vehiclePass && subcatPass && openPass
        }
        .sorted { a, b in
            // Sort by priority first (1 is highest, then 2, 3, etc.)
            // Items with priority 0 go to the end
            let aPriority = a.priority == 0 ? Int.max : a.priority
            let bPriority = b.priority == 0 ? Int.max : b.priority
            if aPriority != bPriority { return aPriority < bPriority }
            if a.vehicleId != b.vehicleId { return a.vehicleId < b.vehicleId }
            if a.category != b.category { return a.category < b.category }
            if a.subCategory != b.subCategory { return a.subCategory < b.subCategory }
            return a.createdAt > b.createdAt
        }
    }

    private func uniqueVehicles() -> [String] {
        let vs = Set(items.map { $0.vehicleId }).sorted()
        return vs
    }

    private func uniqueSubcategories() -> [String] {
        let s = Set(items.map { $0.subCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "General" : $0.subCategory }).sorted()
        return s
    }
    
    private func uniqueCategories() -> [String] {
        let s = Set(items.map { $0.category }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).sorted()
        return s
    }

    private func uniqueVendors() -> [String] {
        let s = Set(items.map { $0.itemVendor }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).sorted()
        return s
    }

    private func uniquePartNames() -> [String] {
        let names = items.flatMap { [$0.part1, $0.part2, $0.part3, $0.part4, $0.part5] }
        let s = Set(names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }).sorted()
        return s
    }

    private func uniquePartUnits() -> [String] {
        let units = items.flatMap { [$0.part1Unit, $0.part2Unit, $0.part3Unit, $0.part4Unit, $0.part5Unit] }
        let s = Set(units.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }).sorted()
        return s
    }

    private var currencyFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        f.maximumFractionDigits = 2
        return f
    }

    private func uniqueItemNames() -> [String] {
        let names = Set(items.map { $0.itemName }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        return names.sorted()
    }

    private func partsSummary(_ r: ProjectList) -> String? {
        func one(_ name: String, _ qty: Int, _ unit: String) -> String? {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return nil }
            let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
            if qty > 0 {
                if trimmedUnit.isEmpty { return "x\(qty) \(trimmedName)" }
                else { return "x\(qty) \(trimmedUnit) \(trimmedName)" }
            } else {
                return trimmedName
            }
        }
        let parts = [
            one(r.part1, r.part1Quantity, r.part1Unit),
            one(r.part2, r.part2Quantity, r.part2Unit),
            one(r.part3, r.part3Quantity, r.part3Unit),
            one(r.part4, r.part4Quantity, r.part4Unit),
            one(r.part5, r.part5Quantity, r.part5Unit)
        ].compactMap { $0 }.joined(separator: ", ")
        return parts.isEmpty ? nil : parts
    }

    private func binding(for item: ProjectList) -> Binding<Bool> {
        Binding<Bool>(
            get: { item.itemCompleted },
            set: { newValue in
                item.itemCompleted = newValue
                if newValue {
                    item.completedAt = Date()
                }
                try? modelContext.save()
            }
        )
    }

    private func toggleCompletion(_ item: ProjectList) {
        item.itemCompleted.toggle()
        if item.itemCompleted {
            item.completedAt = Date()
        }
        try? modelContext.save()
    }

    private func delete(_ item: ProjectList) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    private func delete(at offsets: IndexSet) {
        let filtered = filteredItems()
        for index in offsets { modelContext.delete(filtered[index]) }
        try? modelContext.save()
    }

    private func newItem() {
        guard canCreateItem else { return }
        guard entitlements.requestCreate(ProjectList.self, in: modelContext) else { return }
        let now = Date()
        let sRaw = selectedSubcategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = (selectedSubcategory == "All Projects") ? "General" : (sRaw.isEmpty ? "General" : sRaw)
        let v = (selectedVehicle == "All Vehicles") ? "" : selectedVehicle
        let item = ProjectList(
            createdAt: now,
            updatedAt: now,
            vehicleId: v,
            miles: 0,
            engHours: 0,
            itemName: "New Item",
            itemDescription: "",
            itemNotes: "",
            itemVendor: "",
            category: "",
            subCategory: s,
            itemCompleted: false,
            completedAt: now,
            saveInLogbook: false,
            savedToLogbook: false,
            itemCost: 0,
            laborCost: 0,
            part1: "",
            part1cost: 0,
            part1Unit: "",
            part1Quantity: 0
        )
        modelContext.insert(item)
        try? modelContext.save()
        
        // Begin inline editing for the new item
        editingItemID = item.persistentModelID
        // Defer focus to the next runloop to ensure the row is visible
        DispatchQueue.main.async {
            isEditingName = true
        }
    }

    private func markAllComplete(_ completed: Bool) {
        for item in filteredItems() {
            item.itemCompleted = completed
            if completed {
                item.completedAt = Date()
            }
        }
        try? modelContext.save()
    }
    
    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .cyan
        case 5: return .blue
        default: return .gray
        }
    }
}

private struct ItemNameSuggestionsMenu: View {
    let names: [String]
    let onPick: (String) -> Void

    var body: some View {
        Menu {
            ForEach(names, id: \.self) { n in
                Button(n) { onPick(n) }
            }
        } label: {
            Image(systemName: "text.badge.plus")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ProjectList.self, Settings1.self, configurations: config)
    let context = container.mainContext

    // Seed sample
    let now = Date()
    let r1 = ProjectList(createdAt: now, updatedAt: now, vehicleId: "Vehicle A", miles: 0, engHours: 0, itemName: "Replace filter", itemDescription: "Air filter under hood", itemNotes: "Use OEM part.", itemVendor: "", category: "Engine", subCategory: "Oil", itemCompleted: false, completedAt: now, saveInLogbook: false, savedToLogbook: false, itemCost: 0, laborCost: 0, part1: "Air Filter", part1cost: 18.5, part1Unit: "ea", part1Quantity: 1)
    let r2 = ProjectList(createdAt: now, updatedAt: now, vehicleId: "Vehicle A", miles: 0, engHours: 0, itemName: "Change oil", itemDescription: "5W-30 full synthetic", itemNotes: "Next change in 3 months.", itemVendor: "", category: "Engine", subCategory: "Oil", itemCompleted: true, completedAt: now, saveInLogbook: false, savedToLogbook: false, itemCost: 0, laborCost: 0, part1: "Oil", part1cost: 30, part1Unit: "qt", part1Quantity: 5, part2: "Filter", part2cost: 12, part2Unit: "ea", part2Quantity: 1)
    context.insert(r1); context.insert(r2)

    return LivePunchListView()
        .modelContainer(container)
}

