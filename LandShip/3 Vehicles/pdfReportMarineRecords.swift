//
//  pdfReportMarineRecords.swift
//  LandShip
//
//  A cross-platform SwiftUI view that generates and displays a combined PDF covering
//  NauticalTrax's two regulatory-adjacent record types — HaulOutRecord and SurveyRecord —
//  for the current vehicle scope. NauticalTrax only (see Vertical.enabledFeatures); mirrors
//  pdfReportAviationLogbook.swift's structure: each record type gets its own mini-table via
//  a separate PDFReportRenderer.render(...) call, merged page-by-page into one document.
//
//  The regulatory disclaimer (Vertical.current.regulatoryDisclaimer) is passed as the
//  footerNote to both sections, so it reads consistently on every page.
//

import PDFKit
import SwiftUI
import SwiftData
import Foundation

struct pdfReportMarineRecords: View {
	@Environment(\.modelContext) var modelContext

	@State private var scope: String
	@State private var pdfDocument: PDFDocument?
	@State private var zoomAction: ZoomAction?

	let functions = Functions()

	init(trackVehicleSelected: String) {
		_scope = State(initialValue: trackVehicleSelected.isEmpty ? FleetScope.allSentinel : trackVehicleSelected)
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
						PDFReportFile.printDocument(doc, jobName: "Haul-Out & Survey Records")
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
		guard let pdfData = generateCombinedPDF() else { return }
		if let doc = PDFDocument(data: pdfData) {
			self.pdfDocument = doc
			PDFReportFile.save(data: pdfData, fileName: "Haul-Out & Survey Records")
		}
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

	private func scopeSubtitle(count: Int, noun: String) -> String {
		let scopeTitle = FleetScope.isAll(scope) ? FleetScope.allDisplayLabel : functions.getVehicleDisplayName(vehicleId: scope, context: modelContext)
		let word = count == 1 ? noun : "\(noun)s"
		return "\(scopeTitle) • \(functions.formatDate_DDMMMyy(date: Date())) • \(count) \(word)"
	}

	private func merged(_ sections: [Data?]) -> Data? {
		let combined = PDFDocument()
		var pageIndex = 0
		for section in sections {
			guard let section, let doc = PDFDocument(data: section) else { continue }
			for i in 0..<doc.pageCount {
				guard let page = doc.page(at: i) else { continue }
				combined.insert(page, at: pageIndex)
				pageIndex += 1
			}
		}
		guard pageIndex > 0 else { return nil }
		return combined.dataRepresentation()
	}

	private func generateCombinedPDF() -> Data? {
		merged([
			renderHaulOutRecords(),
			renderSurveyRecords()
		])
	}

	// MARK: - Haul-Out Records

	private func fetchHaulOutRecords() -> [HaulOutRecord] {
		let descriptor: FetchDescriptor<HaulOutRecord>
		if FleetScope.isAll(scope) {
			descriptor = FetchDescriptor(sortBy: [SortDescriptor(\.vehicleId), SortDescriptor(\.haulOutDate, order: .reverse)])
		} else {
			let vehicleId = scope
			descriptor = FetchDescriptor(
				predicate: #Predicate<HaulOutRecord> { $0.vehicleId == vehicleId },
				sortBy: [SortDescriptor(\.haulOutDate, order: .reverse)]
			)
		}
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	private func renderHaulOutRecords() -> Data? {
		let records = fetchHaulOutRecords()
		let columns: [PDFTableColumn] = [
			PDFTableColumn("HAUL-OUT", weight: 0.34),
			PDFTableColumn("WORK\nPERFORMED", weight: 0.33),
			PDFTableColumn("COST &\nNEXT DUE", weight: 0.33)
		]
		let rows: [[PDFCell]] = records.map { ho in
			let vehicleName = ho.vehicleId.isEmpty ? nil : functions.getVehicleDisplayName(vehicleId: ho.vehicleId, context: modelContext)
			var identity: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Date", functions.formatDate_DDMMMyy(date: ho.haulOutDate)),
				("Yard", text(ho.yardName)),
				(Vertical.current.assetSingular, vehicleName)
			]) { identity.append(g) }

			var work: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Bottom Paint", text(ho.bottomPaintType)),
				("Paint Applied", ho.bottomPaintApplied ? "Yes" : nil),
				("Zincs Replaced", ho.zincsReplaced ? "Yes" : nil),
				("Running Gear Serviced", ho.runningGearServiced ? "Yes" : nil)
			]) { work.append(g) }

			var costNext: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Cost", ho.cost != 0 ? functions.formatCurrency(dollars: ho.cost) : nil),
				("Next Due", functions.formatDate_DDMMMyy(date: ho.nextDueDate)),
				("Notes", text(ho.notes))
			]) { costNext.append(g) }

			return [.groups(identity), .groups(work), .groups(costNext)]
		}
		return PDFReportRenderer.render(
			title: "Haul-Out Records",
			subtitle: scopeSubtitle(count: records.count, noun: "haul-out"),
			columns: columns, rows: rows,
			footerNote: Vertical.current.regulatoryDisclaimer,
			style: .standard
		)
	}

	// MARK: - Survey Records

	private func fetchSurveyRecords() -> [SurveyRecord] {
		let descriptor: FetchDescriptor<SurveyRecord>
		if FleetScope.isAll(scope) {
			descriptor = FetchDescriptor(sortBy: [SortDescriptor(\.vehicleId), SortDescriptor(\.surveyDate, order: .reverse)])
		} else {
			let vehicleId = scope
			descriptor = FetchDescriptor(
				predicate: #Predicate<SurveyRecord> { $0.vehicleId == vehicleId },
				sortBy: [SortDescriptor(\.surveyDate, order: .reverse)]
			)
		}
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	private func renderSurveyRecords() -> Data? {
		let records = fetchSurveyRecords()
		let columns: [PDFTableColumn] = [
			PDFTableColumn("SURVEY", weight: 0.34),
			PDFTableColumn("FINDINGS", weight: 0.33),
			PDFTableColumn("COST &\nNEXT DUE", weight: 0.33)
		]
		let rows: [[PDFCell]] = records.map { sv in
			let vehicleName = sv.vehicleId.isEmpty ? nil : functions.getVehicleDisplayName(vehicleId: sv.vehicleId, context: modelContext)
			var identity: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Date", functions.formatDate_DDMMMyy(date: sv.surveyDate)),
				("Surveyor", text(sv.surveyorName)),
				("Type", text(sv.surveyType)),
				(Vertical.current.assetSingular, vehicleName)
			]) { identity.append(g) }

			var findings: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [("Findings", text(sv.findings))]) { findings.append(g) }

			var costNext: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Cost", sv.cost != 0 ? functions.formatCurrency(dollars: sv.cost) : nil),
				("Next Due", functions.formatDate_DDMMMyy(date: sv.nextDueDate)),
				("Notes", text(sv.notes))
			]) { costNext.append(g) }

			return [.groups(identity), .groups(findings), .groups(costNext)]
		}
		return PDFReportRenderer.render(
			title: "Survey Records",
			subtitle: scopeSubtitle(count: records.count, noun: "survey"),
			columns: columns, rows: rows,
			footerNote: Vertical.current.regulatoryDisclaimer,
			style: .standard
		)
	}
}
