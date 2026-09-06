import SwiftUI
import SwiftData
import PhotosUI

struct LiveCheckListView: View {
    // The checklist we're displaying items for
    let checklist: CheckList
    
    // Filters
    @State private var showOnlyOpen: Bool = false
    @State private var refreshTrigger: Int = 0
    
    @State private var editingItemID: PersistentIdentifier? = nil
    @FocusState private var isEditingName: Bool
    @State private var isEditMode: Bool = false
    @State private var showingCompletionHistory: Bool = false
    @State private var showingTips: Bool = false
    
    @State private var editingSectionNameID: PersistentIdentifier? = nil
    @FocusState private var isEditingSectionName: Bool
    
    // Delete confirmation
    @State private var showDeleteConfirmation: Bool = false
    @State private var itemToDelete: CheckListItem?
    
    // PDF report
    @State private var pdfDestination: PDFDestination?

    // Data
    @Environment(\.modelContext) private var modelContext
    @Environment(\.entitlements) private var entitlements
    
    // PDF destination wrapper
    struct PDFDestination: Identifiable, Hashable {
        let id = UUID()
        let checklist: CheckList
        
        static func == (lhs: PDFDestination, rhs: PDFDestination) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    // Query all CheckListItem items sorted by order index
    @Query(sort: \CheckListItem.orderIndex) private var allItems: [CheckListItem]
    
    // Use the query result directly
    private var items: [CheckListItem] {
        allItems
    }

    init(checklist: CheckList) {
        self.checklist = checklist
    }

    var body: some View {
        VStack(spacing: 0) {
            contentList

            // Completion history is tucked behind a button rather than shown inline,
            // so it never competes with the checklist items for vertical space.
            if !checklist.completionLog.isEmpty {
                completionHistoryButton
            }
        }
//        .navigationTitle(checklist.checklistName)
        .toolbar { toolbarContent }
        .onAppear {
            migrateItemIDs()
            expandAllSubItemsSections()
        }
        .alert("Delete Item", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    delete(item)
                    itemToDelete = nil
                }
            }
        } message: {
            if let item = itemToDelete {
                Text("Are you sure you want to delete '\(item.itemName)'? This action cannot be undone.")
            }
        }
        .navigationDestination(item: $pdfDestination) { dest in
            pdfReportCheckListItems(checklist: dest.checklist)
                .ignoresSafeArea()
        }
    }

    // MARK: - Views
    
    /// Bottom bar button that reveals the full completion history in a popover, instead of
    /// permanently occupying space in the checklist itself.
    private var completionHistoryButton: some View {
        Button {
            showingCompletionHistory = true
        } label: {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.green)
                Text("Completion History")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(checklist.completionLog.count) completions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.up")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.secondary.opacity(0.05))
        .popover(isPresented: $showingCompletionHistory) {
            completionHistoryPopoverContent
        }
    }

    /// Full, scrollable completion history shown inside the popover.
    private var completionHistoryPopoverContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.green)
                Text("Completion History")
                    .font(.headline)
                    .bold()
                Spacer()
                Text("\(checklist.completionLog.count) completions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(checklist.completionLog.reversed().enumerated()), id: \.offset) { index, date in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("Completed")
                                .font(.subheadline)
                            Spacer()
                            Text(date, style: .date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(date, style: .time)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(index == 0 ? Color.green.opacity(0.1) : Color.secondary.opacity(0.05))
                        )
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(minWidth: 300, idealWidth: 340, minHeight: 250, idealHeight: 420, maxHeight: 500)
    }

    private var contentList: some View {
        Group {
            if filteredItems().isEmpty {
                ContentUnavailableView("No items", systemImage: "checklist", description: Text("Add items to this checklist using the '+' button."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let flattened = flattenedItemsForDisplay()
                List {
                    Section {
                        ForEach(Array(flattened.enumerated()), id: \.element.persistentModelID) { index, item in
                            if item.parentItemUUID == nil {
                                // Parent item
                                rowView(item)
                            } else {
                                // Sub-item - render with indentation
                                if let parent = items.first(where: { $0.itemID == item.parentItemUUID }) {
                                    subItemRow(item, parent: parent)
                                        .padding(.leading, 40)
                                }
                            }
                        }
                        .onDelete(perform: deleteFlattened)
                        .conditionalModifier(isEditMode) { view in
                            view.onMove(perform: moveFlattened)
                        }
                    }
                }
                .id("\(flattened.count)_\(expandedSubItems.count)")
								.safeAreaInset(edge: .top) {
									// Joined to the title in the same zero-spacing VStack (rather than
									// living in the List's Section header) so there's no gap between
									// them — List/Section header insets otherwise leave a visible band.
									VStack(spacing: 0) {
										PageTitle_Col2_NoPhoto(label: "CHECKLIST ITEMS")
										headerView(count: filteredItems().count)
									}
								}

                .listStyle(.inset)
            }
        }
    }

    // Condensed to two lines (name; vehicle + actions) with tips tucked behind an info
    // button, rather than the six-line header this used to be — on iPhone that header was
    // eating the space that belongs to the actual checklist items below it.
    private func headerView(count: Int) -> some View {
		return VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 6) {
				tipRowChecklist(icon: "checklist", text: checklist.checklistName)
				Spacer(minLength: 8)
				Button {
					showingTips = true
				} label: {
					Image(systemName: "info.circle.fill")
						.font(.title3)
						.foregroundStyle(.blue)
				}
				.buttonStyle(.plain)
				.popover(isPresented: $showingTips) {
					tipsView
						.padding()
						.frame(minWidth: 260, idealWidth: 300)
				}
			}
			HStack(spacing: 12) {
				tipRowVehicle(icon: Vertical.current.assetIcon, text: checklist.vehicleId)
				Spacer(minLength: 8)
				Button(role: .none) {
					markAllComplete(false)
				} label: {
					Label("Reset All", systemImage: "circle")
				}
				Button(role: .none) {
					markAllComplete(true)
				} label: {
					Label("Complete All", systemImage: "checkmark.circle")
				}
			}
			.font(.subheadline)
		}
		.padding(.horizontal)
		.padding(.vertical, 6)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(.ultraThinMaterial)
		.overlay(Divider(), alignment: .bottom)
    }


    // MARK: - Tips View

    private var tipsView: some View {
        VStack(alignment: .leading, spacing: 1) {
					tipRow(icon: "hand.tap", text: "Tap chevron to expand/collapse item details")
#if os(iOS) || os(watchOS) || os(tvOS)
					tipRow(icon: "hand.tap", text: "Long press on item to add sub-items, edit name & delete item")
#else
					tipRow(icon: "hand.tap", text: "Right click on item to add sub-items, edit name & delete item")
#endif
					tipRow(icon: "hand.tap", text: "Tap green + sign to add sub-items")
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
    }
    private func tipRow(icon: String, text: String) -> some View {
			HStack(spacing: 2) {
					Image(systemName: icon)
							.foregroundStyle(.secondary)
							.font(.caption2)
							.frame(width: 14)
					Text(text)
							.font(.caption2)
							.bold()
							.foregroundStyle(.secondary)
			}
    }
	private func tipRowVehicle(icon: String, text: String, color: Color = .blue) -> some View {
		HStack(spacing: 4) {
			Image(systemName: icon)
				.font(.subheadline)
				.frame(width: 20)
			Text(text)
				.font(.subheadline)
				.fontWeight(.semibold)
				.lineLimit(1)
		}
		.foregroundStyle(color)
	}
	private func tipRowChecklist(icon: String, text: String, color: Color = .blue) -> some View {
		HStack(spacing: 4) {
			Image(systemName: icon)
				.font(.subheadline)
				.frame(width: 20)
			Text(text)
				.font(.subheadline)
				.fontWeight(.bold)
				.lineLimit(1)
				.truncationMode(.tail)
		}
		.foregroundStyle(color)
	}

    private func rowView(_ item: CheckListItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Drag handle and delete button when in edit mode
                if isEditMode {
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.tertiary)
                            .font(.body)
                        Button(role: .destructive) {
                            itemToDelete = item
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Delete this item")
                    }
                }
                
                Toggle(isOn: binding(for: item)) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
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
                        
                        // Display thumbnail image if available
                        if item.image1 != nil {
                            HStack {
                                Image_View_Thumbnail(imageData: item.image1)
                                if !item.image1Description.isEmpty {
                                    Text(item.image1Description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
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
                Button(role: .destructive) {
                    itemToDelete = item
                    showDeleteConfirmation = true
                } label: { Label("Delete", systemImage: "trash") }
                Button { toggleCompletion(item) } label: { Label(item.itemCompleted ? "Reopen" : "Complete", systemImage: item.itemCompleted ? "arrow.uturn.left" : "checkmark") }
                    .tint(item.itemCompleted ? .orange : .green)
            }
            .contextMenu {
                Button("Edit Name") {
                    editingItemID = item.persistentModelID
                    isEditingName = true
                }
                Button("Add Sub-Item") {
                    newSubItem(for: item)
                }
                Button("Delete", role: .destructive) {
                    itemToDelete = item
                    showDeleteConfirmation = true
                }
            }
            
            // Sub-items section header (sub-items themselves are now rendered as separate rows)
            if !getSubItems(for: item).isEmpty {
                subItemsSectionHeader(for: item)
            }

            if isRowExpanded(item) {
                // Expanded inline editor for all fields
                VStack(alignment: .leading, spacing: 12) {
                    Group {
                        LabeledContent("Item Name:") {
                            HStack(spacing: 6) {
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
                    }

                    Group {
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
                    
                    // Image editor
                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Item Image")
                                .font(.headline)
                            Image_Edit(
                                label: "1",
                                imageData: Binding(
                                    get: { item.image1 },
                                    set: { v in item.image1 = v; persistChange(for: item) }
                                ),
                                imageDescription: Binding(
                                    get: { item.image1Description },
                                    set: { v in item.image1Description = v; persistChange(for: item) }
                                )
                            )
                        }
                    }
                    
                    // Delete button at the bottom of the expanded form
                    Button(role: .destructive) {
                        itemToDelete = item
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Item", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.2)))
            }
        }
    }
    
    // MARK: - Sub-Items Section
    
    private func subItemsSectionHeader(for parent: CheckListItem) -> some View {
        let subItems = getSubItems(for: parent)
        let completedCount = subItems.filter { $0.itemCompleted }.count
        let inProgressCount = subItems.count - completedCount
        
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { toggleSubItemsExpanded(parent) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isSubItemsExpanded(parent) ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                        .foregroundStyle(.blue)
                    
                    // Editable section name
                    if editingSectionNameID == parent.persistentModelID {
                        TextField("Section Name", text: Binding(
                            get: { parent.subItemsSectionName },
                            set: { newValue in
                                parent.subItemsSectionName = newValue
                                parent.updatedAt = Date()
                                try? modelContext.save()
                            }
                        ))
                        .font(.subheadline)
                        .bold()
                        .focused($isEditingSectionName)
                        .onAppear { isEditingSectionName = true }
                        .onSubmit {
                            editingSectionNameID = nil
                            isEditingSectionName = false
                        }
                        .textFieldStyle(.plain)
                        Text("(\(subItems.count))")
                            .font(.subheadline)
                            .bold()
                    } else {
                        Text("\(parent.subItemsSectionName) (\(subItems.count))")
                            .font(.subheadline)
                            .bold()
                            .onTapGesture(count: 2) {
                                editingSectionNameID = parent.persistentModelID
                                isEditingSectionName = true
                            }
                    }
                    
                    // Completion status indicators
                    if completedCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("\(completedCount)")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                    
                    if inProgressCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "circle.dotted")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("\(inProgressCount)")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    Spacer()
                    Button {
                        newSubItem(for: parent)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(.blue.opacity(0.1)))
            .contextMenu {
                Button("Edit Section Name") {
                    editingSectionNameID = parent.persistentModelID
                    isEditingSectionName = true
                }
                Button("Reset to Default") {
                    parent.subItemsSectionName = "Sub-Items"
                    parent.updatedAt = Date()
                    try? modelContext.save()
                }
            }
        }
        .padding(.leading, 40)
    }
    
    private func subItemRow(_ subItem: CheckListItem, parent: CheckListItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Drag handle when in edit mode
                if isEditMode {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
                
                Toggle(isOn: binding(for: subItem)) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            if editingItemID == subItem.persistentModelID {
                                TextField("Sub-Item Name", text: Binding(
                                    get: { subItem.itemName },
                                    set: { newValue in
                                        subItem.itemName = newValue
                                        subItem.updatedAt = Date()
                                        try? modelContext.save()
                                    }
                                ))
                                .font(.subheadline)
                                .focused($isEditingName)
                                .onAppear { isEditingName = true }
                                .onSubmit {
                                    editingItemID = nil
                                    isEditingName = false
                                }
                            } else {
                                Text(subItem.itemName)
                                    .font(.subheadline)
                            }
                            Spacer()
                            Button {
                                withAnimation { toggleRowExpanded(subItem) }
                            } label: {
                                Image(systemName: isRowExpanded(subItem) ? "chevron.up.circle" : "chevron.down.circle")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        if !subItem.itemDescription.isEmpty && !isRowExpanded(subItem) {
                            Text(subItem.itemDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !subItem.itemNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isRowExpanded(subItem) {
                            Text(subItem.itemNotes)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                #if os(macOS)
                .toggleStyle(.checkbox)
                #else
                .toggleStyle(.switch)
                #endif
                
                // Only show delete button in edit mode
                if isEditMode {
                    Button(role: .destructive) {
                        itemToDelete = subItem
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Expanded editor for sub-item
            if isRowExpanded(subItem) {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Name:") {
                        TextField("Sub-Item Name", text: Binding(
                            get: { subItem.itemName },
                            set: { v in subItem.itemName = v; persistChange(for: subItem) }
                        ))
                        .font(.caption)
                    }
                    
                    LabeledContent("Description:") {
                        TextField("Description", text: Binding(
                            get: { subItem.itemDescription },
                            set: { v in subItem.itemDescription = v; persistChange(for: subItem) }
                        ))
                        .font(.caption)
                    }
                    
                    LabeledContent("Notes:") {
                        TextEditor(text: Binding(
                            get: { subItem.itemNotes },
                            set: { v in subItem.itemNotes = v; persistChange(for: subItem) }
                        ))
                        .frame(minHeight: 40)
                        .font(.caption)
                    }
                    
                    if subItem.itemCompleted {
                        LabeledContent("Completed:") {
                            DatePicker("", selection: Binding(
                                get: { subItem.completedAt },
                                set: { v in subItem.completedAt = v; persistChange(for: subItem) }
                            ), displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .font(.caption)
                        }
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 4).fill(.tertiary.opacity(0.2)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 4).fill(.secondary.opacity(0.1)))
        .contextMenu {
            Button("Edit Name") {
                editingItemID = subItem.persistentModelID
                isEditingName = true
            }
            Button(isRowExpanded(subItem) ? "Collapse" : "Expand Editor") {
                withAnimation { toggleRowExpanded(subItem) }
            }
            Button("Delete", role: .destructive) {
                itemToDelete = subItem
                showDeleteConfirmation = true
            }
        }
    }

    // Expanded row state storage keyed by PersistentIdentifier
    @State private var expandedRows: Set<PersistentIdentifier> = []
    
    // Expanded sub-items state storage
    @State private var expandedSubItems: Set<PersistentIdentifier> = []

    private func isRowExpanded(_ item: CheckListItem) -> Bool {
        expandedRows.contains(item.persistentModelID)
    }

    private func toggleRowExpanded(_ item: CheckListItem) {
        let id = item.persistentModelID
        if expandedRows.contains(id) { expandedRows.remove(id) } else { expandedRows.insert(id) }
    }
    
    private func isSubItemsExpanded(_ item: CheckListItem) -> Bool {
        expandedSubItems.contains(item.persistentModelID)
    }
    
    private func toggleSubItemsExpanded(_ item: CheckListItem) {
        let id = item.persistentModelID
        if expandedSubItems.contains(id) { 
            expandedSubItems.remove(id) 
        } else { 
            expandedSubItems.insert(id) 
        }
        refreshTrigger += 1
    }
    
    private func expandAllSubItemsSections() {
        // Get all parent items that have sub-items
        let parentItems = filteredItems().filter { $0.hasSubItems || !getSubItems(for: $0).isEmpty }
        
        // Only expand sub-items sections where not all sub-items are complete
        for parent in parentItems {
            let subItems = getSubItems(for: parent)
            let allComplete = !subItems.isEmpty && subItems.allSatisfy { $0.itemCompleted }
            
            // Only expand if not all sub-items are completed
            if !allComplete {
                expandedSubItems.insert(parent.persistentModelID)
            }
        }
        
        // Force refresh to ensure sub-items display
        refreshTrigger += 1
    }
    
    /// Ensures all CheckListItems have unique itemID values.
    /// This fixes any items that may have been created with empty or duplicate IDs.
    private func migrateItemIDs() {
        var needsSave = false
        var seenIDs = Set<String>()
        var oldToNewIDMapping: [String: String] = [:]
        
        for item in items {
            let oldID = item.itemID
            
            // Fix empty itemID
            if item.itemID.isEmpty {
                item.itemID = UUID().uuidString
                item.updatedAt = Date()
                needsSave = true
                seenIDs.insert(item.itemID)
                oldToNewIDMapping[oldID] = item.itemID
            }
            // Fix duplicate itemID
            else if seenIDs.contains(item.itemID) {
                let newID = UUID().uuidString
                oldToNewIDMapping[oldID] = newID
                item.itemID = newID
                item.updatedAt = Date()
                needsSave = true
                seenIDs.insert(item.itemID)
            } else {
                seenIDs.insert(item.itemID)
            }
        }
        
        // Update sub-items' parentItemUUID to match new parent IDs
        if !oldToNewIDMapping.isEmpty {
            for item in items {
                if let parentUUID = item.parentItemUUID,
                   let newParentID = oldToNewIDMapping[parentUUID] {
                    item.parentItemUUID = newParentID
                    item.updatedAt = Date()
                    needsSave = true
                    print("[CheckList] Updated sub-item '\(item.itemName)' parent reference from \(parentUUID) to \(newParentID)")
                }
            }
        }
        
        if needsSave {
            try? modelContext.save()
            print("[CheckList] Migrated \(seenIDs.count) items with unique IDs")
        }
        
        // Fix orphaned sub-items by attempting to reconnect based on name matching
        repairOrphanedSubItems()
    }
    
    /// Repairs orphaned sub-items by trying to match them to parents based on item names
    private func repairOrphanedSubItems() {
        let allChecklistItems = items.filter { $0.checklistName == checklist.checklistName }
        let parents = allChecklistItems.filter { $0.parentItemUUID == nil }
        let subItems = allChecklistItems.filter { $0.parentItemUUID != nil }
        
        var needsSave = false
        
        for subItem in subItems {
            guard let parentUUID = subItem.parentItemUUID else { continue }
            
            // Check if parent exists
            let hasParent = parents.contains { $0.itemID == parentUUID }
            if hasParent { continue }
            
            // This is an orphaned sub-item - try to find its parent by name matching
            print("[CheckList] 🔧 Attempting to repair orphaned sub-item: '\(subItem.itemName)'")
            
            // Strategy: Look for parent items whose name is similar or contains key words
            var bestMatch: CheckListItem? = nil
            
            // Check if sub-item name contains clues about parent
            let subItemLower = subItem.itemName.lowercased()
            
            for parent in parents {
                let parentLower = parent.itemName.lowercased()
                
                // Direct containment match
                if subItemLower.contains(parentLower) || parentLower.contains(subItemLower.prefix(20)) {
                    bestMatch = parent
                    break
                }
                
                // Keyword matching
                let parentKeywords = parentLower.split(separator: " ").filter { $0.count > 3 }
                let subKeywords = subItemLower.split(separator: " ").filter { $0.count > 3 }
                
                let matchingKeywords = parentKeywords.filter { pk in
                    subKeywords.contains { sk in String(sk) == String(pk) }
                }
                
                if matchingKeywords.count >= 2 {
                    bestMatch = parent
                    break
                }
            }
            
            if let parent = bestMatch {
                subItem.parentItemUUID = parent.itemID
                subItem.updatedAt = Date()
                parent.hasSubItems = true
                parent.updatedAt = Date()
                needsSave = true
                print("[CheckList] ✅ Reconnected '\(subItem.itemName)' to parent '\(parent.itemName)'")
            } else {
                print("[CheckList] ⚠️ Could not find parent for '\(subItem.itemName)' - will convert to top-level item")
                // Convert orphaned sub-item to top-level item
                subItem.parentItemUUID = nil
                subItem.updatedAt = Date()
                needsSave = true
            }
        }
        
        if needsSave {
            try? modelContext.save()
            print("[CheckList] Completed orphaned sub-items repair")
        }
    }
    
    // Get sub-items for a parent item
    private func getSubItems(for parent: CheckListItem) -> [CheckListItem] {
        items.filter { $0.parentItemUUID == parent.itemID }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    private func persistChange(for item: CheckListItem) {
        item.updatedAt = Date()
        try? modelContext.save()
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button {
                pdfDestination = PDFDestination(checklist: checklist)
            } label: {
                Label("PDF", systemImage: "doc.text")
            }
            Toggle(isOn: $showOnlyOpen) {
#if os(macOS)
                Image(systemName: showOnlyOpen ? "eye" : "eye.slash")
#else
                VStack(spacing: 2) {
                    Image(systemName: showOnlyOpen ? "eye" : "eye.slash")
                    Text(showOnlyOpen ? "Open" : "All")
                        .font(.caption2)
                }
#endif
            }
            .toggleStyle(.button)
            .help(showOnlyOpen ? "Open" : "All")
            .accessibilityLabel(showOnlyOpen ? "Open" : "All")
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
            Button(action: newItem) {
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

    // MARK: - Helpers

    private var queryIdentity: String {
        // Changing this forces NavigationStack to rebuild and @Query to refetch in a predictable way
        "\(checklist.checklistName)|\(showOnlyOpen)|\(refreshTrigger)"
    }

    private func filteredItems() -> [CheckListItem] {
        items.filter { item in
            // Filter by checklist name
            let checklistPass = item.checklistName == checklist.checklistName
            // Only show parent-level items (not sub-items)
            let isParentLevel = item.parentItemUUID == nil
            // Open/Closed filter
            let openPass = showOnlyOpen ? (item.itemCompleted == false) : true
            return checklistPass && isParentLevel && openPass
        }
        .sorted { a, b in
            // Sort by orderIndex
            a.orderIndex < b.orderIndex
        }
    }
    
    // Creates a flat list for the UI that includes parent items and their expanded sub-items
    private func flattenedItemsForDisplay() -> [CheckListItem] {
        var result: [CheckListItem] = []
        let parents = filteredItems()
        
        // Find orphaned sub-items
        let allChecklistItems = items.filter { $0.checklistName == checklist.checklistName }
        let allSubItems = allChecklistItems.filter { $0.parentItemUUID != nil }
        
        print("[LiveCheckList] === Flattening Display ===")
        print("[LiveCheckList] Total items in DB for this checklist: \(allChecklistItems.count)")
        print("[LiveCheckList] Parent items after filtering: \(parents.count)")
        print("[LiveCheckList] Total sub-items in DB: \(allSubItems.count)")
        print("[LiveCheckList] showOnlyOpen filter is: \(showOnlyOpen)")
        
        // Check for orphaned sub-items
        var orphanedSubItems: [CheckListItem] = []
        for subItem in allSubItems {
            if let parentUUID = subItem.parentItemUUID {
                let hasParent = parents.contains { $0.itemID == parentUUID }
                if !hasParent {
                    orphanedSubItems.append(subItem)
                }
            }
        }
        
        if !orphanedSubItems.isEmpty {
            print("[LiveCheckList] ⚠️ Found \(orphanedSubItems.count) ORPHANED sub-items:")
            for orphan in orphanedSubItems {
                print("[LiveCheckList]   - '\(orphan.itemName)' looking for parent UUID: '\(orphan.parentItemUUID ?? "nil")'")
            }
            print("[LiveCheckList] Available parent IDs:")
            for parent in parents {
                print("[LiveCheckList]   - '\(parent.itemName)' has itemID: '\(parent.itemID)'")
            }
        }
        
        for parent in parents {
            result.append(parent)
            let subItems = getSubItems(for: parent)
            let isExpanded = isSubItemsExpanded(parent)
            
            print("[LiveCheckList]   Parent: '\(parent.itemName)' (ID: '\(parent.itemID)') - completed: \(parent.itemCompleted), sub-items: \(subItems.count), expanded: \(isExpanded)")
            
            // Add sub-items if expanded
            if isExpanded {
                result.append(contentsOf: subItems)
                for subItem in subItems {
                    print("[LiveCheckList]     - Sub: '\(subItem.itemName)' - completed: \(subItem.itemCompleted)")
                }
            }
        }
        
        print("[LiveCheckList] Flattened list has \(result.count) items total (parents + expanded sub-items)")
        print("[LiveCheckList] Expanded sub-items sections: \(expandedSubItems.count)")
        
        return result
    }

    private func uniqueItemNames() -> [String] {
        let names = Set(items.map { $0.itemName }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        return names.sorted()
    }

    private func binding(for item: CheckListItem) -> Binding<Bool> {
        Binding<Bool>(
            get: { item.itemCompleted },
            set: { newValue in
                item.itemCompleted = newValue
                if newValue {
                    item.completedAt = Date()
                    // If this is a parent item, complete all sub-items
                    if item.hasSubItems {
                        let subItems = getSubItems(for: item)
                        for subItem in subItems {
                            subItem.itemCompleted = true
                            subItem.completedAt = Date()
                        }
                    }
                } else {
                    // If uncompleting a parent, uncheck all sub-items
                    if item.hasSubItems {
                        let subItems = getSubItems(for: item)
                        for subItem in subItems {
                            subItem.itemCompleted = false
                        }
                    }
                }
                
                // If this is a sub-item, check if all sub-items are complete to update parent
                if let parentUUID = item.parentItemUUID,
                   let parent = items.first(where: { $0.itemID == parentUUID }) {
                    updateParentCompletionStatus(parent)
                }
                
                try? modelContext.save()
                
                // Check if checklist is now 100% complete and log if so
                checkAndLogChecklistCompletion()
            }
        )
    }

    private func toggleCompletion(_ item: CheckListItem) {
        item.itemCompleted.toggle()
        if item.itemCompleted {
            item.completedAt = Date()
            // If this is a parent item, complete all sub-items
            if item.hasSubItems {
                let subItems = getSubItems(for: item)
                for subItem in subItems {
                    subItem.itemCompleted = true
                    subItem.completedAt = Date()
                }
            }
        } else {
            // If uncompleting a parent, uncheck all sub-items
            if item.hasSubItems {
                let subItems = getSubItems(for: item)
                for subItem in subItems {
                    subItem.itemCompleted = false
                }
            }
        }
        
        // If this is a sub-item, check if all sub-items are complete to update parent
        if let parentUUID = item.parentItemUUID,
           let parent = items.first(where: { $0.itemID == parentUUID }) {
            updateParentCompletionStatus(parent)
        }
        
        try? modelContext.save()
        
        // Check if checklist is now 100% complete and log if so
        checkAndLogChecklistCompletion()
    }
    
    private func updateParentCompletionStatus(_ parent: CheckListItem) {
        let subItems = getSubItems(for: parent)
        if !subItems.isEmpty {
            let allComplete = subItems.allSatisfy { $0.itemCompleted }
            if allComplete && !parent.itemCompleted {
                parent.itemCompleted = true
                parent.completedAt = Date()
            } else if !allComplete && parent.itemCompleted {
                parent.itemCompleted = false
            }
        }
    }
    
    // MARK: - Checklist Completion Tracking
    
    /// Checks if all items in the checklist are 100% complete
    private func areAllChecklistItemsComplete() -> Bool {
        let allChecklistItems = items.filter { $0.checklistName == checklist.checklistName }
        guard !allChecklistItems.isEmpty else { return false }
        return allChecklistItems.allSatisfy { $0.itemCompleted }
    }
    
    /// Logs a completion event when the checklist becomes 100% complete
    private func checkAndLogChecklistCompletion() {
        if areAllChecklistItemsComplete() {
            let now = Date()
            checklist.completionLog.append(now)
            checklist.updatedAt = now
            try? modelContext.save()
            print("[CheckList] ✅ Logged checklist completion at \(now)")
        }
    }

    private func delete(_ item: CheckListItem) {
        // If this is a sub-item, update parent's hasSubItems flag
        if let parentUUID = item.parentItemUUID,
           let parent = items.first(where: { $0.itemID == parentUUID }) {
            let remainingSubItems = getSubItems(for: parent).filter { $0.itemID != item.itemID }
            if remainingSubItems.isEmpty {
                parent.hasSubItems = false
                parent.updatedAt = Date()
            }
        }
        
        // Also delete all sub-items if this is a parent item
        let subItems = getSubItems(for: item)
        for subItem in subItems {
            modelContext.delete(subItem)
        }
        modelContext.delete(item)
        try? modelContext.save()
        refreshTrigger += 1
    }

    private func delete(at offsets: IndexSet) {
        let filtered = filteredItems()
        for index in offsets { modelContext.delete(filtered[index]) }
        try? modelContext.save()
    }
    
    private func deleteFlattened(at offsets: IndexSet) {
        let flattened = flattenedItemsForDisplay()
        for index in offsets {
            let item = flattened[index]
            if let parent = items.first(where: { $0.itemID == item.parentItemUUID }) {
                deleteSubItem(item, parent: parent)
            } else {
                delete(item)
            }
        }
    }
    
    private func move(from source: IndexSet, to destination: Int) {
        var filtered = filteredItems()
        filtered.move(fromOffsets: source, toOffset: destination)
        
        // Reassign orderIndex to all items based on new order
        for (index, item) in filtered.enumerated() {
            item.orderIndex = index
            item.updatedAt = Date()
        }
        
        try? modelContext.save()
        refreshTrigger += 1
    }
    
    private func moveFlattened(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else { return }
        let flattened = flattenedItemsForDisplay()
        let movingItem = flattened[sourceIndex]
        
        // Check if moving item is a sub-item
        if let parentUUID = movingItem.parentItemUUID,
           let parent = items.first(where: { $0.itemID == parentUUID }) {
            // Moving a sub-item - only allow reordering within its parent
            let subItems = getSubItems(for: parent)
            guard let subIndex = subItems.firstIndex(where: { $0.persistentModelID == movingItem.persistentModelID }) else { return }
            
            // Calculate destination index within sub-items
            var destSubIndex = 0
            var flatIndex = 0
            for item in flattened {
                if flatIndex == destination { break }
                if item.parentItemUUID == parentUUID {
                    destSubIndex += 1
                }
                flatIndex += 1
            }
            
            moveSubItems(for: parent, from: IndexSet(integer: subIndex), to: destSubIndex)
        } else {
            // Moving a parent item - use regular move
            let parents = filteredItems()
            guard let parentIndex = parents.firstIndex(where: { $0.persistentModelID == movingItem.persistentModelID }) else { return }
            
            // Calculate destination in parent-only list
            var destParentIndex = 0
            for (index, item) in flattened.enumerated() {
                if index >= destination { break }
                if item.parentItemUUID == nil {
                    destParentIndex += 1
                }
            }
            
            move(from: IndexSet(integer: parentIndex), to: destParentIndex)
        }
    }

    private func newItem() {
        guard entitlements.requestCreate(CheckListItem.self, in: modelContext) else { return }
        let now = Date()

        // Calculate the next orderIndex - place new items at the bottom
        let currentItems = filteredItems()
        let maxOrderIndex = currentItems.map { $0.orderIndex }.max() ?? -1
        let nextOrderIndex = maxOrderIndex + 1
        
        let item = CheckListItem(
            inactive: false,
            createdAt: now,
            updatedAt: now,
            checklistName: checklist.checklistName,
            itemName: "New Item",
            itemDescription: "",
            itemNotes: "",
            itemCompleted: false,
            completedAt: now,
            orderIndex: nextOrderIndex,
            image1: nil,
            image1Description: ""
        )
        modelContext.insert(item)
        try? modelContext.save()
        
        // Force refresh by incrementing trigger
        refreshTrigger += 1
        
        // Begin inline editing for the new item
        editingItemID = item.persistentModelID
        // Defer focus to the next runloop to ensure the row is visible
        DispatchQueue.main.async {
            isEditingName = true
        }
    }

    private func markAllComplete(_ completed: Bool) {
        // Get ALL items for this checklist, not just filtered ones
        let allChecklistItems = items.filter { $0.checklistName == checklist.checklistName }
        for item in allChecklistItems {
            item.itemCompleted = completed
            if completed {
                item.completedAt = Date()
            }
        }
        try? modelContext.save()
        
        // Check if checklist is now 100% complete and log if so
        if completed {
            checkAndLogChecklistCompletion()
        }
    }
    
    // MARK: - Sub-Item Management
    
    private func newSubItem(for parent: CheckListItem) {
        guard entitlements.requestCreate(CheckListItem.self, in: modelContext) else { return }
        let now = Date()

        // Calculate the next orderIndex for sub-items
        let currentSubItems = getSubItems(for: parent)
        let maxOrderIndex = currentSubItems.map { $0.orderIndex }.max() ?? -1
        let nextOrderIndex = maxOrderIndex + 1
        
        let subItem = CheckListItem(
            inactive: false,
            createdAt: now,
            updatedAt: now,
            checklistName: checklist.checklistName,
            itemName: "New Sub-Item",
            itemDescription: "",
            itemNotes: "",
            itemCompleted: false,
            completedAt: now,
            orderIndex: nextOrderIndex,
            image1: nil,
            image1Description: "",
            itemID: UUID().uuidString,
            parentItemUUID: parent.itemID,
            hasSubItems: false
        )
        
        // Mark parent as having sub-items
        parent.hasSubItems = true
        parent.updatedAt = now
        
        modelContext.insert(subItem)
        try? modelContext.save()
        
        // Expand the sub-items section if not already expanded
        if !isSubItemsExpanded(parent) {
            withAnimation {
                toggleSubItemsExpanded(parent)
            }
        }
        
        // Force refresh
        refreshTrigger += 1
        
        // Begin inline editing for the new sub-item
        editingItemID = subItem.persistentModelID
        // Defer focus to the next runloop to ensure the row is visible
        DispatchQueue.main.async {
            isEditingName = true
        }
    }
    
    private func deleteSubItem(_ subItem: CheckListItem, parent: CheckListItem) {
        // Check if parent will have remaining sub-items after deletion
        let remainingSubItems = getSubItems(for: parent).filter { $0.itemID != subItem.itemID }
        
        modelContext.delete(subItem)
        
        // Update parent's hasSubItems flag based on remaining count
        if remainingSubItems.isEmpty {
            parent.hasSubItems = false
        }
        parent.updatedAt = Date()
        
        try? modelContext.save()
        refreshTrigger += 1
    }
    
    private func moveSubItems(for parent: CheckListItem, from source: IndexSet, to destination: Int) {
        var subItems = getSubItems(for: parent)
        subItems.move(fromOffsets: source, toOffset: destination)
        
        // Reassign orderIndex to all sub-items based on new order
        for (index, subItem) in subItems.enumerated() {
            subItem.orderIndex = index
            subItem.updatedAt = Date()
        }
        
        try? modelContext.save()
        refreshTrigger += 1
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
    let container = try! ModelContainer(for: CheckList.self, CheckListItem.self, Settings1.self, configurations: config)
    let context = container.mainContext

    // Seed sample checklist
    let checklist = CheckList(
        inactive: false,
        createdAt: Date(),
        updatedAt: Date(),
        vehicleId: "Vehicle A",
        category: "Pre-Trip",
        checklistName: "Pre-Trip Inspection",
        checklistDescription: "Standard pre-trip safety checklist",
        checklistNotes: "Complete before every long trip",
        checklistCompleted: false,
        completedAt: Date()
    )
    context.insert(checklist)

    // Seed sample items
    let now = Date()
    let item1 = CheckListItem(
        inactive: false,
        createdAt: now,
        updatedAt: now,
        checklistName: "Pre-Trip Inspection",
        itemName: "Check tire pressure",
        itemDescription: "All four tires and spare",
        itemNotes: "Target: 35 PSI",
        itemCompleted: false,
        completedAt: now,
        orderIndex: 0,
        image1: nil,
        image1Description: ""
    )
    let item2 = CheckListItem(
        inactive: false,
        createdAt: now.addingTimeInterval(-60),
        updatedAt: now.addingTimeInterval(-60),
        checklistName: "Pre-Trip Inspection",
        itemName: "Check oil level",
        itemDescription: "Engine oil",
        itemNotes: "",
        itemCompleted: true,
        completedAt: now,
        orderIndex: 1,
        image1: nil,
        image1Description: ""
    )
    let item3 = CheckListItem(
        inactive: false,
        createdAt: now.addingTimeInterval(-120),
        updatedAt: now.addingTimeInterval(-120),
        checklistName: "Pre-Trip Inspection",
        itemName: "Test all lights",
        itemDescription: "Headlights, brake lights, turn signals",
        itemNotes: "",
        itemCompleted: false,
        completedAt: now,
        orderIndex: 2,
        image1: nil,
        image1Description: ""
    )
    context.insert(item1)
    context.insert(item2)
    context.insert(item3)

    try? context.save()

    return NavigationStack {
        LiveCheckListView(checklist: checklist)
            .modelContainer(container)
    }
}

