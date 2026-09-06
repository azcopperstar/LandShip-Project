/*
 File: pdfReportService.swift
 Module: LandShip

 Summary
 -------
 A cross-platform SwiftUI view that generates and displays a PDF report of service records
 (ServiceRecords1). Built on the shared PDFReportRenderer engine (PDFReportStyle.swift): four
 category columns carry nearly every ServiceRecords1 field, grouped and stacked so the report
 fits a portrait US-Letter page. The view owns its own vehicle scope via the shared
 VehicleScopePicker and can switch between "All Vehicles" and a specific vehicle without leaving
 the report. A "TRACKED COSTS SUMMARY" footer (shared across every cost-bearing report) totals
 lifetime costs across Parts, Fuel Log, Service Records, Items, Improvements, and Projects.

 Key Features
 ------------
 - Shared in-report vehicle picker (VehicleScopePicker) that re-fetches and regenerates on change
 - Empty/zero fields are dropped before layout so sparse records produce short rows
 - Built-in print support and zoom controls via the shared PDFKitView/PDFReportFile helpers

 Excluded on purpose
 --------------------
 "Service Item & Vehicle Stats" (intervals, remaining miles/hours, next-due estimates) in
 EditRecord are computed live from the linked MxItems3 template and current vehicle odometer —
 not stored on ServiceRecords1 itself — so they're left out of this pass, same as the vehicle-
 totals-style sections skipped in Trip Log.

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
 - Models: ServiceRecords1
 - Shared: PDFReportStyle.swift (PDFReportRenderer, PDFKitView, ZoomAction, PDFReportFile,
   VehicleScopePicker, PDFCostSummaryBuilder)
 - Utilities: Functions (date/currency formatting, vehicle display name lookup)
*/

import PDFKit
import SwiftUI
import SwiftData
import Foundation

/// A SwiftUI view that builds and displays a PDF report of service records.
/// - Parameter trackVehicleSelected: The initial scope — "All Vehicles" (or empty) for every
///   vehicle, or a specific `Vehicle8.name` to report on just that vehicle's service records.
///   The report owns this value afterward via its in-report vehicle picker.
struct pdfReportService: View {
	@Environment(\.modelContext) var modelContext

	@State private var scope: String
	@State private var pdfDocument: PDFDocument?
	@State private var zoomAction: ZoomAction?
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
		.toolbar {
			ToolbarItem(placement: .automatic) {
				VehicleScopePicker(scope: $scope)
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
						PDFReportFile.printDocument(doc, jobName: "Service Records")
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
		.fileExporter(isPresented: $isExportingCSV, document: csvDocument, contentType: .commaSeparatedText, defaultFilename: "Service Records") { _ in }
	}

	// MARK: - CSV Export

	private func generateCSV() -> String {
		let records = fetchRecords()

		let partCount = 5
		var headers = [
			"Inactive", "Created At", "Updated At", "Service Date", Vertical.current.assetSingular, "\(Vertical.current.assetSingular) Display Name",
			Vertical.current.primaryMeterLabel, "Engine Hours", "Service Item", "Service Item ID", "Description", "Notes",
			"Vendor", "Labor Cost",
			"Custom Measure Label", "Custom Measure Unit", "Custom Measure Value",
			"Image 1 Description", "Image 2 Description", "Image 3 Description", "Image 4 Description", "Image 5 Description",
			"Sub Item 1", "Sub Item 1 ID", "Sub Item 1 Description", "Sub Item 1 Labor Cost", "Sub Item 1 Comments",
			"Sub Item 2", "Sub Item 2 ID", "Sub Item 2 Description", "Sub Item 2 Labor Cost", "Sub Item 2 Comments",
			"Sub Item 3", "Sub Item 3 ID", "Sub Item 3 Description", "Sub Item 3 Labor Cost", "Sub Item 3 Comments",
			"Sub Item 4", "Sub Item 4 ID", "Sub Item 4 Description", "Sub Item 4 Labor Cost", "Sub Item 4 Comments",
			"Sub Item 5", "Sub Item 5 ID", "Sub Item 5 Description", "Sub Item 5 Labor Cost", "Sub Item 5 Comments"
		]
		for i in 1...partCount {
			headers.append(contentsOf: ["Part \(i)", "Part \(i) Cost", "Part \(i) Unit", "Part \(i) Quantity"])
		}

		let rows: [[String]] = records.map { r in
			let vehicleName = r.vehicleId.isEmpty ? "" : functions.getVehicleDisplayName(vehicleId: r.vehicleId, context: modelContext)
			var row = [
				CSVField.bool(r.inactive), CSVField.date(r.createdAt), CSVField.date(r.updatedAt), CSVField.date(r.mxDate), r.vehicleId, vehicleName,
				CSVField.int(r.Miles), CSVField.float(r.engHours), r.mxName, r.mxItemId, r.mxDescription, r.Notes,
				r.vendor, CSVField.float(r.laborCost),
				r.customMeasureLabel, r.customMeasureUnit, CSVField.float(r.customMeasureValue),
				r.image1Description, r.image2Description, r.image3Description, r.image4Description, r.image5Description,
				r.subItem1, r.subItem1Id, r.subItem1Description, CSVField.float(r.subItem1LaborCost), r.subItem1Comments,
				r.subItem2, r.subItem2Id, r.subItem2Description, CSVField.float(r.subItem2LaborCost), r.subItem2Comments,
				r.subItem3, r.subItem3Id, r.subItem3Description, CSVField.float(r.subItem3LaborCost), r.subItem3Comments,
				r.subItem4, r.subItem4Id, r.subItem4Description, CSVField.float(r.subItem4LaborCost), r.subItem4Comments,
				r.subItem5, r.subItem5Id, r.subItem5Description, CSVField.float(r.subItem5LaborCost), r.subItem5Comments
			]
			let parts: [(name: String, cost: Float, unit: String, quantity: Int)] = [
				(r.part1, r.part1cost, r.part1Unit, r.part1Quantity),
				(r.part2, r.part2cost, r.part2Unit, r.part2Quantity),
				(r.part3, r.part3cost, r.part3Unit, r.part3Quantity),
				(r.part4, r.part4cost, r.part4Unit, r.part4Quantity),
				(r.part5, r.part5cost, r.part5Unit, r.part5Quantity)
			]
			for part in parts {
				row.append(contentsOf: [part.name, CSVField.float(part.cost), part.unit, CSVField.int(part.quantity)])
			}
			return row
		}

		return CSVBuilder.build(headers: headers, rows: rows)
	}

	// MARK: - Generation

	private func generateAndShowPDF() {
		guard let pdfData = generatePDFWithTable() else { return }
		if let doc = PDFDocument(data: pdfData) {
			self.pdfDocument = doc
			PDFReportFile.save(data: pdfData, fileName: "Service Records")
		}
	}

	private func fetchRecords() -> [ServiceRecords1] {
		let descriptor: FetchDescriptor<ServiceRecords1>
		if scope == "All Vehicles" || scope.isEmpty {
			descriptor = FetchDescriptor<ServiceRecords1>(sortBy: [
				SortDescriptor(\.vehicleId, order: .forward),
				SortDescriptor(\.mxDate, order: .reverse)
			])
		} else {
			let vehicleId = scope
			descriptor = FetchDescriptor<ServiceRecords1>(
				predicate: #Predicate<ServiceRecords1> { $0.vehicleId == vehicleId },
				sortBy: [SortDescriptor(\.mxDate, order: .reverse)]
			)
		}
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	/// Builds the full multipage PDF for the current `scope`. Returns raw PDF data suitable
	/// for wrapping in a PDFDocument and/or saving to disk.
	func generatePDFWithTable() -> Data? {
		let records = fetchRecords()

		let columns: [PDFTableColumn] = [
			PDFTableColumn("SERVICE", weight: 0.20),
			PDFTableColumn("DETAILS", weight: 0.22),
			PDFTableColumn("PARTS USED", weight: 0.30),
			PDFTableColumn("COSTS &\nNOTES", weight: 0.28)
		]

		let rows: [[PDFCell]] = records.map { record in
			[
				serviceCell(record),
				detailsCell(record),
				partsCell(record),
				costsAndNotesCell(record)
			]
		}

		let scopeTitle = FleetScope.isAll(scope) ? FleetScope.allDisplayLabel : functions.getVehicleDisplayName(vehicleId: scope, context: modelContext)
		let recordWord = records.count == 1 ? "record" : "records"
		let subtitle = "\(scopeTitle) • \(functions.formatDate_DDMMMyy(date: Date())) • \(records.count) \(recordWord)"

		let summary = serviceSummary(records)
		return PDFReportRenderer.render(title: "Service Records Report", subtitle: subtitle, columns: columns, rows: rows, summary: summary, style: .standard)
	}

	private func serviceSummary(_ records: [ServiceRecords1]) -> PDFReportSummary {
		let groups = pdfVehicleScopedSummaryGroups(scope: scope, records: records, vehicleId: \.vehicleId, context: modelContext) { subset in
			let totalLabor = subset.reduce(Float(0)) { $0 + $1.laborCost }
			let totalParts = subset.reduce(Float(0)) { total, record in
				total + record.part1cost * Float(record.part1Quantity)
					+ record.part2cost * Float(record.part2Quantity)
					+ record.part3cost * Float(record.part3Quantity)
					+ record.part4cost * Float(record.part4Quantity)
					+ record.part5cost * Float(record.part5Quantity)
			}
			let totalSubItemsLabor = subset.reduce(Float(0)) {
				$0 + $1.subItem1LaborCost + $1.subItem2LaborCost + $1.subItem3LaborCost + $1.subItem4LaborCost + $1.subItem5LaborCost
			}
			return [
				("Total Records", subset.isEmpty ? nil : "\(subset.count)"),
				("Total Labor", totalLabor != 0 ? pdfCurrencyString(totalLabor) : nil),
				("Total Parts", totalParts != 0 ? pdfCurrencyString(totalParts) : nil),
				("Total Sub-Items Labor", totalSubItemsLabor != 0 ? pdfCurrencyString(totalSubItemsLabor) : nil),
				("Total Cost", (totalLabor + totalParts + totalSubItemsLabor) != 0 ? pdfCurrencyString(totalLabor + totalParts + totalSubItemsLabor) : nil)
			]
		}
		return PDFReportSummary(title: "SERVICE RECORDS SUMMARY", groups: groups)
	}

	// MARK: - Field-group builders
	//
	// Each cell drops empty strings and zero-valued numbers before handing fields to the
	// renderer, mirroring EditRecord's own gating so sparse records produce short rows instead
	// of a wall of zeros.

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

	private func serviceCell(_ record: ServiceRecords1) -> PDFCell {
		let vehicleName = record.vehicleId.isEmpty ? nil : functions.getVehicleDisplayName(vehicleId: record.vehicleId, context: modelContext)

		var groups: [PDFFieldGroup] = []
		if let identity = fieldGroup(nil, [
			(Vertical.current.assetSingular, vehicleName),
			("Date", functions.formatDate_DDMMMyy(date: record.mxDate)),
			("Service Item", text(record.mxName)),
			("Vendor", text(record.vendor))
		]) {
			groups.append(identity)
		}

		return .imageWithGroups(record.image1, caption: record.image1Description, groups: groups)
	}

	private func detailsCell(_ record: ServiceRecords1) -> PDFCell {
		var groups: [PDFFieldGroup] = []
		if let details = fieldGroup(nil, [
			("Description", text(record.mxDescription)),
			(Vertical.current.primaryMeterLabel, record.Miles != 0 ? NumberFormatter.localizedString(from: NSNumber(value: record.Miles), number: .decimal) : nil),
			("Engine Hours", record.engHours != 0 ? String(format: "%.1f hrs", record.engHours) : nil),
			(record.customMeasureLabel.isEmpty ? "Custom" : record.customMeasureLabel,
			 record.customMeasureValue != 0 ? "\(String(format: "%.1f", record.customMeasureValue)) \(record.customMeasureUnit)" : nil)
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

	private func partsCell(_ record: ServiceRecords1) -> PDFCell {
		var groups: [PDFFieldGroup] = []
		if let parts = fieldGroup(nil, [
			("Part 1", partLine(name: record.part1, cost: record.part1cost, unit: record.part1Unit, quantity: record.part1Quantity)),
			("Part 2", partLine(name: record.part2, cost: record.part2cost, unit: record.part2Unit, quantity: record.part2Quantity)),
			("Part 3", partLine(name: record.part3, cost: record.part3cost, unit: record.part3Unit, quantity: record.part3Quantity)),
			("Part 4", partLine(name: record.part4, cost: record.part4cost, unit: record.part4Unit, quantity: record.part4Quantity)),
			("Part 5", partLine(name: record.part5, cost: record.part5cost, unit: record.part5Unit, quantity: record.part5Quantity))
		]) {
			groups.append(parts)
		}
		if let subItems = fieldGroup("Sub-Items", [
			("Item 1", subItemLine(name: record.subItem1, cost: record.subItem1LaborCost)),
			("Item 2", subItemLine(name: record.subItem2, cost: record.subItem2LaborCost)),
			("Item 3", subItemLine(name: record.subItem3, cost: record.subItem3LaborCost)),
			("Item 4", subItemLine(name: record.subItem4, cost: record.subItem4LaborCost)),
			("Item 5", subItemLine(name: record.subItem5, cost: record.subItem5LaborCost))
		]) {
			groups.append(subItems)
		}
		return .groups(groups)
	}

	private func subItemLine(name: String, cost: Float) -> String? {
		let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedName.isEmpty else { return nil }
		return cost != 0 ? "\(trimmedName) — \(functions.formatCurrency(dollars: cost))" : trimmedName
	}

	private func costsAndNotesCell(_ record: ServiceRecords1) -> PDFCell {
		var groups: [PDFFieldGroup] = []

		let partsCost = record.part1cost * Float(record.part1Quantity)
			+ record.part2cost * Float(record.part2Quantity)
			+ record.part3cost * Float(record.part3Quantity)
			+ record.part4cost * Float(record.part4Quantity)
			+ record.part5cost * Float(record.part5Quantity)
		let subItemsLaborCost = record.subItem1LaborCost + record.subItem2LaborCost + record.subItem3LaborCost
			+ record.subItem4LaborCost + record.subItem5LaborCost
		let total = record.laborCost + partsCost + subItemsLaborCost

		if let costs = fieldGroup("Costs", [
			("Labor", record.laborCost != 0 ? functions.formatCurrency(dollars: record.laborCost) : nil),
			("Parts", partsCost != 0 ? functions.formatCurrency(dollars: partsCost) : nil),
			("Sub-Items Labor", subItemsLaborCost != 0 ? functions.formatCurrency(dollars: subItemsLaborCost) : nil),
			("Total", total != 0 ? functions.formatCurrency(dollars: total) : nil)
		]) {
			groups.append(costs)
		}

		if let notes = fieldGroup(nil, [("Notes", text(record.Notes))]) {
			groups.append(notes)
		}

		return .groups(groups)
	}
}

// MARK: - Previews
/// A small preview host that seeds an in-memory SwiftData container and presents two previews:
/// one for all vehicles and one for a specific vehicle.
private struct ServiceReportPreviewHost: View {
	let container: ModelContainer

	init() {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try! ModelContainer(for: ServiceRecords1.self, Vehicle8.self, configurations: config)

		let context = container.mainContext

		let vehicle = Vehicle8(name: "Vehicle A", manufacturer: "Acme", model: "Hauler")
		context.insert(vehicle)

		let samples: [ServiceRecords1] = [
			ServiceRecords1(mxDate: Date(), vehicleId: "Vehicle A", Miles: 42150, engHours: 812.3, mxName: "Oil Change", mxDescription: "Full synthetic 5W-30", Notes: "Next due in 3 months.", vendor: "Quick Lube", laborCost: 45, part1: "Oil Filter", part1cost: 12.5, part1Unit: "ea", part1Quantity: 1, part2: "Oil", part2cost: 8.0, part2Unit: "qt", part2Quantity: 5),
			ServiceRecords1(mxDate: Date().addingTimeInterval(-2592000), vehicleId: "Vehicle A", mxName: "Tire Rotation", vendor: "")
		]
		samples.forEach { context.insert($0) }
		try? context.save()

		self.container = container
	}

	var body: some View {
		Group {
			pdfReportService(trackVehicleSelected: "All Vehicles")
				.previewDisplayName("All Vehicles")

			pdfReportService(trackVehicleSelected: "Vehicle A")
				.previewDisplayName("Vehicle A")
		}
		.modelContainer(container)
	}
}

#Preview {
	ServiceReportPreviewHost()
}
