/*
 File: pdfReportVehicles.swift
 Module: LandShip

 Summary
 -------
 A cross-platform SwiftUI view that generates and displays a PDF report of vehicles (Vehicle8).
 Built on the shared PDFReportRenderer engine (PDFReportStyle.swift): five category columns
 carry nearly every Vehicle8 field, grouped and stacked so the report still fits a portrait
 US-Letter page. The view owns its own vehicle scope and can switch between "All Vehicles" and
 a specific vehicle without leaving the report.

 Key Features
 ------------
 - In-report vehicle picker (toolbar Menu) that re-fetches and regenerates on change
 - Respects the "showInactiveVehicles" preference for the All Vehicles scope; a specifically
   selected vehicle always renders regardless of its active state
 - Unit-aware formatting driven by Settings1 (via PrefsFunctions/UnitIndex), matching EditVehicle
 - Empty/zero fields are dropped before layout so sparse vehicles produce short rows
 - Built-in print support and zoom controls via the shared PDFKitView/PDFReportFile helpers

 Data Flow
 ---------
 - `scope` (@State) selects "All Vehicles" or a specific vehicle by name; the picker mutates it.
 - `generatePDFWithTable()` fetches vehicles via FetchDescriptor (not @Query, since scope can
   change after the view appears), builds one PDFCell row per vehicle, and hands them to
   `PDFReportRenderer.render(...)`.
 - The resulting Data is wrapped in PDFDocument and assigned to state (`pdfDocument`) for display,
   and saved to the app's Documents folder via `PDFReportFile.save(data:fileName:)`.

 Dependencies
 ------------
 - Frameworks: PDFKit, SwiftUI, SwiftData, Foundation
 - Models: Vehicle8
 - Shared: PDFReportStyle.swift (PDFReportRenderer, PDFKitView, ZoomAction, PDFReportFile)
 - Utilities: Functions (date/currency formatting), PrefsFunctions/UnitIndex (units of measure)
*/

import PDFKit
import SwiftUI
import SwiftData
import Foundation

/// A SwiftUI view that builds and displays a PDF report of vehicles.
/// - Parameter trackVehicleSelected: The initial scope — "All Vehicles" (or empty) for every
///   vehicle, or a specific `Vehicle8.name` to report on just one. The report owns this value
///   afterward via its in-report vehicle picker.
struct pdfReportVehicles: View {
	@Environment(\.modelContext) var modelContext
	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false

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
		.onChange(of: showInactiveVehicles) {
			generateAndShowPDF()
		}
		.toolbar {
			ToolbarItem(placement: .automatic) {
				vehiclePicker
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
						PDFReportFile.printDocument(doc, jobName: "Vehicles")
					}
				} label: {
					Label("Print", systemImage: "printer")
				}
				.keyboardShortcut("p", modifiers: .command)
				.disabled(pdfDocument == nil)
			}
		}
	}

	// MARK: - Vehicle picker

	private var vehiclePicker: some View {
		let vehicles = fetchAllVehicles().filter { showInactiveVehicles || !$0.inactive }
		return Menu {
			Button("All Vehicles") { scope = "All Vehicles" }
			ForEach(vehicles, id: \.name) { vehicle in
				Button(vehicle.displayName.isEmpty ? vehicle.name : vehicle.displayName) {
					scope = vehicle.name
				}
			}
		} label: {
			Label(currentScopeLabel(), systemImage: "car")
		}
		.accessibilityLabel("Vehicle Filter")
	}

	private func currentScopeLabel() -> String {
		guard scope != "All Vehicles" && !scope.isEmpty else { return "All Vehicles" }
		let selected = scope
		let descriptor = FetchDescriptor<Vehicle8>(predicate: #Predicate<Vehicle8> { $0.name == selected })
		guard let vehicle = try? modelContext.fetch(descriptor).first else { return scope }
		return vehicle.displayName.isEmpty ? vehicle.name : vehicle.displayName
	}

	// MARK: - Generation

	private func generateAndShowPDF() {
		guard let pdfData = generatePDFWithTable() else { return }
		if let doc = PDFDocument(data: pdfData) {
			self.pdfDocument = doc
			PDFReportFile.save(data: pdfData, fileName: "Vehicles")
		}
	}

	private func fetchAllVehicles() -> [Vehicle8] {
		let descriptor = FetchDescriptor<Vehicle8>(sortBy: [SortDescriptor(\.sortOrder, order: .forward)])
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	/// Builds the full multipage PDF for the current `scope`. Returns raw PDF data suitable
	/// for wrapping in a PDFDocument and/or saving to disk.
	func generatePDFWithTable() -> Data? {
		let allVehicles = fetchAllVehicles()
		var nameToDisplayName: [String: String] = [:]
		for vehicle in allVehicles {
			nameToDisplayName[vehicle.name] = vehicle.displayName.isEmpty ? vehicle.name : vehicle.displayName
		}

		let vehicles: [Vehicle8]
		if scope == "All Vehicles" || scope.isEmpty {
			vehicles = allVehicles.filter { showInactiveVehicles || !$0.inactive }
		} else {
			vehicles = allVehicles.filter { $0.name == scope }
		}

		let units = prefsFunctions.loadSettingsArray(context: modelContext, userName: "primary1") ?? Array(repeating: "", count: 13)

		let columns: [PDFTableColumn] = [
			PDFTableColumn("VEHICLE", weight: 0.20),
			PDFTableColumn("MECHANICAL &\nUSAGE", weight: 0.20),
			PDFTableColumn("DIMENSIONS &\nWEIGHTS", weight: 0.21),
			PDFTableColumn("CAPACITIES &\nTIRES", weight: 0.19),
			PDFTableColumn("INSURANCE &\nSERVICE", weight: 0.20)
		]

		let rows: [[PDFCell]] = vehicles.map { vehicle in
			[
				vehicleCell(vehicle, nameToDisplayName: nameToDisplayName),
				mechanicalCell(vehicle, units: units),
				dimensionsWeightsCell(vehicle, units: units),
				capacitiesTiresCell(vehicle, units: units),
				insuranceServiceCell(vehicle)
			]
		}

		let scopeTitle = (scope == "All Vehicles" || scope.isEmpty) ? "All Vehicles" : (nameToDisplayName[scope] ?? scope)
		let vehicleWord = vehicles.count == 1 ? "vehicle" : "vehicles"
		let subtitle = "\(scopeTitle) • \(functions.formatDate_DDMMMyy(date: Date())) • \(vehicles.count) \(vehicleWord)"

		return PDFReportRenderer.render(title: "Vehicles Report", subtitle: subtitle, columns: columns, rows: rows, style: .standard)
	}

	// MARK: - Field-group builders
	//
	// Each cell drops empty strings and zero-valued numbers before handing fields to the
	// renderer, mirroring EditVehicle's own `> 0` / `!= ""` display gating so sparse vehicles
	// produce short rows instead of a wall of zeros.

	private func text(_ value: String) -> String? {
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}

	private func num(_ value: Int, unit: String) -> String? {
		guard value != 0 else { return nil }
		let formatted = NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
		return unit.isEmpty ? formatted : "\(formatted) \(unit)"
	}

	private func fieldGroup(_ heading: String?, _ fields: [(String, String?)]) -> PDFFieldGroup? {
		let resolved: [(label: String, value: String)] = fields.compactMap { label, value in
			guard let value else { return nil }
			return (label: label, value: value)
		}
		guard !resolved.isEmpty else { return nil }
		return PDFFieldGroup(heading: heading, fields: resolved)
	}

	private func vehicleCell(_ vehicle: Vehicle8, nameToDisplayName: [String: String]) -> PDFCell {
		let displayName = vehicle.displayName.isEmpty ? vehicle.name : vehicle.displayName

		var groups: [PDFFieldGroup] = []
		if let identity = fieldGroup(nil, [
			("Vehicle", displayName),
			("Status", vehicle.inactive ? "Inactive" : "Active"),
			("Year", vehicle.year > 0 ? functions.formatYear(year: vehicle.year) : nil),
			("Make", text(vehicle.manufacturer)),
			("Model", text(vehicle.model)),
			("Trim", text(vehicle.trim)),
			("VIN", text(vehicle.vin)),
			("Plate", text(vehicle.licensePlate)),
			("Title #", text(vehicle.titleNumber))
		]) {
			groups.append(identity)
		}

		let aspect = text(vehicle.vehicleAspect)
		let master = vehicle.linkedMasterVehicleId.isEmpty ? nil : (nameToDisplayName[vehicle.linkedMasterVehicleId] ?? vehicle.linkedMasterVehicleId)
		let synced = vehicle.linkedSyncFields.isEmpty ? nil : vehicle.linkedSyncFields.map(\.displayName).sorted().joined(separator: ", ")
		if let linked = fieldGroup("Linked Record", [
			("Aspect", aspect),
			("Master", master),
			("Synced", synced)
		]) {
			groups.append(linked)
		}

		return .imageWithGroups(vehicle.image1, caption: vehicle.image1Description, groups: groups)
	}

	private func mechanicalCell(_ vehicle: Vehicle8, units: [String]) -> PDFCell {
		let distanceUnit = units[safe: UnitIndex.distance] ?? ""
		var groups: [PDFFieldGroup] = []

		if let mechanical = fieldGroup(nil, [
			("Fuel Type", text(vehicle.fuelType)),
			("Engine", text(vehicle.engine)),
			("Engine S/N", text(vehicle.engineSerialNumber)),
			("Transmission", text(vehicle.transmission)),
			("Trans S/N", text(vehicle.transmissionSerialNumber))
		]) {
			groups.append(mechanical)
		}

		if let usage = fieldGroup("Usage", [
			("Odometer", num(vehicle.mileage, unit: distanceUnit)),
			("Odometer (Virtual)", num(vehicle.mileageVirtual, unit: distanceUnit)),
			("Engine Hours", vehicle.engHours != 0 ? String(format: "%.1f hrs", vehicle.engHours) : nil),
			("Doors", vehicle.doors > 0 ? "\(vehicle.doors)" : nil),
			("Seats", vehicle.seats > 0 ? "\(vehicle.seats)" : nil)
		]) {
			groups.append(usage)
		}

		return .groups(groups)
	}

	private func dimensionsWeightsCell(_ vehicle: Vehicle8, units: [String]) -> PDFCell {
		let wheelBaseUnit = units[safe: UnitIndex.wheelBase] ?? ""
		let lengthUnit = units[safe: UnitIndex.length] ?? ""
		let widthUnit = units[safe: UnitIndex.width] ?? ""
		let heightUnit = units[safe: UnitIndex.height] ?? ""
		let areaUnit = units[safe: UnitIndex.area] ?? ""
		let massUnit = units[safe: UnitIndex.mass] ?? ""

		var groups: [PDFFieldGroup] = []

		if let dimensions = fieldGroup("Dimensions", [
			("Wheelbase", num(vehicle.wheelbase, unit: wheelBaseUnit)),
			("Length", num(vehicle.length, unit: lengthUnit)),
			("Width", num(vehicle.width, unit: widthUnit)),
			("Height", num(vehicle.height, unit: heightUnit)),
			("Cargo", num(vehicle.cargoSpace, unit: areaUnit))
		]) {
			groups.append(dimensions)
		}

		if let weights = fieldGroup("Weights", [
			("Weight", num(vehicle.weight, unit: massUnit)),
			("Date Weighed", vehicle.weight != 0 ? functions.formatDate_DDMMMyy(date: vehicle.dateWeighed) : nil),
			("GVWR", num(vehicle.gvwr, unit: massUnit)),
			("GCWR", num(vehicle.gcwr, unit: massUnit)),
			("GAWR Front", num(vehicle.gawrFront, unit: massUnit)),
			("GAWR Rear", num(vehicle.gawrRear, unit: massUnit)),
			("Towing", num(vehicle.towingCapcity, unit: massUnit)),
			("UVW", num(vehicle.uvw, unit: massUnit)),
			("CCC", num(vehicle.ccc, unit: massUnit)),
			("Payload", num(vehicle.availablePayload, unit: massUnit))
		]) {
			groups.append(weights)
		}

		let totalVehicleWeight = vehicle.scaleWeightFrontAxle + vehicle.scaleWeightRearAxle + vehicle.scaleWeightPusherAxle + vehicle.scaleWeightTagAxle
		let totalRollingWeight = totalVehicleWeight + vehicle.scaleWeightTrailerAxle
		if let scale = fieldGroup("Scale Readings", [
			("Steer Axle", num(vehicle.scaleWeightFrontAxle, unit: massUnit)),
			("Drive Axle(s)", num(vehicle.scaleWeightRearAxle, unit: massUnit)),
			("Pusher Axle", num(vehicle.scaleWeightPusherAxle, unit: massUnit)),
			("Tag Axle", num(vehicle.scaleWeightTagAxle, unit: massUnit)),
			("Trailer Axle(s)", num(vehicle.scaleWeightTrailerAxle, unit: massUnit)),
			("Total Vehicle Wt", num(totalVehicleWeight, unit: massUnit)),
			("Total Rolling Wt", num(totalRollingWeight, unit: massUnit))
		]) {
			groups.append(scale)
		}

		return .groups(groups)
	}

	private func capacitiesTiresCell(_ vehicle: Vehicle8, units: [String]) -> PDFCell {
		let fuelUnit = units[safe: UnitIndex.fuel] ?? ""
		let defUnit = units[safe: UnitIndex.def] ?? ""
		let pressureUnit = units[safe: UnitIndex.pressure] ?? ""

		var groups: [PDFFieldGroup] = []

		if let capacities = fieldGroup("Capacities", [
			("Fuel", num(vehicle.fuelCapacity, unit: fuelUnit)),
			("DEF", num(vehicle.defCapacity, unit: defUnit)),
			("Fresh Water", num(vehicle.waterCapacity, unit: fuelUnit)),
			("Gray Water", num(vehicle.grayCapacity, unit: fuelUnit)),
			("Black Water", num(vehicle.blackCapacity, unit: fuelUnit))
		]) {
			groups.append(capacities)
		}

		if let tires = fieldGroup("Tires", [
			("Size", text(vehicle.tireSize)),
			("Pressure Front", num(vehicle.tirePressureFront, unit: pressureUnit)),
			("Pressure Rear", num(vehicle.tirePressureRear, unit: pressureUnit)),
			("Pressure Tag", num(vehicle.tirePressureTag, unit: pressureUnit)),
			("Pressure Pusher", num(vehicle.tirePressurePusher, unit: pressureUnit)),
			("Stud Size", text(vehicle.wheelStudSize)),
			("Nut Socket", text(vehicle.wheelNutSocket)),
			("Nut Torque", text(vehicle.wheelNutTorque))
		]) {
			groups.append(tires)
		}

		return .groups(groups)
	}

	private func insuranceServiceCell(_ vehicle: Vehicle8) -> PDFCell {
		var groups: [PDFFieldGroup] = []

		let hasInsurance = !vehicle.insuranceCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
			|| !vehicle.insurancePolicyNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		if let insurance = fieldGroup("Insurance", [
			("Provider", text(vehicle.insuranceCompany)),
			("Policy #", text(vehicle.insurancePolicyNumber)),
			("Holder", text(vehicle.insurancePolicyHolder)),
			("Expiration", hasInsurance ? functions.formatDate_DDMMMyy(date: vehicle.insuranceExpiration) : nil)
		]) {
			groups.append(insurance)
		}

		if let online = fieldGroup("Online Service", [
			("Provider", text(vehicle.onlineServiceProvider)),
			("Number", text(vehicle.onlineServiceNumber)),
			("URL", text(vehicle.onlineServiceURL)),
			("Login", text(vehicle.onlineServiceLogin)),
			("Billing Acct", text(vehicle.onlineServiceBillingAccount)),
			("Mobile #", text(vehicle.vehicleMobileNumber))
		]) {
			groups.append(online)
		}

		let hasPurchaseInfo = vehicle.price != 0 || !vehicle.placePurchased.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		if let purchase = fieldGroup("Purchase", [
			("Price", vehicle.price != 0 ? functions.formatCurrency(dollars: Float(vehicle.price)) : nil),
			("Place", text(vehicle.placePurchased)),
			("Date", hasPurchaseInfo ? functions.formatDate_DDMMMyy(date: vehicle.datePurchased) : nil),
			("Owner", text(vehicle.ownerId)),
			("Location", text(vehicle.locationId))
		]) {
			groups.append(purchase)
		}

		if let notes = fieldGroup("Notes", [
			("Notes", text(vehicle.notes))
		]) {
			groups.append(notes)
		}

		return .groups(groups)
	}
}

// MARK: - Previews
/// A small preview host that seeds an in-memory SwiftData container and presents two previews:
/// one for all vehicles and one for a specific vehicle.
private struct VehiclesReportPreviewHost: View {
	let container: ModelContainer

	init() {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try! ModelContainer(for: Vehicle8.self, configurations: config)

		let context = container.mainContext

		let samples: [Vehicle8] = [
			Vehicle8(name: "Vehicle A", manufacturer: "Acme", model: "Hauler", year: 2021, trim: "XL", mileage: 12050, engHours: 12.5, transmission: "6-spd Auto", engine: "3.0L V6", fuelType: "Diesel", notes: "Primary tow vehicle.", vin: "1A2B3C4D5E6F7G8H9", licensePlate: "ABC123", image1Description: "Front view"),
			Vehicle8(name: "Vehicle B", manufacturer: "Bravo", model: "Runner", year: 2018, trim: "Sport", mileage: 5400, engHours: 4.0, transmission: "CVT", engine: "2.0L I4", fuelType: "Gasoline", notes: "Compact and efficient.", vin: "9H8G7F6E5D4C3B2A1Z", licensePlate: "XYZ789", image1Description: "Side view")
		]
		samples.forEach { context.insert($0) }
		try? context.save()

		self.container = container
	}

	var body: some View {
		Group {
			// All Vehicles preview
			pdfReportVehicles(trackVehicleSelected: "All Vehicles")
				.previewDisplayName("All Vehicles")

			// Specific vehicle preview
			pdfReportVehicles(trackVehicleSelected: "Vehicle A")
				.previewDisplayName("Vehicle A")
		}
		.modelContainer(container)
	}
}

#Preview {
	VehiclesReportPreviewHost()
}
