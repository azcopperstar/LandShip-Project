//
//  GenericModelPicker.swift
//  Created by [Your Name] on [Date].
//
//  Overview:
//  ModelPicker is a reusable, generic SwiftUI View that presents a Picker
//  backed by SwiftData for any @Model type M. It bridges the gap between
//  SwiftData's persistent identity (PersistentIdentifier) and a caller's
//  optional model selection (Binding<M?>), so you can easily bind the picker
//  to your app's domain state while benefiting from SwiftData querying,
//  filtering, and sorting.
//
//  Responsibilities:
//  - Query SwiftData for items of type M using @Query, optionally constrained
//    by a Predicate and/or sorted using SortDescriptor.
//  - Render a SwiftUI Picker with an optional "empty" row to represent nil selection.
//  - Keep an internal selection (PersistentIdentifier) in sync with the external
//    Binding<M?>, and vice versa.
//  - Provide callbacks when selection changes, enabling parent views to react.
//  - Optionally auto-select the first available item when none is selected.
//  - Always respect the shared @AppStorage("showInactiveVehicles") setting to decide
//    whether items marked inactive should be shown.
//
//  Key Behaviors and Notes:
//  - Identity Handling: The Picker uses the model's persistentModelID for its
//    selection, since Picker requires a Hashable selection type. The external
//    binding remains a model instance (M?).
//  - Empty Choice: When includeEmptyChoice is true (default), an empty option is
//    shown at the top to allow clearing the selection (i.e., setting it to nil).
//  - Auto-Select: If autoSelectFirst is enabled and there is no current selection,
//    the first item in the query results will be selected on appear.
//  - Inactive Filtering: The @AppStorage("showInactiveVehicles") preference is
//    always applied. If false, items with inactive == true are filtered out.
//  - Synchronization: The view listens for changes to items, selectedID, the external
//    selection binding, and the @AppStorage setting to keep everything in sync. If the
//    currently selected model disappears from the displayed results, it will either clear
//    the selection or auto-select the first item if configured.
//  - Accessibility: The Picker's label is hidden visually but set as an accessibility
//    label to improve VoiceOver support.
//
//  Dependencies and Assumptions:
//  - M conforms to PersistentModel & Identifiable.
//  - The caller provides a labelProvider that returns a user-facing string for each item.
//  - The shared preference key is "showInactiveVehicles".
//  - Your models expose a Bool property named `inactive`. We provide a protocol
//    (Inactivatable) and conform known models to it so we can read the value directly.
//
//  Performance Considerations:
//  - @Query fetches are managed by SwiftData.
//  - Reflection fallback is kept but should be rarely used after protocol cast.
//
//  Example Usage (Vehicles):
//      @State private var selectedVehicle: Vehicle8?
//      ModelPicker<Vehicle8>(
//          selection: $selectedVehicle,
//          title: "Vehicle",
//          includeEmptyChoice: true,
//          emptyChoiceLabel: "All Vehicles",
//          autoSelectFirst: false,
//          sort: [SortDescriptor(\.name, order: .forward)],
//          labelProvider: { $0.name }
//      )
//

import SwiftUI
import SwiftData

// MARK: - Inactive protocol and known conformances

/// Models that expose an `inactive` Bool should conform to this.
/// We add retroactive conformances for known models here.
protocol Inactivatable {
	var inactive: Bool { get }
}

// Add conformances for your models that have `inactive`.
extension Vehicle8: Inactivatable {}
extension MxItems3: Inactivatable {}
extension MxParts1: Inactivatable {}
extension Vendors1: Inactivatable {}
extension ServiceRecords1: Inactivatable {}
extension FuelLog1: Inactivatable {}
extension TripLog2: Inactivatable {}
extension VehicleSystems1: Inactivatable {}
// If you have other models with `inactive`, add similar one-liners above.

/// A generic SwiftData-backed picker for any @Model type `M`.
/// - Displays rows using a caller-provided `labelProvider`.
/// - Optionally filters/sorts via SwiftData `Predicate` and `SortDescriptor`.
/// - Always applies the shared @AppStorage("showInactiveVehicles") preference to hide
///   inactive items. Prefers protocol access; falls back to reflection if needed.
/// - Binds to the selected object (`M?`). Internally uses `PersistentIdentifier` for Picker selection.
struct ModelPicker<M: PersistentModel & Identifiable>: View {
	// MARK: - Recursion limit for reflection
	private let maxMirrorDepth: Int = 6

	// MARK: - Binding to selected object
	@Binding private var selection: M?

	// MARK: - Options
	private let title: String
	private let includeEmptyChoice: Bool
	private let emptyChoiceLabel: String
	private let autoSelectFirst: Bool

	private let labelProvider: (M) -> String
	private let onSelectionChanged: ((M?) -> Void)?

	// MARK: - App-wide setting
	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false

	// MARK: - Query
	@Query private var items: [M]
	@State private var selectedID: PersistentIdentifier?

	// MARK: - Derived Data
	private var displayedItems: [M] {
		guard showInactiveVehicles == false else {
			return items
		}
		var kept: [M] = []
		for item in items {
			let (inactive, _) = isInactiveFlagTrue(on: item)
			if !inactive {
				kept.append(item)
			}
		}
		return kept
	}

	// MARK: - Init
	init(
		selection: Binding<M?>,
		title: String = "Select",
		includeEmptyChoice: Bool = true,
		emptyChoiceLabel: String = "—",
		autoSelectFirst: Bool = false,
		filter: Predicate<M>? = nil,
		sort: [SortDescriptor<M>] = [],
		labelProvider: @escaping (M) -> String,
		onSelectionChanged: ((M?) -> Void)? = nil
	) {
		self._selection = selection
		self.title = title
		self.includeEmptyChoice = includeEmptyChoice
		self.emptyChoiceLabel = emptyChoiceLabel
		self.autoSelectFirst = autoSelectFirst
		self.labelProvider = labelProvider
		self.onSelectionChanged = onSelectionChanged

		if let filter {
			self._items = Query(filter: filter, sort: sort)
		} else if sort.isEmpty {
			self._items = Query()
		} else {
			self._items = Query(sort: sort)
		}
	}

	// MARK: - Body
	var body: some View {
		Picker(selection: $selectedID) {
			if includeEmptyChoice {
				Text(emptyChoiceLabel)
					.foregroundStyle(.secondary)
					.tag(Optional<PersistentIdentifier>.none)
			}
			ForEach(displayedItems) { item in
				Text(labelProvider(item))
					.tag(Optional<PersistentIdentifier>(item.persistentModelID))
			}
		} label: {
			Text(title).hidden()
		}
		.accessibilityLabel(title)
		.onAppear {
			if let current = selection {
				selectedID = current.persistentModelID
				if !displayedItems.contains(where: { $0.persistentModelID == current.persistentModelID }) {
					reconcileSelectionAfterDisplayChange()
				}
			} else if autoSelectFirst, let first = displayedItems.first {
				selection = first
				selectedID = first.persistentModelID
				onSelectionChanged?(selection)
			}
		}
		.onChange(of: items) { _, _ in
			reconcileSelectionAfterDisplayChange()
		}
		.onChange(of: showInactiveVehicles) { _, _ in
			reconcileSelectionAfterDisplayChange()
		}
		.onChange(of: selectedID) { _, newID in
			if let id = newID {
				let found = displayedItems.first(where: { $0.persistentModelID == id })
				if selection?.persistentModelID != found?.persistentModelID {
					selection = found
					onSelectionChanged?(selection)
				}
			} else {
				if selection != nil {
					selection = nil
					onSelectionChanged?(selection)
				}
			}
		}
		.onChange(of: selection) { _, newSelection in
			if let newSelection {
				let newID = newSelection.persistentModelID
				if !displayedItems.contains(where: { $0.persistentModelID == newID }) {
					reconcileSelectionAfterDisplayChange()
				} else if selectedID != newID {
					selectedID = newID
				}
			} else {
				if selectedID != nil {
					selectedID = nil
				}
			}
		}
	}

	// MARK: - Helpers

	/// Returns (isInactive, pathDescription) for an item.
	/// Prefers protocol access; falls back to reflection if needed.
	private func isInactiveFlagTrue(on item: M) -> (Bool, String?) {
		// Preferred: direct protocol read (bypasses SwiftData wrappers)
		if let cast = item as? Inactivatable {
			let val = cast.inactive
			return (val, "protocol")
		}

		// Fallback: recursive reflection (handles underscored storage)
		let top = Mirror(reflecting: item)
		if let (val, path) = findInactive(in: top, currentPath: "root", depth: 0) {
			return (val, path)
		}
		return (false, nil)
	}

	/// Search helper: recursively traverse mirrors to find a Bool/Optional<Bool> child named "inactive".
	/// Accepts labels with leading underscores (e.g., "_inactive") by normalizing them.
	private func findInactive(in mirror: Mirror, currentPath: String, depth: Int) -> (Bool, String)? {
		if depth > maxMirrorDepth { return nil }

		// Scan current level
		for child in mirror.children {
			guard let rawLabel = child.label else { continue }
			let normalized = rawLabel.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
			let path = currentPath + "." + rawLabel

			if normalized == "inactive" {
				// Direct Bool
				if let b = child.value as? Bool {
					return (b, path)
				}
				// Optional Bool
				if let ob = child.value as? Optional<Bool> {
					switch ob {
					case .some(let v):
						return (v, path)
					case .none:
						return (false, path)
					}
				}
				// Wrapper/object: recurse into it to try to find wrapped value
				let wrapped = Mirror(reflecting: child.value)
				if let (b2, p2) = findInactive(in: wrapped, currentPath: path, depth: depth + 1) {
					return (b2, p2)
				}
				return (false, path)
			}
		}

		// Recurse into children objects/containers
		for child in mirror.children {
			let nextMirror = Mirror(reflecting: child.value)
			if nextMirror.children.isEmpty { continue }
			if let (val, path) = findInactive(in: nextMirror, currentPath: currentPath + "." + (child.label ?? "?"), depth: depth + 1) {
				return (val, path)
			}
		}

		// Also traverse superclass chain
		if let superMirror = mirror.superclassMirror {
			if let (val, path) = findInactive(in: superMirror, currentPath: currentPath + ".__super__", depth: depth + 1) {
				return (val, path)
			}
		}

		return nil
	}

	/// Produce a readable label for logs using labelProvider; if nil, try common name fields; else fall back to type+ID.
	private func safeLabel(for item: M?) -> String {
		guard let item else { return "(nil)" }
		let provided = labelProvider(item)
		if !provided.isEmpty { return provided }
		let mirror = Mirror(reflecting: item)
		let candidates = ["name", "mxName", "vendorName", "partName", "title"]
		for key in candidates {
			if let val = mirror.children.first(where: { $0.label == key })?.value as? String, !val.isEmpty {
				return val
			}
		}
		return "\(type(of: item))[\(item.persistentModelID)]"
	}

	/// Reconcile the current selection against the current displayed items.
	private func reconcileSelectionAfterDisplayChange() {
		let containsSelected = selectedID.flatMap { id in
			displayedItems.contains(where: { $0.persistentModelID == id })
		} ?? false

		if !containsSelected {
			if autoSelectFirst, let first = displayedItems.first {
				selection = first
				selectedID = first.persistentModelID
			} else {
				selection = nil
				selectedID = nil
			}
			onSelectionChanged?(selection)
		} else {
			if let current = selection, selectedID != current.persistentModelID {
				selectedID = current.persistentModelID
			}
		}
	}
}
