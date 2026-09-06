/*
 File: pdfReportTrip.swift
 Module: LandShip

 Summary
 -------
 A cross-platform SwiftUI view that generates and displays a PDF report of trip log entries
 (TripLog2). Built on the shared PDFReportRenderer engine (PDFReportStyle.swift): four category
 columns carry nearly every TripLog2 field, grouped and stacked so the report fits a portrait
 US-Letter page. The view owns its own vehicle scope via the shared VehicleScopePicker and can
 switch between "All Vehicles" and a specific vehicle without leaving the report.

 Key Features
 ------------
 - Shared in-report vehicle picker (VehicleScopePicker) that re-fetches and regenerates on change
 - Enroute stops (up to 6) are summarized as one line each instead of expanding every sub-field —
   otherwise a single row could sprawl across a dozen fields per stop
 - Empty/zero fields are dropped before layout so sparse trips produce short rows
 - Built-in print support and zoom controls via the shared PDFKitView/PDFReportFile helpers

 Excluded on purpose
 --------------------
 No cost summary footer: TripLog2 has no stored cost field. Trip fuel cost only exists by joining
 each stop's linked FuelLog1 record (via fuelAdded#Log) to its fuelPrice — since every one of
 those purchases is already counted in the Fuel Log report's own cost summary, adding it here
 would double-count. "Vehicle Totals"/"Group Totals" in EditTripLog are likewise computed live
 across sibling records, not stored per-row, and are left out of this pass.

 Data Flow
 ---------
 - `scope` (@State) selects "All Vehicles" or a specific vehicle by name; the picker mutates it.
 - `generatePDFWithTable()` fetches trips via FetchDescriptor (not @Query, since scope can change
   after the view appears), builds one PDFCell row per trip, and hands them to
   `PDFReportRenderer.render(...)`.
 - The resulting Data is wrapped in PDFDocument and assigned to state (`pdfDocument`) for display,
   and saved to the app's Documents folder via `PDFReportFile.save(data:fileName:)`.

 Dependencies
 ------------
 - Frameworks: PDFKit, SwiftUI, SwiftData, Foundation
 - Models: TripLog2
 - Shared: PDFReportStyle.swift (PDFReportRenderer, PDFKitView, ZoomAction, PDFReportFile, VehicleScopePicker)
 - Utilities: Functions (date formatting, vehicle display name lookup)
*/

import PDFKit
import SwiftUI
import SwiftData
import Foundation

/// A SwiftUI view that builds and displays a PDF report of trip log entries.
/// - Parameter trackVehicleSelected: The initial scope — "All Vehicles" (or empty) for every
///   vehicle, or a specific `Vehicle8.name` to report on just that vehicle's trips. The report
///   owns this value afterward via its in-report vehicle picker.
struct pdfReportTrip: View {
	@Environment(\.modelContext) var modelContext

	@State private var scope: String
	@State private var pdfDocument: PDFDocument?
	@State private var zoomAction: ZoomAction?
	@State private var csvDocument = CSVDocument(text: "")
	@State private var isExportingCSV = false

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
						PDFReportFile.printDocument(doc, jobName: "Trip Log")
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
		.fileExporter(isPresented: $isExportingCSV, document: csvDocument, contentType: .commaSeparatedText, defaultFilename: "Trip Log") { _ in }
	}

	// MARK: - CSV Export

	private func generateCSV() -> String {
		let trips = fetchTrips()

		let stopCount = 6
		var headers = [
			"Inactive", Vertical.current.assetSingular, "\(Vertical.current.assetSingular) Display Name", "Log Name", "Notes",
			"Created At", "Updated At", "Trip Start", "Trip End",
			"\(Vertical.current.primaryMeterLabel) Start", "\(Vertical.current.primaryMeterLabel) End",
			"Engine Hours Start", "Engine Hours End",
			"Fuel Qty Start", "Fuel Qty End", "Fuel Consumed",
			"Fuel Level Start", "Fuel Level End", "Fuel Level Start Fraction", "Fuel Level End Fraction",
			"DEF Level Start", "DEF Level Start Fraction", "DEF Level End", "DEF Level End Fraction",
			"DEF Qty Start", "DEF Qty End",
			"Location Start", "Location End",
			"Towed \(Vertical.current.assetSingular)", "Towed \(Vertical.current.assetSingular) ID", "Trip Group",
			"Image 1 Description", "Image 2 Description", "Image 3 Description"
		]
		for i in 1...stopCount {
			headers.append(contentsOf: [
				"Stop \(i) Fuel Added Log", "Stop \(i) Fuel Added", "Stop \(i) Entry Time", "Stop \(i) Exit Time",
				"Stop \(i) Reason", "Stop \(i) Comment", "Stop \(i) Location"
			])
		}

		let rows: [[String]] = trips.map { trip in
			let vehicleName = trip.vehicleId.isEmpty ? "" : functions.getVehicleDisplayName(vehicleId: trip.vehicleId, context: modelContext)
			let towedName = trip.vehicleIdTowed.isEmpty ? "" : functions.getVehicleDisplayName(vehicleId: trip.vehicleIdTowed, context: modelContext)
			var row = [
				CSVField.bool(trip.inactive), trip.vehicleId, vehicleName, trip.logName, trip.tripNotes,
				CSVField.date(trip.createdAt), CSVField.date(trip.updatedAt), CSVField.date(trip.tripDateTimeStart), CSVField.date(trip.tripDateTimeEnd),
				CSVField.int(trip.odometerStart), CSVField.int(trip.odometerEnd),
				CSVField.float(trip.engHoursStart), CSVField.float(trip.engHoursEnd),
				CSVField.float(trip.fuelQuantityStart), CSVField.float(trip.fuelQuantityEnd), CSVField.float(trip.fuelConsumed),
				CSVField.float(trip.fuelLevelStart1), CSVField.float(trip.fuelLevelEnd1), trip.fuelLevelStart, trip.fuelLevelEnd,
				CSVField.float(trip.defLevel1), trip.defLevelFraction, CSVField.float(trip.defLevelEnd1), trip.defLevelEndFraction,
				CSVField.float(trip.defQuantityStart), CSVField.float(trip.defQuantityEnd),
				trip.locationStart, trip.locationEnd,
				CSVField.bool(trip.vehicleTowed), towedName.isEmpty ? trip.vehicleIdTowed : towedName, trip.tripGroup,
				trip.image1Description, trip.image2Description, trip.image3Description
			]
			let stops: [(log: String, added: Float, entry: Date?, exit: Date?, reason: String, comment: String, location: String)] = [
				(trip.fuelAdded1Log, trip.fuelAdded1, trip.fuelDateTime1, trip.fuelExitTime1, trip.stopReason1, trip.stopComment1, trip.fuelLocation1),
				(trip.fuelAdded2Log, trip.fuelAdded2, trip.fuelDateTime2, trip.fuelExitTime2, trip.stopReason2, trip.stopComment2, trip.fuelLocation2),
				(trip.fuelAdded3Log, trip.fuelAdded3, trip.fuelDateTime3, trip.fuelExitTime3, trip.stopReason3, trip.stopComment3, trip.fuelLocation3),
				(trip.fuelAdded4Log, trip.fuelAdded4, trip.fuelDateTime4, trip.fuelExitTime4, trip.stopReason4, trip.stopComment4, trip.fuelLocation4),
				(trip.fuelAdded5Log, trip.fuelAdded5, trip.fuelDateTime5, trip.fuelExitTime5, trip.stopReason5, trip.stopComment5, trip.fuelLocation5),
				(trip.fuelAdded6Log, trip.fuelAdded6, trip.fuelDateTime6, trip.fuelExitTime6, trip.stopReason6, trip.stopComment6, trip.fuelLocation6)
			]
			for stop in stops {
				row.append(contentsOf: [
					stop.log, CSVField.float(stop.added), stop.entry.map(CSVField.date) ?? "", stop.exit.map(CSVField.date) ?? "",
					stop.reason, stop.comment, stop.location
				])
			}
			return row
		}

		return CSVBuilder.build(headers: headers, rows: rows)
	}

	// MARK: - Generation

	private func generateAndShowPDF() {
		guard let pdfData = generatePDFWithTable() else { return }
		if let doc = PDFDocument(data: pdfData) {
			self.pdfDocument = doc
			PDFReportFile.save(data: pdfData, fileName: "Trip Log")
		}
	}

	private func fetchTrips() -> [TripLog2] {
		let descriptor: FetchDescriptor<TripLog2>
		if scope == "All Vehicles" || scope.isEmpty {
			descriptor = FetchDescriptor<TripLog2>(sortBy: [
				SortDescriptor(\.vehicleId, order: .forward),
				SortDescriptor(\.tripDateTimeStart, order: .reverse)
			])
		} else {
			let vehicleId = scope
			descriptor = FetchDescriptor<TripLog2>(
				predicate: #Predicate<TripLog2> { $0.vehicleId == vehicleId },
				sortBy: [SortDescriptor(\.tripDateTimeStart, order: .reverse)]
			)
		}
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	/// Builds the full multipage PDF for the current `scope`. Returns raw PDF data suitable
	/// for wrapping in a PDFDocument and/or saving to disk.
	func generatePDFWithTable() -> Data? {
		let trips = fetchTrips()

		let columns: [PDFTableColumn] = [
			PDFTableColumn("TRIP", weight: 0.20),
			PDFTableColumn("TRAVEL\nSUMMARY", weight: 0.30),
			PDFTableColumn("ENROUTE\nSTOPS", weight: 0.26),
			PDFTableColumn("CHECKS &\nNOTES", weight: 0.24)
		]

		let rows: [[PDFCell]] = trips.map { trip in
			[
				tripCell(trip),
				travelSummaryCell(trip),
				enrouteStopsCell(trip),
				checksAndNotesCell(trip)
			]
		}

		let scopeTitle = FleetScope.isAll(scope) ? FleetScope.allDisplayLabel : functions.getVehicleDisplayName(vehicleId: scope, context: modelContext)
		let tripWord = trips.count == 1 ? "trip" : "trips"
		let subtitle = "\(scopeTitle) • \(functions.formatDate_DDMMMyy(date: Date())) • \(trips.count) \(tripWord)"

		let summary = tripSummary(trips)
		return PDFReportRenderer.render(title: "Trip Log Report", subtitle: subtitle, columns: columns, rows: rows, summary: summary, style: .standard)
	}

	/// Trip Log has no cost field of its own, so this breaks down distance/duration/fuel instead.
	private func tripSummary(_ trips: [TripLog2]) -> PDFReportSummary {
		let groups = pdfVehicleScopedSummaryGroups(scope: scope, records: trips, vehicleId: \.vehicleId, context: modelContext) { subset in
			let totalDistance = subset.reduce(0) { total, trip in
				total + (trip.odometerEnd > trip.odometerStart ? trip.odometerEnd - trip.odometerStart : 0)
			}
			let totalSeconds = subset.reduce(0.0) { total, trip in
				let seconds = trip.tripDateTimeEnd.timeIntervalSince(trip.tripDateTimeStart)
				return total + max(0, seconds)
			}
			let totalHours = Int(totalSeconds) / 3600
			let totalMinutes = (Int(totalSeconds) % 3600) / 60
			let totalFuelConsumed = subset.reduce(Float(0)) { $0 + $1.fuelConsumed }

			return [
				("Total Trips", subset.isEmpty ? nil : "\(subset.count)"),
				("Total Distance", totalDistance != 0 ? NumberFormatter.localizedString(from: NSNumber(value: totalDistance), number: .decimal) : nil),
				("Total Duration", totalSeconds != 0 ? "\(totalHours)h \(totalMinutes)m" : nil),
				("Total Fuel Consumed", totalFuelConsumed != 0 ? String(format: "%.1f", totalFuelConsumed) : nil)
			]
		}
		return PDFReportSummary(title: "TRIP LOG SUMMARY", groups: groups)
	}

	// MARK: - Field-group builders
	//
	// Each cell drops empty strings and zero-valued numbers before handing fields to the
	// renderer, mirroring EditTripLog's own gating so sparse trips produce short rows instead of
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

	private func tripCell(_ trip: TripLog2) -> PDFCell {
		let vehicleName = trip.vehicleId.isEmpty ? nil : functions.getVehicleDisplayName(vehicleId: trip.vehicleId, context: modelContext)
		let towedName = trip.vehicleTowed && !trip.vehicleIdTowed.isEmpty ? functions.getVehicleDisplayName(vehicleId: trip.vehicleIdTowed, context: modelContext) : nil

		var groups: [PDFFieldGroup] = []
		if let identity = fieldGroup(nil, [
			(Vertical.current.assetSingular, vehicleName),
			("Log Name", text(trip.logName)),
			("Trip Group", text(trip.tripGroup)),
			("Towed \(Vertical.current.assetSingular)", towedName)
		]) {
			groups.append(identity)
		}

		return .imageWithGroups(trip.image1, caption: trip.image1Description, groups: groups)
	}

	private func travelSummaryCell(_ trip: TripLog2) -> PDFCell {
		var groups: [PDFFieldGroup] = []

		let distance = trip.odometerEnd > trip.odometerStart ? trip.odometerEnd - trip.odometerStart : 0
		let duration: String? = {
			let seconds = trip.tripDateTimeEnd.timeIntervalSince(trip.tripDateTimeStart)
			guard seconds > 0 else { return nil }
			let hours = Int(seconds) / 3600
			let minutes = (Int(seconds) % 3600) / 60
			return "\(hours)h \(minutes)m"
		}()

		if let summary = fieldGroup(nil, [
			("Distance", distance != 0 ? "\(NumberFormatter.localizedString(from: NSNumber(value: distance), number: .decimal))" : nil),
			("Duration", duration),
			("Fuel Consumed", trip.fuelConsumed != 0 ? String(format: "%.1f", trip.fuelConsumed) : nil)
		]) {
			groups.append(summary)
		}

		if let start = fieldGroup("Start", [
			("Date/Time", functions.formatDate_DDMMMyy_HHmm(date: trip.tripDateTimeStart)),
			(Vertical.current.primaryMeterLabel, trip.odometerStart != 0 ? NumberFormatter.localizedString(from: NSNumber(value: trip.odometerStart), number: .decimal) : nil),
			("Engine Hours", trip.engHoursStart != 0 ? String(format: "%.1f hrs", trip.engHoursStart) : nil),
			("Location", text(trip.locationStart)),
			("Fuel Level", text(trip.fuelLevelStart)),
			("DEF Level", text(trip.defLevelFraction))
		]) {
			groups.append(start)
		}

		if let end = fieldGroup("End", [
			("Date/Time", trip.tripDateTimeEnd > trip.tripDateTimeStart ? functions.formatDate_DDMMMyy_HHmm(date: trip.tripDateTimeEnd) : nil),
			(Vertical.current.primaryMeterLabel, trip.odometerEnd != 0 ? NumberFormatter.localizedString(from: NSNumber(value: trip.odometerEnd), number: .decimal) : nil),
			("Engine Hours", trip.engHoursEnd != 0 ? String(format: "%.1f hrs", trip.engHoursEnd) : nil),
			("Location", text(trip.locationEnd)),
			("Fuel Level", text(trip.fuelLevelEnd)),
			("DEF Level", text(trip.defLevelEndFraction))
		]) {
			groups.append(end)
		}

		return .groups(groups)
	}

	/// One compact line per active stop instead of expanding every sub-field (reason, location,
	/// fuel added, entry time) into its own row — otherwise a single trip could sprawl across
	/// dozens of fields.
	private func stopLine(reason: String, location: String, fuelAdded: Float, dateTime: Date?) -> String? {
		let r = reason.trimmingCharacters(in: .whitespacesAndNewlines)
		let l = location.trimmingCharacters(in: .whitespacesAndNewlines)
		guard fuelAdded != 0 || !r.isEmpty || !l.isEmpty else { return nil }
		var parts: [String] = []
		if !r.isEmpty { parts.append(r) }
		if !l.isEmpty { parts.append(l) }
		if fuelAdded != 0 { parts.append("\(String(format: "%.1f", fuelAdded)) gal") }
		if let dateTime { parts.append(functions.formatDate_DDMMM(date: dateTime)) }
		return parts.joined(separator: " • ")
	}

	private func enrouteStopsCell(_ trip: TripLog2) -> PDFCell {
		let totalFuelAdded = trip.fuelAdded1 + trip.fuelAdded2 + trip.fuelAdded3 + trip.fuelAdded4 + trip.fuelAdded5 + trip.fuelAdded6

		var groups: [PDFFieldGroup] = []
		if let stops = fieldGroup(nil, [
			("Stop 1", stopLine(reason: trip.stopReason1, location: trip.fuelLocation1, fuelAdded: trip.fuelAdded1, dateTime: trip.fuelDateTime1)),
			("Stop 2", stopLine(reason: trip.stopReason2, location: trip.fuelLocation2, fuelAdded: trip.fuelAdded2, dateTime: trip.fuelDateTime2)),
			("Stop 3", stopLine(reason: trip.stopReason3, location: trip.fuelLocation3, fuelAdded: trip.fuelAdded3, dateTime: trip.fuelDateTime3)),
			("Stop 4", stopLine(reason: trip.stopReason4, location: trip.fuelLocation4, fuelAdded: trip.fuelAdded4, dateTime: trip.fuelDateTime4)),
			("Stop 5", stopLine(reason: trip.stopReason5, location: trip.fuelLocation5, fuelAdded: trip.fuelAdded5, dateTime: trip.fuelDateTime5)),
			("Stop 6", stopLine(reason: trip.stopReason6, location: trip.fuelLocation6, fuelAdded: trip.fuelAdded6, dateTime: trip.fuelDateTime6)),
			("Total Fuel Added", totalFuelAdded != 0 ? "\(String(format: "%.1f", totalFuelAdded)) gal" : nil)
		]) {
			groups.append(stops)
		}

		return .groups(groups)
	}

	private func checksAndNotesCell(_ trip: TripLog2) -> PDFCell {
		var groups: [PDFFieldGroup] = []

		let startChecked: [(String, Bool)] = [
			("Engine Oil", trip.startOilChecked),
			("Engine Coolant", trip.startEngineCoolantChecked),
			("Secondary Coolant", trip.startSecondaryCoolantChecked),
			("Power Steering", trip.startPowerSteeringChecked),
			("Brake", trip.startBrakeFluidChecked),
			("Transmission", trip.startTransmissionFluidChecked),
			("Rear Axle", trip.startRearAxleChecked),
			("Front Axle", trip.startFrontAxleChecked),
			("Fuel/Water Separator", trip.startFuelWaterSeparatorChecked),
			("Air System Water Bleed", trip.startAirSystemWaterBleedChecked)
		]
		let startNames = startChecked.filter(\.1).map(\.0)
		if let checks = fieldGroup("Start Checks", [("Checked", startNames.isEmpty ? nil : startNames.joined(separator: ", "))]) {
			groups.append(checks)
		}

		let endChecked: [(String, Bool)] = [
			("Engine Oil", trip.endOilChecked),
			("Engine Coolant", trip.endEngineCoolantChecked),
			("Secondary Coolant", trip.endSecondaryCoolantChecked),
			("Power Steering", trip.endPowerSteeringChecked),
			("Brake", trip.endBrakeFluidChecked),
			("Transmission", trip.endTransmissionFluidChecked),
			("Rear Axle", trip.endRearAxleChecked),
			("Front Axle", trip.endFrontAxleChecked),
			("Fuel/Water Separator", trip.endFuelWaterSeparatorChecked),
			("Air System Water Bleed", trip.endAirSystemWaterBleedChecked)
		]
		let endNames = endChecked.filter(\.1).map(\.0)
		if let checks = fieldGroup("End Checks", [("Checked", endNames.isEmpty ? nil : endNames.joined(separator: ", "))]) {
			groups.append(checks)
		}

		if let notes = fieldGroup(nil, [("Notes", text(trip.tripNotes))]) {
			groups.append(notes)
		}

		return .groups(groups)
	}
}

// MARK: - Previews
/// A small preview host that seeds an in-memory SwiftData container and presents two previews:
/// one for all vehicles and one for a specific vehicle.
private struct TripReportPreviewHost: View {
	let container: ModelContainer

	init() {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try! ModelContainer(for: TripLog2.self, Vehicle8.self, configurations: config)

		let context = container.mainContext

		let vehicle = Vehicle8(name: "Vehicle A", manufacturer: "Acme", model: "Hauler")
		context.insert(vehicle)

		let samples: [TripLog2] = [
			TripLog2(vehicleId: "Vehicle A", logName: "Weekend haul", tripNotes: "Smooth trip, no issues.", tripDateTimeStart: Date().addingTimeInterval(-7200), tripDateTimeEnd: Date(), odometerStart: 41800, odometerEnd: 42150, engHoursStart: 800.0, engHoursEnd: 812.3, fuelConsumed: 42.5),
			TripLog2(vehicleId: "Vehicle A", logName: "", tripNotes: "", tripDateTimeStart: Date().addingTimeInterval(-172800), tripDateTimeEnd: Date().addingTimeInterval(-172800))
		]
		samples.forEach { context.insert($0) }
		try? context.save()

		self.container = container
	}

	var body: some View {
		Group {
			pdfReportTrip(trackVehicleSelected: "All Vehicles")
				.previewDisplayName("All Vehicles")

			pdfReportTrip(trackVehicleSelected: "Vehicle A")
				.previewDisplayName("Vehicle A")
		}
		.modelContainer(container)
	}
}

#Preview {
	TripReportPreviewHost()
}
