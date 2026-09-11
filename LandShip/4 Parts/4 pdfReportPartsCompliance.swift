//
//  4 pdfReportPartsCompliance.swift
//  LandShip
//
//  A cross-platform SwiftUI view generating a combined compliance PDF for AeroTrax parts —
//  the "produce the life-limited parts status in one tap" report, which is exactly what a
//  buyer's pre-purchase inspection asks for. Mirrors pdfReportAviationLogbook.swift's
//  merged-sections approach: three record shapes (parts, PartInstallation, directives/
//  attachments) don't share a column schema, so each gets its own PDFReportRenderer.render
//  call and the resulting single-section PDFDocuments are merged page-by-page. AeroTrax only
//  (see Vertical.enabledFeatures.partCompliance).
//
//  Only parts that have been through the compliance workflow (approval basis, limit type,
//  part class, or condition code set) are included — this deliberately excludes mundane
//  consumables so the report doesn't drown the life-limited parts in oil filters.
//
//  Attachment rows are a manifest only (filename/kind/size/date) — payload bytes are never
//  embedded, or a 20-part report could balloon into hundreds of megabytes.
//

import PDFKit
import SwiftUI
import SwiftData
import Foundation

struct pdfReportPartsCompliance: View {
	@Environment(\.modelContext) var modelContext

	@State private var scope: String
	@State private var pdfDocument: PDFDocument?
	@State private var zoomAction: ZoomAction?
	@State private var csvDocument = CSVDocument(text: "")
	@State private var isExportingCSV = false

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
						PDFReportFile.printDocument(doc, jobName: "Parts Compliance")
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
		.fileExporter(isPresented: $isExportingCSV, document: csvDocument, contentType: .commaSeparatedText, defaultFilename: "Parts Compliance") { _ in }
	}

	// MARK: - Shared helpers (each report file keeps its own copy — see pdfReportAviationLogbook.swift)

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

	private func flagsSummary(_ flags: Set<PartTimeFlag>) -> String {
		var lines: [String] = []
		if flags.contains(.installSnapshotAheadOfMeter) { lines.append("Install meter ahead of current meter") }
		if flags.contains(.implausibleAccrual) { lines.append("Unusually high accrual — verify meter") }
		if flags.contains(.timeBaseMismatch) { lines.append("Limit time base differs from aircraft meter") }
		if flags.contains(.noCurrentMeterReading) { lines.append("No current aircraft meter reading") }
		if flags.contains(.noInstallSnapshot) { lines.append("No install meter reading recorded") }
		return lines.joined(separator: "; ")
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
			renderLifeAndLimits(),
			renderInstallationHistory(),
			renderDirectivesAndAttachments()
		])
	}

	private func generateAndShowPDF() {
		guard let pdfData = generateCombinedPDF() else { return }
		if let doc = PDFDocument(data: pdfData) {
			self.pdfDocument = doc
			PDFReportFile.save(data: pdfData, fileName: "Parts Compliance")
		}
	}

	/// Parts that have been through the compliance workflow at all — approval basis, limit
	/// type, part class, or condition code set. Excludes plain consumables so the report
	/// stays focused on the parts that actually carry compliance data.
	private func fetchComplianceParts() -> [MxParts1] {
		let descriptor: FetchDescriptor<MxParts1>
		if FleetScope.isAll(scope) {
			descriptor = FetchDescriptor(sortBy: [SortDescriptor(\.vehicleId), SortDescriptor(\.partName)])
		} else {
			let vehicleId = scope
			descriptor = FetchDescriptor(
				predicate: #Predicate<MxParts1> { $0.vehicleId == vehicleId },
				sortBy: [SortDescriptor(\.partName)]
			)
		}
		let all = (try? modelContext.fetch(descriptor)) ?? []
		return all.filter { !$0.approvalBasis.isEmpty || !$0.limitType.isEmpty || !$0.partClass.isEmpty || !$0.conditionCode.isEmpty }
	}

	private func fetchAttachments(forPart partName: String) -> [RecordAttachment] {
		let fd = FetchDescriptor<RecordAttachment>(
			predicate: #Predicate<RecordAttachment> { $0.ownerType == "MxParts1" && $0.ownerKey == partName },
			sortBy: [SortDescriptor(\RecordAttachment.documentDate, order: .reverse)]
		)
		return (try? modelContext.fetch(fd)) ?? []
	}

	// MARK: - Life & Limits

	private func renderLifeAndLimits() -> Data? {
		let parts = fetchComplianceParts()
		let snapshots = Functions().loadPartTimeSnapshots(context: modelContext, parts: parts)
		let columns: [PDFTableColumn] = [
			PDFTableColumn("PART", weight: 0.30),
			PDFTableColumn("TIME & LIMITS", weight: 0.40),
			PDFTableColumn("STATUS", weight: 0.30)
		]
		let rows: [[PDFCell]] = parts.map { part in
			let snapshot = snapshots[part.partName]
			var identity: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Part", text(part.partName)),
				("P/N", text(part.partNumber)),
				("S/N", text(part.serialNumber)),
				("Class", text(part.partClass)),
				("Approval Basis", text(part.approvalBasis))
			]) { identity.append(g) }

			var timeGroup: [PDFFieldGroup] = []
			if let snapshot, let g = fieldGroup(nil, [
				("TSN", "\(snapshot.tsn.formatted(.number.precision(.fractionLength(1)))) hrs"),
				("TSO", snapshot.tso != snapshot.tsn ? "\(snapshot.tso.formatted(.number.precision(.fractionLength(1)))) hrs" : nil),
				("TSR", snapshot.tsr != 0 ? "\(snapshot.tsr.formatted(.number.precision(.fractionLength(1)))) hrs" : nil)
			]) { timeGroup.append(g) }
			if let g = fieldGroup(nil, [
				("Limit Type", text(part.limitType)),
				("Limit Hours", part.limitHours != 0 ? "\(part.limitHours)" : nil),
				("Limit Cycles", part.limitCycles != 0 ? "\(part.limitCycles)" : nil)
			]) { timeGroup.append(g) }

			var statusGroup: [PDFFieldGroup] = []
			if let snapshot, let remaining = PartTimeMath.remaining(
				snapshot: snapshot, limitType: part.limitType, limitHours: part.limitHours,
				limitCycles: part.limitCycles, limitCalendarMonths: part.limitCalendarMonths,
				installDate: snapshot.installDate
			), let g = fieldGroup(nil, [
				("Remaining Hours", remaining.remainingHours.map { "\($0.formatted(.number.precision(.fractionLength(1))))" }),
				("Overdue", remaining.isOverdue ? "YES" : nil)
			]) { statusGroup.append(g) }
			if let snapshot, !snapshot.flags.isEmpty, let g = fieldGroup("Flags", [("Note", flagsSummary(snapshot.flags))]) {
				statusGroup.append(g)
			}
			if let g = fieldGroup(nil, [("Condition", text(part.conditionCode))]) { statusGroup.append(g) }

			return [.groups(identity), .groups(timeGroup), .groups(statusGroup)]
		}
		return PDFReportRenderer.render(
			title: "Parts Compliance — Time & Life",
			subtitle: scopeSubtitle(count: parts.count, noun: "part"),
			columns: columns, rows: rows,
			footerNote: Vertical.current.regulatoryDisclaimer,
			style: .standard
		)
	}

	// MARK: - Installation History

	private func fetchInstallationHistoryForReport() -> [PartInstallation] {
		let complianceParts = Set(fetchComplianceParts().map { $0.partName })
		guard !complianceParts.isEmpty else { return [] }
		let fd = FetchDescriptor<PartInstallation>(sortBy: [SortDescriptor(\PartInstallation.partName), SortDescriptor(\PartInstallation.installDate, order: .reverse)])
		let all = (try? modelContext.fetch(fd)) ?? []
		return all.filter { complianceParts.contains($0.partName) }
	}

	private func renderInstallationHistory() -> Data? {
		let installations = fetchInstallationHistoryForReport()
		let columns: [PDFTableColumn] = [
			PDFTableColumn("PART", weight: 0.34),
			PDFTableColumn("INSTALLED ON", weight: 0.33),
			PDFTableColumn("DATES", weight: 0.33)
		]
		let rows: [[PDFCell]] = installations.map { installation in
			let vehicleName = installation.vehicleId.isEmpty ? nil : functions.getVehicleDisplayName(vehicleId: installation.vehicleId, context: modelContext)
			var identity: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [("Part", text(installation.partName))]) { identity.append(g) }

			var installedOn: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				(Vertical.current.assetSingular, vehicleName),
				("Position", text(installation.position))
			]) { installedOn.append(g) }

			var dates: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Installed", functions.formatDate_DDMMMyy(date: installation.installDate)),
				("Removed", installation.removalDate.map { functions.formatDate_DDMMMyy(date: $0) }),
				("Removal Reason", text(installation.removalReason))
			]) { dates.append(g) }

			return [.groups(identity), .groups(installedOn), .groups(dates)]
		}
		return PDFReportRenderer.render(
			title: "Parts Compliance — Installation History",
			subtitle: scopeSubtitle(count: installations.count, noun: "installation"),
			columns: columns, rows: rows,
			footerNote: Vertical.current.regulatoryDisclaimer,
			style: .standard
		)
	}

	// MARK: - Directives & Attachments

	private func renderDirectivesAndAttachments() -> Data? {
		let parts = fetchComplianceParts()
		let columns: [PDFTableColumn] = [
			PDFTableColumn("PART", weight: 0.30),
			PDFTableColumn("DIRECTIVES & BULLETINS", weight: 0.40),
			PDFTableColumn("ATTACHMENTS", weight: 0.30)
		]
		let rows: [[PDFCell]] = parts.compactMap { part -> [PDFCell]? in
			let directives = Functions().loadDirectives(context: modelContext, forPartNumber: part.partNumber)
			let attachments = fetchAttachments(forPart: part.partName)
			guard !directives.isEmpty || !attachments.isEmpty else { return nil }

			var identity: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [("Part", text(part.partName)), ("P/N", text(part.partNumber))]) { identity.append(g) }

			var directiveGroups: [PDFFieldGroup] = []
			for directive in directives {
				if let g = fieldGroup(nil, [
					("Number", text(directive.adNumber)),
					("Title", text(directive.title)),
					("Next Due", functions.formatDate_DDMMMyy(date: directive.nextDueDate))
				]) { directiveGroups.append(g) }
			}

			var attachmentGroups: [PDFFieldGroup] = []
			for attachment in attachments {
				if let g = fieldGroup(nil, [
					("File", text(attachment.fileName)),
					("Kind", text(attachment.attachmentKind)),
					("Date", functions.formatDate_DDMMMyy(date: attachment.documentDate))
				]) { attachmentGroups.append(g) }
			}

			return [.groups(identity), .groups(directiveGroups), .groups(attachmentGroups)]
		}
		return PDFReportRenderer.render(
			title: "Parts Compliance — Directives & Attachments",
			subtitle: scopeSubtitle(count: rows.count, noun: "part"),
			columns: columns, rows: rows,
			footerNote: Vertical.current.regulatoryDisclaimer,
			style: .standard
		)
	}

	// MARK: - CSV Export

	private func generateCSV() -> String {
		let parts = fetchComplianceParts()
		let snapshots = Functions().loadPartTimeSnapshots(context: modelContext, parts: parts)
		let installations = fetchInstallationHistoryForReport()

		let lifeHeaders = [
			"Part Name", "Part Number", "Serial Number", "Part Class", "Approval Basis", "Condition Code",
			"Limit Type", "Limit Hours", "Limit Cycles", "TSN", "CSN", "TSO", "CSO", "TSR",
			"Remaining Hours", "Overdue", "Flags"
		]
		let lifeRows: [[String]] = parts.map { part in
			let snapshot = snapshots[part.partName]
			let remaining = snapshot.flatMap {
				PartTimeMath.remaining(
					snapshot: $0, limitType: part.limitType, limitHours: part.limitHours,
					limitCycles: part.limitCycles, limitCalendarMonths: part.limitCalendarMonths,
					installDate: $0.installDate
				)
			}
			return [
				part.partName, part.partNumber, part.serialNumber, part.partClass, part.approvalBasis, part.conditionCode,
				part.limitType, CSVField.float(part.limitHours), CSVField.int(part.limitCycles),
				snapshot.map { CSVField.float($0.tsn) } ?? "", snapshot.map { CSVField.int($0.csn) } ?? "",
				snapshot.map { CSVField.float($0.tso) } ?? "", snapshot.map { CSVField.int($0.cso) } ?? "",
				snapshot.map { CSVField.float($0.tsr) } ?? "",
				remaining?.remainingHours.map { CSVField.float($0) } ?? "",
				remaining.map { CSVField.bool($0.isOverdue) } ?? "",
				snapshot.map { flagsSummary($0.flags) } ?? ""
			]
		}

		let installHeaders = ["Part Name", Vertical.current.assetSingular, "Position", "Install Date", "Removal Date", "Removal Reason"]
		let installRows: [[String]] = installations.map { installation in
			let vehicleName = installation.vehicleId.isEmpty ? "" : functions.getVehicleDisplayName(vehicleId: installation.vehicleId, context: modelContext)
			return [
				installation.partName, vehicleName.isEmpty ? installation.vehicleId : vehicleName, installation.position,
				CSVField.date(installation.installDate), installation.removalDate.map(CSVField.date) ?? "", installation.removalReason
			]
		}

		var directiveRows: [[String]] = []
		var attachmentRows: [[String]] = []
		for part in parts {
			for directive in Functions().loadDirectives(context: modelContext, forPartNumber: part.partNumber) {
				directiveRows.append([part.partName, part.partNumber, directive.adNumber, directive.title, CSVField.date(directive.nextDueDate)])
			}
			for attachment in fetchAttachments(forPart: part.partName) {
				attachmentRows.append([part.partName, attachment.fileName, attachment.attachmentKind, CSVField.date(attachment.documentDate)])
			}
		}
		let directiveHeaders = ["Part Name", "Part Number", "AD/Bulletin Number", "Title", "Next Due"]
		let attachmentHeaders = ["Part Name", "File Name", "Kind", "Document Date"]

		var output = "LIFE & LIMITS\r\n" + CSVBuilder.build(headers: lifeHeaders, rows: lifeRows)
		output += "\r\nINSTALLATION HISTORY\r\n" + CSVBuilder.build(headers: installHeaders, rows: installRows)
		output += "\r\nDIRECTIVES & BULLETINS\r\n" + CSVBuilder.build(headers: directiveHeaders, rows: directiveRows)
		output += "\r\nATTACHMENTS\r\n" + CSVBuilder.build(headers: attachmentHeaders, rows: attachmentRows)
		return output
	}
}
