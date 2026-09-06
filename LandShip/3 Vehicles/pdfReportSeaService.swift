//
//  pdfReportSeaService.swift
//  LandShip
//
//  A cross-platform SwiftUI view that generates and displays a PDF of the mariner's sea
//  service log (SeaServiceEntry), with a lifetime-totals and credential/currency summary
//  block pulled from the singleton MarinerCredential record. NauticalTrax only (see
//  Vertical.enabledFeatures). Not vehicle-scoped — sea service spans every vessel served on,
//  so unlike most reports in this app there is no VehicleScopePicker here, matching
//  DisplaySeaService's own design. Mirrors pdfReportPilotLogbook.swift's structure.
//
//  The regulatory disclaimer (Vertical.current.regulatoryDisclaimer) is passed as the
//  footerNote, consistent with the other AeroTrax/NauticalTrax reports.
//

import PDFKit
import SwiftUI
import SwiftData
import Foundation

struct pdfReportSeaService: View {
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
						PDFReportFile.printDocument(doc, jobName: "Sea Service Log")
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
		.fileExporter(isPresented: $isExportingCSV, document: csvDocument, contentType: .commaSeparatedText, defaultFilename: "Sea Service Log") { _ in }
	}

	// MARK: - CSV Export

	private func generateCSV() -> String {
		let entries = fetchEntries()
		let headers = [
			"Date", "Vessel", "Route", "Waters", "Capacity Served", "Tonnage", "Days of Service", "Hours Underway", "Remarks",
			"Image 1 Description"
		]
		let rows: [[String]] = entries.map { entry in
			[
				CSVField.date(entry.date), vesselDisplay(entry), entry.routeDescription, entry.watersType, entry.capacityServed,
				CSVField.float(entry.tonnage), CSVField.float(entry.daysOfService), CSVField.float(entry.hoursUnderway), entry.remarks, entry.image1Description
			]
		}
		var output = CSVBuilder.build(headers: headers, rows: rows)
		if let cred = fetchCredential() {
			output += "\r\nCREDENTIAL & CURRENCY\r\n"
			output += CSVBuilder.build(headers: ["Credential Type", "Credential Number", "Endorsements", "Issue Date", "Expiration Date", "Medical Cert Expiration", "Notes"],
				rows: [[cred.credentialType, cred.credentialNumber, cred.endorsements, CSVField.date(cred.issueDate), CSVField.date(cred.expirationDate), CSVField.date(cred.medicalCertExpirationDate), cred.notes]])
		}
		return output
	}

	// MARK: - Generation

	private func generateAndShowPDF() {
		guard let pdfData = generatePDFWithTable() else { return }
		if let doc = PDFDocument(data: pdfData) {
			self.pdfDocument = doc
			PDFReportFile.save(data: pdfData, fileName: "Sea Service Log")
		}
	}

	private func fetchEntries() -> [SeaServiceEntry] {
		let descriptor = FetchDescriptor<SeaServiceEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	private func fetchCredential() -> MarinerCredential? {
		let descriptor = FetchDescriptor<MarinerCredential>()
		return (try? modelContext.fetch(descriptor))?.first
	}

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

	private func vesselDisplay(_ entry: SeaServiceEntry) -> String {
		if !entry.vehicleId.isEmpty {
			return functions.getVehicleDisplayName(vehicleId: entry.vehicleId, context: modelContext)
		}
		return entry.vesselIdentifier.isEmpty ? "—" : entry.vesselIdentifier
	}

	private func numberString(_ value: Float) -> String? {
		value != 0 ? String(format: "%.1f", value) : nil
	}

	func generatePDFWithTable() -> Data? {
		let entries = fetchEntries()

		let columns: [PDFTableColumn] = [
			PDFTableColumn("VOYAGE", weight: 0.30),
			PDFTableColumn("SERVICE", weight: 0.42),
			PDFTableColumn("REMARKS", weight: 0.28)
		]

		let rows: [[PDFCell]] = entries.map { entry in
			var voyage: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Date", functions.formatDate_DDMMMyy(date: entry.date)),
				("Vessel", text(vesselDisplay(entry))),
				("Route", text(entry.routeDescription))
			]) { voyage.append(g) }

			var service: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Waters", text(entry.watersType)),
				("Capacity Served", text(entry.capacityServed)),
				("Tonnage", numberString(entry.tonnage)),
				("Days of Service", numberString(entry.daysOfService)),
				("Hours Underway", numberString(entry.hoursUnderway))
			]) { service.append(g) }

			var remarksGroup: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [("Remarks", text(entry.remarks))]) { remarksGroup.append(g) }

			return [.groups(voyage), .groups(service), .groups(remarksGroup)]
		}

		let entryWord = entries.count == 1 ? "entry" : "entries"
		let subtitle = "\(functions.formatDate_DDMMMyy(date: Date())) • \(entries.count) \(entryWord)"

		return PDFReportRenderer.render(
			title: "Sea Service Log",
			subtitle: subtitle,
			columns: columns, rows: rows,
			summary: seaServiceSummary(entries),
			footerNote: Vertical.current.regulatoryDisclaimer,
			style: .standard
		)
	}

	private func seaServiceSummary(_ entries: [SeaServiceEntry]) -> PDFReportSummary {
		func sum(_ keyPath: (SeaServiceEntry) -> Float) -> Float {
			entries.reduce(0) { $0 + keyPath($1) }
		}
		var groups: [PDFFieldGroup] = []
		if let totals = fieldGroup("Lifetime Totals", [
			("Total Days of Service", numberString(sum { $0.daysOfService })),
			("Total Hours Underway", numberString(sum { $0.hoursUnderway })),
			("Total Entries", entries.isEmpty ? nil : "\(entries.count)")
		]) { groups.append(totals) }

		if let cred = fetchCredential(), let credGroup = fieldGroup("Credential & Currency", [
			("Credential Type", text(cred.credentialType)),
			("Endorsements", text(cred.endorsements)),
			("Expiration Date", functions.formatDate_DDMMMyy(date: cred.expirationDate)),
			("Medical Cert Expiration", functions.formatDate_DDMMMyy(date: cred.medicalCertExpirationDate))
		]) {
			groups.append(credGroup)
		}

		return PDFReportSummary(title: "SEA SERVICE SUMMARY", groups: groups)
	}
}
