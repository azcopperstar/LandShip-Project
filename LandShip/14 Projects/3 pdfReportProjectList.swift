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
	@State private var csvDocument = CSVDocument(text: "")
	@State private var isExportingCSV = false

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
						punchListDestination = PunchListDestination(subcategory: sub)
					}
				}
				.navigationTitle("Choose Sub-Category")
			}
		}
		.sheet(item: $punchListDestination) { dest in
			NavigationStack {
				pdfReportPunchList(trackVehicleSelected: scope, projectSubcategory: dest.subcategory)
			}
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
			ToolbarItem(placement: .automatic) {
				Button {
					csvDocument = CSVDocument(text: generateCSV())
					isExportingCSV = true
				} label: {
					Label("Export CSV", systemImage: "tablecells")
				}
			}
		}
		.fileExporter(isPresented: $isExportingCSV, document: csvDocument, contentType: .commaSeparatedText, defaultFilename: "Project List") { _ in }
	}

	// MARK: - CSV Export

	private func generateCSV() -> String {
		let items = fetchProjects()
		let partCount = 5
		var headers = [
			"Inactive", "Created At", "Updated At", Vertical.current.assetSingular, "\(Vertical.current.assetSingular) Display Name",
			Vertical.current.primaryMeterLabel, "Engine Hours", "Item Name", "Description", "Notes", "Vendor",
			"Category", "Category Order", "Sub-Category", "Sub-Category Order", "Project Order", "Priority",
			"Completed", "Completed At", "Save In Logbook", "Saved To Logbook", "Linked Addition ID", "Item Cost", "Labor Cost",
			"Image 1 Description", "Image 2 Description", "Image 3 Description", "Image 4 Description", "Image 5 Description"
		]
		for i in 1...partCount {
			headers.append(contentsOf: ["Part \(i)", "Part \(i) Cost", "Part \(i) Unit", "Part \(i) Quantity"])
		}
		let rows: [[String]] = items.map { p in
			let vehicleName = p.vehicleId.isEmpty ? "" : functions.getVehicleDisplayName(vehicleId: p.vehicleId, context: modelContext)
			var row = [
				CSVField.bool(p.inactive), CSVField.date(p.createdAt), CSVField.date(p.updatedAt), p.vehicleId, vehicleName,
				CSVField.int(p.miles), CSVField.float(p.engHours), p.itemName, p.itemDescription, p.itemNotes, p.itemVendor,
				p.category, CSVField.int(p.categoryOrder), p.subCategory, CSVField.int(p.subcategoryOrder), CSVField.int(p.projectOrder), CSVField.int(p.priority),
				CSVField.bool(p.itemCompleted), CSVField.date(p.completedAt), CSVField.bool(p.saveInLogbook), CSVField.bool(p.savedToLogbook), p.additionsLinkId, CSVField.float(p.itemCost), CSVField.float(p.laborCost),
				p.image1Description, p.image2Description, p.image3Description, p.image4Description, p.image5Description
			]
			let parts: [(name: String, cost: Float, unit: String, quantity: Int)] = [
				(p.part1, p.part1cost, p.part1Unit, p.part1Quantity),
				(p.part2, p.part2cost, p.part2Unit, p.part2Quantity),
				(p.part3, p.part3cost, p.part3Unit, p.part3Quantity),
				(p.part4, p.part4cost, p.part4Unit, p.part4Quantity),
				(p.part5, p.part5cost, p.part5Unit, p.part5Quantity)
			]
			for part in parts {
				row.append(contentsOf: [part.name, CSVField.float(part.cost), part.unit, CSVField.int(part.quantity)])
			}
			return row
		}
		return CSVBuilder.build(headers: headers, rows: rows)
	}

	// MARK: - Punch List hand-off

	private struct PunchListDestination: Identifiable, Hashable {
		let id = UUID()
		let subcategory: String
	}
	@State private var punchListDestination: PunchListDestination?

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

		let scopeTitle = FleetScope.isAll(scope) ? FleetScope.allDisplayLabel : functions.getVehicleDisplayName(vehicleId: scope, context: modelContext)
		let itemWord = items.count == 1 ? "project" : "projects"
		let subtitle = "\(scopeTitle) • \(functions.formatDate_DDMMMyy(date: Date())) • \(items.count) \(itemWord)"

		let summary = projectsSummary(items)
		return PDFReportRenderer.render(title: "Project List Report", subtitle: subtitle, columns: columns, rows: rows, summary: summary, style: .standard)
	}

	private func projectsSummary(_ items: [ProjectList]) -> PDFReportSummary {
		let groups = pdfVehicleScopedSummaryGroups(scope: scope, records: items, vehicleId: \.vehicleId, context: modelContext) { subset in
			let completedCount = subset.filter(\.itemCompleted).count
			let totalLabor = subset.reduce(Float(0)) { $0 + $1.laborCost }
			let totalParts = subset.reduce(Float(0)) { total, item in
				total + item.part1cost * Float(item.part1Quantity)
					+ item.part2cost * Float(item.part2Quantity)
					+ item.part3cost * Float(item.part3Quantity)
					+ item.part4cost * Float(item.part4Quantity)
					+ item.part5cost * Float(item.part5Quantity)
			}
			let inProgressCount = subset.count - completedCount
			return [
				("Total Projects", subset.isEmpty ? nil : "\(subset.count)"),
				("Completed", completedCount != 0 ? "\(completedCount)" : nil),
				("In Progress", inProgressCount != 0 ? "\(inProgressCount)" : nil),
				("Total Labor", totalLabor != 0 ? pdfCurrencyString(totalLabor) : nil),
				("Total Parts", totalParts != 0 ? pdfCurrencyString(totalParts) : nil),
				("Total Cost", (totalLabor + totalParts) != 0 ? pdfCurrencyString(totalLabor + totalParts) : nil)
			]
		}
		return PDFReportSummary(title: "PROJECTS SUMMARY", groups: groups)
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
			(Vertical.current.assetSingular, vehicleName),
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
