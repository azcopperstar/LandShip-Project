//
//  pdfReportAviationLogbook.swift
//  LandShip
//
//  A cross-platform SwiftUI view that generates and displays a combined logbook-style PDF
//  covering AeroTrax's three regulatory-adjacent record types — AirworthinessDirective,
//  InspectionCycle, and ComponentTimes — for the current vehicle scope. AeroTrax only (see
//  Vertical.enabledFeatures); mirrors pdfReportParts.swift's structure, but since the three
//  record types don't share a column schema, each gets its own mini-table via a separate
//  PDFReportRenderer.render(...) call, and the resulting single-section PDFDocuments are
//  merged page-by-page into one document rather than teaching the shared engine to mix
//  column schemas within a single render pass.
//
//  The regulatory disclaimer (Vertical.current.regulatoryDisclaimer) is passed as the
//  footerNote to all three sections, so it reads consistently on every page.
//

import PDFKit
import SwiftUI
import SwiftData
import Foundation

struct pdfReportAviationLogbook: View {
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
						PDFReportFile.printDocument(doc, jobName: "Logbook")
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
			PDFReportFile.save(data: pdfData, fileName: "Logbook")
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
			renderAirworthinessDirectives(),
			renderInspectionCycles(),
			renderComponentTimes()
		])
	}

	// MARK: - Airworthiness Directives

	private func fetchAirworthinessDirectives() -> [AirworthinessDirective] {
		let descriptor: FetchDescriptor<AirworthinessDirective>
		if FleetScope.isAll(scope) {
			descriptor = FetchDescriptor(sortBy: [SortDescriptor(\.vehicleId), SortDescriptor(\.nextDueDate)])
		} else {
			let vehicleId = scope
			descriptor = FetchDescriptor(
				predicate: #Predicate<AirworthinessDirective> { $0.vehicleId == vehicleId },
				sortBy: [SortDescriptor(\.nextDueDate)]
			)
		}
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	private func renderAirworthinessDirectives() -> Data? {
		let ads = fetchAirworthinessDirectives()
		let columns: [PDFTableColumn] = [
			PDFTableColumn("AIRWORTHINESS\nDIRECTIVE", weight: 0.34),
			PDFTableColumn("COMPLIANCE", weight: 0.33),
			PDFTableColumn("SCHEDULE", weight: 0.33)
		]
		let rows: [[PDFCell]] = ads.map { ad in
			let vehicleName = ad.vehicleId.isEmpty ? nil : functions.getVehicleDisplayName(vehicleId: ad.vehicleId, context: modelContext)
			var identity: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("AD Number", text(ad.adNumber)),
				("Title", text(ad.title)),
				("Applicability", text(ad.applicability)),
				(Vertical.current.assetSingular, vehicleName)
			]) { identity.append(g) }

			var compliance: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Method", text(ad.methodOfCompliance)),
				("Signed Off By", text(ad.signedOffBy)),
				("Compliance Date", functions.formatDate_DDMMMyy(date: ad.complianceDate)),
				("Compliance Hours", ad.complianceHours != 0 ? "\(ad.complianceHours)" : nil)
			]) { compliance.append(g) }

			var schedule: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Recurring", ad.isRecurring ? "Yes (\(ad.intervalType))" : "One-Time"),
				("Interval", ad.isRecurring && ad.intervalValue != 0 ? "\(ad.intervalValue)" : nil),
				("Next Due Date", functions.formatDate_DDMMMyy(date: ad.nextDueDate)),
				("Next Due Hours", ad.nextDueHours != 0 ? "\(ad.nextDueHours)" : nil)
			]) { schedule.append(g) }

			return [.groups(identity), .groups(compliance), .groups(schedule)]
		}
		return PDFReportRenderer.render(
			title: "Airworthiness Directives",
			subtitle: scopeSubtitle(count: ads.count, noun: "directive"),
			columns: columns, rows: rows,
			footerNote: Vertical.current.regulatoryDisclaimer,
			style: .standard
		)
	}

	// MARK: - Inspection Cycles

	private func fetchInspectionCycles() -> [InspectionCycle] {
		let descriptor: FetchDescriptor<InspectionCycle>
		if FleetScope.isAll(scope) {
			descriptor = FetchDescriptor(sortBy: [SortDescriptor(\.vehicleId), SortDescriptor(\.nextDueDate)])
		} else {
			let vehicleId = scope
			descriptor = FetchDescriptor(
				predicate: #Predicate<InspectionCycle> { $0.vehicleId == vehicleId },
				sortBy: [SortDescriptor(\.nextDueDate)]
			)
		}
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	private func renderInspectionCycles() -> Data? {
		let inspections = fetchInspectionCycles()
		let columns: [PDFTableColumn] = [
			PDFTableColumn("INSPECTION", weight: 0.34),
			PDFTableColumn("LAST\nCOMPLIED", weight: 0.33),
			PDFTableColumn("NEXT DUE", weight: 0.33)
		]
		let rows: [[PDFCell]] = inspections.map { insp in
			let vehicleName = insp.vehicleId.isEmpty ? nil : functions.getVehicleDisplayName(vehicleId: insp.vehicleId, context: modelContext)
			var identity: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Type", text(insp.inspectionType)),
				("Performing Shop", text(insp.performingShop)),
				(Vertical.current.assetSingular, vehicleName)
			]) { identity.append(g) }

			var last: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Date", functions.formatDate_DDMMMyy(date: insp.lastCompliedDate)),
				("Hours", insp.lastCompliedHours != 0 ? "\(insp.lastCompliedHours)" : nil)
			]) { last.append(g) }

			var next: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Date", functions.formatDate_DDMMMyy(date: insp.nextDueDate)),
				("Hours", insp.nextDueHours != 0 ? "\(insp.nextDueHours)" : nil),
				("Interval (Months)", insp.intervalMonths != 0 ? "\(insp.intervalMonths)" : nil),
				("Interval (Hours)", insp.intervalHours != 0 ? "\(insp.intervalHours)" : nil)
			]) { next.append(g) }

			return [.groups(identity), .groups(last), .groups(next)]
		}
		return PDFReportRenderer.render(
			title: "Inspection Cycles",
			subtitle: scopeSubtitle(count: inspections.count, noun: "inspection"),
			columns: columns, rows: rows,
			footerNote: Vertical.current.regulatoryDisclaimer,
			style: .standard
		)
	}

	// MARK: - Component Times

	private func fetchComponentTimes() -> [ComponentTimes] {
		let descriptor: FetchDescriptor<ComponentTimes>
		if FleetScope.isAll(scope) {
			descriptor = FetchDescriptor(sortBy: [SortDescriptor(\.vehicleId), SortDescriptor(\.componentName)])
		} else {
			let vehicleId = scope
			descriptor = FetchDescriptor(
				predicate: #Predicate<ComponentTimes> { $0.vehicleId == vehicleId },
				sortBy: [SortDescriptor(\.componentName)]
			)
		}
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	private func renderComponentTimes() -> Data? {
		let components = fetchComponentTimes()
		let columns: [PDFTableColumn] = [
			PDFTableColumn("COMPONENT", weight: 0.34),
			PDFTableColumn("TIMES", weight: 0.33),
			PDFTableColumn("NOTES", weight: 0.33)
		]
		let rows: [[PDFCell]] = components.map { comp in
			let vehicleName = comp.vehicleId.isEmpty ? nil : functions.getVehicleDisplayName(vehicleId: comp.vehicleId, context: modelContext)
			var identity: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Component", text(comp.componentName)),
				("Type", text(comp.componentType)),
				(Vertical.current.assetSingular, vehicleName)
			]) { identity.append(g) }

			var times: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Total Time", comp.totalTime != 0 ? "\(comp.totalTime)" : nil),
				("Time Since Overhaul", comp.timeSinceOverhaul != 0 ? "\(comp.timeSinceOverhaul)" : nil),
				("Last Overhaul Date", functions.formatDate_DDMMMyy(date: comp.lastOverhaulDate))
			]) { times.append(g) }

			var notesGroup: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [("Notes", text(comp.notes))]) { notesGroup.append(g) }

			return [.groups(identity), .groups(times), .groups(notesGroup)]
		}
		return PDFReportRenderer.render(
			title: "Component Times",
			subtitle: scopeSubtitle(count: components.count, noun: "component"),
			columns: columns, rows: rows,
			footerNote: Vertical.current.regulatoryDisclaimer,
			style: .standard
		)
	}
}
