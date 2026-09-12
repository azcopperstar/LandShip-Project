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
	@State private var csvDocument = CSVDocument(text: "")
	@State private var isExportingCSV = false

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
						PDFReportFile.printDocument(doc, jobName: Vertical.current.assetPlural)
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
		.fileExporter(isPresented: $isExportingCSV, document: csvDocument, contentType: .commaSeparatedText, defaultFilename: Vertical.current.assetPlural) { _ in }
	}

	// MARK: - CSV Export

	private func generateCSV() -> String {
		let vehicles = fetchAllVehicles().filter { showInactiveVehicles || !$0.inactive || $0.name == scope }
		let scoped = FleetScope.isAll(scope) ? vehicles : vehicles.filter { $0.name == scope }

		let headers = [
			"Name", "Display Name", "Inactive", "Manufacturer", "Model", "Year", "Trim",
			Vertical.current.distanceMeterLabel, "Virtual \(Vertical.current.distanceMeterLabel)", Vertical.current.hoursMeterLabel,
			"Transmission", "Engine", "Engine Serial #", "Transmission Serial #", "Fuel Type",
			"Doors", "Seats", "Cargo Space", "Length", "Width", "Height", "Weight", "Date Weighed",
			"Wheelbase", "GVWR", "GCWR", "GAWR Front", "GAWR Rear", "Towing Capacity", "UVW", "CCC",
			"Fuel Capacity", "DEF Capacity", "Water Capacity", "Gray Capacity", "Black Capacity",
			"Image URL", "Price", "Notes", "Created At", "Updated At", "Owner ID", "Location ID",
			Vertical.current.registrationLabel, Vertical.current.plateLabel, "Date Purchased", "Place Purchased",
			"Tire Size", "Title Number", "Online Service Provider", "Online Service Number",
			"Online Service Login", "Online Service URL", "Online Service Billing Account",
			"\(Vertical.current.assetSingular) Mobile #", "Insurance Company", "Insurance Policy #",
			"Insurance Policy Holder", "Insurance Expiration", "Tire Pressure Front", "Tire Pressure Rear",
			"Tire Pressure Tag", "Tire Pressure Pusher", "Wheel Stud Size", "Wheel Nut Socket",
			"Wheel Nut Torque", "Available Payload", "Scale Weight Front Axle", "Scale Weight Rear Axle",
			"Scale Weight Pusher Axle", "Scale Weight Tag Axle", "Scale Weight Trailer Axle", "Sort Order",
			"Linked Master Vehicle ID", "Master Vehicle Display Name", "\(Vertical.current.assetSingular) Aspect",
			"Image 1 Description", "Image 2 Description", "Image 3 Description"
		]

		let rows: [[String]] = scoped.map { v in
			let masterName = v.linkedMasterVehicleId.isEmpty ? "" : functions.getVehicleDisplayName(vehicleId: v.linkedMasterVehicleId, context: modelContext)
			return [
				v.name, v.displayName, CSVField.bool(v.inactive), v.manufacturer, v.model, CSVField.int(v.year), v.trim,
				CSVField.int(v.mileage), CSVField.int(v.mileageVirtual), CSVField.float(v.engHours),
				v.transmission, v.engine, v.engineSerialNumber, v.transmissionSerialNumber, v.fuelType,
				CSVField.int(v.doors), CSVField.int(v.seats), CSVField.int(v.cargoSpace), CSVField.int(v.length), CSVField.int(v.width), CSVField.int(v.height), CSVField.int(v.weight), CSVField.date(v.dateWeighed),
				CSVField.int(v.wheelbase), CSVField.int(v.gvwr), CSVField.int(v.gcwr), CSVField.int(v.gawrFront), CSVField.int(v.gawrRear), CSVField.int(v.towingCapcity), CSVField.int(v.uvw), CSVField.int(v.ccc),
				CSVField.int(v.fuelCapacity), CSVField.int(v.defCapacity), CSVField.int(v.waterCapacity), CSVField.int(v.grayCapacity), CSVField.int(v.blackCapacity),
				v.imageUrl, CSVField.int(v.price), v.notes, CSVField.date(v.createdAt), CSVField.date(v.updatedAt), v.ownerId, v.locationId,
				v.vin, v.licensePlate, CSVField.date(v.datePurchased), v.placePurchased,
				v.tireSize, v.titleNumber, v.onlineServiceProvider, v.onlineServiceNumber,
				v.onlineServiceLogin, v.onlineServiceURL, v.onlineServiceBillingAccount,
				v.vehicleMobileNumber, v.insuranceCompany, v.insurancePolicyNumber,
				v.insurancePolicyHolder, CSVField.date(v.insuranceExpiration), CSVField.int(v.tirePressureFront), CSVField.int(v.tirePressureRear),
				CSVField.int(v.tirePressureTag), CSVField.int(v.tirePressurePusher), v.wheelStudSize, v.wheelNutSocket,
				v.wheelNutTorque, CSVField.int(v.availablePayload), CSVField.int(v.scaleWeightFrontAxle), CSVField.int(v.scaleWeightRearAxle),
				CSVField.int(v.scaleWeightPusherAxle), CSVField.int(v.scaleWeightTagAxle), CSVField.int(v.scaleWeightTrailerAxle), CSVField.int(v.sortOrder),
				v.linkedMasterVehicleId, masterName, v.vehicleAspect,
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
			PDFReportFile.save(data: pdfData, fileName: Vertical.current.assetPlural)
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
			PDFTableColumn(Vertical.current.assetSingular.uppercased(), weight: 0.20),
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

		let scopeTitle = FleetScope.isAll(scope) ? FleetScope.allDisplayLabel : (nameToDisplayName[scope] ?? scope)
		let vehicleWord = vehicles.count == 1 ? Vertical.current.assetSingular.lowercased() : Vertical.current.assetPlural.lowercased()
		let subtitle = "\(scopeTitle) • \(functions.formatDate_DDMMMyy(date: Date())) • \(vehicles.count) \(vehicleWord)"

		return PDFReportRenderer.render(title: "\(Vertical.current.assetPlural) Report", subtitle: subtitle, columns: columns, rows: rows, style: .standard)
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
			(Vertical.current.assetSingular, displayName),
			("Status", vehicle.inactive ? "Inactive" : "Active"),
			("Year", vehicle.year > 0 ? functions.formatYear(year: vehicle.year) : nil),
			("Make", text(vehicle.manufacturer)),
			("Model", text(vehicle.model)),
			("Trim", text(vehicle.trim)),
			(Vertical.current.registrationLabel, text(vehicle.vin)),
			(Vertical.current.plateLabel, text(vehicle.licensePlate)),
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

		let isAviation = Vertical.current.id == .aviation
		if let mechanical = fieldGroup(nil, [
			("Fuel Type", text(vehicle.fuelType)),
			("Engine", isAviation ? nil : text(vehicle.engine)),
			("Engine S/N", isAviation ? nil : text(vehicle.engineSerialNumber)),
			("Transmission", isAviation ? nil : text(vehicle.transmission)),
			("Trans S/N", isAviation ? nil : text(vehicle.transmissionSerialNumber))
		]) {
			groups.append(mechanical)
		}

		let showsDistance = Vertical.current.visibleFieldGroups.contains(.odometer)
		if let usage = fieldGroup("Usage", [
			(showsDistance ? Vertical.current.distanceMeterLabel : "", showsDistance ? num(vehicle.mileage, unit: distanceUnit) : nil),
			(showsDistance ? "\(Vertical.current.distanceMeterLabel) (Virtual)" : "", showsDistance ? num(vehicle.mileageVirtual, unit: distanceUnit) : nil),
			(Vertical.current.hoursMeterLabel, vehicle.engHours != 0 ? String(format: "%.1f hrs", vehicle.engHours) : nil),
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

		let isAviation = Vertical.current.id == .aviation
		if let dimensions = fieldGroup("Dimensions", [
			("Wheelbase", isAviation ? nil : num(vehicle.wheelbase, unit: wheelBaseUnit)),
			("Length", num(vehicle.length, unit: lengthUnit)),
			(isAviation ? "Wing Span" : "Width", num(vehicle.width, unit: widthUnit)),
			("Height", isAviation ? nil : num(vehicle.height, unit: heightUnit)),
			("Cargo", num(vehicle.cargoSpace, unit: areaUnit))
		]) {
			groups.append(dimensions)
		}

		if Vertical.current.visibleFieldGroups.contains(.weightRatings), let weights = fieldGroup("Weights", [
			("Weight", num(vehicle.weight, unit: massUnit)),
			("Date Weighed", vehicle.weight != 0 ? functions.formatDate_DDMMMyy(date: vehicle.dateWeighed) : nil),
			("GVWR", num(vehicle.gvwr, unit: massUnit)),
			("GCWR", num(vehicle.gcwr, unit: massUnit)),
			("GAWR Front", num(vehicle.gawrFront, unit: massUnit)),
			("GAWR Rear", num(vehicle.gawrRear, unit: massUnit)),
			("Towing", Vertical.current.visibleFieldGroups.contains(.towing) ? num(vehicle.towingCapcity, unit: massUnit) : nil),
			("UVW", num(vehicle.uvw, unit: massUnit)),
			("CCC", num(vehicle.ccc, unit: massUnit)),
			("Payload", num(vehicle.availablePayload, unit: massUnit))
		]) {
			groups.append(weights)
		}

		let totalVehicleWeight = vehicle.scaleWeightFrontAxle + vehicle.scaleWeightRearAxle + vehicle.scaleWeightPusherAxle + vehicle.scaleWeightTagAxle
		let totalRollingWeight = totalVehicleWeight + vehicle.scaleWeightTrailerAxle
		if Vertical.current.visibleFieldGroups.contains(.axleWeights), let scale = fieldGroup("Scale Readings", [
			("Steer Axle", num(vehicle.scaleWeightFrontAxle, unit: massUnit)),
			("Drive Axle(s)", num(vehicle.scaleWeightRearAxle, unit: massUnit)),
			("Pusher Axle", num(vehicle.scaleWeightPusherAxle, unit: massUnit)),
			("Tag Axle", num(vehicle.scaleWeightTagAxle, unit: massUnit)),
			("Trailer Axle(s)", num(vehicle.scaleWeightTrailerAxle, unit: massUnit)),
			("Total \(Vertical.current.assetSingular) Wt", num(totalVehicleWeight, unit: massUnit)),
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

		let rvTanks = Vertical.current.visibleFieldGroups.contains(.rvTanks)
		if let capacities = fieldGroup("Capacities", [
			("Fuel", num(vehicle.fuelCapacity, unit: fuelUnit)),
			("DEF", rvTanks ? num(vehicle.defCapacity, unit: defUnit) : nil),
			("Fresh Water", rvTanks ? num(vehicle.waterCapacity, unit: fuelUnit) : nil),
			("Gray Water", rvTanks ? num(vehicle.grayCapacity, unit: fuelUnit) : nil),
			("Black Water", rvTanks ? num(vehicle.blackCapacity, unit: fuelUnit) : nil)
		]) {
			groups.append(capacities)
		}

		if Vertical.current.visibleFieldGroups.contains(.tires), let tires = fieldGroup("Tires", [
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
