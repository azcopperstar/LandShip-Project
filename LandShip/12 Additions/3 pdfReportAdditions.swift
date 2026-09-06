/*
 File: pdfReportAdditions.swift
 Module: LandShip

 Summary
 -------
 A cross-platform SwiftUI view that generates and displays a PDF report of vehicle improvements
 (Additions). Built on the shared PDFReportRenderer engine (PDFReportStyle.swift): three category
 columns carry every Additions field, grouped and stacked so the report fits a portrait
 US-Letter page. The view owns its own vehicle scope via the shared VehicleScopePicker and can
 switch between "All Vehicles" and a specific vehicle without leaving the report. A "TRACKED
 COSTS SUMMARY" footer (shared across every cost-bearing report) totals lifetime costs across
 Parts, Fuel Log, Service Records, Items, Improvements, and Projects.

 Key Features
 ------------
 - Shared in-report vehicle picker (VehicleScopePicker) that re-fetches and regenerates on change
 - Empty/zero fields are dropped before layout so sparse records produce short rows
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
 - Models: Additions
 - Shared: PDFReportStyle.swift (PDFReportRenderer, PDFKitView, ZoomAction, PDFReportFile,
   VehicleScopePicker, PDFCostSummaryBuilder)
 - Utilities: Functions (date/currency formatting, vehicle display name lookup)
*/

import PDFKit
import SwiftUI
import SwiftData
import Foundation

/// A SwiftUI view that builds and displays a PDF report of vehicle improvements.
/// - Parameter trackVehicleSelected: The initial scope — "All Vehicles" (or empty) for every
///   vehicle, or a specific `Vehicle8.name` to report on just that vehicle's improvements. The
///   report owns this value afterward via its in-report vehicle picker.
struct pdfReportAdditions: View {
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
						PDFReportFile.printDocument(doc, jobName: "Additions")
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
			PDFReportFile.save(data: pdfData, fileName: "Additions")
		}
	}

	private func fetchAdditions() -> [Additions] {
		let descriptor: FetchDescriptor<Additions>
		if scope == "All Vehicles" || scope.isEmpty {
			descriptor = FetchDescriptor<Additions>(sortBy: [
				SortDescriptor(\.vehicleId, order: .forward),
				SortDescriptor(\.category, order: .forward),
				SortDescriptor(\.subCategory, order: .forward)
			])
		} else {
			let vehicleId = scope
			descriptor = FetchDescriptor<Additions>(
				predicate: #Predicate<Additions> { $0.vehicleId == vehicleId },
				sortBy: [SortDescriptor(\.category, order: .forward), SortDescriptor(\.subCategory, order: .forward)]
			)
		}
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	/// Builds the full multipage PDF for the current `scope`. Returns raw PDF data suitable
	/// for wrapping in a PDFDocument and/or saving to disk.
	func generatePDFWithTable() -> Data? {
		let items = fetchAdditions()

		let columns: [PDFTableColumn] = [
			PDFTableColumn("IMPROVEMENT", weight: 0.24),
			PDFTableColumn("DETAILS", weight: 0.42),
			PDFTableColumn("COST &\nINSTALL", weight: 0.34)
		]

		let rows: [[PDFCell]] = items.map { item in
			[
				improvementCell(item),
				detailsCell(item),
				costCell(item)
			]
		}

		let scopeTitle = (scope == "All Vehicles" || scope.isEmpty) ? "All Vehicles" : functions.getVehicleDisplayName(vehicleId: scope, context: modelContext)
		let itemWord = items.count == 1 ? "improvement" : "improvements"
		let subtitle = "\(scopeTitle) • \(functions.formatDate_DDMMMyy(date: Date())) • \(items.count) \(itemWord)"

		let costSummary = PDFCostSummaryBuilder.build(scope: scope, context: modelContext)
		return PDFReportRenderer.render(title: "Improvements Report", subtitle: subtitle, columns: columns, rows: rows, costSummary: costSummary, style: .standard)
	}

	// MARK: - Field-group builders
	//
	// Each cell drops empty strings and zero-valued numbers before handing fields to the
	// renderer, mirroring EditAdditions's own gating so sparse records produce short rows
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

	private func improvementCell(_ item: Additions) -> PDFCell {
		let vehicleName = item.vehicleId.isEmpty ? nil : functions.getVehicleDisplayName(vehicleId: item.vehicleId, context: modelContext)

		var groups: [PDFFieldGroup] = []
		if let identity = fieldGroup(nil, [
			("Vehicle", vehicleName),
			("Item", text(item.itemName)),
			("Category", text(item.category)),
			("Sub-Category", text(item.subCategory))
		]) {
			groups.append(identity)
		}

		return .imageWithGroups(item.image1, caption: item.image1Description, groups: groups)
	}

	private func detailsCell(_ item: Additions) -> PDFCell {
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

	private func costCell(_ item: Additions) -> PDFCell {
		var groups: [PDFFieldGroup] = []
		if let cost = fieldGroup(nil, [
			("Cost", item.itemCost != 0 ? functions.formatCurrency(dollars: item.itemCost) : nil),
			("Miles", item.miles != 0 ? NumberFormatter.localizedString(from: NSNumber(value: item.miles), number: .decimal) : nil),
			("Engine Hours", item.engHours != 0 ? String(format: "%.1f hrs", item.engHours) : nil)
		]) {
			groups.append(cost)
		}
		return .groups(groups)
	}
}

// MARK: - Previews
/// A small preview host that seeds an in-memory SwiftData container and presents two previews:
/// one for all vehicles and one for a specific vehicle.
private struct AdditionsReportPreviewHost: View {
	let container: ModelContainer

	init() {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try! ModelContainer(for: Additions.self, Vehicle8.self, configurations: config)

		let context = container.mainContext

		let vehicle = Vehicle8(name: "Vehicle A", manufacturer: "Acme", model: "Hauler")
		context.insert(vehicle)

		let samples: [Additions] = [
			Additions(vehicleId: "Vehicle A", miles: 42150, itemName: "Roof Rack", itemDescription: "Aluminum cross rails.", itemNotes: "Installed by dealer.", itemVendor: "Acme Accessories", category: "Exterior", subCategory: "Racks", itemCost: 350.0),
			Additions(vehicleId: "Vehicle A", itemName: "Dash Cam")
		]
		samples.forEach { context.insert($0) }
		try? context.save()

		self.container = container
	}

	var body: some View {
		Group {
			pdfReportAdditions(trackVehicleSelected: "All Vehicles")
				.previewDisplayName("All Vehicles")

			pdfReportAdditions(trackVehicleSelected: "Vehicle A")
				.previewDisplayName("Vehicle A")
		}
		.modelContainer(container)
	}
}

#Preview {
	AdditionsReportPreviewHost()
}
