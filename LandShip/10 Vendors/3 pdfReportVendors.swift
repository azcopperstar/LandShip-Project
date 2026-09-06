/*
 File: pdfReportVendors.swift
 Module: LandShip

 Summary
 -------
 A cross-platform SwiftUI view that generates and displays a PDF report of vendors/shops
 (Vendors1). Built on the shared PDFReportRenderer engine (PDFReportStyle.swift): four category
 columns carry every Vendors1 field, grouped and stacked so the report fits a portrait US-Letter
 page.

 Key Features
 ------------
 - Vendors are global, not scoped to a vehicle — there is no vehicle picker on this report
 - Empty fields are dropped before layout so sparse vendor records produce short rows
 - Built-in print support and zoom controls via the shared PDFKitView/PDFReportFile helpers

 Data Flow
 ---------
 - `@Query` fetches every `Vendors1` record, sorted by name; there is no scope to react to.
 - `generatePDFWithTable()` builds one PDFCell row per vendor and hands them to
   `PDFReportRenderer.render(...)`.
 - The resulting Data is wrapped in PDFDocument and assigned to state (`pdfDocument`) for display,
   and saved to the app's Documents folder via `PDFReportFile.save(data:fileName:)`.

 Dependencies
 ------------
 - Frameworks: PDFKit, SwiftUI, SwiftData, Foundation
 - Models: Vendors1
 - Shared: PDFReportStyle.swift (PDFReportRenderer, PDFKitView, ZoomAction, PDFReportFile)
 - Utilities: Functions (date formatting)
*/

import PDFKit
import SwiftUI
import SwiftData
import Foundation

/// A SwiftUI view that builds and displays a PDF report of vendors/shops. Vendors are global
/// (not per-vehicle), so unlike the other reports this one takes no scope parameter.
struct pdfReportVendors: View {
	@Query(sort: [SortDescriptor(\Vendors1.vendorName, order: .forward)]) private var dataSet: [Vendors1]
	@Environment(\.modelContext) var modelContext

	@State private var pdfDocument: PDFDocument?
	@State private var zoomAction: ZoomAction?
	@State private var csvDocument = CSVDocument(text: "")
	@State private var isExportingCSV = false

	let functions = Functions()

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
		.toolbar {
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
						PDFReportFile.printDocument(doc, jobName: "Vendors and Shops")
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
		.fileExporter(isPresented: $isExportingCSV, document: csvDocument, contentType: .commaSeparatedText, defaultFilename: "Vendors and Shops") { _ in }
	}

	// MARK: - CSV Export

	private func generateCSV() -> String {
		let headers = [
			"Inactive", "Created At", "Updated At", "Vendor Name", "Vendor Type",
			"Contact 1", "Contact 2", "Contact 3", "Address", "City", "State", "Zip",
			"Phone", "Email", "Website", "Notes",
			"Image 1 Description", "Image 2 Description", "Image 3 Description"
		]
		let rows: [[String]] = dataSet.map { v in
			[
				CSVField.bool(v.inactive), CSVField.date(v.createdAt), CSVField.date(v.updatedAt), v.vendorName, v.vendorType,
				v.vendorContact1, v.vendorContact2, v.vendorContact3, v.vendorAddress, v.vendorCity, v.vendorState, v.vendorZip,
				v.vendorPhone, v.vendorEmail, v.vendorWebsite, v.vendorNotes,
				v.image1Description, v.image2Description, v.image3Description
			]
		}
		return CSVBuilder.build(headers: headers, rows: rows)
	}

	// MARK: - Generation

	private func generateAndShowPDF() {
		guard let pdfData = generatePDFWithTable() else { return }
		if let doc = PDFDocument(data: pdfData) {
			self.pdfDocument = doc
			PDFReportFile.save(data: pdfData, fileName: "Vendors and Shops")
		}
	}

	/// Builds the full multipage PDF. Returns raw PDF data suitable for wrapping in a
	/// PDFDocument and/or saving to disk.
	func generatePDFWithTable() -> Data? {
		let columns: [PDFTableColumn] = [
			PDFTableColumn("VENDOR", weight: 0.22),
			PDFTableColumn("CONTACTS", weight: 0.20),
			PDFTableColumn("ADDRESS &\nCOMMS", weight: 0.30),
			PDFTableColumn("NOTES", weight: 0.28)
		]

		let rows: [[PDFCell]] = dataSet.map { vendor in
			[
				vendorCell(vendor),
				contactsCell(vendor),
				addressAndCommsCell(vendor),
				notesCell(vendor)
			]
		}

		let vendorWord = dataSet.count == 1 ? "vendor" : "vendors"
		let subtitle = "\(functions.formatDate_DDMMMyy(date: Date())) • \(dataSet.count) \(vendorWord)"

		let summary = vendorsSummary(dataSet)
		return PDFReportRenderer.render(title: "Vendors and Shops Report", subtitle: subtitle, columns: columns, rows: rows, summary: summary, style: .standard)
	}

	/// Breaks down the vendor list by type — the one categorical dimension worth totaling here.
	/// Vendors have no vehicle association, so there's no per-vehicle breakdown to add here.
	private func vendorsSummary(_ vendors: [Vendors1]) -> PDFReportSummary {
		var countsByType: [String: Int] = [:]
		for vendor in vendors {
			let type = text(vendor.vendorType) ?? "Uncategorized"
			countsByType[type, default: 0] += 1
		}
		// countsByType only ever contains types that were actually observed, so every count here
		// is already nonzero; only the trailing "Total Vendors" line needs its own zero guard.
		let byType: [(label: String, value: String)] = countsByType.sorted { $0.key < $1.key }.map { ($0.key, "\($0.value)") }
		let fields = byType + (vendors.isEmpty ? [] : [("Total Vendors", "\(vendors.count)")])
		return PDFReportSummary(
			title: "VENDORS SUMMARY",
			groups: fields.isEmpty ? [] : [PDFFieldGroup(fields: fields)]
		)
	}

	// MARK: - Field-group builders
	//
	// Each cell drops empty fields before handing them to the renderer, mirroring EditIVendors's
	// own gating so sparse vendor records produce short rows instead of a wall of blanks.

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

	private func vendorCell(_ vendor: Vendors1) -> PDFCell {
		var groups: [PDFFieldGroup] = []
		if let identity = fieldGroup(nil, [
			("Vendor", text(vendor.vendorName)),
			("Type", text(vendor.vendorType))
		]) {
			groups.append(identity)
		}
		return .imageWithGroups(vendor.image1, caption: vendor.image1Description, groups: groups)
	}

	private func contactsCell(_ vendor: Vendors1) -> PDFCell {
		var groups: [PDFFieldGroup] = []
		if let contacts = fieldGroup(nil, [
			("Contact 1", text(vendor.vendorContact1)),
			("Contact 2", text(vendor.vendorContact2)),
			("Contact 3", text(vendor.vendorContact3))
		]) {
			groups.append(contacts)
		}
		return .groups(groups)
	}

	private func addressAndCommsCell(_ vendor: Vendors1) -> PDFCell {
		var groups: [PDFFieldGroup] = []
		if let address = fieldGroup("Address", [
			("Street", text(vendor.vendorAddress)),
			("City", text(vendor.vendorCity)),
			("State", text(vendor.vendorState)),
			("Zip", text(vendor.vendorZip))
		]) {
			groups.append(address)
		}
		if let comms = fieldGroup("Contact", [
			("Phone", text(vendor.vendorPhone)),
			("Email", text(vendor.vendorEmail)),
			("Website", text(vendor.vendorWebsite))
		]) {
			groups.append(comms)
		}
		return .groups(groups)
	}

	private func notesCell(_ vendor: Vendors1) -> PDFCell {
		var groups: [PDFFieldGroup] = []
		if let notes = fieldGroup(nil, [("Notes", text(vendor.vendorNotes))]) {
			groups.append(notes)
		}
		return .groups(groups)
	}
}

// MARK: - Previews
/// A small preview host that seeds an in-memory SwiftData container.
private struct VendorsReportPreviewHost: View {
	let container: ModelContainer

	init() {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try! ModelContainer(for: Vendors1.self, configurations: config)

		let context = container.mainContext

		let samples: [Vendors1] = [
			Vendors1(createdAt: Date(), updatedAt: Date(), vendorName: "AutoParts Plus", vendorType: "Parts Vendor", vendorContact1: "Jane Doe", vendorContact2: "", vendorContact3: "", vendorAddress: "123 Main St", vendorCity: "Springfield", vendorState: "IL", vendorZip: "62704", vendorPhone: "555-1234", vendorEmail: "jane@autopartsplus.com", vendorWebsite: "", vendorNotes: "Preferred parts supplier."),
			Vendors1(createdAt: Date(), updatedAt: Date(), vendorName: "Quick Lube", vendorType: "Service & Repair", vendorContact1: "", vendorContact2: "", vendorContact3: "", vendorAddress: "", vendorCity: "", vendorState: "", vendorZip: "", vendorPhone: "", vendorEmail: "", vendorWebsite: "", vendorNotes: "")
		]
		samples.forEach { context.insert($0) }
		try? context.save()

		self.container = container
	}

	var body: some View {
		pdfReportVendors()
			.modelContainer(container)
	}
}

#Preview {
	VendorsReportPreviewHost()
}
