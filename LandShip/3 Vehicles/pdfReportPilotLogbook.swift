//
//  pdfReportPilotLogbook.swift
//  LandShip
//
//  A cross-platform SwiftUI view that generates and displays a PDF of the pilot's logbook
//  (PilotLogbookEntry), with a lifetime-totals and certificate/currency summary block pulled
//  from the singleton PilotCertification record. AeroTrax only (see Vertical.enabledFeatures).
//  Not vehicle-scoped — a pilot's logbook spans every aircraft flown, so unlike most reports
//  in this app there is no VehicleScopePicker here, matching DisplayPilotLogbook's own design.
//
//  The regulatory disclaimer (Vertical.current.regulatoryDisclaimer) is passed as the
//  footerNote, consistent with the other AeroTrax/NauticalTrax reports.
//

import PDFKit
import SwiftUI
import SwiftData
import Foundation

struct pdfReportPilotLogbook: View {
	@Environment(\.modelContext) var modelContext

	@State private var pdfDocument: PDFDocument?
	@State private var zoomAction: ZoomAction?

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
						PDFReportFile.printDocument(doc, jobName: "Pilot Logbook")
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
			PDFReportFile.save(data: pdfData, fileName: "Pilot Logbook")
		}
	}

	private func fetchEntries() -> [PilotLogbookEntry] {
		let descriptor = FetchDescriptor<PilotLogbookEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	private func fetchCertification() -> PilotCertification? {
		let descriptor = FetchDescriptor<PilotCertification>()
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

	private func aircraftDisplay(_ entry: PilotLogbookEntry) -> String {
		if !entry.vehicleId.isEmpty {
			return functions.getVehicleDisplayName(vehicleId: entry.vehicleId, context: modelContext)
		}
		return entry.aircraftIdentifier.isEmpty ? "—" : entry.aircraftIdentifier
	}

	private func hoursString(_ value: Float) -> String? {
		value != 0 ? String(format: "%.1f", value) : nil
	}

	func generatePDFWithTable() -> Data? {
		let entries = fetchEntries()

		let columns: [PDFTableColumn] = [
			PDFTableColumn("FLIGHT", weight: 0.30),
			PDFTableColumn("TIME", weight: 0.42),
			PDFTableColumn("LANDINGS &\nREMARKS", weight: 0.28)
		]

		let rows: [[PDFCell]] = entries.map { entry in
			var flight: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Date", functions.formatDate_DDMMMyy(date: entry.date)),
				("Aircraft", text(aircraftDisplay(entry))),
				("Route", (entry.departureLocation.isEmpty && entry.arrivalLocation.isEmpty) ? nil : "\(entry.departureLocation) → \(entry.arrivalLocation)")
			]) { flight.append(g) }

			var time: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Total", hoursString(entry.totalTime)),
				("PIC", hoursString(entry.picTime)),
				("SIC", hoursString(entry.sicTime)),
				("Dual Received", hoursString(entry.dualReceived)),
				("Solo", hoursString(entry.soloTime)),
				("Night", hoursString(entry.nightTime)),
				("Actual Instrument", hoursString(entry.actualInstrumentTime)),
				("Simulated Instrument", hoursString(entry.simulatedInstrumentTime)),
				("Cross-Country", hoursString(entry.crossCountryTime))
			]) { time.append(g) }

			var landingsRemarks: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Day Landings", entry.dayLandings != 0 ? "\(entry.dayLandings)" : nil),
				("Night Landings", entry.nightLandings != 0 ? "\(entry.nightLandings)" : nil),
				("Remarks", text(entry.remarks))
			]) { landingsRemarks.append(g) }

			return [.groups(flight), .groups(time), .groups(landingsRemarks)]
		}

		let entryWord = entries.count == 1 ? "entry" : "entries"
		let subtitle = "\(functions.formatDate_DDMMMyy(date: Date())) • \(entries.count) \(entryWord)"

		return PDFReportRenderer.render(
			title: "Pilot Logbook",
			subtitle: subtitle,
			columns: columns, rows: rows,
			summary: logbookSummary(entries),
			footerNote: Vertical.current.regulatoryDisclaimer,
			style: .standard
		)
	}

	private func logbookSummary(_ entries: [PilotLogbookEntry]) -> PDFReportSummary {
		func sum(_ keyPath: (PilotLogbookEntry) -> Float) -> Float {
			entries.reduce(0) { $0 + keyPath($1) }
		}
		var groups: [PDFFieldGroup] = []
		if let totals = fieldGroup("Lifetime Totals", [
			("Total Time", hoursString(sum { $0.totalTime })),
			("PIC", hoursString(sum { $0.picTime })),
			("SIC", hoursString(sum { $0.sicTime })),
			("Dual Received", hoursString(sum { $0.dualReceived })),
			("Solo", hoursString(sum { $0.soloTime })),
			("Night", hoursString(sum { $0.nightTime })),
			("Actual Instrument", hoursString(sum { $0.actualInstrumentTime })),
			("Simulated Instrument", hoursString(sum { $0.simulatedInstrumentTime })),
			("Cross-Country", hoursString(sum { $0.crossCountryTime })),
			("Day Landings", entries.reduce(0) { $0 + $1.dayLandings } != 0 ? "\(entries.reduce(0) { $0 + $1.dayLandings })" : nil),
			("Night Landings", entries.reduce(0) { $0 + $1.nightLandings } != 0 ? "\(entries.reduce(0) { $0 + $1.nightLandings })" : nil)
		]) { groups.append(totals) }

		if let cert = fetchCertification(), let certGroup = fieldGroup("Certificate & Currency", [
			("Certificate Type", text(cert.certificateType)),
			("Ratings", text(cert.ratings)),
			("Medical Class", text(cert.medicalClass)),
			("Medical Expiration", functions.formatDate_DDMMMyy(date: cert.medicalExpirationDate)),
			("Flight Review Due", functions.formatDate_DDMMMyy(date: cert.flightReviewDueDate))
		]) {
			groups.append(certGroup)
		}

		return PDFReportSummary(title: "LOGBOOK SUMMARY", groups: groups)
	}
}
