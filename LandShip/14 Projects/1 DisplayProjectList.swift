//
//  DisplayProjectList.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import SwiftUI
import SwiftData

struct DisplayProjectList: View {
	// MARK: - Data sources and environment
	
	@Query var vehicles: [Vehicle8]
	@Environment(\.modelContext) var modelContext
	
	@State private var selectedRecord: ProjectList?
	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false
	
	// MARK: - Vehicle selection
	
	@Binding var trackVehicleSelected: String
	@State private var selectedVehicle: Vehicle8?
	@State private var allVehiclesSelected: Bool = true
	
	// MARK: - Navigation state
	
	@State private var newRecordToEdit: ProjectList?
	@State private var showVehicleSelectionAlert: Bool = false
	
	// MARK: - PDF Report
	
	private struct ReportDestination: Hashable { let scope: String }
	@State private var reportDestination: ReportDestination?
	
	// MARK: - Editor state

	private struct ProjectEditorItem: Identifiable {
		let id: UUID = UUID()
		let isNew: Bool
		let project: ProjectList?
	}
	@State private var projectEditorItem: ProjectEditorItem?
	@State private var editingProject: ProjectList?
	@State private var projectCategory: String = ""
	@State private var projectSubcategory: String = ""
	@State private var projectName: String = ""
	@State private var projectDescription: String = ""
	@State private var projectNotes: String = ""
	
	// MARK: - Delete confirmation
	
	@State private var showDeleteConfirmation: Bool = false
	@State private var projectToDelete: ProjectList?
	
	// MARK: - Edit mode for reordering
	
	@State private var isEditMode: Bool = false
	
	// MARK: - Category editing
	
	@State private var showCategoryEditor: Bool = false
	@State private var editingCategoryName: String = ""
	@State private var newCategoryName: String = ""
	
	// MARK: - Body
	
	var body: some View {
		Group {
			ModelPicker(
				selection: $selectedVehicle,
				title: "",
				includeEmptyChoice: true,
				emptyChoiceLabel: "All Vehicles",
				autoSelectFirst: false,
				filter: showInactiveVehicles ? nil : #Predicate<Vehicle8> { $0.inactive == false },
				sort: [SortDescriptor(\.displayName, order: .forward)],
				labelProvider: { v in "\(v.year) \(v.displayName)"},
				thumbnailData: { $0.image1 }
			)
			.frame(maxWidth: .infinity)

			QueryView(for: ProjectList.self, sort: [
				SortDescriptor(\.categoryOrder),
				SortDescriptor(\.projectOrder)
			]) { records in
				projectsList(records: records)
			} filter: {
				#Predicate { item in
					(showInactiveVehicles || !item.inactive) && (
						trackVehicleSelected == "All Vehicles"
						|| item.vehicleId == trackVehicleSelected
					)
				}
			}
		}
		.toolbar {
			ToolbarItem(placement: .automatic) {
				NavigationLink(destination: LivePunchListView()) {
					Label("Punch List", systemImage: "checklist")
				}
			}

			ToolbarItem(placement: .automatic) {
				Button {
					let frozen = trackVehicleSelected
					reportDestination = ReportDestination(scope: frozen)
				} label: {
					Label("Report", systemImage: "doc.text")
				}
			}

			ToolbarItem(placement: .automatic) {
				Button {
					withAnimation { isEditMode.toggle() }
				} label: {
					Label(isEditMode ? "Done" : "Edit", systemImage: isEditMode ? "checkmark" : "pencil")
				}
			}

			if !allVehiclesSelected {
				ToolbarItem(placement: .automatic) {
					Button(action: addNewRecord) {
						Label("New", systemImage: "plus")
					}
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
		.navigationDestination(item: $newRecordToEdit) { record in
			EditProjectList(Records: record, startEditing: true)
		}
		.navigationDestination(item: $reportDestination) { dest in
			pdfReportProjectList(trackVehicleSelected: dest.scope)
				.ignoresSafeArea()
		}
		.alert("Select a Specific Vehicle", isPresented: $showVehicleSelectionAlert) {
			Button("OK", role: .cancel) {}
		} message: {
			Text("A project can only be created when a specific vehicle is selected. Please choose a vehicle — 'All Vehicles' is not allowed.")
		}
		.alert("Delete Project", isPresented: $showDeleteConfirmation) {
			Button("Cancel", role: .cancel) {
				projectToDelete = nil
			}
			Button("Delete", role: .destructive) {
				if let project = projectToDelete {
					deleteProject(project)
					projectToDelete = nil
				}
			}
		} message: {
			if let project = projectToDelete {
				Text("Are you sure you want to delete '\(project.itemName)'? This action cannot be undone.")
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
			Text("Renaming '\(editingCategoryName)' will update all projects in this category.")
		}
		.sheet(item: $projectEditorItem) { item in
			projectEditorSheet(isNew: item.isNew)
		}
	}
	
	// MARK: - Projects List
	
	private enum ListItem: Identifiable {
		case category(String, Int)  // category name, order
		case subcategory(String, String)  // subcategory name, parent category
		case project(ProjectList)
		
		var id: String {
			switch self {
			case .category(let name, _): return "category_\(name)"
			case .subcategory(let name, let parent): return "subcategory_\(parent)_\(name)"
			case .project(let record): return "project_\(record.id)"
			}
		}
	}
	
	@ViewBuilder
	private func projectsList(records: [ProjectList]) -> some View {
		if records.isEmpty {
			List {
				EmptyStateSection(
					title: "Add your first Project",
					systemImage: "square.grid.3x1.folder.badge.plus",
					description: "Create a project to track items and tasks.\n\nTo add additional projects after this first one, select the '+' button at the top of the form.",
					actionTitle: "Add First Project",
					action: addNewRecord
				)
			}
		} else {
			List {
				ForEach(createFlatList(from: records)) { item in
					switch item {
					case .category(let name, _):
						categoryHeaderRow(name)
					case .subcategory(let name, _):
						subcategoryHeaderRow(name)
					case .project(let record):
						projectRow(record)
							.listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
					}
				}
				.conditionalModifier(isEditMode) { view in
					view.onMove { from, to in
						performMove(records: records, from: from, to: to)
					}
				}
				
				// Category Totals Section
				categoryTotalsSection(records: records)
			}
			.safeAreaInset(edge: .top) {
				VStack(spacing: 0) {
					PageTitle_Col2_NoPhoto(label: "PROJECTS")
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
		.padding(.horizontal, 8)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color.secondary.opacity(0.15))
		.cornerRadius(6)
		.listRowBackground(Color.clear)
		.listRowSeparator(.hidden)
		.listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 2, trailing: 10))
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
	
	private func subcategoryHeaderRow(_ subcategory: String) -> some View {
		HStack {
			Image(systemName: "folder")
				.font(.caption)
				.foregroundStyle(.secondary)
			Text(subcategory.isEmpty ? "General" : subcategory)
				.font(.subheadline)
				.fontWeight(.semibold)
				.textCase(nil)
				.foregroundStyle(.secondary)
			Spacer(minLength: 0)
		}
		.padding(.vertical, 6)
		.padding(.horizontal, 8)
		.padding(.leading, 12)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color.secondary.opacity(0.08))
		.cornerRadius(4)
		.listRowBackground(Color.clear)
		.listRowSeparator(.hidden)
		.listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 2, trailing: 10))
	}
	
	@ViewBuilder
	private func projectRow(_ record: ProjectList) -> some View {
		NavigationLink {
			EditProjectList(Records: record)
				.id(record.id)
		} label: {
			VStack(alignment: .leading, spacing: 4) {
				HStack(spacing: 8) {
					if record.itemCompleted {
						Image(systemName: "checkmark.circle.fill")
							.font(.title3)
							.foregroundStyle(.green)
					} else {
						PriorityBadge(value: max(1, min(5, record.priority)))
					}
					Text(record.itemName)
						.font(.headline)
						.fontWeight(.semibold)
				}
				
				if !record.itemDescription.isEmpty {
					Text(record.itemDescription)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}
				
				HStack(spacing: 12) {
					Label(record.vehicleId.isEmpty ? "—" : record.vehicleId, systemImage: "car")
						.font(.caption2)
						.foregroundStyle(.tertiary)
					
					if record.itemCompleted {
						Label("Completed", systemImage: "checkmark.circle.fill")
							.font(.caption2)
							.foregroundStyle(.green)
					}
				}
			}
			.padding(.vertical, 4)
		}
		.swipeActions(edge: .leading) {
			Button {
				editProject(record)
			} label: {
				Label("Edit", systemImage: "pencil")
			}
			.tint(.blue)
		}
		.swipeActions(edge: .trailing) {
			Button(role: .destructive) {
				projectToDelete = record
				showDeleteConfirmation = true
			} label: {
				Label("Delete", systemImage: "trash")
			}
		}
		.contextMenu {
			Button {
				editProject(record)
			} label: {
				Label("Edit Project Info", systemImage: "pencil")
			}
			Button(role: .destructive) {
				projectToDelete = record
				showDeleteConfirmation = true
			} label: {
				Label("Delete Project", systemImage: "trash")
			}
		}
	}
	
	// MARK: - Category Totals Section
	
	private struct SubcategoryTotal: Identifiable {
		let id = UUID()
		let name: String
		let itemCost: Float
		let laborCost: Float
		var totalCost: Float { itemCost + laborCost }
	}
	
	private struct CategoryTotal: Identifiable {
		let id = UUID()
		let name: String
		let subcategories: [SubcategoryTotal]
		var totalItemCost: Float { subcategories.reduce(0) { $0 + $1.itemCost } }
		var totalLaborCost: Float { subcategories.reduce(0) { $0 + $1.laborCost } }
		var totalCost: Float { totalItemCost + totalLaborCost }
	}
	
	@ViewBuilder
	private func categoryTotalsSection(records: [ProjectList]) -> some View {
		let totals = calculateCategoryTotals(records: records)
		let grandTotal = totals.reduce(0) { $0 + $1.totalCost }
		
		// Only show if there are costs to display
		if grandTotal > 0 {
			Section {
				VStack(alignment: .leading, spacing: 0) {
					// Header
					HStack {
						Text("Category Totals")
							.font(.headline)
							.fontWeight(.heavy)
							.foregroundStyle(.blue)
						Spacer()
						Text("(\(records.count) projects)")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					.padding(.vertical, 10)
					.padding(.horizontal, 8)
					.background(Color.secondary.opacity(0.15))
					.cornerRadius(6)
					
					// Category breakdowns
					ForEach(totals) { category in
						VStack(alignment: .leading, spacing: 4) {
							// Category name and total
							HStack {
								Text(category.name)
									.font(.subheadline)
									.fontWeight(.bold)
									.foregroundStyle(.primary)
								Spacer()
								Text(formatCurrency(category.totalCost))
									.font(.subheadline)
									.fontWeight(.bold)
									.foregroundStyle(.primary)
							}
							.padding(.top, 12)
							.padding(.horizontal, 8)
							.padding(.bottom, 4)
							
							// Subcategory breakdown
							ForEach(category.subcategories) { subcategory in
								VStack(alignment: .leading, spacing: 2) {
									HStack {
										Text(subcategory.name.isEmpty ? "General" : subcategory.name)
											.font(.caption)
											.fontWeight(.medium)
											.foregroundStyle(.secondary)
											.padding(.leading, 20)
										Spacer()
										Text(formatCurrency(subcategory.totalCost))
											.font(.caption)
											.fontWeight(.medium)
											.foregroundStyle(.secondary)
									}
									.padding(.horizontal, 8)
									
									// Parts and labor breakdown under subcategory
									if subcategory.itemCost > 0 || subcategory.laborCost > 0 {
										VStack(alignment: .leading, spacing: 1) {
											if subcategory.itemCost > 0 {
												HStack {
													Text("Parts")
														.font(.caption2)
														.foregroundStyle(.tertiary)
														.padding(.leading, 36)
													Spacer()
													Text(formatCurrency(subcategory.itemCost))
														.font(.caption2)
														.foregroundStyle(.tertiary)
												}
												.padding(.horizontal, 8)
											}
											if subcategory.laborCost > 0 {
												HStack {
													Text("Labor")
														.font(.caption2)
														.foregroundStyle(.tertiary)
														.padding(.leading, 36)
													Spacer()
													Text(formatCurrency(subcategory.laborCost))
														.font(.caption2)
														.foregroundStyle(.tertiary)
												}
												.padding(.horizontal, 8)
											}
										}
										.padding(.bottom, 4)
									}
								}
								.padding(.vertical, 2)
							}
							
							Divider()
								.padding(.horizontal, 8)
								.padding(.top, 4)
						}
					}
					
					// Grand total
					HStack {
						Text("Grand Total")
							.font(.headline)
							.fontWeight(.bold)
						Spacer()
						Text(formatCurrency(grandTotal))
							.font(.headline)
							.fontWeight(.bold)
							.foregroundStyle(.blue)
					}
					.padding(.vertical, 12)
					.padding(.horizontal, 8)
					.background(Color.blue.opacity(0.1))
					.cornerRadius(6)
				}
			}
			.listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
			.listRowBackground(Color.clear)
		}
	}
	
	private func calculateCategoryTotals(records: [ProjectList]) -> [CategoryTotal] {
		// Group by category
		let categoryGroups = Dictionary(grouping: records) { record in
			record.category.isEmpty ? "Uncategorized" : record.category
		}
		
		var categoryTotals: [CategoryTotal] = []
		
		for (categoryName, projects) in categoryGroups {
			// Group projects by subcategory within this category
			let subcategoryGroups = Dictionary(grouping: projects) { project in
				project.subCategory
			}
			
			var subcategoryTotals: [SubcategoryTotal] = []
			
			for (subcategoryName, subProjects) in subcategoryGroups {
				// Calculate parts cost from all 5 parts (quantity * cost per unit)
				var partsCost: Float = 0
				for project in subProjects {
					partsCost += Float(project.part1Quantity) * project.part1cost
					partsCost += Float(project.part2Quantity) * project.part2cost
					partsCost += Float(project.part3Quantity) * project.part3cost
					partsCost += Float(project.part4Quantity) * project.part4cost
					partsCost += Float(project.part5Quantity) * project.part5cost
				}
				
				// laborCost field contains the actual labor cost
				let laborCost = subProjects.reduce(0) { $0 + $1.laborCost }
				
				subcategoryTotals.append(SubcategoryTotal(
					name: subcategoryName,
					itemCost: partsCost,
					laborCost: laborCost
				))
			}
			
			// Sort subcategories by name
			subcategoryTotals.sort { $0.name < $1.name }
			
			categoryTotals.append(CategoryTotal(
				name: categoryName,
				subcategories: subcategoryTotals
			))
		}
		
		// Sort categories by name
		categoryTotals.sort { $0.name < $1.name }
		
		return categoryTotals
	}
	
	private func formatCurrency(_ value: Float) -> String {
		let formatter = NumberFormatter()
		formatter.numberStyle = .currency
		formatter.currencySymbol = "$"
		formatter.minimumFractionDigits = 2
		formatter.maximumFractionDigits = 2
		return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
	}
	
	// MARK: - Tips View
	
	private var tipsView: some View {
		VStack(alignment: .leading, spacing: 1) {
			tipRow(icon: "hand.tap", text: "Long-press either category or checklist for edit options")
			tipRow(icon: "pencil", text: "Edit Mode: reorder categories and checklists by dragging/dropping handles")
			tipRowVehicle(icon: "car", text: "\(trackVehicleSelected)")
		}

//		VStack(alignment: .leading, spacing: 1) {
//			tipRow(icon: "car", text: "Vehicle: \(trackVehicleSelected)")
//			tipRow(icon: "hand.tap", text: "Long-press either category or project for edit options")
//			tipRow(icon: "pencil", text: "Edit Mode: reorder categories and projects by dragging/dropping handles")
//		}
//		.padding(.horizontal, 2)
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
		let projects: [ProjectList]
	}
	
	private func groupAndSortRecords(_ records: [ProjectList]) -> [CategoryGroup] {
		let grouped = Dictionary(grouping: records) { rec in
			rec.category.isEmpty ? "Uncategorized" : rec.category
		}
		
		var groups: [CategoryGroup] = []
		for (category, items) in grouped {
			let sortedItems = items.sorted { $0.projectOrder < $1.projectOrder }
			let categoryOrder = items.first?.categoryOrder ?? 0
			groups.append(CategoryGroup(category: category, order: categoryOrder, projects: sortedItems))
		}
		
		return groups.sorted { $0.order < $1.order }
	}
	
	private func createFlatList(from records: [ProjectList]) -> [ListItem] {
		let grouped = groupAndSortRecords(records)
		var items: [ListItem] = []
		
		for group in grouped {
			items.append(.category(group.category, group.order))
			
			// Group projects by subcategory within this category
			let subcategoryGroups = Dictionary(grouping: group.projects) { project in
				project.subCategory
			}
			
			// Sort subcategories by their subcategoryOrder
			let sortedSubcategories = subcategoryGroups.keys.sorted { sub1, sub2 in
				// Get the first project from each subcategory to determine order
				guard let projects1 = subcategoryGroups[sub1], let first1 = projects1.first,
					  let projects2 = subcategoryGroups[sub2], let first2 = projects2.first else {
					return sub1 < sub2
				}
				return first1.subcategoryOrder < first2.subcategoryOrder
			}
			
			for subcategory in sortedSubcategories {
				// Only add subcategory header if there are multiple subcategories in this category
				// or if there's at least one non-empty subcategory
				let hasMultipleSubcategories = subcategoryGroups.count > 1
				let hasNamedSubcategory = !subcategory.isEmpty
				
				if hasMultipleSubcategories || hasNamedSubcategory {
					items.append(.subcategory(subcategory, group.category))
				}
				
				// Add projects under this subcategory
				if let projects = subcategoryGroups[subcategory] {
					let sortedProjects = projects.sorted { $0.projectOrder < $1.projectOrder }
					for project in sortedProjects {
						items.append(.project(project))
					}
				}
			}
		}
		
		return items
	}
	
	private func performMove(records: [ProjectList], from source: IndexSet, to destination: Int) {
		// Get current flat list
		let currentItems = createFlatList(from: records)
		
		guard let sourceIndex = source.first,
			  sourceIndex < currentItems.count else { return }
		
		let movingItem = currentItems[sourceIndex]
		
		// Determine if we're moving a category, subcategory, or a project
		switch movingItem {
		case .category:
			// Moving a category - need to move all its subcategories and projects together
			var itemsToMove: [ListItem] = [movingItem]
			var idx = sourceIndex + 1
			
			// Collect all subcategories and projects in this category
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
			
		case .subcategory:
			// Moving a subcategory - need to move all its projects together
			var itemsToMove: [ListItem] = [movingItem]
			var idx = sourceIndex + 1
			
			// Collect all projects in this subcategory
			while idx < currentItems.count {
				if case .category = currentItems[idx] {
					break
				}
				if case .subcategory = currentItems[idx] {
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
			
		case .project(let project):
			// Moving a single project
			var newItems = currentItems
			newItems.move(fromOffsets: source, toOffset: destination)
			
			// Update the project's category and subcategory based on its new position
			var currentCat: String?
			var currentSubcat: String?
			for (_, item) in newItems.enumerated() {
				if case .category(let name, _) = item {
					currentCat = name
					currentSubcat = nil  // Reset subcategory when we hit a new category
				}
				if case .subcategory(let name, _) = item {
					currentSubcat = name
				}
				if case .project(let proj) = item, proj.id == project.id {
					if let cat = currentCat {
						let actualCategory = cat == "Uncategorized" ? "" : cat
						project.category = actualCategory
						project.subCategory = currentSubcat ?? ""
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
		var subcategoryOrderCounter = 0
		var currentCategoryName: String?
		var currentSubcategoryName: String?
		var projectOrderInCurrentSubcategory = 0
		var projectOrderInCurrentCategory = 0
		var categoryToOrderMap: [String: Int] = [:]
		
		for item in items {
			switch item {
			case .category(let categoryName, _):
				currentCategoryName = categoryName
				currentSubcategoryName = nil
				categoryToOrderMap[categoryName] = categoryOrderCounter
				categoryOrderCounter += 1
				subcategoryOrderCounter = 0
				projectOrderInCurrentCategory = 0
				projectOrderInCurrentSubcategory = 0
				
			case .subcategory(let subcategoryName, _):
				currentSubcategoryName = subcategoryName
				projectOrderInCurrentSubcategory = 0
				
			case .project(let project):
				if let catName = currentCategoryName {
					let actualCategory = catName == "Uncategorized" ? "" : catName
					// If this is the first project in a subcategory, increment the subcategory counter
					if projectOrderInCurrentSubcategory == 0 && currentSubcategoryName != nil {
						subcategoryOrderCounter += 1
					}
					project.category = actualCategory
					project.subCategory = currentSubcategoryName ?? ""
					project.categoryOrder = categoryToOrderMap[catName] ?? 0
					project.subcategoryOrder = subcategoryOrderCounter
					project.projectOrder = projectOrderInCurrentCategory
					project.updatedAt = Date()
					projectOrderInCurrentCategory += 1
					projectOrderInCurrentSubcategory += 1
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
		
		editingProject = nil
		projectCategory = ""
		projectSubcategory = ""
		projectName = "New Project"
		projectDescription = ""
		projectNotes = ""
		projectEditorItem = ProjectEditorItem(isNew: true, project: nil)
	}

	private func editProject(_ project: ProjectList) {
		editingProject = project
		projectCategory = project.category
		projectSubcategory = project.subCategory
		projectName = project.itemName
		projectDescription = project.itemDescription
		projectNotes = project.itemNotes
		projectEditorItem = ProjectEditorItem(isNew: false, project: project)
	}

	private func saveProject() {
		if let existing = editingProject {
			existing.category = projectCategory.trimmingCharacters(in: .whitespacesAndNewlines)
			existing.subCategory = projectSubcategory.trimmingCharacters(in: .whitespacesAndNewlines)
			existing.itemName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
			existing.itemDescription = projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
			existing.itemNotes = projectNotes.trimmingCharacters(in: .whitespacesAndNewlines)
			existing.updatedAt = Date()

			try? modelContext.save()
			projectEditorItem = nil
		} else {
			let descriptor = FetchDescriptor<ProjectList>()
			let allProjects = (try? modelContext.fetch(descriptor)) ?? []
			
			let trimmedCategory = projectCategory.trimmingCharacters(in: .whitespacesAndNewlines)
			let trimmedSubcategory = projectSubcategory.trimmingCharacters(in: .whitespacesAndNewlines)
			let categoryProjects = allProjects.filter { $0.category == trimmedCategory }
			let categoryOrder = categoryProjects.first?.categoryOrder ?? (allProjects.map { $0.categoryOrder }.max() ?? -1) + 1
			
			// Calculate subcategory order
			let subcategoryProjects = categoryProjects.filter { $0.subCategory == trimmedSubcategory }
			let subcategoryOrder = subcategoryProjects.first?.subcategoryOrder ?? (categoryProjects.map { $0.subcategoryOrder }.max() ?? -1) + 1
			
			let maxProjectOrder = categoryProjects.map { $0.projectOrder }.max() ?? -1
			
			// Get vehicle details for prefilling
			let functions = Functions()
			let details = functions.loadVehicleDetails(context: modelContext, vehicleId: trackVehicleSelected)
			let currentMiles = details?.mileage ?? 0
			let currentHours = details?.engHours ?? 0
			
			let newRecord = ProjectList(
				inactive: false,
				createdAt: Date(),
				updatedAt: Date(),
				vehicleId: trackVehicleSelected,
				miles: currentMiles,
				engHours: currentHours,
				itemName: projectName.trimmingCharacters(in: .whitespacesAndNewlines),
				itemDescription: projectDescription.trimmingCharacters(in: .whitespacesAndNewlines),
				itemNotes: projectNotes.trimmingCharacters(in: .whitespacesAndNewlines),
				itemVendor: "",
				category: trimmedCategory,
				categoryOrder: categoryOrder,
				subCategory: trimmedSubcategory,
				subcategoryOrder: subcategoryOrder,
				projectOrder: maxProjectOrder + 1,
				priority: 5,
				itemCompleted: false,
				completedAt: Date(),
				saveInLogbook: false,
				savedToLogbook: false,
				itemCost: 0,
				laborCost: 0,
				part1: "",
				part1cost: 0,
				part1Unit: "",
				part1Quantity: 0,
				part2: "",
				part2cost: 0,
				part2Unit: "",
				part2Quantity: 0,
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
				part5Quantity: 0,
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
			
			modelContext.insert(newRecord)
			try? modelContext.save()
			projectEditorItem = nil
			newRecordToEdit = newRecord
		}
	}
	
	private func deleteProject(_ project: ProjectList) {
		modelContext.delete(project)
		try? modelContext.save()
	}
	
	private func uniqueCategories() -> [String] {
		let descriptor = FetchDescriptor<ProjectList>()
		guard let allProjects = try? modelContext.fetch(descriptor) else { return [] }
		let categories = Set(allProjects.map { $0.category }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
		return categories.sorted()
	}
	
	private func uniqueSubcategories() -> [String] {
		let descriptor = FetchDescriptor<ProjectList>()
		guard let allProjects = try? modelContext.fetch(descriptor) else { return [] }
		let subcategories = Set(allProjects.map { $0.subCategory }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
		return subcategories.sorted()
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
		
		let descriptor = FetchDescriptor<ProjectList>()
		guard let allProjects = try? modelContext.fetch(descriptor) else {
			showCategoryEditor = false
			return
		}
		
		// Handle "Uncategorized" which represents empty category strings
		let searchCategory = editingCategoryName == "Uncategorized" ? "" : editingCategoryName
		
		for project in allProjects where project.category == searchCategory {
			project.category = trimmedNew
			project.updatedAt = Date()
		}
		
		try? modelContext.save()
		showCategoryEditor = false
	}
	
	// MARK: - Editor Sheet
	
	private func projectEditorSheet(isNew: Bool) -> some View {
		NavigationStack {
			Form {
				Section(header: Text("Project Information")) {
					LabeledContent {
						HStack(spacing: 6) {
							TextField("Category", text: $projectCategory, prompt: Text("e.g., Upgrades, Repairs"))
								.textFieldStyle(.roundedBorder)
							Menu {
								ForEach(uniqueCategories(), id: \.self) { cat in
									Button(cat) { projectCategory = cat }
								}
							} label: {
								Image(systemName: "text.badge.plus")
							}
							.accessibilityLabel("Category suggestions")
						}
					} label: {
#if os(iOS)
						Text("Category")
#endif
					}
					
					LabeledContent {
						HStack(spacing: 6) {
							TextField("Subcategory", text: $projectSubcategory, prompt: Text("Optional project subcategory"))
								.textFieldStyle(.roundedBorder)
							Menu {
								ForEach(uniqueSubcategories(), id: \.self) { sub in
									Button(sub) { projectSubcategory = sub }
								}
							} label: {
								Image(systemName: "text.badge.plus")
							}
							.accessibilityLabel("Subcategory suggestions")
						}
					} label: {
#if os(iOS)
						Text("Subcategory")
#endif
					}
					
					LabeledContent {
						TextField("Project Name", text: $projectName)
							.textFieldStyle(.roundedBorder)
					} label: {
#if os(iOS)
						Text("Name")
#endif
					}
					
					LabeledContent {
						TextField("Description", text: $projectDescription, prompt: Text("Optional"))
							.textFieldStyle(.roundedBorder)
					} label: {
#if os(iOS)
						Text("Description")
#endif
					}
					
					LabeledContent {
						TextEditor(text: $projectNotes)
							.frame(minHeight: 100)
							.overlay(
								RoundedRectangle(cornerRadius: 8)
									.stroke(Color.secondary.opacity(0.3), lineWidth: 1)
							)
					} label: {
						Text("Notes")
					}
				}
				
				if isNew {
					Section {
						HStack {
							Image(systemName: "car")
								.foregroundStyle(.secondary)
							Text("Vehicle: \(trackVehicleSelected)")
								.foregroundStyle(.secondary)
						}
						.font(.caption)
					}
				}
			}
			.navigationTitle(isNew ? "New Project" : "Edit Project")
			#if os(iOS) || os(watchOS) || os(tvOS)
			.navigationBarTitleDisplayMode(.inline)
			#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						projectEditorItem = nil
					}
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						saveProject()
					}
					.disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
				}
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
        case 4: return .teal
        default: return .blue
        }
    }
    private func textColor(for v: Int) -> Color {
        switch v {
        case 1: return .white   // blue
        case 2: return .black   // green
        case 3: return .black   // yellow
        case 4: return .white   // orange
        default: return .white  // red
        }
    }
    var body: some View {
        ZStack {
            Circle()
                .fill(color(for: value))
                .frame(width: 18, height: 18)
            Text("\(value)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(textColor(for: value))
        }
        .accessibilityLabel("Priority \(value)")
    }
}

// MARK: - Previews

#Preview("DisplayProjectList – Seeded Data") {
	@Previewable @State var trackVehicleSelected = "RV Commander"
	
	let container = try! ModelContainer(
		for: ProjectList.self, Vehicle8.self,
		configurations: ModelConfiguration(isStoredInMemoryOnly: true)
	)
	
	// Create sample vehicles
	let vehicle1 = Vehicle8(
		name: "RV Commander",
		manufacturer: "Forest River",
		model: "Georgetown",
		year: 2021,
		mileage: 15420,
		engHours: 245.5
	)
	
	let vehicle2 = Vehicle8(
		name: "Trail Blazer",
		manufacturer: "Jeep",
		model: "Wrangler",
		year: 2022,
		mileage: 8930,
		engHours: 0
	)
	
	container.mainContext.insert(vehicle1)
	container.mainContext.insert(vehicle2)
	
	// Create sample projects with different categories and priorities
	let projects = [
		// Engine category
		ProjectList(
			vehicleId: "RV Commander",
			miles: 15420,
			engHours: 245.5,
			itemName: "Replace Air Filter",
			itemDescription: "Replace engine air filter with high-flow K&N filter",
			itemNotes: "Check for any debris or damage to intake system",
			category: "Engine",
			categoryOrder: 0,
			subCategory: "Maintenance",
			projectOrder: 0,
			priority: 2,
			itemCompleted: false,
			completedAt: Date(),
			itemCost: 45.99,
			laborCost: 0
		),
		ProjectList(
			vehicleId: "RV Commander",
			miles: 15420,
			engHours: 245.5,
			itemName: "Oil Leak Repair",
			itemDescription: "Fix oil leak from valve cover gasket",
			itemNotes: "Appears to be driver side valve cover",
			category: "Engine",
			categoryOrder: 0,
			subCategory: "Repair",
			projectOrder: 1,
			priority: 1,
			itemCompleted: false,
			completedAt: Date(),
			itemCost: 125.50,
			laborCost: 200.00
		),
		
		// Interior category
		ProjectList(
			vehicleId: "RV Commander",
			miles: 15420,
			engHours: 245.5,
			itemName: "Install USB Charging Ports",
			itemDescription: "Add USB-C ports to dining area and bedroom",
			itemNotes: "Need dual USB-C with 45W power delivery",
			category: "Interior",
			categoryOrder: 1,
			subCategory: "Upgrades",
			projectOrder: 0,
			priority: 3,
			itemCompleted: false,
			completedAt: Date(),
			itemCost: 89.99,
			laborCost: 0
		),
		ProjectList(
			vehicleId: "RV Commander",
			miles: 15420,
			engHours: 245.5,
			itemName: "Replace Cabinet Hinges",
			itemDescription: "Replace worn soft-close hinges in kitchen cabinets",
			itemNotes: "Need Blum 110° soft-close hinges",
			category: "Interior",
			categoryOrder: 1,
			subCategory: "Repair",
			projectOrder: 1,
			priority: 4,
			itemCompleted: true,
			completedAt: Date(),
			itemCost: 156.00,
			laborCost: 0
		),
		
		// Electrical category
		ProjectList(
			vehicleId: "RV Commander",
			miles: 15420,
			engHours: 245.5,
			itemName: "Solar Panel Installation",
			itemDescription: "Install 400W solar system on roof",
			itemNotes: "Includes panels, MPPT controller, and wiring",
			category: "Electrical",
			categoryOrder: 2,
			subCategory: "Upgrades",
			projectOrder: 0,
			priority: 2,
			itemCompleted: false,
			completedAt: Date(),
			itemCost: 1250.00,
			laborCost: 500.00
		),
		
		// Trail Blazer projects
		ProjectList(
			vehicleId: "Trail Blazer",
			miles: 8930,
			engHours: 0,
			itemName: "Lift Kit Installation",
			itemDescription: "Install 3-inch suspension lift kit",
			itemNotes: "TeraFlex 3\" lift with Fox shocks",
			category: "Suspension",
			categoryOrder: 0,
			subCategory: "Upgrades",
			projectOrder: 0,
			priority: 1,
			itemCompleted: false,
			completedAt: Date(),
			itemCost: 2400.00,
			laborCost: 800.00
		),
		ProjectList(
			vehicleId: "Trail Blazer",
			miles: 8930,
			engHours: 0,
			itemName: "Install Rock Sliders",
			itemDescription: "Add heavy-duty rock sliders for trail protection",
			itemNotes: "Metalcloak overland series",
			category: "Exterior",
			categoryOrder: 1,
			subCategory: "Protection",
			projectOrder: 0,
			priority: 2,
			itemCompleted: true,
			completedAt: Date(),
			itemCost: 899.99,
			laborCost: 150.00
		)
	]
	
	for project in projects {
		container.mainContext.insert(project)
	}
	
	return NavigationStack {
		DisplayProjectList(trackVehicleSelected: $trackVehicleSelected)
			.modelContainer(container)
	}
}
