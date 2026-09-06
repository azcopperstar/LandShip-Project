/*
 File: pdfReportSubscriptions.swift
 Module: LandShip

 Summary
 -------
 A cross-platform SwiftUI view that generates and displays a PDF report of subscriptions and
 recurring expenses (Subscriptions). Built on the shared PDFReportRenderer engine
 (PDFReportStyle.swift): three category columns carry every Subscriptions field, grouped and
 stacked so the report fits a portrait US-Letter page. The view owns its own vehicle scope via
 the shared VehicleScopePicker and can switch between "All Vehicles" and a specific vehicle
 without leaving the report.

 Key Features
 ------------
 - Shared in-report vehicle picker (VehicleScopePicker) that re-fetches and regenerates on change
 - Next payment due is computed from lastPayment + itemRecurringDays × itemRecurringInterval
 - Empty/zero fields are dropped before layout so sparse records produce short rows
 - Built-in print support and zoom controls via the shared PDFKitView/PDFReportFile helpers

 Excluded on purpose
 --------------------
 No "TRACKED COSTS SUMMARY" footer: subscriptions are recurring billing, not one-time tracked
 costs, so they're not one of the six categories (Parts, Fuel Log, Service Records, Items,
 Improvements, Projects) that footer totals.

 Data Flow
 ---------
 - `scope` (@State) selects "All Vehicles" or a specific vehicle by name; the picker mutates it.
 - `generatePDFWithTable()` fetches records via FetchDescriptor (not @Query, since scope can
   change after the view appears), builds one PDFCell row per record, and hands them to
   `PDFReportRenderer.render(...)`.
 - The resulting Data is wrapped in PDFDocument and assigned to state (`pdfDocument`) for display,
   and saved to the app's Documents folder via `PDFReportFile.save(data:fileName:)`.

 Dependencies
 ------------
 - Frameworks: PDFKit, SwiftUI, SwiftData, Foundation
 - Models: Subscriptions
 - Shared: PDFReportStyle.swift (PDFReportRenderer, PDFKitView, ZoomAction, PDFReportFile, VehicleScopePicker)
 - Utilities: Functions (date/currency formatting, vehicle display name lookup)
*/

import PDFKit
import SwiftUI
import SwiftData
import Foundation

/// A SwiftUI view that builds and displays a PDF report of subscriptions and recurring expenses.
/// - Parameter trackVehicleSelected: The initial scope — "All Vehicles" (or empty) for every
///   vehicle, or a specific `Vehicle8.name` to report on just that vehicle's subscriptions. The
///   report owns this value afterward via its in-report vehicle picker.
struct pdfReportSubscriptions: View {
	@Environment(\.modelContext) var modelContext

	@State private var scope: String
	@State private var pdfDocument: PDFDocument?
	@State private var zoomAction: ZoomAction?

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
						PDFReportFile.printDocument(doc, jobName: "Subscriptions")
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
			PDFReportFile.save(data: pdfData, fileName: "Expenditures")
		}
	}

	private func fetchSubscriptions() -> [Subscriptions] {
		let descriptor: FetchDescriptor<Subscriptions>
		if scope == "All Vehicles" || scope.isEmpty {
			descriptor = FetchDescriptor<Subscriptions>(sortBy: [
				SortDescriptor(\.vehicleId, order: .forward),
				SortDescriptor(\.category, order: .forward),
				SortDescriptor(\.subCategory, order: .forward)
			])
		} else {
			let vehicleId = scope
			descriptor = FetchDescriptor<Subscriptions>(
				predicate: #Predicate<Subscriptions> { $0.vehicleId == vehicleId },
				sortBy: [SortDescriptor(\.category, order: .forward), SortDescriptor(\.subCategory, order: .forward)]
			)
		}
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	/// Builds the full multipage PDF for the current `scope`. Returns raw PDF data suitable
	/// for wrapping in a PDFDocument and/or saving to disk.
	func generatePDFWithTable() -> Data? {
		let items = fetchSubscriptions()

		let columns: [PDFTableColumn] = [
			PDFTableColumn("SUBSCRIPTION", weight: 0.24),
			PDFTableColumn("DETAILS", weight: 0.38),
			PDFTableColumn("BILLING &\nINSTALL", weight: 0.38)
		]

		let rows: [[PDFCell]] = items.map { item in
			[
				subscriptionCell(item),
				detailsCell(item),
				billingCell(item)
			]
		}

		let scopeTitle = (scope == "All Vehicles" || scope.isEmpty) ? "All Vehicles" : functions.getVehicleDisplayName(vehicleId: scope, context: modelContext)
		let itemWord = items.count == 1 ? "subscription" : "subscriptions"
		let subtitle = "\(scopeTitle) • \(functions.formatDate_DDMMMyy(date: Date())) • \(items.count) \(itemWord)"

		return PDFReportRenderer.render(title: "Expenditures, Subscriptions and Recurring Payments", subtitle: subtitle, columns: columns, rows: rows, style: .standard)
	}

	// MARK: - Field-group builders
	//
	// Each cell drops empty strings and zero-valued numbers before handing fields to the
	// renderer, mirroring EditSubscriptions's own gating so sparse records produce short rows
	// instead of a wall of zeros.

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

	private func nextPaymentDue(_ item: Subscriptions) -> Date? {
		guard item.itemRecurring, item.itemRecurringDays > 0 else { return nil }
		let component: Calendar.Component
		switch item.itemRecurringInterval {
			case "Day": component = .day
			case "Year": component = .year
			default: component = .month
		}
		return Calendar.current.date(byAdding: component, value: item.itemRecurringDays, to: item.lastPayment)
	}

	private func subscriptionCell(_ item: Subscriptions) -> PDFCell {
		let vehicleName = item.vehicleId.isEmpty ? nil : functions.getVehicleDisplayName(vehicleId: item.vehicleId, context: modelContext)

		var groups: [PDFFieldGroup] = []
		if let identity = fieldGroup(nil, [
			("Vehicle", vehicleName),
			("Item", text(item.itemName)),
			("Category", text(item.category)),
			("Sub-Category", text(item.subCategory))
		]) {
			groups.append(identity)
		}

		return .imageWithGroups(item.image1, caption: item.image1Description, groups: groups)
	}

	private func detailsCell(_ item: Subscriptions) -> PDFCell {
		var groups: [PDFFieldGroup] = []
		if let details = fieldGroup(nil, [
			("Description", text(item.itemDescription)),
			("Notes", text(item.itemNotes)),
			("Vendor", text(item.itemVendor)),
			("Account #", text(item.accountNumber))
		]) {
			groups.append(details)
		}
		return .groups(groups)
	}

	private func billingCell(_ item: Subscriptions) -> PDFCell {
		var groups: [PDFFieldGroup] = []
		if let billing = fieldGroup(nil, [
			("Cost", item.itemCost != 0 ? functions.formatCurrency(dollars: item.itemCost) : nil),
			("Recurring", item.itemRecurring ? "Every \(item.itemRecurringDays) \(item.itemRecurringInterval)\(item.itemRecurringDays == 1 ? "" : "s")" : nil),
			("Last Payment", functions.formatDate_DDMMMyy(date: item.lastPayment)),
			("Next Due", nextPaymentDue(item).map { functions.formatDate_DDMMMyy(date: $0) })
		]) {
			groups.append(billing)
		}
		if let install = fieldGroup(nil, [
			("Miles", item.miles != 0 ? NumberFormatter.localizedString(from: NSNumber(value: item.miles), number: .decimal) : nil),
			("Engine Hours", item.engHours != 0 ? String(format: "%.1f hrs", item.engHours) : nil)
		]) {
			groups.append(install)
		}
		return .groups(groups)
	}
}

// MARK: - Previews
/// A small preview host that seeds an in-memory SwiftData container and presents two previews:
/// one for all vehicles and one for a specific vehicle.
private struct SubscriptionsReportPreviewHost: View {
	let container: ModelContainer

	init() {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try! ModelContainer(for: Subscriptions.self, Vehicle8.self, configurations: config)

		let context = container.mainContext

		let vehicle = Vehicle8(name: "Vehicle A", manufacturer: "Acme", model: "Hauler")
		context.insert(vehicle)

		let samples: [Subscriptions] = [
			Subscriptions(lastPayment: Date(), vehicleId: "Vehicle A", itemName: "Satellite Radio", itemDescription: "SiriusXM All Access", itemVendor: "SiriusXM", accountNumber: "SXM-1234", category: "Entertainment", itemRecurring: true, itemRecurringInterval: "Month", itemRecurringDays: 1, itemCost: 21.99),
			Subscriptions(vehicleId: "Vehicle A", itemName: "Roadside Assistance")
		]
		samples.forEach { context.insert($0) }
		try? context.save()

		self.container = container
	}

	var body: some View {
		Group {
			pdfReportSubscriptions(trackVehicleSelected: "All Vehicles")
				.previewDisplayName("All Vehicles")

			pdfReportSubscriptions(trackVehicleSelected: "Vehicle A")
				.previewDisplayName("Vehicle A")
		}
		.modelContainer(container)
	}
}

#Preview {
	SubscriptionsReportPreviewHost()
}
