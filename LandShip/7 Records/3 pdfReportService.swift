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
		}
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

		let scopeTitle = (scope == "All Vehicles" || scope.isEmpty) ? "All Vehicles" : functions.getVehicleDisplayName(vehicleId: scope, context: modelContext)
		let recordWord = records.count == 1 ? "record" : "records"
		let subtitle = "\(scopeTitle) • \(functions.formatDate_DDMMMyy(date: Date())) • \(records.count) \(recordWord)"

		let costSummary = PDFCostSummaryBuilder.build(scope: scope, context: modelContext)
		return PDFReportRenderer.render(title: "Service Records Report", subtitle: subtitle, columns: columns, rows: rows, costSummary: costSummary, style: .standard)
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
			("Vehicle", vehicleName),
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
			("Miles", record.Miles != 0 ? NumberFormatter.localizedString(from: NSNumber(value: record.Miles), number: .decimal) : nil),
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
		return .groups(groups)
	}

	private func costsAndNotesCell(_ record: ServiceRecords1) -> PDFCell {
		var groups: [PDFFieldGroup] = []

		let partsCost = record.part1cost * Float(record.part1Quantity)
			+ record.part2cost * Float(record.part2Quantity)
			+ record.part3cost * Float(record.part3Quantity)
			+ record.part4cost * Float(record.part4Quantity)
			+ record.part5cost * Float(record.part5Quantity)
		let total = record.laborCost + partsCost

		if let costs = fieldGroup("Costs", [
			("Labor", record.laborCost != 0 ? functions.formatCurrency(dollars: record.laborCost) : nil),
			("Parts", partsCost != 0 ? functions.formatCurrency(dollars: partsCost) : nil),
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
