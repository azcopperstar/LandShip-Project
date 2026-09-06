/*
 File: 3 pdfReportParts.swift
 Module: LandShip

 Summary
 -------
 A cross-platform SwiftUI view that generates and displays a PDF report of parts inventory
 (MxParts1). Built on the shared PDFReportRenderer engine (PDFReportStyle.swift): four category
 columns carry every MxParts1 field, grouped and stacked so the report fits a portrait US-Letter
 page. The view owns its own vehicle scope via the shared VehicleScopePicker and can switch
 between "All Vehicles" and a specific vehicle without leaving the report.

 Key Features
 ------------
 - Shared in-report vehicle picker (VehicleScopePicker) that re-fetches and regenerates on change
 - Unit/currency formatting via Functions (matches EditParts)
 - Empty/zero fields are dropped before layout so sparse parts produce short rows
 - Built-in print support and zoom controls via the shared PDFKitView/PDFReportFile helpers

 Data Flow
 ---------
 - `scope` (@State) selects "All Vehicles" or a specific vehicle by name; the picker mutates it.
 - `generatePDFWithTable()` fetches parts via FetchDescriptor (not @Query, since scope can change
   after the view appears), builds one PDFCell row per part, and hands them to
   `PDFReportRenderer.render(...)`.
 - The resulting Data is wrapped in PDFDocument and assigned to state (`pdfDocument`) for display,
   and saved to the app's Documents folder via `PDFReportFile.save(data:fileName:)`.

 Dependencies
 ------------
 - Frameworks: PDFKit, SwiftUI, SwiftData, Foundation
 - Models: MxParts1
 - Shared: PDFReportStyle.swift (PDFReportRenderer, PDFKitView, ZoomAction, PDFReportFile, VehicleScopePicker)
 - Utilities: Functions (currency formatting, vehicle display name lookup)
*/

import PDFKit
import SwiftUI
import SwiftData
import Foundation

/// A SwiftUI view that builds and displays a PDF report of parts inventory.
/// - Parameter trackVehicleSelected: The initial scope — "All Vehicles" (or empty) for every
///   part, or a specific `Vehicle8.name` to report on just that vehicle's parts. The report owns
///   this value afterward via its in-report vehicle picker.
struct pdfReportParts: View {
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
						PDFReportFile.printDocument(doc, jobName: "Parts Inventory")
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
			PDFReportFile.save(data: pdfData, fileName: "Parts Inventory")
		}
	}

	private func fetchParts() -> [MxParts1] {
		let descriptor: FetchDescriptor<MxParts1>
		if scope == "All Vehicles" || scope.isEmpty {
			descriptor = FetchDescriptor<MxParts1>(sortBy: [
				SortDescriptor(\.vehicleId, order: .forward),
				SortDescriptor(\.partName, order: .forward)
			])
		} else {
			let vehicleId = scope
			descriptor = FetchDescriptor<MxParts1>(
				predicate: #Predicate<MxParts1> { $0.vehicleId == vehicleId },
				sortBy: [SortDescriptor(\.partName, order: .forward)]
			)
		}
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	/// Builds the full multipage PDF for the current `scope`. Returns raw PDF data suitable
	/// for wrapping in a PDFDocument and/or saving to disk.
	func generatePDFWithTable() -> Data? {
		let parts = fetchParts()

		let columns: [PDFTableColumn] = [
			PDFTableColumn("PART", weight: 0.22),
			PDFTableColumn("DETAILS &\nNOTES", weight: 0.30),
			PDFTableColumn("COST &\nQUANTITY", weight: 0.20),
			PDFTableColumn("SOURCE &\nSTATUS", weight: 0.28)
		]

		let rows: [[PDFCell]] = parts.map { part in
			[
				partCell(part),
				detailsCell(part),
				costCell(part),
				sourceCell(part)
			]
		}

		let scopeTitle = (scope == "All Vehicles" || scope.isEmpty) ? "All Vehicles" : functions.getVehicleDisplayName(vehicleId: scope, context: modelContext)
		let partWord = parts.count == 1 ? "part" : "parts"
		let subtitle = "\(scopeTitle) • \(functions.formatDate_DDMMMyy(date: Date())) • \(parts.count) \(partWord)"

		return PDFReportRenderer.render(title: "Parts Inventory Report", subtitle: subtitle, columns: columns, rows: rows, style: .standard)
	}

	// MARK: - Field-group builders
	//
	// Each cell drops empty strings and zero-valued numbers before handing fields to the
	// renderer, mirroring EditParts's own gating so sparse parts produce short rows instead of
	// a wall of zeros.

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

	private func partCell(_ part: MxParts1) -> PDFCell {
		let vehicleName = part.vehicleId.isEmpty ? nil : functions.getVehicleDisplayName(vehicleId: part.vehicleId, context: modelContext)

		var groups: [PDFFieldGroup] = []
		if let identity = fieldGroup(nil, [
			("Part", text(part.partName)),
			("Part #", text(part.partNumber)),
			("Manufacturer", text(part.partManufacture)),
			("System", text(part.vehicleSystem)),
			("Vehicle", vehicleName)
		]) {
			groups.append(identity)
		}

		return .imageWithGroups(part.image1, caption: part.image1Description, groups: groups)
	}

	private func detailsCell(_ part: MxParts1) -> PDFCell {
		var groups: [PDFFieldGroup] = []
		if let details = fieldGroup(nil, [
			("Description", text(part.partDescription)),
			("Notes", text(part.Notes))
		]) {
			groups.append(details)
		}
		return .groups(groups)
	}

	private func costCell(_ part: MxParts1) -> PDFCell {
		var groups: [PDFFieldGroup] = []
		let totalCost = part.costPerUnit * Float(part.partQuantity)
		if let cost = fieldGroup(nil, [
			("Unit Price", part.costPerUnit != 0 ? functions.formatCurrency(dollars: part.costPerUnit) : nil),
			("Quantity", part.partQuantity != 0 ? NumberFormatter.localizedString(from: NSNumber(value: part.partQuantity), number: .decimal) : nil),
			("Unit", text(part.partUnit)),
			("Total Cost", part.costPerUnit != 0 ? functions.formatCurrency(dollars: totalCost) : nil)
		]) {
			groups.append(cost)
		}
		return .groups(groups)
	}

	private func sourceCell(_ part: MxParts1) -> PDFCell {
		var groups: [PDFFieldGroup] = []
		if let source = fieldGroup(nil, [
			("Supplier", text(part.partSupplier)),
			("Source", text(part.partSource)),
			("Location", text(part.partLocation)),
			("Status", text(part.partStatus))
		]) {
			groups.append(source)
		}
		return .groups(groups)
	}
}

// MARK: - Previews
/// A small preview host that seeds an in-memory SwiftData container and presents two previews:
/// one for all vehicles and one for a specific vehicle.
private struct PartsReportPreviewHost: View {
	let container: ModelContainer

	init() {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try! ModelContainer(for: MxParts1.self, Vehicle8.self, configurations: config)

		let context = container.mainContext

		let vehicle = Vehicle8(name: "Vehicle A", manufacturer: "Acme", model: "Hauler")
		context.insert(vehicle)

		let samples: [MxParts1] = [
			MxParts1(vehicleId: "Vehicle A", vehicleSystem: "Engine", partName: "Oil Filter", partNumber: "OF-9876", partManufacture: "FilterCo", partDescription: "High performance oil filter.", Notes: "Replace every 5,000 miles.", costPerUnit: 12.99, partUnit: "each", partSource: "Aisle 3", partQuantity: 4, partLocation: "Bin B", partStatus: "In Stock", partSupplier: "AutoParts Plus"),
			MxParts1(vehicleId: "Vehicle A", vehicleSystem: "Brakes", partName: "Brake Pads", partNumber: "BP-1234", partManufacture: "StopCo", partDescription: "", Notes: "", costPerUnit: 45.0, partUnit: "set", partSource: "", partQuantity: 2, partLocation: "", partStatus: "", partSupplier: "")
		]
		samples.forEach { context.insert($0) }
		try? context.save()

		self.container = container
	}

	var body: some View {
		Group {
			pdfReportParts(trackVehicleSelected: "All Vehicles")
				.previewDisplayName("All Vehicles")

			pdfReportParts(trackVehicleSelected: "Vehicle A")
				.previewDisplayName("Vehicle A")
		}
		.modelContainer(container)
	}
}

#Preview {
	PartsReportPreviewHost()
}
