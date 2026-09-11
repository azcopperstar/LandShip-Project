//
//  4 pdfReportFuelProgram.swift
//  LandShip
//
//  The "does the fuel program actually save money" report — price trend by airport,
//  contract fuel savings, all-in cost, and fee-waiver misses. AeroTrax only (Vertical
//  .enabledFeatures.fuelOperations); mirrors pdfReportPartsCompliance.swift's merged-
//  sections approach, since price-trend rows and fee-waiver rows don't share a column
//  schema.
//
//  Cost-per-distance reuses FuelMath's full-to-full interval stats (the same numbers
//  EditFuelLog and pdfReportFuel show). Cost per flight *hour* is left out of this pass —
//  FuelLog1 tracks a cumulative engine-hours meter reading, not hours flown per leg, and
//  deriving that reliably needs the same anchor logic FuelMath.interval already applies
//  to distance; extending it to a second meter is a follow-on, not squeezed in here.
//

import PDFKit
import SwiftUI
import SwiftData
import Foundation

struct pdfReportFuelProgram: View {
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
						PDFReportFile.printDocument(doc, jobName: "Fuel Program")
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
		.fileExporter(isPresented: $isExportingCSV, document: csvDocument, contentType: .commaSeparatedText, defaultFilename: "Fuel Program") { _ in }
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
			renderPriceAndContractTrend(),
			renderFeeWaivers()
		])
	}

	private func generateAndShowPDF() {
		guard let pdfData = generateCombinedPDF() else { return }
		if let doc = PDFDocument(data: pdfData) {
			self.pdfDocument = doc
			PDFReportFile.save(data: pdfData, fileName: "Fuel Program")
		}
	}

	/// Every fuel log in scope with at least one fuel-program field set — a plain
	/// piston-GA fill-up with no ticket/contract/waiver data has nothing to report here.
	private func fetchProgramLogs() -> [FuelLog1] {
		let descriptor: FetchDescriptor<FuelLog1>
		if FleetScope.isAll(scope) {
			descriptor = FetchDescriptor(sortBy: [SortDescriptor(\FuelLog1.airportIdentifier), SortDescriptor(\FuelLog1.fuelDateTime)])
		} else {
			let vehicleId = scope
			descriptor = FetchDescriptor(
				predicate: #Predicate<FuelLog1> { $0.vehicleId == vehicleId },
				sortBy: [SortDescriptor(\FuelLog1.airportIdentifier), SortDescriptor(\FuelLog1.fuelDateTime)]
			)
		}
		let all = (try? modelContext.fetch(descriptor)) ?? []
		return all.filter {
			!$0.ticketNumber.isEmpty || $0.postedPricePerUnit != 0 || $0.contractPricePerUnit != 0
				|| $0.feeWaiverThresholdQuantity != 0
		}
	}

	// MARK: - Price & Contract Trend

	private func renderPriceAndContractTrend() -> Data? {
		let logs = fetchProgramLogs()
		let intervalStats = functions.loadFuelIntervalStatsBatch(context: modelContext, logs: logs)
		let columns: [PDFTableColumn] = [
			PDFTableColumn("AIRPORT &\nDATE", weight: 0.30),
			PDFTableColumn("PRICE &\nCONTRACT", weight: 0.40),
			PDFTableColumn("SAVINGS &\nCOST TREND", weight: 0.30)
		]
		let rows: [[PDFCell]] = logs.map { log in
			let vehicleName = log.vehicleId.isEmpty ? nil : functions.getVehicleDisplayName(vehicleId: log.vehicleId, context: modelContext)
			var identity: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Airport", text(log.airportIdentifier)),
				(Vertical.current.assetSingular, vehicleName),
				("Date", functions.formatDate_DDMMMyy(date: log.fuelDateTime)),
				("Ticket", text(log.ticketNumber))
			]) { identity.append(g) }

			var price: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Posted Price", log.postedPricePerUnit != 0 ? functions.formatCurrency(dollars: log.postedPricePerUnit) : nil),
				("Contract Price", log.contractPricePerUnit != 0 ? functions.formatCurrency(dollars: log.contractPricePerUnit) : nil),
				("Contract Release", text(log.contractReleaseNumber))
			]) { price.append(g) }

			var savings: [PDFFieldGroup] = []
			let breakdown = FuelMath.costBreakdown(log)
			if let g = fieldGroup(nil, [
				("Contract Savings", breakdown.contractSavings != 0 ? functions.formatCurrency(dollars: breakdown.contractSavings) : nil),
				("All-In Cost", breakdown.allInCost != 0 ? functions.formatCurrency(dollars: breakdown.allInCost) : nil)
			]) { savings.append(g) }
			let stats = intervalStats[log.persistentModelID]
			if let stats, stats.costPerDistance != 0, let g = fieldGroup(nil, [
				("Cost / Distance", functions.formatCurrency(dollars: stats.costPerDistance))
			]) { savings.append(g) }

			return [.groups(identity), .groups(price), .groups(savings)]
		}
		return PDFReportRenderer.render(
			title: "Fuel Program — Price & Contract Trend",
			subtitle: scopeSubtitle(count: logs.count, noun: "entry"),
			columns: columns, rows: rows,
			footerNote: Vertical.current.regulatoryDisclaimer,
			style: .standard
		)
	}

	// MARK: - Fee Waivers

	private func renderFeeWaivers() -> Data? {
		let logs = fetchProgramLogs().filter { $0.feeWaiverThresholdQuantity != 0 }
		let columns: [PDFTableColumn] = [
			PDFTableColumn("AIRPORT &\nDATE", weight: 0.34),
			PDFTableColumn("WAIVER", weight: 0.33),
			PDFTableColumn("FEES PAID", weight: 0.33)
		]
		let rows: [[PDFCell]] = logs.map { log in
			let vehicleName = log.vehicleId.isEmpty ? nil : functions.getVehicleDisplayName(vehicleId: log.vehicleId, context: modelContext)
			var identity: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Airport", text(log.airportIdentifier)),
				(Vertical.current.assetSingular, vehicleName),
				("Date", functions.formatDate_DDMMMyy(date: log.fuelDateTime))
			]) { identity.append(g) }

			var waiver: [PDFFieldGroup] = []
			if let g = fieldGroup(nil, [
				("Threshold", "\(log.feeWaiverThresholdQuantity.formatted(.number.precision(.fractionLength(0))))"),
				("Uplifted", log.upliftQuantity != 0 ? "\(log.upliftQuantity.formatted(.number.precision(.fractionLength(0))))" : nil),
				("Status", log.feeWaiverAchieved ? "Achieved" : "Missed"),
				("Notes", text(log.feeWaiverNotes))
			]) { waiver.append(g) }

			var feesPaid: [PDFFieldGroup] = []
			let breakdown = FuelMath.costBreakdown(log)
			if !log.feeWaiverAchieved, breakdown.totalFees != 0, let g = fieldGroup(nil, [
				("Total Fees", functions.formatCurrency(dollars: breakdown.totalFees))
			]) { feesPaid.append(g) }

			return [.groups(identity), .groups(waiver), .groups(feesPaid)]
		}
		return PDFReportRenderer.render(
			title: "Fuel Program — Fee Waivers",
			subtitle: scopeSubtitle(count: rows.count, noun: "entry"),
			columns: columns, rows: rows,
			footerNote: Vertical.current.regulatoryDisclaimer,
			style: .standard
		)
	}

	// MARK: - CSV Export

	private func generateCSV() -> String {
		let logs = fetchProgramLogs()
		let intervalStats = functions.loadFuelIntervalStatsBatch(context: modelContext, logs: logs)

		let priceHeaders = [
			"Airport", Vertical.current.assetSingular, "Date", "Ticket",
			"Posted Price", "Contract Price", "Contract Release",
			"Contract Savings", "All-In Cost", "Cost / Distance"
		]
		let priceRows: [[String]] = logs.map { log in
			let vehicleName = log.vehicleId.isEmpty ? "" : functions.getVehicleDisplayName(vehicleId: log.vehicleId, context: modelContext)
			let breakdown = FuelMath.costBreakdown(log)
			let stats = intervalStats[log.persistentModelID]
			return [
				log.airportIdentifier, vehicleName, CSVField.date(log.fuelDateTime), log.ticketNumber,
				CSVField.float(log.postedPricePerUnit), CSVField.float(log.contractPricePerUnit), log.contractReleaseNumber,
				CSVField.float(breakdown.contractSavings), CSVField.float(breakdown.allInCost),
				stats.map { CSVField.float($0.costPerDistance) } ?? ""
			]
		}

		let waiverLogs = logs.filter { $0.feeWaiverThresholdQuantity != 0 }
		let waiverHeaders = [
			"Airport", Vertical.current.assetSingular, "Date", "Threshold", "Uplifted", "Achieved", "Notes", "Total Fees"
		]
		let waiverRows: [[String]] = waiverLogs.map { log in
			let vehicleName = log.vehicleId.isEmpty ? "" : functions.getVehicleDisplayName(vehicleId: log.vehicleId, context: modelContext)
			let breakdown = FuelMath.costBreakdown(log)
			return [
				log.airportIdentifier, vehicleName, CSVField.date(log.fuelDateTime),
				CSVField.float(log.feeWaiverThresholdQuantity), CSVField.float(log.upliftQuantity),
				CSVField.bool(log.feeWaiverAchieved), log.feeWaiverNotes, CSVField.float(breakdown.totalFees)
			]
		}

		var output = "PRICE & CONTRACT TREND\r\n" + CSVBuilder.build(headers: priceHeaders, rows: priceRows)
		output += "\r\nFEE WAIVERS\r\n" + CSVBuilder.build(headers: waiverHeaders, rows: waiverRows)
		return output
	}
}

// MARK: - Preview

private struct FuelProgramReportPreviewHost: View {
	let container: ModelContainer

	init() {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try! ModelContainer(for: FuelLog1.self, Vehicle8.self, configurations: config)
		let context = container.mainContext

		let vehicle = Vehicle8(name: "N12345", manufacturer: "Cessna", model: "Citation")
		context.insert(vehicle)

		let sample = FuelLog1(
			vehicleId: "N12345", logName: "KTEB Fill", fuelDateTime: Date(), odometer: 0,
			fuelAdded: 800, fuelPrice: 6.10, fuelCost: 4880, fuelType: "Jet A"
		)
		sample.airportIdentifier = "KTEB"
		sample.ticketNumber = "T-10245"
		sample.postedPricePerUnit = 6.10
		sample.contractPricePerUnit = 5.35
		sample.contractReleaseNumber = "REL-9981"
		sample.feeWaiverThresholdQuantity = 200
		sample.feeWaiverAchieved = false
		sample.feeRamp = 450
		sample.upliftQuantity = 180
		sample.upliftUnitRaw = FuelQuantityUnit.usGallon.rawValue
		context.insert(sample)
		try? context.save()

		self.container = container
	}

	var body: some View {
		pdfReportFuelProgram(trackVehicleSelected: "N12345")
			.modelContainer(container)
	}
}

#Preview {
	FuelProgramReportPreviewHost()
}
