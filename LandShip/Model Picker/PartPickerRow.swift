//
//  PartPickerRow.swift
//  Created by [Your Name] on [Date].
//
//  Overview:
//  PartPickerRow is a small, reusable SwiftUI view that presents a generic picker
//  (backed by SwiftData) for choosing a single MxParts1 entity. It is intended to be
//  embedded in forms or settings screens where a user needs to select a part that
//  belongs to a specific vehicle.
//
//  Responsibilities:
//  - Query SwiftData for MxParts1 entities, optionally filtered by vehicleId.
//  - Display those entities via a generic ModelPicker control.
//  - Provide an "empty" option to allow clearing a selection.
//  - Optionally auto-select the first available item.
//  - Optionally seed the selection from a provided part name on first appearance.
//  - Notify a caller via a callback when the selection changes.
//
//  Key Behaviors and Notes:
//  - Filtering: If a vehicleId is supplied, the picker shows parts whose
//    MxParts1.vehicleId matches that value, plus parts marked "All Vehicles".
//    If vehicleId is empty, all parts are shown.
//  - Sorting: Results are sorted by partName ascending.
//  - Seeding: On first appearance, if no selection exists and a seedPartName is provided,
//    the view will attempt a one-time lookup by partName and set the selection if found.
//  - Callbacks: Whenever the selection changes (including from seeding), onSelected is
//    invoked with the new value, allowing parent views or coordinators to react.
//  - Data Layer: Uses SwiftData (ModelContext, Predicate, FetchDescriptor) for fetching.
//  - UI Layer: Delegates actual UI to a ModelPicker generic control that can render
//    a list of items with labels derived from the entity.
//
//  Dependencies:
//  - MxParts1: A SwiftData model type representing a "Part". Must expose:
//      - vehicleId: String
//      - partName: String
//  - ModelPicker: A generic SwiftUI component capable of presenting SwiftData-backed
//    results with filtering, sorting, and label customization.
//
//  Assumptions:
//  - partName is unique or at least stable enough for the seeding operation. If there
//    are multiple parts with the same name, the first match is used.
//  - vehicleId is either empty (no filtering) or a valid identifier to constrain results.
//  - ModelPicker is compatible with optional selections (MxParts1?).
//
//  Threading & Performance:
//  - All SwiftUI view logic executes on the main actor. SwiftData fetches here are simple
//    and limited (fetchLimit = 1 for seeding). If parts data is very large, consider
//    refining the filter or adding pagination in ModelPicker.
//  - The one-time seeding fetch is executed in onAppear to avoid unnecessary repeated
//    work and to ensure the ModelContext is available.
//
//  Example Usage:
//      @State private var selectedPart: MxParts1?
//      PartPickerRow(
//          title: "Part",
//          vehicleId: myVehicle.id,
//          selection: $selectedPart,
//          seedPartName: "Front Brake Pad",
//          autoSelectFirst: true,
//          onSelected: { newPart in
//              // Handle selection
//          }
//      )
//

import SwiftUI
import SwiftData

/// A SwiftUI row that renders a picker for selecting an MxParts1 entity,
/// optionally filtered by vehicle and seeded by a provided part name.
struct PartPickerRow: View {
    /// Title displayed by the picker (e.g., the row label).
    let title: String

    /// If non-empty, restricts the picker to parts whose vehicleId matches this value or
    /// are marked "All Vehicles". If empty, no filtering by vehicleId is applied.
    let vehicleId: String

    /// The current selection binding. This allows the picker to read and update the
    /// selected MxParts1 from outside this view. The selection is optional to allow
    /// for a "no selection" state.
    @Binding var selection: MxParts1?

    /// An optional part name used to seed the initial selection on first appearance
    /// if selection is currently nil. If a matching part is found, it becomes the selection.
    let seedPartName: String?

    /// If true, the picker will automatically select the first available item when
    /// no selection is present. The behavior is implemented inside ModelPicker.
    let autoSelectFirst: Bool

    /// Optional callback invoked whenever the selection changes, including from
    /// initial seeding. Provides the new selection or nil when cleared.
    let onSelected: ((MxParts1?) -> Void)?

    /// SwiftData model context used for fetching the initial seed item and for any
    /// SwiftData interactions that ModelPicker may perform.
    @Environment(\.modelContext) private var modelContext

    /// Designated initializer providing all configuration values and the selection binding.
    /// - Parameters:
    ///   - title: Text to show as the picker's label.
    ///   - vehicleId: Vehicle identifier to filter parts by. Empty string means no filter.
    ///   - selection: A binding to the selected MxParts1, or nil for no selection.
    ///   - seedPartName: Optional part name used to seed the selection on first appearance.
    ///   - autoSelectFirst: If true, auto-selects the first item when none is selected.
    ///   - onSelected: Callback invoked when the selection changes.
    init(
        title: String,
        vehicleId: String,
        selection: Binding<MxParts1?>,
        seedPartName: String? = nil,
        autoSelectFirst: Bool = false,
        onSelected: ((MxParts1?) -> Void)? = nil
    ) {
        self.title = title
        self.vehicleId = vehicleId
        self._selection = selection
        self.seedPartName = seedPartName
        self.autoSelectFirst = autoSelectFirst
        self.onSelected = onSelected
    }

    var body: some View {
        // Build an optional SwiftData predicate. If vehicleId is empty, we skip filtering.
        // Otherwise, include parts matching the provided vehicleId as well as parts
        // marked "All Vehicles", since those apply to every vehicle.
        let partsFilter: Predicate<MxParts1>? = vehicleId.isEmpty ? nil : #Predicate<MxParts1> { $0.vehicleId == vehicleId || $0.vehicleId == "All Vehicles" }

        // Delegate most of the UI and data management to a generic ModelPicker.
        // We pass:
        // - selection binding to allow two-way state updates
        // - a title and an "empty" option label
        // - autoSelectFirst to allow the picker to choose the first item when appropriate
        // - an optional filter and a sort descriptor (by partName ascending)
        // - a label provider that renders each part's name
        // - a selection change handler to propagate changes upstream
        ModelPicker(
            selection: $selection,
            title: title,
            includeEmptyChoice: true,
            emptyChoiceLabel: "—",
            autoSelectFirst: autoSelectFirst,
            filter: partsFilter,
            sort: [SortDescriptor(\.partName, order: .forward)],
            labelProvider: { $0.partName },
            onSelectionChanged: { newPart in
                onSelected?(newPart)
            }
        )
        .onAppear {
            // Seeding logic:
            // If the caller provided a seedPartName and there is currently no selection,
            // attempt a one-time lookup by partName. If a match is found, update the
            // selection and notify the caller via onSelected.
            if selection == nil, let name = seedPartName, !name.isEmpty {
                // Fetch only one item for efficiency.
                var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == name })
                fd.fetchLimit = 1
                if let found = try? modelContext.fetch(fd).first {
                    selection = found
                    onSelected?(found)
                }
            }
        }
    }
}
