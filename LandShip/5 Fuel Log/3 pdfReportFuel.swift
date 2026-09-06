/*
 File: pdfReportFuel.swift
 Module: LandShip

 Summary
 -------
 A cross-platform SwiftUI view that generates and displays a PDF report of fuel log entries
 (FuelLog1). Built on the shared PDFReportRenderer engine (PDFReportStyle.swift): three category
 columns carry nearly every FuelLog1 field, grouped and stacked so the report fits a portrait
 US-Letter page. The view owns its own vehicle scope via the shared VehicleScopePicker and can
 switch between "All Vehicles" and a specific vehicle without leaving the report.

 Key Features
 ------------
 - Shared in-report vehicle picker (VehicleScopePicker) that re-fetches and regenerates on change
 - Unit-aware formatting driven by Settings1 (via PrefsFunctions/UnitIndex), matching EditFuelLog
 - Empty/zero fields are dropped before layout so sparse fuel logs produce short rows
 - Built-in print support and zoom controls via the shared PDFKitView/PDFReportFile helpers

 Excluded on purpose
 --------------------
 "Statistics Since Previous Fueling" and "Vehicle Totals" in EditFuelLog are computed on the fly
 from surrounding fuel log records, not stored on FuelLog1 itself; reproducing them here would
 mean re-running that aggregation per row. Left out of this pass.

 Data Flow
 ---------
 - `scope` (@State) selects "All Vehicles" or a specific vehicle by name; the picker mutates it.
 - `generatePDFWithTable()` fetches fuel logs via FetchDescriptor (not @Query, since scope can
   change after the view appears), builds one PDFCell row per entry, and hands them to
   `PDFReportRenderer.render(...)`.
 - The resulting Data is wrapped in PDFDocument and assigned to state (`pdfDocument`) for display,
   and saved to the app's Documents folder via `PDFReportFile.save(data:fileName:)`.

 Dependencies
 ------------
 - Frameworks: PDFKit, SwiftUI, SwiftData, Foundation
 - Models: FuelLog1
 - Shared: PDFReportStyle.swift (PDFReportRenderer, PDFKitView, ZoomAction, PDFReportFile, VehicleScopePicker)
 - Utilities: Functions (date/currency/fuel-level formatting, vehicle display name lookup),
   PrefsFunctions/UnitIndex (units of measure)
*/

import PDFKit
import SwiftUI
import SwiftData
import Foundation

/// A SwiftUI view that builds and displays a PDF report of fuel log entries.
/// - Parameter trackVehicleSelected: The initial scope — "All Vehicles" (or empty) for every
///   vehicle, or a specific `Vehicle8.name` to report on just that vehicle's fuel logs. The
///   report owns this value afterward via its in-report vehicle picker.
struct pdfReportFuel: View {
	@Environment(\.modelContext) var modelContext

	@State private var scope: String
	@State private var pdfDocument: PDFDocument?
	@State private var zoomAction: ZoomAction?

	let functions = Functions()
	let prefsFunctions = PrefsFunctions()

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
						PDFReportFile.printDocument(doc, jobName: "Fuel Log")
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
			PDFReportFile.save(data: pdfData, fileName: "Fuel Log")
		}
	}

	private func fetchFuelLogs() -> [FuelLog1] {
		let descriptor: FetchDescriptor<FuelLog1>
		if scope == "All Vehicles" || scope.isEmpty {
			descriptor = FetchDescriptor<FuelLog1>(sortBy: [
				SortDescriptor(\.vehicleId, order: .forward),
				SortDescriptor(\.fuelDateTime, order: .reverse)
			])
		} else {
			let vehicleId = scope
			descriptor = FetchDescriptor<FuelLog1>(
				predicate: #Predicate<FuelLog1> { $0.vehicleId == vehicleId },
				sortBy: [SortDescriptor(\.fuelDateTime, order: .reverse)]
			)
		}
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	/// Builds the full multipage PDF for the current `scope`. Returns raw PDF data suitable
	/// for wrapping in a PDFDocument and/or saving to disk.
	func generatePDFWithTable() -> Data? {
		let logs = fetchFuelLogs()
		let units = prefsFunctions.loadSettingsArray(context: modelContext, userName: "primary1") ?? Array(repeating: "", count: 13)

		let columns: [PDFTableColumn] = [
			PDFTableColumn("VEHICLE &\nLOCATION", weight: 0.28),
			PDFTableColumn("FUELING &\nDEF", weight: 0.42),
			PDFTableColumn("CHECKS &\nNOTES", weight: 0.30)
		]

		let rows: [[PDFCell]] = logs.map { log in
			[
				vehicleLocationCell(log, units: units),
				fuelingCell(log, units: units),
				checksAndNotesCell(log)
			]
		}

		let scopeTitle = (scope == "All Vehicles" || scope.isEmpty) ? "All Vehicles" : functions.getVehicleDisplayName(vehicleId: scope, context: modelContext)
		let logWord = logs.count == 1 ? "entry" : "entries"
		let subtitle = "\(scopeTitle) • \(functions.formatDate_DDMMMyy(date: Date())) • \(logs.count) \(logWord)"

		return PDFReportRenderer.render(title: "Fuel Log Report", subtitle: subtitle, columns: columns, rows: rows, style: .standard)
	}

	// MARK: - Field-group builders
	//
	// Each cell drops empty strings and zero-valued numbers before handing fields to the
	// renderer, mirroring EditFuelLog's own gating so sparse entries produce short rows instead
	// of a wall of zeros.

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

	/// Falls back to an eighths-based description (e.g. "1/2 Tank") when no free-text fraction
	/// label was entered, matching the original report's behavior.
	private func levelText(fraction: String, level: Float) -> String? {
		text(fraction.isEmpty ? functions.getFuelLevel(unit: level) : fraction)
	}

	private func vehicleLocationCell(_ log: FuelLog1, units: [String]) -> PDFCell {
		let distanceUnit = units[safe: UnitIndex.distance] ?? ""
		let vehicleName = log.vehicleId.isEmpty ? nil : functions.getVehicleDisplayName(vehicleId: log.vehicleId, context: modelContext)
		let exitTime = (log.fuelExitTime.map { $0 > log.fuelDateTime ? $0 : nil } ?? nil).map { functions.formatDate_DDMMMyy_HHmm(date: $0) }

		var groups: [PDFFieldGroup] = []
		if let identity = fieldGroup(nil, [
			("Vehicle", vehicleName),
			("Log Name", text(log.logName)),
			("Date/Time", functions.formatDate_DDMMMyy_HHmm(date: log.fuelDateTime)),
			("Exit Time", exitTime),
			("Location", text(log.location)),
			("Odometer", log.odometer != 0 ? "\(NumberFormatter.localizedString(from: NSNumber(value: log.odometer), number: .decimal)) \(distanceUnit)" : nil),
			("Engine Hours", log.engHours != 0 ? String(format: "%.1f hrs", log.engHours) : nil)
		]) {
			groups.append(identity)
		}

		return .imageWithGroups(log.image1, caption: log.image1Description, groups: groups)
	}

	private func fuelingCell(_ log: FuelLog1, units: [String]) -> PDFCell {
		let fuelUnit = units[safe: UnitIndex.fuel] ?? ""
		let defUnit = units[safe: UnitIndex.def] ?? ""
		let oilUnit = units[safe: UnitIndex.oil] ?? ""

		var groups: [PDFFieldGroup] = []

		if let fueling = fieldGroup(nil, [
			("Fuel Type", text(log.fuelType)),
			("Level Start", levelText(fraction: log.fuelLevelStartFraction, level: log.fuelLevelStart1)),
			("Level End", levelText(fraction: log.fuelLevelEndFraction, level: log.fuelLevelEnd1)),
			("Fuel Added", log.fuelAdded != 0 ? "\(String(format: "%.1f", log.fuelAdded)) \(fuelUnit)" : nil),
			("Price/\(fuelUnit)", log.fuelPrice != 0 ? functions.formatCurrency(dollars: log.fuelPrice) : nil),
			("Cost", log.fuelCost != 0 ? functions.formatCurrency(dollars: log.fuelCost) : nil),
			("Oil Added", log.oilAdded != 0 ? "\(String(format: "%.1f", log.oilAdded)) \(oilUnit)" : nil)
		]) {
			groups.append(fueling)
		}

		if let def = fieldGroup("DEF", [
			("Added", log.defAdded != 0 ? "\(String(format: "%.1f", log.defAdded)) \(defUnit)" : nil),
			("Price", log.defPrice != 0 ? functions.formatCurrency(dollars: log.defPrice) : nil),
			("Cost", (log.defAdded != 0 && log.defPrice != 0) ? functions.formatCurrency(dollars: log.defAdded * log.defPrice) : nil),
			("Level Start", levelText(fraction: log.defLevelStartFraction, level: log.defLevelStart1)),
			("Level End", levelText(fraction: log.defLevelFraction, level: log.defLevel1))
		]) {
			groups.append(def)
		}

		return .groups(groups)
	}

	private func checksAndNotesCell(_ log: FuelLog1) -> PDFCell {
		var groups: [PDFFieldGroup] = []

		let checkedFluids: [(String, Bool)] = [
			("Engine Oil", log.oilChecked),
			("Engine Coolant", log.engineCoolantChecked),
			("Secondary Coolant", log.secondaryCoolantChecked),
			("Power Steering", log.powerSteeringChecked),
			("Brake", log.brakeFluidChecked),
			("Transmission", log.transmissionFluidChecked),
			("Rear Axle", log.rearAxleChecked),
			("Front Axle", log.frontAxleChecked),
			("Fuel/Water Separator", log.fuelWaterSeparatorChecked),
			("Air System Water Bleed", log.airSystemWaterBleedChecked)
		]
		let checkedNames = checkedFluids.filter(\.1).map(\.0)
		if let checks = fieldGroup("Fluid Checks", [
			("Checked", checkedNames.isEmpty ? nil : checkedNames.joined(separator: ", "))
		]) {
			groups.append(checks)
		}

		if let notes = fieldGroup(nil, [
			("Notes", text(log.fuelNotes))
		]) {
			groups.append(notes)
		}

		return .groups(groups)
	}
}

// MARK: - Previews
/// A small preview host that seeds an in-memory SwiftData container and presents two previews:
/// one for all vehicles and one for a specific vehicle.
private struct FuelReportPreviewHost: View {
	let container: ModelContainer

	init() {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try! ModelContainer(for: FuelLog1.self, Vehicle8.self, configurations: config)

		let context = container.mainContext

		let vehicle = Vehicle8(name: "Vehicle A", manufacturer: "Acme", model: "Hauler")
		context.insert(vehicle)

		let samples: [FuelLog1] = [
			FuelLog1(vehicleId: "Vehicle A", logName: "Morning fill-up", fuelNotes: "Topped off before the trip.", fuelDateTime: Date(), odometer: 42150, location: "Pilot Travel Center", engHours: 812.3, fuelAdded: 62.4, defAdded: 3.0, defPrice: 3.29, fuelLevelStart1: 0.25, fuelLevelEnd1: 1.0, fuelPrice: 3.79, fuelCost: 236.5, fuelType: "Diesel", oilChecked: true, brakeFluidChecked: true),
			FuelLog1(vehicleId: "Vehicle A", logName: "", fuelNotes: "", fuelDateTime: Date().addingTimeInterval(-86400), odometer: 41820, location: "", fuelType: "Diesel")
		]
		samples.forEach { context.insert($0) }
		try? context.save()

		self.container = container
	}

	var body: some View {
		Group {
			pdfReportFuel(trackVehicleSelected: "All Vehicles")
				.previewDisplayName("All Vehicles")

			pdfReportFuel(trackVehicleSelected: "Vehicle A")
				.previewDisplayName("Vehicle A")
		}
		.modelContainer(container)
	}
}

#Preview {
	FuelReportPreviewHost()
}
