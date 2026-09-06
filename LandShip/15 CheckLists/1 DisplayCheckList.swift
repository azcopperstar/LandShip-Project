//
//  DisplayCheckList.swift
//  LandShip
//
//  Created by JP on 2/19/26.
//

import SwiftUI
import SwiftData

struct DisplayCheckList: View {
	// MARK: - Data sources and environment
	
	@Query var vehicles: [Vehicle8]
	@Query var allCheckListItems: [CheckListItem]
	@Query(sort: [SortDescriptor(\CheckList.categoryOrder), SortDescriptor(\CheckList.checklistOrder)])
	var allChecklists: [CheckList]
	@Environment(\.modelContext) var modelContext
	@Environment(\.entitlements) private var entitlements

	@State private var selectedRecord: CheckList?
	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false
	
	// MARK: - Vehicle selection
	
	@Binding var trackVehicleSelected: String
	@State private var selectedVehicle: Vehicle8?
	@State private var allVehiclesSelected: Bool = true
	
	// MARK: - Navigation state
	
	@State private var newRecordToEdit: CheckList?
	@State private var showVehicleSelectionAlert: Bool = false

	// MARK: - PDF Report
	// Lets a checklist generate its report directly from the list (right-click/long-press a row)
	// instead of requiring you to open LiveCheckListView first.
	private struct ReportDestination: Identifiable, Hashable {
		let id = UUID()
		let checklist: CheckList
		static func == (lhs: ReportDestination, rhs: ReportDestination) -> Bool { lhs.id == rhs.id }
		func hash(into hasher: inout Hasher) { hasher.combine(id) }
	}
	@State private var reportDestination: ReportDestination?
	
	// MARK: - Editor state
	
	@State private var showChecklistEditor: Bool = false
	@State private var editingChecklist: CheckList?
	@State private var checklistCategory: String = ""
	@State private var checklistName: String = ""
	@State private var checklistDescription: String = ""
	@State private var checklistNotes: String = ""
	@State private var checklistVehicleId: String = ""
	@State private var headerBgColor: Color = .clear
	@State private var headerFgColor: Color = .blue

	// MARK: - Delete confirmation
	// (Rename-cascade confirmation for the checklist name lives in ChecklistEditorSheetView,
	// which owns the Save button; see hasLinkedRecords/onSaveWithRename below.)
	
	@State private var showDeleteConfirmation: Bool = false
	@State private var checklistToDelete: CheckList?
	
	// MARK: - Edit mode for reordering
	
	@State private var isEditMode: Bool = false
	
	// MARK: - Category editing
	
	@State private var showCategoryEditor: Bool = false
	@State private var editingCategoryName: String = ""
	@State private var newCategoryName: String = ""
	
	// MARK: - Computed Properties
	
	private var filteredChecklists: [CheckList] {
		allChecklists.filter { item in
			(showInactiveVehicles || !item.inactive) && (
				trackVehicleSelected == "All Vehicles"
				|| item.vehicleId == trackVehicleSelected
			)
		}
	}
	
	// MARK: - Body
	
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

	var body: some View {
		// A `Group` here is "transparent" for preference-based modifiers like `.toolbar` — with
		// two children, SwiftUI applies the toolbar content once per child, duplicating every
		// item. `VStack` produces the same vertical layout without that duplication.
		VStack(spacing: 0) {
			ModelPicker(
				selection: $selectedVehicle,
				title: "",
				includeEmptyChoice: true,
				emptyChoiceLabel: FleetScope.allDisplayLabel,
				autoSelectFirst: false,
				filter: showInactiveVehicles ? nil : #Predicate<Vehicle8> { $0.inactive == false },
				sort: [SortDescriptor(\.displayName, order: .forward)],
				labelProvider: { v in "\(v.year) \(v.displayName)"},
				thumbnailData: { $0.image1 }
			)
			.frame(maxWidth: .infinity)

			checklistsList(records: filteredChecklists)
				.animation(.none, value: filteredChecklists.count)
				.transaction { transaction in
					transaction.animation = nil
					transaction.disablesAnimations = true
				}
		}
		.toolbar {
			ToolbarItem(placement: .automatic) {
				Button {
					withAnimation {
						isEditMode.toggle()
					}
				} label: {
#if os(macOS)
					Image(systemName: isEditMode ? "checkmark" : "pencil")
#else
					VStack(spacing: 2) {
					Image(systemName: isEditMode ? "checkmark" : "pencil")
					Text(isEditMode ? "Done" : "Edit")
						.font(.caption2)
				}
#endif
				}
				.help(isEditMode ? "Done" : "Edit")
				.accessibilityLabel(isEditMode ? "Done editing" : "Edit order")
			}

			if !allVehiclesSelected {
				ToolbarItem(placement: .automatic) {
					Button(action: addNewRecord) {
#if os(macOS)
						Image(systemName: "plus")
#else
						VStack(spacing: 2) {
						Image(systemName: "plus")
						Text("New")
							.font(.caption2)
					}
#endif
					}
					.help("New")
					.accessibilityLabel("New")
				}
			}
		}
		.onChange(of: selectedVehicle) { _, newVehicle in
			trackVehicleSelected = newVehicle?.name ?? "All Vehicles"
			allVehiclesSelected = (trackVehicleSelected == "All Vehicles")
		}
		.onChange(of: trackVehicleSelected) { _, newValue in
			allVehiclesSelected = (newValue == "All Vehicles")
			if newValue == "All Vehicles" {
				selectedVehicle = nil
			} else {
				selectedVehicle = vehicles.first(where: { $0.name == newValue })
			}
		}
		.onAppear {
			allVehiclesSelected = (trackVehicleSelected == "All Vehicles")
			if trackVehicleSelected != "All Vehicles" {
				selectedVehicle = vehicles.first(where: { $0.name == trackVehicleSelected })
			}
		}
//		.navigationTitle("Checklists")
		.navigationDestination(item: $newRecordToEdit) { record in
			LiveCheckListView(checklist: record)
		}
		.navigationDestination(item: $reportDestination) { dest in
			pdfReportCheckListItems(checklist: dest.checklist)
				.ignoresSafeArea()
		}
		.alert("Select a Specific \(Vertical.current.assetSingular)", isPresented: $showVehicleSelectionAlert) {
			Button("OK", role: .cancel) {}
		} message: {
			Text("A checklist can only be created when a specific \(Vertical.current.assetSingular.lowercased()) is selected. Please choose a \(Vertical.current.assetSingular.lowercased()) — '\(FleetScope.allDisplayLabel)' is not allowed.")
		}
		.alert("Delete Checklist", isPresented: $showDeleteConfirmation) {
			Button("Cancel", role: .cancel) {
				checklistToDelete = nil
			}
			Button("Delete", role: .destructive) {
				if let checklist = checklistToDelete {
					deleteChecklist(checklist)
					checklistToDelete = nil
				}
			}
		} message: {
			if let checklist = checklistToDelete {
				Text("Are you sure you want to delete '\(checklist.checklistName)'? This action cannot be undone.")
			}
		}
		.alert("Rename Category", isPresented: $showCategoryEditor) {
			TextField("Category Name", text: $newCategoryName)
			Button("Cancel", role: .cancel) {
				showCategoryEditor = false
			}
			Button("Save") {
				saveCategoryName()
			}
		} message: {
			Text("Renaming '\(editingCategoryName)' will update all checklists in this category.")
		}
		.sheet(isPresented: $showChecklistEditor) {
			ChecklistEditorSheetView(
				checklistName: $checklistName,
				checklistCategory: $checklistCategory,
				checklistDescription: $checklistDescription,
				checklistNotes: $checklistNotes,
				checklistVehicleId: $checklistVehicleId,
				headerBgColor: $headerBgColor,
				headerFgColor: $headerFgColor,
				editingChecklist: editingChecklist,
				trackVehicleSelected: trackVehicleSelected,
				uniqueCategories: uniqueCategories(),
				hasLinkedRecords: hasLinkedRecords,
				onSave: { saveChecklist(updateLinkedItems: false) },
				onSaveWithRename: { saveChecklist(updateLinkedItems: true) },
				onCancel: { showChecklistEditor = false }
			)
		}
	}
	
	// MARK: - Checklists List
	
	private enum ListItem: Identifiable {
		case category(String, Int)  // category name, order
		case checklist(CheckList)
		
		var id: String {
			switch self {
			case .category(let name, _): return "category_\(name)"
			case .checklist(let record): return "checklist_\(record.id)"
			}
		}
	}
	
	@ViewBuilder
	private func checklistsList(records: [CheckList]) -> some View {
		if records.isEmpty {
			List {
				EmptyStateSection(
					title: "Add your first Checklist",
					systemImage: "checklist",
					description: "Create a checklist to track recurring tasks and inspections.\n\nTo add additional checklists after this first one, select the '+' button at the top of the form.",
					actionTitle: "Add First Checklist",
					action: addNewRecord
				)
			}
		} else {
			List {
				ForEach(createFlatList(from: records)) { item in
					switch item {
					case .category(let name, _):
						categoryHeaderRow(name)
							.listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
					case .checklist(let record):
						checklistRow(record)
							.listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
					}
				}
				.conditionalModifier(isEditMode) { view in
					view.onMove { from, to in
						performMove(records: records, from: from, to: to)
					}
				}
			}
			.animation(.none, value: 0)
			.safeAreaInset(edge: .top) {
				VStack(spacing: 0) {
					PageTitle_Col2_NoPhoto(label: "CHECKLIST")
					tipsView
						.frame(maxWidth: .infinity, alignment: .leading)
				}
			}

			
			#if os(iOS) || os(watchOS) || os(tvOS)
			.listRowSpacing(2)
			.listStyle(.insetGrouped)
			#else
			.listStyle(.inset)
			#endif
		}
	}
	
	private func categoryHeaderRow(_ category: String) -> some View {
		HStack {
			Text(category)
				.font(.headline)
				.fontWeight(.heavy)
				.textCase(nil)
				.foregroundStyle(.blue)
			Spacer(minLength: 0)
			if !isEditMode {
				Image(systemName: "pencil.circle")
					.foregroundStyle(.blue)
					.font(.caption)
			}
		}
		.padding(.vertical, 10)
		.listRowBackground(Color.secondary.opacity(0.1))
		.listRowSeparator(.hidden)
		.contentShape(Rectangle())
		.onTapGesture {
			if !isEditMode {
				editCategoryName(category)
			}
		}
		.contextMenu {
			if !isEditMode {
				Button {
					editCategoryName(category)
				} label: {
					Label("Rename Category", systemImage: "pencil")
				}
			}
		}
	}
	
	@ViewBuilder
	private func checklistRow(_ record: CheckList) -> some View {
		HStack(spacing: 12) {
			// Drag handle and delete button when in edit mode
			if isEditMode {
				HStack(spacing: 8) {
					Image(systemName: "line.3.horizontal")
						.foregroundStyle(.tertiary)
						.font(.body)
					Button(role: .destructive) {
						checklistToDelete = record
						showDeleteConfirmation = true
					} label: {
						Image(systemName: "trash")
							.foregroundStyle(.red)
					}
					.buttonStyle(.plain)
					.help("Delete this checklist")
				}
			}
			
			NavigationLink {
				LiveCheckListView(checklist: record)
					.id(record.id)
			} label: {
				VStack(alignment: .leading, spacing: 4) {
					Text(record.checklistName)
						.font(.headline)
						.fontWeight(.semibold)
					
					if !record.checklistDescription.isEmpty {
						Text(record.checklistDescription)
							.font(.caption)
							.foregroundStyle(.secondary)
							.lineLimit(2)
					}
					
					HStack(spacing: 12) {
						Label(record.vehicleId.isEmpty ? "—" : record.vehicleId, systemImage: Vertical.current.assetIcon)
							.font(.caption2)
							.foregroundStyle(.tertiary)
						
						// Display checklist item completion status
						checklistCompletionBadge(for: record)
					}
				}
				.padding(.vertical, 4)
			}
		}
		.swipeActions(edge: .leading) {
			Button {
				editChecklist(record)
			} label: {
				Label("Edit", systemImage: "pencil")
			}
			.tint(.blue)
		}
		.swipeActions(edge: .trailing) {
			Button(role: .destructive) {
				checklistToDelete = record
				showDeleteConfirmation = true
			} label: {
				Label("Delete", systemImage: "trash")
			}
		}
		.contextMenu {
			Button {
				editChecklist(record)
			} label: {
				Label("Edit Checklist Info", systemImage: "pencil")
			}
			Button {
				reportDestination = ReportDestination(checklist: record)
			} label: {
				Label("Generate PDF Report", systemImage: "doc.text")
			}
			Button(role: .destructive) {
				checklistToDelete = record
				showDeleteConfirmation = true
			} label: {
				Label("Delete Checklist", systemImage: "trash")
			}
		}

	}
	
	// MARK: - Checklist Completion Badge
	
	@ViewBuilder
	private func checklistCompletionBadge(for checklist: CheckList) -> some View {
		let status = getChecklistCompletionStatus(for: checklist)
		let itemLabel = status.totalItems == 1 ? "item" : "items"
		
		Group {
			if status.totalItems == 0 {
				// No items in checklist
				Label("No Items", systemImage: "circle.dotted")
					.font(.caption2)
					.foregroundStyle(.secondary)
			} else if status.completedItems == 0 {
				// Not started (blue)
				Label("\(status.totalItems) \(itemLabel)", systemImage: "circle")
					.font(.caption2)
					.foregroundStyle(.blue)
			} else if status.completedItems < status.totalItems {
				// In progress (orange with count)
				Label("\(status.completedItems)/\(status.totalItems) \(itemLabel)", systemImage: "circle.lefthalf.filled")
					.font(.caption2)
					.foregroundStyle(.orange)
			} else {
				// All complete (green)
				Label("Complete", systemImage: "checkmark.circle.fill")
					.font(.caption2)
					.foregroundStyle(.green)
			}
		}
		.id("\(checklist.id)_\(status.totalItems)_\(status.completedItems)")
	}
	
	private struct ChecklistCompletionStatus {
		let totalItems: Int
		let completedItems: Int
	}
	
	private func getChecklistCompletionStatus(for checklist: CheckList) -> ChecklistCompletionStatus {
		// Use the @Query property instead of fetching during render
		let items = allCheckListItems.filter { $0.checklistName == checklist.checklistName }
		let totalItems = items.count
		let completedItems = items.filter { $0.itemCompleted }.count
		
		return ChecklistCompletionStatus(totalItems: totalItems, completedItems: completedItems)
	}
	
	// MARK: - Tips View
	
	private var tipsView: some View {
		VStack(alignment: .leading, spacing: 1) {
#if os(macOS)
			tipRow(icon: "hand.tap", text: "Right-click either category or checklist for edit, report, and delete options")
#else
			tipRow(icon: "hand.tap", text: "Long-press either category or checklist for edit, report, and delete options")
#endif
			
			tipRow(icon: "pencil", text: "Edit Mode icon above is used to reorder categories and checklists by dragging/dropping handles")
			tipRowVehicle(icon: Vertical.current.assetIcon, text: "\(trackVehicleSelected)")
		}
		.padding(.horizontal, 2)
//		.padding(.vertical, 1)
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
				.frame(width: 24)
			Text(text)
				.font(.headline)
		}
		.foregroundStyle(.blue)
	}
	private func tipRowChecklist(icon: String, text: String) -> some View {
		HStack(spacing: 2) {
			Image(systemName: icon)
				.font(.title2)
				.frame(width: 24)
			Text(text)
				.font(.headline)
				.bold()
		}
		.foregroundStyle(.blue)
	}

	// MARK: - Helper Functions
	
	private struct CategoryGroup {
		let category: String
		let order: Int
		let checklists: [CheckList]
	}
	
	private func groupAndSortRecords(_ records: [CheckList]) -> [CategoryGroup] {
		let grouped = Dictionary(grouping: records) { rec in
			rec.category.isEmpty ? "Uncategorized" : rec.category
		}
		
		var groups: [CategoryGroup] = []
		for (category, items) in grouped {
			let sortedItems = items.sorted { $0.checklistOrder < $1.checklistOrder }
			let categoryOrder = items.first?.categoryOrder ?? 0
			groups.append(CategoryGroup(category: category, order: categoryOrder, checklists: sortedItems))
		}
		
		return groups.sorted { $0.order < $1.order }
	}
	
	private func createFlatList(from records: [CheckList]) -> [ListItem] {
		let grouped = groupAndSortRecords(records)
		var items: [ListItem] = []
		
		for group in grouped {
			items.append(.category(group.category, group.order))
			for checklist in group.checklists {
				items.append(.checklist(checklist))
			}
		}
		
		return items
	}
	
	private func performMove(records: [CheckList], from source: IndexSet, to destination: Int) {
		// Get current flat list
		let currentItems = createFlatList(from: records)
		
		guard let sourceIndex = source.first,
			  sourceIndex < currentItems.count else { return }
		
		let movingItem = currentItems[sourceIndex]
		
		// Determine if we're moving a category or a checklist
		switch movingItem {
		case .category:
			// Moving a category - need to move all its checklists together
			var itemsToMove: [ListItem] = [movingItem]
			var idx = sourceIndex + 1
			
			// Collect all checklists in this category
			while idx < currentItems.count {
				if case .category = currentItems[idx] {
					break
				}
				itemsToMove.append(currentItems[idx])
				idx += 1
			}
			
			// Remove all items
			var newItems = currentItems
			newItems.removeSubrange(sourceIndex..<sourceIndex + itemsToMove.count)
			
			// Calculate new insertion point
			let insertIndex = destination > sourceIndex ? destination - itemsToMove.count : destination
			let clampedInsert = max(0, min(insertIndex, newItems.count))
			
			// Insert all items at new location
			newItems.insert(contentsOf: itemsToMove, at: clampedInsert)
			
			// Update all records with new order
			updateOrdersFromFlatList(newItems)
			
		case .checklist(let checklist):
			// Moving a single checklist
			var newItems = currentItems
			newItems.move(fromOffsets: source, toOffset: destination)
			
			// Update the checklist's category based on its new position
			var currentCat: String?
			for (_, item) in newItems.enumerated() {
				if case .category(let name, _) = item {
					currentCat = name
				}
				if case .checklist(let cl) = item, cl.id == checklist.id {
					if let cat = currentCat {
						checklist.category = cat
					}
					break
				}
			}
			
			// Update all records with new order
			updateOrdersFromFlatList(newItems)
		}
		
		try? modelContext.save()
	}
	
	private func updateOrdersFromFlatList(_ items: [ListItem]) {
		var categoryOrderCounter = 0
		var currentCategoryName: String?
		var checklistOrderInCurrentCategory = 0
		var categoryToOrderMap: [String: Int] = [:]
		
		for item in items {
			switch item {
			case .category(let categoryName, _):
				currentCategoryName = categoryName
				categoryToOrderMap[categoryName] = categoryOrderCounter
				categoryOrderCounter += 1
				checklistOrderInCurrentCategory = 0
				
			case .checklist(let checklist):
				if let catName = currentCategoryName {
					checklist.category = catName
					checklist.categoryOrder = categoryToOrderMap[catName] ?? 0
					checklist.checklistOrder = checklistOrderInCurrentCategory
					checklist.updatedAt = Date()
					checklistOrderInCurrentCategory += 1
				}
			}
		}
	}
	
	// MARK: - Record Management
	
	private func addNewRecord() {
		guard !trackVehicleSelected.isEmpty, trackVehicleSelected != "All Vehicles" else {
			showVehicleSelectionAlert = true
			return
		}
		guard entitlements.requestCreate(CheckList.self, in: modelContext) else { return }

		editingChecklist = nil
		checklistCategory = ""
		checklistName = "New Checklist"
		checklistDescription = ""
		checklistNotes = ""
		checklistVehicleId = trackVehicleSelected
		headerBgColor = .clear
		headerFgColor = .blue
		showChecklistEditor = true
	}

	private func editChecklist(_ checklist: CheckList) {
		editingChecklist = checklist
		checklistCategory = checklist.category
		checklistName = checklist.checklistName
		checklistDescription = checklist.checklistDescription
		checklistNotes = checklist.checklistNotes
		checklistVehicleId = checklist.vehicleId
		headerBgColor = checklist.headerBgColorHex.isEmpty ? .clear : (Color(hex: checklist.headerBgColorHex) ?? .clear)
		headerFgColor = checklist.headerFgColorHex.isEmpty ? .blue : (Color(hex: checklist.headerFgColorHex) ?? .blue)
		showChecklistEditor = true
	}
	
	/// True if any `CheckListItem` references `name` by checklist name. Used to decide whether
	/// the rename-cascade dialog is worth showing — a brand-new or never-referenced checklist has
	/// nothing to break, so saving proceeds silently.
	private func hasLinkedRecords(_ name: String) -> Bool {
		guard !name.isEmpty else { return false }
		var fd = FetchDescriptor<CheckListItem>(predicate: #Predicate<CheckListItem> { $0.checklistName == name })
		fd.fetchLimit = 1
		return ((try? modelContext.fetch(fd)) ?? []).isEmpty == false
	}

	/// Updates every `CheckListItem` that references this checklist by name (LandShip's
	/// string-based linking convention — the same one used for vendor/part/item/system renames),
	/// so existing links survive a checklist rename instead of silently orphaning.
	private func renameLinkedCheckListItems(from oldName: String, to newName: String) {
		guard !oldName.isEmpty, oldName != newName else { return }
		let itemsDescriptor = FetchDescriptor<CheckListItem>(predicate: #Predicate<CheckListItem> { $0.checklistName == oldName })
		if let itemsToUpdate = try? modelContext.fetch(itemsDescriptor) {
			for item in itemsToUpdate {
				item.checklistName = newName
				item.updatedAt = Date()
			}
		}
	}

	private func saveChecklist(updateLinkedItems: Bool) {
		if let existing = editingChecklist {
			// Capture the old name before changing it
			let oldChecklistName = existing.checklistName
			let newChecklistName = checklistName.trimmingCharacters(in: .whitespacesAndNewlines)

			existing.category = checklistCategory.trimmingCharacters(in: .whitespacesAndNewlines)
			existing.checklistName = newChecklistName
			existing.checklistDescription = checklistDescription.trimmingCharacters(in: .whitespacesAndNewlines)
			existing.checklistNotes = checklistNotes.trimmingCharacters(in: .whitespacesAndNewlines)
			existing.vehicleId = checklistVehicleId.trimmingCharacters(in: .whitespacesAndNewlines)
			existing.headerBgColorHex = headerBgColor.hexString()
			existing.headerFgColorHex = headerFgColor.hexString()
			existing.updatedAt = Date()

			// If the checklist name changed, update all associated CheckListItem records —
			// but only when the user opted in via the rename-cascade dialog.
			if updateLinkedItems, oldChecklistName != newChecklistName {
				renameLinkedCheckListItems(from: oldChecklistName, to: newChecklistName)
			}

			try? modelContext.save()
			showChecklistEditor = false
		} else {
			let descriptor = FetchDescriptor<CheckList>()
			let allChecklists = (try? modelContext.fetch(descriptor)) ?? []
			
			let trimmedCategory = checklistCategory.trimmingCharacters(in: .whitespacesAndNewlines)
			let categoryChecklists = allChecklists.filter { $0.category == trimmedCategory }
			let categoryOrder = categoryChecklists.first?.categoryOrder ?? (allChecklists.map { $0.categoryOrder }.max() ?? -1) + 1
			let maxChecklistOrder = categoryChecklists.map { $0.checklistOrder }.max() ?? -1
			
			let newRecord = CheckList(
				inactive: false,
				createdAt: Date(),
				updatedAt: Date(),
				vehicleId: trackVehicleSelected,
				category: trimmedCategory,
				categoryOrder: categoryOrder,
				checklistName: checklistName.trimmingCharacters(in: .whitespacesAndNewlines),
				checklistDescription: checklistDescription.trimmingCharacters(in: .whitespacesAndNewlines),
				checklistNotes: checklistNotes.trimmingCharacters(in: .whitespacesAndNewlines),
				checklistCompleted: false,
				completedAt: Date(),
				checklistOrder: maxChecklistOrder + 1,
				headerBgColorHex: headerBgColor.hexString(),
				headerFgColorHex: headerFgColor.hexString()
			)
			
			modelContext.insert(newRecord)
			try? modelContext.save()
			showChecklistEditor = false
			newRecordToEdit = newRecord
		}
	}
	
	private func deleteChecklist(_ checklist: CheckList) {
		modelContext.delete(checklist)
		try? modelContext.save()
	}
	
	private func uniqueCategories() -> [String] {
		let descriptor = FetchDescriptor<CheckList>()
		guard let allChecklists = try? modelContext.fetch(descriptor) else { return [] }
		let categories = Set(allChecklists.map { $0.category }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
		return categories.sorted()
	}
	
	private func editCategoryName(_ category: String) {
		editingCategoryName = category
		newCategoryName = category
		showCategoryEditor = true
	}
	
	private func saveCategoryName() {
		let trimmedNew = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
		
		guard !trimmedNew.isEmpty, trimmedNew != editingCategoryName else {
			showCategoryEditor = false
			return
		}
		
		let descriptor = FetchDescriptor<CheckList>()
		guard let allChecklists = try? modelContext.fetch(descriptor) else {
			showCategoryEditor = false
			return
		}
		
		// Handle "Uncategorized" which represents empty category strings
		let searchCategory = editingCategoryName == "Uncategorized" ? "" : editingCategoryName
		
		for checklist in allChecklists where checklist.category == searchCategory {
			checklist.category = trimmedNew
			checklist.updatedAt = Date()
		}
		
		try? modelContext.save()
		showCategoryEditor = false
	}
	

}

// MARK: - Checklist Editor Sheet

private struct ChecklistEditorSheetView: View {
	@Binding var checklistName: String
	@Binding var checklistCategory: String
	@Binding var checklistDescription: String
	@Binding var checklistNotes: String
	@Binding var checklistVehicleId: String
	@Binding var headerBgColor: Color
	@Binding var headerFgColor: Color
	let editingChecklist: CheckList?
	let trackVehicleSelected: String
	let uniqueCategories: [String]
	let hasLinkedRecords: (String) -> Bool
	let onSave: () -> Void
	let onSaveWithRename: () -> Void
	let onCancel: () -> Void

	// Controls presentation of the rename-cascade confirmation dialog, shown when saving
	// a checklist name change that would otherwise orphan items that reference it by name.
	@State private var showingRenameChoice: Bool = false

	// Vehicle picker for the "Edit Checklist Info" flow — lets an existing checklist be
	// reassigned to a different vehicle instead of being locked to the one it was created under.
	@Query(sort: [SortDescriptor(\Vehicle8.displayName, order: .forward)]) private var vehicles: [Vehicle8]
	private var vehicleBinding: Binding<Vehicle8?> {
		Binding(
			get: { vehicles.first(where: { $0.name == checklistVehicleId }) },
			set: { checklistVehicleId = $0?.name ?? "" }
		)
	}

	var body: some View {
		NavigationStack {
			Form {
				Section(header: Text("Checklist Information")) {
					LabeledContent {
						HStack(spacing: 6) {
							TextField("Category", text: $checklistCategory, prompt: Text("e.g., Engine Start, Maintenance"))
								.textFieldStyle(.roundedBorder)
							Menu {
								ForEach(uniqueCategories, id: \.self) { cat in
									Button(cat) { checklistCategory = cat }
								}
							} label: {
								Image(systemName: "text.badge.plus")
							}
							.accessibilityLabel("Category suggestions")
						}
					} label: {
#if os(iOS)
						Text("Catagory")
#endif
					}

					LabeledContent {
						TextField("Checklist Name", text: $checklistName)
							.textFieldStyle(.roundedBorder)
					} label: {
#if os(iOS)
						Text("Name")
#endif
					}
					if editingChecklist != nil {
						Text("Renaming this checklist offers to update any items that reference it by name.")
							.font(.caption)
							.foregroundStyle(.secondary)
					}

					LabeledContent {
						TextField("Description", text: $checklistDescription, prompt: Text("Optional"))
							.textFieldStyle(.roundedBorder)
					} label: {
#if os(iOS)
						Text("Description")
#endif
					}

					LabeledContent {
						TextEditor(text: $checklistNotes)
							.frame(minHeight: 100)
							.overlay(
								RoundedRectangle(cornerRadius: 8)
									.stroke(Color.secondary.opacity(0.3), lineWidth: 1)
							)
					} label: {
						Text("Notes")
					}
				}

				if editingChecklist == nil {
					Section {
						HStack {
							Image(systemName: Vertical.current.assetIcon)
								.foregroundStyle(.secondary)
							Text("\(Vertical.current.assetSingular): \(trackVehicleSelected)")
								.foregroundStyle(.secondary)
						}
						.font(.caption)
					}
				} else {
					Section(header: Text(Vertical.current.assetSingular)) {
						LabeledContent {
							ModelPicker(
								selection: vehicleBinding,
								title: Vertical.current.assetSingular,
								includeEmptyChoice: false,
								autoSelectFirst: false,
								labelProvider: { "\($0.year) \($0.displayName)" },
								thumbnailData: { $0.image1 }
							)
						} label: {
#if os(iOS)
							Text(Vertical.current.assetSingular)
#endif
						}
					}
				}

				Section(header: Text("PDF Report Header Appearance")) {
					ColorPicker("Background Color", selection: $headerBgColor, supportsOpacity: true)
					ColorPicker("Text Color", selection: $headerFgColor, supportsOpacity: false)
					HStack {
						Spacer()
						Button("Reset to Defaults") {
							headerBgColor = .clear
							headerFgColor = .blue
						}
						.font(.caption)
						.foregroundStyle(.secondary)
					}
				}
			}
			.navigationTitle(editingChecklist == nil ? "New Checklist" : "Edit Checklist")
			#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
			#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						onCancel()
					}
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						let trimmedName = checklistName.trimmingCharacters(in: .whitespacesAndNewlines)
						if let existing = editingChecklist, existing.checklistName != trimmedName, hasLinkedRecords(existing.checklistName) {
							showingRenameChoice = true
						} else {
							onSave()
						}
					}
					.disabled(checklistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
					.confirmationDialog(
						"Checklist Name Changed",
						isPresented: $showingRenameChoice,
						titleVisibility: .visible
					) {
						Button("Update Linked Records") {
							onSaveWithRename()
						}
						Button("Save Without Updating Links", role: .destructive) {
							onSave()
						}
						Button("Cancel", role: .cancel) { }
					} message: {
						if let existing = editingChecklist {
							Text("Renaming \"\(existing.checklistName)\" to \"\(checklistName.trimmingCharacters(in: .whitespacesAndNewlines))\" will break its links to this checklist's items unless they're updated to the new name. Update them now?")
						}
					}
				}
			}
		}
	}
}

// MARK: - Preview

#Preview("DisplayCheckList – Seeded Data") {
	@MainActor
	func makeContainer() -> ModelContainer {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		return try! ModelContainer(for: Vehicle8.self, CheckList.self, Settings1.self, configurations: config)
	}
	
	let container = makeContainer()
	let context = container.mainContext
	
	// Seed vehicles
	let vehicleA = Vehicle8(name: "Vehicle A", year: 2021, mileage: 12050, engHours: 12.5, fuelType: "Gasoline", fuelCapacity: 26)
	let vehicleB = Vehicle8(name: "Vehicle B", year: 2019, mileage: 5400, engHours: 4.0, fuelType: "Diesel", fuelCapacity: 32)
	context.insert(vehicleA)
	context.insert(vehicleB)
	
	// Seed checklists with order indices
	let checklist1 = CheckList(
		inactive: false,
		createdAt: Date(),
		updatedAt: Date(),
		vehicleId: "Vehicle A",
		category: "Pre-Trip",
		categoryOrder: 0,
		checklistName: "Pre-Trip Inspection",
		checklistDescription: "Standard pre-trip safety checklist",
		checklistNotes: "Complete before every long trip",
		checklistCompleted: false,
		completedAt: Date(),
		checklistOrder: 0
	)
	let checklist2 = CheckList(
		inactive: false,
		createdAt: Date(),
		updatedAt: Date(),
		vehicleId: "Vehicle A",
		category: "Maintenance",
		categoryOrder: 1,
		checklistName: "Weekly Maintenance",
		checklistDescription: "Weekly maintenance tasks",
		checklistNotes: "Check fluids, tire pressure, lights",
		checklistCompleted: true,
		completedAt: Date(),
		checklistOrder: 0
	)
	let checklist3 = CheckList(
		inactive: false,
		createdAt: Date(),
		updatedAt: Date(),
		vehicleId: "Vehicle B",
		category: "Post-Trip",
		categoryOrder: 2,
		checklistName: "Post-Trip Review",
		checklistDescription: "End-of-trip inspection checklist",
		checklistNotes: "",
		checklistCompleted: false,
		completedAt: Date(),
		checklistOrder: 0
	)
	context.insert(checklist1)
	context.insert(checklist2)
	context.insert(checklist3)
	
	try? context.save()
	
	let selection = State(initialValue: "All Vehicles")
	
	return NavigationStack {
		DisplayCheckList(trackVehicleSelected: selection.projectedValue)
			.modelContainer(container)
	}
}
// MARK: - View Extension

extension View {
	@ViewBuilder
	func conditionalModifier<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
		if condition {
			transform(self)
		} else {
			self
		}
	}
}

