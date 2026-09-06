/*
 File: pdfReportProjectList.swift
 Module: LandShip

 Summary
 -------
 A cross-platform SwiftUI view that generates and displays a PDF report of project list items
 (ProjectList). Built on the shared PDFReportRenderer engine (PDFReportStyle.swift): four category
 columns carry nearly every ProjectList field, grouped and stacked so the report fits a portrait
 US-Letter page. The view owns its own vehicle scope via the shared VehicleScopePicker and can
 switch between "All Vehicles" and a specific vehicle without leaving the report. A "TRACKED
 COSTS SUMMARY" footer (shared across every cost-bearing report) totals lifetime costs across
 Parts, Fuel Log, Service Records, Items, Improvements, and Projects.

 Key Features
 ------------
 - Shared in-report vehicle picker (VehicleScopePicker) that re-fetches and regenerates on change
 - Empty/zero fields are dropped before layout so sparse projects produce short rows
 - A toolbar button still routes into the Punch List view (checkbox-style project tracking) for
   a chosen sub-category, matching the original report's behavior
 - Built-in print support and zoom controls via the shared PDFKitView/PDFReportFile helpers

 Data Flow
 ---------
 - `scope` (@State) selects "All Vehicles" or a specific vehicle by name; the picker mutates it.
 - `generatePDFWithTable()` fetches records via FetchDescriptor (not @Query, since scope can
   change after the view appears), builds one PDFCell row per record, and hands them to
   `PDFReportRenderer.render(...)`.
 - The resulting Data is wrapped in PDFDocument and assigned to state (`pdfDocument`) for display,
   and saved to the app's Documents folder via `PDFReportFile.save(data:fileName:)`.

 Dependencies
 ------------
 - Frameworks: PDFKit, SwiftUI, SwiftData, Foundation
 - Models: ProjectList
 - Shared: PDFReportStyle.swift (PDFReportRenderer, PDFKitView, ZoomAction, PDFReportFile,
   VehicleScopePicker, PDFCostSummaryBuilder)
 - Utilities: Functions (date/currency formatting, vehicle display name lookup)
*/

import PDFKit
import SwiftUI
import SwiftData
import Foundation

/// A SwiftUI view that builds and displays a PDF report of project list items.
/// - Parameter trackVehicleSelected: The initial scope — "All Vehicles" (or empty) for every
///   vehicle, or a specific `Vehicle8.name` to report on just that vehicle's projects. The
///   report owns this value afterward via its in-report vehicle picker.
struct pdfReportProjectList: View {
	@Environment(\.modelContext) var modelContext

	@State private var scope: String
	@State private var pdfDocument: PDFDocument?
	@State private var zoomAction: ZoomAction?
	@State private var showingSubcategoryPicker = false

	let functions = Functions()

	init(trackVehicleSelected: String) {
		_scope = State(initialValue: trackVehicleSelected.isEmpty ? "All Vehicles" : trackVehicleSelected)
	}

	var body: some View {
		Group {
			if let doc = pdfDocument {
				PDFKitView(showing: doc, zoomAction: $zoomAction)
					.ignoresSafeArea()
			} else {
				VStack(spacing: 16) {
					ProgressView("Generating PDF…")
					Button("Try Again") {
						generateAndShowPDF()
					}
				}
				.padding()
			}
		}
		.onAppear {
			if pdfDocument == nil {
				generateAndShowPDF()
			}
		}
		.onChange(of: scope) {
			generateAndShowPDF()
		}
		.sheet(isPresented: $showingSubcategoryPicker) {
			NavigationStack {
				List(uniqueSubcategories(), id: \.self) { sub in
					Button(sub) {
						showingSubcategoryPicker = false
						punchListSubcategory = sub
					}
				}
				.navigationTitle("Choose Sub-Category")
			}
		}
		.navigationDestination(item: $punchListSubcategory) { sub in
			pdfReportPunchList(trackVehicleSelected: scope, projectSubcategory: sub)
				.ignoresSafeArea()
		}
		.toolbar {
			ToolbarItem(placement: .automatic) {
				VehicleScopePicker(scope: $scope)
			}
			ToolbarItem(placement: .automatic) {
				Button {
					showingSubcategoryPicker = true
				} label: {
					Label("Punch List", systemImage: "list.bullet")
				}
			}
			ToolbarItem(placement: .automatic) {
				Button("Regenerate") {
					generateAndShowPDF()
				}
			}
			ToolbarItemGroup(placement: .automatic) {
				Button {
					zoomAction = .zoomOut
				} label: {
					Image(systemName: "minus.magnifyingglass")
				}
				Button {
					zoomAction = .zoomIn
				} label: {
					Image(systemName: "plus.magnifyingglass")
				}
				Button("Fit") {
					zoomAction = .fit
				}
				Button("100%") {
					zoomAction = .actual
				}
			}
			ToolbarItem(placement: .automatic) {
				Button {
					if let doc = pdfDocument {
						PDFReportFile.printDocument(doc, jobName: "Project List")
					}
				} label: {
					Label("Print", systemImage: "printer")
				}
				.keyboardShortcut("p", modifiers: .command)
				.disabled(pdfDocument == nil)
			}
		}
	}

	// MARK: - Punch List hand-off

	@State private var punchListSubcategory: String?

	private func uniqueSubcategories() -> [String] {
		Array(Set(fetchProjects().map { $0.subCategory.isEmpty ? "General" : $0.subCategory })).sorted()
	}

	// MARK: - Generation

	private func generateAndShowPDF() {
		guard let pdfData = generatePDFWithTable() else { return }
		if let doc = PDFDocument(data: pdfData) {
			self.pdfDocument = doc
			PDFReportFile.save(data: pdfData, fileName: "Project List")
		}
	}

	private func fetchProjects() -> [ProjectList] {
		let descriptor: FetchDescriptor<ProjectList>
		if scope == "All Vehicles" || scope.isEmpty {
			descriptor = FetchDescriptor<ProjectList>(sortBy: [
				SortDescriptor(\.priority, order: .forward),
				SortDescriptor(\.vehicleId, order: .forward),
				SortDescriptor(\.category, order: .forward),
				SortDescriptor(\.subCategory, order: .forward)
			])
		} else {
			let vehicleId = scope
			descriptor = FetchDescriptor<ProjectList>(
				predicate: #Predicate<ProjectList> { $0.vehicleId == vehicleId },
				sortBy: [SortDescriptor(\.priority, order: .forward), SortDescriptor(\.category, order: .forward), SortDescriptor(\.subCategory, order: .forward)]
			)
		}
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	/// Builds the full multipage PDF for the current `scope`. Returns raw PDF data suitable
	/// for wrapping in a PDFDocument and/or saving to disk.
	func generatePDFWithTable() -> Data? {
		let items = fetchProjects()

		let columns: [PDFTableColumn] = [
			PDFTableColumn("PROJECT", weight: 0.20),
			PDFTableColumn("DETAILS", weight: 0.22),
			PDFTableColumn("PARTS &\nLABOR", weight: 0.30),
			PDFTableColumn("COSTS &\nPROGRESS", weight: 0.28)
		]

		let rows: [[PDFCell]] = items.map { item in
			[
				projectCell(item),
				detailsCell(item),
				partsCell(item),
				costsAndProgressCell(item)
			]
		}

		let scopeTitle = (scope == "All Vehicles" || scope.isEmpty) ? "All Vehicles" : functions.getVehicleDisplayName(vehicleId: scope, context: modelContext)
		let itemWord = items.count == 1 ? "project" : "projects"
		let subtitle = "\(scopeTitle) • \(functions.formatDate_DDMMMyy(date: Date())) • \(items.count) \(itemWord)"

		let costSummary = PDFCostSummaryBuilder.build(scope: scope, context: modelContext)
		return PDFReportRenderer.render(title: "Project List Report", subtitle: subtitle, columns: columns, rows: rows, costSummary: costSummary, style: .standard)
	}

	// MARK: - Field-group builders
	//
	// Each cell drops empty strings and zero-valued numbers before handing fields to the
	// renderer, mirroring EditProjectList's own gating so sparse projects produce short rows
	// instead of a wall of zeros.

	private func text(_ value: String) -> String? {
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}

	private func fieldGroup(_ heading: String?, _ fields: [(String, String?)]) -> PDFFieldGroup? {
		let resolved: [(label: String, value: String)] = fields.compactMap { label, value in
			guard let value else { return nil }
			return (label: label, value: value)
		}
		guard !resolved.isEmpty else { return nil }
		return PDFFieldGroup(heading: heading, fields: resolved)
	}

	private func projectCell(_ item: ProjectList) -> PDFCell {
		let vehicleName = item.vehicleId.isEmpty ? nil : functions.getVehicleDisplayName(vehicleId: item.vehicleId, context: modelContext)

		var groups: [PDFFieldGroup] = []
		if let identity = fieldGroup(nil, [
			("Vehicle", vehicleName),
			("Item", text(item.itemName)),
			("Category", text(item.category)),
			("Sub-Category", text(item.subCategory)),
			("Priority", item.priority > 0 ? "\(item.priority)" : nil),
			("Status", item.itemCompleted ? "Completed" : "In Progress")
		]) {
			groups.append(identity)
		}

		return .imageWithGroups(item.image1, caption: item.image1Description, groups: groups)
	}

	private func detailsCell(_ item: ProjectList) -> PDFCell {
		var groups: [PDFFieldGroup] = []
		if let details = fieldGroup(nil, [
			("Description", text(item.itemDescription)),
			("Notes", text(item.itemNotes)),
			("Vendor", text(item.itemVendor))
		]) {
			groups.append(details)
		}
		return .groups(groups)
	}

	private func partLine(name: String, cost: Float, unit: String, quantity: Int) -> String? {
		let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedName.isEmpty, quantity > 0 else { return nil }
		let total = functions.formatCurrency(dollars: cost * Float(quantity))
		let unitSuffix = unit.isEmpty ? "" : " \(unit)"
		return "\(trimmedName) — \(quantity)\(unitSuffix) @ \(functions.formatCurrency(dollars: cost)) = \(total)"
	}

	private func partsCell(_ item: ProjectList) -> PDFCell {
		var groups: [PDFFieldGroup] = []
		if let parts = fieldGroup(nil, [
			("Part 1", partLine(name: item.part1, cost: item.part1cost, unit: item.part1Unit, quantity: item.part1Quantity)),
			("Part 2", partLine(name: item.part2, cost: item.part2cost, unit: item.part2Unit, quantity: item.part2Quantity)),
			("Part 3", partLine(name: item.part3, cost: item.part3cost, unit: item.part3Unit, quantity: item.part3Quantity)),
			("Part 4", partLine(name: item.part4, cost: item.part4cost, unit: item.part4Unit, quantity: item.part4Quantity)),
			("Part 5", partLine(name: item.part5, cost: item.part5cost, unit: item.part5Unit, quantity: item.part5Quantity))
		]) {
			groups.append(parts)
		}
		return .groups(groups)
	}

	private func costsAndProgressCell(_ item: ProjectList) -> PDFCell {
		var groups: [PDFFieldGroup] = []

		let partsCost = item.part1cost * Float(item.part1Quantity)
			+ item.part2cost * Float(item.part2Quantity)
			+ item.part3cost * Float(item.part3Quantity)
			+ item.part4cost * Float(item.part4Quantity)
			+ item.part5cost * Float(item.part5Quantity)
		let total = item.laborCost + partsCost

		if let costs = fieldGroup("Costs", [
			("Labor", item.laborCost != 0 ? functions.formatCurrency(dollars: item.laborCost) : nil),
			("Parts", partsCost != 0 ? functions.formatCurrency(dollars: partsCost) : nil),
			("Total", total != 0 ? functions.formatCurrency(dollars: total) : nil)
		]) {
			groups.append(costs)
		}

		if let progress = fieldGroup(nil, [
			("Miles", item.miles != 0 ? NumberFormatter.localizedString(from: NSNumber(value: item.miles), number: .decimal) : nil),
			("Engine Hours", item.engHours != 0 ? String(format: "%.1f hrs", item.engHours) : nil),
			("Completed", item.itemCompleted ? functions.formatDate_DDMMMyy(date: item.completedAt) : nil)
		]) {
			groups.append(progress)
		}

		return .groups(groups)
	}
}

// MARK: - Previews
/// A small preview host that seeds an in-memory SwiftData container and presents two previews:
/// one for all vehicles and one for a specific vehicle.
private struct ProjectListReportPreviewHost: View {
	let container: ModelContainer

	init() {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try! ModelContainer(for: ProjectList.self, Vehicle8.self, configurations: config)

		let context = container.mainContext

		let vehicle = Vehicle8(name: "Vehicle A", manufacturer: "Acme", model: "Hauler")
		context.insert(vehicle)

		let samples: [ProjectList] = [
			ProjectList(vehicleId: "Vehicle A", miles: 42150, itemName: "Replace air filter", itemDescription: "Engine air filter due for replacement.", itemNotes: "Check monthly.", category: "Engine", priority: 2, completedAt: Date(), laborCost: 20, part1: "Air Filter", part1cost: 18.5, part1Unit: "ea", part1Quantity: 1),
			ProjectList(vehicleId: "Vehicle A", itemName: "Wax exterior", itemCompleted: true, completedAt: Date())
		]
		samples.forEach { context.insert($0) }
		try? context.save()

		self.container = container
	}

	var body: some View {
		Group {
			pdfReportProjectList(trackVehicleSelected: "All Vehicles")
				.previewDisplayName("All Vehicles")

			pdfReportProjectList(trackVehicleSelected: "Vehicle A")
				.previewDisplayName("Vehicle A")
		}
		.modelContainer(container)
	}
}

#Preview {
	ProjectListReportPreviewHost()
}
