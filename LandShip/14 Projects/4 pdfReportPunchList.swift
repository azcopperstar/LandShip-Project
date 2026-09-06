import SwiftUI
import SwiftData
import PDFKit
#if os(macOS)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct pdfReportPunchList: View {
	// Input selection
	@State private var trackVehicleSelected: String
	@State private var projectSubcategory: String
	
	// Data
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss
	@Query private var dataSet: [ProjectList]
	
	@State private var debugLayout: Bool = false
	@State private var pdfDocument: PDFDocument?
	@State private var diagStatus: String = "idle"
	@State private var csvDocument = CSVDocument(text: "")
	@State private var isExportingCSV = false

	let functions = Functions()
	
	// Init to configure @Query with simpler, explicit pieces to help the type-checker
	init(trackVehicleSelected: String, projectSubcategory: String) {
		_trackVehicleSelected = State(initialValue: trackVehicleSelected)
		_projectSubcategory = State(initialValue: projectSubcategory)
		
		// Prepare commonly used sort descriptors explicitly
		let sortPriority = SortDescriptor(\ProjectList.priority, order: .forward)
		let sortVehicle = SortDescriptor(\ProjectList.vehicleId, order: .forward)
		let sortCategory = SortDescriptor(\ProjectList.category, order: .forward)
		let sortSubCategory = SortDescriptor(\ProjectList.subCategory, order: .forward)
		let sortCreatedDesc = SortDescriptor(\ProjectList.createdAt, order: .reverse)
		
		if trackVehicleSelected == "All Vehicles" {
			let sRaw = projectSubcategory.trimmingCharacters(in: .whitespacesAndNewlines)
			let s = sRaw.isEmpty ? "General" : sRaw
			if s == "All Projects" {
				let predicate: Predicate<ProjectList> = #Predicate { item in
					true
				}
				self._dataSet = Query(filter: predicate, sort: [sortPriority, sortVehicle, sortCategory, sortSubCategory, sortCreatedDesc])
			} else {
				let predicate: Predicate<ProjectList> = #Predicate { item in
					item.subCategory == s
				}
				self._dataSet = Query(filter: predicate, sort: [sortPriority, sortVehicle, sortCategory, sortSubCategory, sortCreatedDesc])
			}
		} else {
			let v = trackVehicleSelected
			let sRaw = projectSubcategory.trimmingCharacters(in: .whitespacesAndNewlines)
			let s = sRaw.isEmpty ? "General" : sRaw
			if s == "All Projects" {
				let predicate: Predicate<ProjectList> = #Predicate { item in
					item.vehicleId == v
				}
				self._dataSet = Query(filter: predicate, sort: [sortPriority, sortCategory, sortSubCategory, sortCreatedDesc])
			} else {
				let predicate: Predicate<ProjectList> = #Predicate { item in
					item.vehicleId == v && item.subCategory == s
				}
				self._dataSet = Query(filter: predicate, sort: [sortPriority, sortCategory, sortSubCategory, sortCreatedDesc])
			}
		}
	}
	
	var body: some View {
		Group {
			if let doc = pdfDocument {
				PunchListPDFKitView(showing: doc)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.ignoresSafeArea()
			} else {
				VStack(spacing: 12) {
					ProgressView("Preparing Punch List…")
					Text(diagStatus)
						.font(.headline)
						.foregroundStyle(.red)
					Button("Generate Now") {
						generate()
					}
				}
				.padding()
			}
		}
		.navigationTitle("Punch List")
		.toolbar {
#if os(macOS)
			ToolbarItemGroup(placement: .automatic) {
				Button { dismiss() } label: {
					Label("Punch List", systemImage: "list.bullet")
				}
				VehicleScopePicker(scope: $trackVehicleSelected)
				subcategoryPicker
				Button {
					printPDF()
				} label: {
					Label("Print", systemImage: "printer")
				}
				.keyboardShortcut("p", modifiers: .command)
				.disabled(pdfDocument == nil)
				Button {
					csvDocument = CSVDocument(text: generateCSV())
					isExportingCSV = true
				} label: {
					Label("Export CSV", systemImage: "tablecells")
				}
			}
#else
			ToolbarItemGroup(placement: .topBarTrailing) {
				Button { dismiss() } label: {
					Label("Punch List", systemImage: "list.bullet")
				}
				VehicleScopePicker(scope: $trackVehicleSelected)
				subcategoryPicker
				Button {
					printPDF()
				} label: {
					Label("Print", systemImage: "printer")
				}
				.disabled(pdfDocument == nil)
				Button {
					csvDocument = CSVDocument(text: generateCSV())
					isExportingCSV = true
				} label: {
					Label("Export CSV", systemImage: "tablecells")
				}
			}
#endif
		}
		.fileExporter(isPresented: $isExportingCSV, document: csvDocument, contentType: .commaSeparatedText, defaultFilename: "Punch List") { _ in }
		.onAppear {
			generate()
		}
		.onChange(of: trackVehicleSelected) {
			generate()
		}
		.onChange(of: projectSubcategory) {
			generate()
		}
	}
	
	private func generate() {
		diagStatus = "scheduled"
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
			self.diagStatus = "rendering"
			let title = "PUNCH LIST — \(self.projectSubcategory.uppercased())"
			let items = self.fetchFilteredData()
			let rows = items.map { PunchListRow(from: $0) }
			let summary = self.punchListSummary(items)
			guard let data = Self.renderPDFData(title: title, rows: rows, vehicle: self.trackVehicleSelected, subcat: self.projectSubcategory, debug: self.debugLayout, summary: summary) else {
				print("[PunchListPDF] FAIL: renderPDFData returned nil")
				self.diagStatus = "Couldn't generate PDF. Please try again."
				return
			}
			guard let doc = PDFDocument(data: data) else {
				print("[PunchListPDF] FAIL: PDFDocument(data:) returned nil")
				self.diagStatus = "Couldn't generate PDF. Please try again."
				return
			}
			self.pdfDocument = doc
			PDFReportFile.save(data: data, fileName: "Punch List")
		}
	}

	// MARK: - CSV Export

	private func generateCSV() -> String {
		let items = dataSet
		let partCount = 5
		var headers = [
			"Inactive", "Created At", "Updated At", Vertical.current.assetSingular, "\(Vertical.current.assetSingular) Display Name",
			Vertical.current.primaryMeterLabel, "Engine Hours", "Item Name", "Description", "Notes", "Vendor",
			"Category", "Category Order", "Sub-Category", "Sub-Category Order", "Project Order", "Priority",
			"Completed", "Completed At", "Save In Logbook", "Saved To Logbook", "Linked Addition ID", "Item Cost", "Labor Cost",
			"Image 1 Description", "Image 2 Description", "Image 3 Description", "Image 4 Description", "Image 5 Description"
		]
		for i in 1...partCount {
			headers.append(contentsOf: ["Part \(i)", "Part \(i) Cost", "Part \(i) Unit", "Part \(i) Quantity"])
		}
		let rows: [[String]] = items.map { p in
			let vehicleName = p.vehicleId.isEmpty ? "" : functions.getVehicleDisplayName(vehicleId: p.vehicleId, context: modelContext)
			var row = [
				CSVField.bool(p.inactive), CSVField.date(p.createdAt), CSVField.date(p.updatedAt), p.vehicleId, vehicleName,
				CSVField.int(p.miles), CSVField.float(p.engHours), p.itemName, p.itemDescription, p.itemNotes, p.itemVendor,
				p.category, CSVField.int(p.categoryOrder), p.subCategory, CSVField.int(p.subcategoryOrder), CSVField.int(p.projectOrder), CSVField.int(p.priority),
				CSVField.bool(p.itemCompleted), CSVField.date(p.completedAt), CSVField.bool(p.saveInLogbook), CSVField.bool(p.savedToLogbook), p.additionsLinkId, CSVField.float(p.itemCost), CSVField.float(p.laborCost),
				p.image1Description, p.image2Description, p.image3Description, p.image4Description, p.image5Description
			]
			let parts: [(name: String, cost: Float, unit: String, quantity: Int)] = [
				(p.part1, p.part1cost, p.part1Unit, p.part1Quantity),
				(p.part2, p.part2cost, p.part2Unit, p.part2Quantity),
				(p.part3, p.part3cost, p.part3Unit, p.part3Quantity),
				(p.part4, p.part4cost, p.part4Unit, p.part4Quantity),
				(p.part5, p.part5cost, p.part5Unit, p.part5Quantity)
			]
			for part in parts {
				row.append(contentsOf: [part.name, CSVField.float(part.cost), part.unit, CSVField.int(part.quantity)])
			}
			return row
		}
		return CSVBuilder.build(headers: headers, rows: rows)
	}

	// MARK: Picker Views
	private var subcategoryPicker: some View {
		let subs = uniqueSubcategories()
		return Menu {
			Button("All Projects") { projectSubcategory = "All Projects" }
			ForEach(subs, id: \.self) { s in
				Button(s) { projectSubcategory = s }
			}
		} label: {
			Label(projectSubcategory, systemImage: "line.3.horizontal.decrease.circle")
		}
		.accessibilityLabel("Projects Filter")
	}
	
	// MARK: Helper Functions
	private func fetchFilteredData() -> [ProjectList] {
		var descriptor = FetchDescriptor<ProjectList>(
			sortBy: [
				SortDescriptor(\.priority, order: .forward),
				SortDescriptor(\.vehicleId, order: .forward),
				SortDescriptor(\.category, order: .forward),
				SortDescriptor(\.subCategory, order: .forward),
				SortDescriptor(\.createdAt, order: .reverse)
			]
		)
		
		// Apply filters based on current selections
		if trackVehicleSelected == "All Vehicles" {
			let sRaw = projectSubcategory.trimmingCharacters(in: .whitespacesAndNewlines)
			let s = sRaw.isEmpty ? "General" : sRaw
			if s != "All Projects" {
				descriptor.predicate = #Predicate<ProjectList> { item in
					item.subCategory == s
				}
			}
		} else {
			let v = trackVehicleSelected
			let sRaw = projectSubcategory.trimmingCharacters(in: .whitespacesAndNewlines)
			let s = sRaw.isEmpty ? "General" : sRaw
			if s == "All Projects" {
				descriptor.predicate = #Predicate<ProjectList> { item in
					item.vehicleId == v
				}
			} else {
				descriptor.predicate = #Predicate<ProjectList> { item in
					item.vehicleId == v && item.subCategory == s
				}
			}
		}
		
		let items = (try? modelContext.fetch(descriptor)) ?? []
		// Handle priority 0 items going to the end
		let withPriority = items.filter { $0.priority > 0 }
		let withoutPriority = items.filter { $0.priority == 0 }
		return withPriority + withoutPriority
	}

	/// Breaks down totals for just this punch list's own filtered items (vehicle + sub-category),
	/// not a cross-report/cross-category summary. `items` is already filtered to the current
	/// sub-category, so when `trackVehicleSelected` is "All Vehicles" this still breaks down per
	/// vehicle within that sub-category, same as every other report.
	private func punchListSummary(_ items: [ProjectList]) -> PDFReportSummary {
		let groups = pdfVehicleScopedSummaryGroups(scope: trackVehicleSelected, records: items, vehicleId: \.vehicleId, context: modelContext) { subset in
			let completedCount = subset.filter(\.itemCompleted).count
			let totalLabor = subset.reduce(Float(0)) { $0 + $1.laborCost }
			let totalParts = subset.reduce(Float(0)) { total, item in
				total + item.part1cost * Float(item.part1Quantity)
					+ item.part2cost * Float(item.part2Quantity)
					+ item.part3cost * Float(item.part3Quantity)
					+ item.part4cost * Float(item.part4Quantity)
					+ item.part5cost * Float(item.part5Quantity)
			}
			return [
				("Total Items", subset.isEmpty ? nil : "\(subset.count)"),
				("Completed", completedCount != 0 ? "\(completedCount)" : nil),
				("Total Labor", totalLabor != 0 ? pdfCurrencyString(totalLabor) : nil),
				("Total Parts", totalParts != 0 ? pdfCurrencyString(totalParts) : nil),
				("Total Cost", (totalLabor + totalParts) != 0 ? pdfCurrencyString(totalLabor + totalParts) : nil)
			]
		}
		return PDFReportSummary(title: "PUNCH LIST SUMMARY", groups: groups)
	}

	private func uniqueSubcategories() -> [String] {
		let descriptor = FetchDescriptor<ProjectList>()
		let allItems = (try? modelContext.fetch(descriptor)) ?? []
		let subs = Set(allItems.map { $0.subCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "General" : $0.subCategory }).sorted()
		return subs
	}
	
	// MARK: Print PDF
	private func printPDF() {
		guard let doc = pdfDocument else { return }
		PDFReportFile.printDocument(doc, jobName: "Punch List")
	}

	// MARK: PDF Generation
	private nonisolated static func renderPDFData(title: String, rows: [PunchListRow], vehicle: String, subcat: String, debug: Bool, summary: PDFReportSummary) -> Data? {
		// Page metrics (portrait Letter)
		let pageWidth: CGFloat = 612
		let pageHeight: CGFloat = 792
		let margin: CGFloat = 36
		let headerHeight: CGFloat = 40
		let footerHeight: CGFloat = 20
		
#if os(macOS)
		let data = NSMutableData()
		var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
		guard let consumer = CGDataConsumer(data: data as CFMutableData),
					let cg = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
		
		func beginPage(pageNumber: Int) {
			cg.beginPDFPage(nil)
			let nsGC = NSGraphicsContext(cgContext: cg, flipped: false)
			NSGraphicsContext.saveGraphicsState()
			NSGraphicsContext.current = nsGC
			Self.drawHeader(title: title, page: pageNumber, vehicle: vehicle, subcat: subcat, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, headerHeight: headerHeight)
			Self.drawFooter(page: pageNumber, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, footerHeight: footerHeight)
		}
		func endPage() {
			NSGraphicsContext.restoreGraphicsState()
			cg.endPDFPage()
		}
		
		var y: CGFloat = margin + headerHeight
		let maxBottom = pageHeight - margin - footerHeight
		var pageNumber = 1
		beginPage(pageNumber: pageNumber)
		
		// Draw table headers
		y += Self.drawPunchHeaders(at: CGPoint(x: margin, y: y), pageWidth: pageWidth, margin: margin, pageHeight: pageHeight)
		
		for record in rows {
			let rowHeight = Self.measureRow(record: record, contentWidth: pageWidth - 2*margin)
			if y + rowHeight > maxBottom {
				endPage()
				pageNumber += 1
				beginPage(pageNumber: pageNumber)
				y = margin + headerHeight
				y += Self.drawPunchHeaders(at: CGPoint(x: margin, y: y), pageWidth: pageWidth, margin: margin, pageHeight: pageHeight)
			}
			y += Self.drawPunchRow(record: record, at: CGPoint(x: margin, y: y), contentWidth: pageWidth - 2*margin, rowHeight: rowHeight, pageHeight: pageHeight, debug: debug)
		}

		if !summary.groups.isEmpty {
			let summaryHeight = Self.measureSummaryHeight(summary)
			if y + summaryHeight > maxBottom {
				endPage()
				pageNumber += 1
				beginPage(pageNumber: pageNumber)
				y = margin + headerHeight
			}
			_ = Self.drawSummaryMac(summary, at: CGPoint(x: margin, y: y), width: pageWidth - 2 * margin, pageHeight: pageHeight)
		}

		endPage()
		cg.closePDF()
		return data as Data
#else
		let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
		let renderer = UIGraphicsPDFRenderer(bounds: bounds)
		let data = renderer.pdfData { ctx in
			var y: CGFloat = margin + headerHeight
			let maxBottom = pageHeight - margin - footerHeight
			var pageNumber = 1
			
			func beginPage() {
				ctx.beginPage()
				Self.drawHeader_iOS(title: title, page: pageNumber, vehicle: vehicle, subcat: subcat, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, headerHeight: headerHeight)
				Self.drawFooter_iOS(page: pageNumber, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, footerHeight: footerHeight)
			}

			beginPage()
			y += Self.drawPunchHeaders_iOS(at: CGPoint(x: margin, y: y), pageWidth: pageWidth, margin: margin)
			
			for record in rows {
				let rowHeight = Self.measureRow(record: record, contentWidth: pageWidth - 2*margin)
				if y + rowHeight > maxBottom {
					pageNumber += 1
					beginPage()
					y = margin + headerHeight
					y += Self.drawPunchHeaders_iOS(at: CGPoint(x: margin, y: y), pageWidth: pageWidth, margin: margin)
				}
				y += Self.drawPunchRow_iOS(record: record, at: CGPoint(x: margin, y: y), contentWidth: pageWidth - 2*margin, rowHeight: rowHeight, debug: debug)
			}

			if !summary.groups.isEmpty {
				let summaryHeight = Self.measureSummaryHeight(summary)
				if y + summaryHeight > maxBottom {
					pageNumber += 1
					beginPage()
					y = margin + headerHeight
				}
				_ = Self.drawSummaryIOS(summary, at: CGPoint(x: margin, y: y), width: pageWidth - 2 * margin)
			}
		}
		return data
#endif
	}

	// MARK: Summary block (drawn after the last row, matching this file's existing per-platform
	// drawing style rather than the shared engine's — see the file-level note above
	// PunchListPDFKitView on why this report predates that engine). `summary.groups` is one
	// unheaded group when a specific vehicle is selected, or one heading-per-vehicle group plus a
	// trailing "ALL VEHICLES" group when scope is "All Vehicles" — see
	// `pdfVehicleScopedSummaryGroups` in PDFReportStyle.swift.
	private nonisolated static func measureSummaryHeight(_ summary: PDFReportSummary) -> CGFloat {
		let titleHeight: CGFloat = 24
		let lineHeight: CGFloat = 16
		let headingHeight: CGFloat = 18
		var contentHeight: CGFloat = 0
		for (index, group) in summary.groups.enumerated() {
			if let heading = group.heading, !heading.isEmpty {
				contentHeight += (index == 0 ? 0 : 6) + headingHeight
			}
			contentHeight += CGFloat(group.fields.count) * lineHeight
		}
		return titleHeight + contentHeight + 16
	}

#if os(macOS)
	@discardableResult
	private nonisolated static func drawSummaryMac(_ summary: PDFReportSummary, at origin: CGPoint, width: CGFloat, pageHeight: CGFloat) -> CGFloat {
		let height = measureSummaryHeight(summary)
		func flip(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: pageHeight - r.maxY, width: r.width, height: r.height) }

		NSColor.separatorColor.setStroke()
		NSBezierPath(rect: flip(CGRect(x: origin.x, y: origin.y, width: width, height: height))).stroke()

		let innerX = origin.x + 12
		let innerWidth = width - 24
		var y = origin.y + 8
		let rightPara = NSMutableParagraphStyle(); rightPara.alignment = .right

		NSAttributedString(string: summary.title, attributes: [.font: NSFont.boldSystemFont(ofSize: 12)])
			.draw(in: flip(CGRect(x: innerX, y: y, width: innerWidth, height: 16)))
		y += 24

		let headingFont = NSFont.boldSystemFont(ofSize: 10)
		let lineFont = NSFont.systemFont(ofSize: 10)
		for (index, group) in summary.groups.enumerated() {
			if let heading = group.heading, !heading.isEmpty {
				if index > 0 { y += 6 }
				NSAttributedString(string: heading.uppercased(), attributes: [.font: headingFont])
					.draw(in: flip(CGRect(x: innerX, y: y, width: innerWidth, height: 14)))
				y += 18
			}
			for field in group.fields {
				NSAttributedString(string: field.label, attributes: [.font: lineFont]).draw(in: flip(CGRect(x: innerX, y: y, width: innerWidth * 0.6, height: 14)))
				NSAttributedString(string: field.value, attributes: [.font: lineFont, .paragraphStyle: rightPara])
					.draw(in: flip(CGRect(x: innerX, y: y, width: innerWidth, height: 14)))
				y += 16
			}
		}

		return height
	}
#else
	@discardableResult
	private nonisolated static func drawSummaryIOS(_ summary: PDFReportSummary, at origin: CGPoint, width: CGFloat) -> CGFloat {
		let height = measureSummaryHeight(summary)
		UIColor.separator.setStroke()
		UIBezierPath(rect: CGRect(x: origin.x, y: origin.y, width: width, height: height)).stroke()

		let innerX = origin.x + 12
		let innerWidth = width - 24
		var y = origin.y + 8
		let rightPara = NSMutableParagraphStyle(); rightPara.alignment = .right

		NSAttributedString(string: summary.title, attributes: [.font: UIFont.boldSystemFont(ofSize: 12)])
			.draw(in: CGRect(x: innerX, y: y, width: innerWidth, height: 16))
		y += 24

		let headingFont = UIFont.boldSystemFont(ofSize: 10)
		let lineFont = UIFont.systemFont(ofSize: 10)
		for (index, group) in summary.groups.enumerated() {
			if let heading = group.heading, !heading.isEmpty {
				if index > 0 { y += 6 }
				NSAttributedString(string: heading.uppercased(), attributes: [.font: headingFont])
					.draw(in: CGRect(x: innerX, y: y, width: innerWidth, height: 14))
				y += 18
			}
			for field in group.fields {
				NSAttributedString(string: field.label, attributes: [.font: lineFont]).draw(in: CGRect(x: innerX, y: y, width: innerWidth * 0.6, height: 14))
				NSAttributedString(string: field.value, attributes: [.font: lineFont, .paragraphStyle: rightPara])
					.draw(in: CGRect(x: innerX, y: y, width: innerWidth, height: 14))
				y += 16
			}
		}

		return height
	}
#endif

	// MARK: Layout helpers
	private nonisolated static func measureRow(record: PunchListRow, contentWidth: CGFloat) -> CGFloat {
		// Layout: [Checkbox 24] [Name | Description] [Notes] and Parts box below
		let leftWidth = contentWidth * 0.60
		let rightWidth = contentWidth * 0.40
#if os(macOS)
		let font = NSFont.systemFont(ofSize: 10)
#else
		let font = UIFont.systemFont(ofSize: 10)
#endif
		let pad: CGFloat = 8
		let textHeight: (String, CGFloat) -> CGFloat = { text, width in
			let attr = [NSAttributedString.Key.font: font]
			let rect = NSAttributedString(string: text, attributes: attr)
				.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
			return ceil(rect.height)
		}
		let titleH = textHeight(record.itemName.trimmingCharacters(in: .whitespacesAndNewlines), leftWidth - 24 - pad)
		let descH = textHeight(record.itemDescription.trimmingCharacters(in: .whitespacesAndNewlines), leftWidth - 24 - pad)
		let notesH = textHeight(record.itemNotes.trimmingCharacters(in: .whitespacesAndNewlines), rightWidth)
		let mainH = max(26 + titleH + (descH > 0 ? (6 + descH) : 0), notesH)
		let partsH: CGFloat = 56 // increased from 44 to 56 for more parts space
		return pad + mainH + 6 + partsH + pad
	}
	
	// MARK: Drawing (macOS)
#if os(macOS)
	private nonisolated static func drawHeader(title: String, page: Int, vehicle: String, subcat: String, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat, headerHeight: CGFloat) {
		let titleFont = NSFont.boldSystemFont(ofSize: 14)
		let subFont = NSFont.systemFont(ofSize: 10)
		let left = NSMutableParagraphStyle(); left.alignment = .left
		let right = NSMutableParagraphStyle(); right.alignment = .right
		let subcatDisplay = subcat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "General" : subcat.trimmingCharacters(in: .whitespacesAndNewlines)
		let vehicleDisplay = FleetScope.isAll(vehicle) ? FleetScope.allDisplayLabel : vehicle
		let subtitle = "\(vehicleDisplay) • \(subcatDisplay)"
		let titleRectTop = CGRect(x: margin, y: margin, width: pageWidth - 2*margin, height: headerHeight/2)
		let subRectTop = CGRect(x: margin, y: margin + headerHeight/2 - 2, width: pageWidth - 2*margin, height: headerHeight/2)
		let titleRect = CGRect(x: titleRectTop.minX, y: pageHeight - titleRectTop.maxY, width: titleRectTop.width, height: titleRectTop.height)
		let subRect = CGRect(x: subRectTop.minX, y: pageHeight - subRectTop.maxY, width: subRectTop.width, height: subRectTop.height)
		NSAttributedString(string: title, attributes: [.font: titleFont, .paragraphStyle: left]).draw(in: titleRect)
		NSAttributedString(string: "\(subtitle) • \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)) — Page \(page)", attributes: [.font: subFont, .paragraphStyle: right]).draw(in: subRect)
	}
	private nonisolated static func drawFooter(page: Int, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat, footerHeight: CGFloat) {
		let f = NSFont.systemFont(ofSize: 9)
		let center = NSMutableParagraphStyle(); center.alignment = .center
		let rectTop = CGRect(x: margin, y: pageHeight - margin - footerHeight, width: pageWidth - 2*margin, height: footerHeight)
		let rect = CGRect(x: rectTop.minX, y: pageHeight - rectTop.maxY, width: rectTop.width, height: rectTop.height)
		NSAttributedString(string: "Page \(page)", attributes: [.font: f, .paragraphStyle: center]).draw(in: rect)
	}
	
	private nonisolated static func drawPunchHeaders(at origin: CGPoint, pageWidth: CGFloat, margin: CGFloat, pageHeight: CGFloat) -> CGFloat {
		let width = pageWidth - 2*margin
		let height: CGFloat = 22
		let rectTop = CGRect(x: origin.x, y: origin.y, width: width, height: height)
		let rect = CGRect(x: rectTop.minX, y: pageHeight - rectTop.maxY, width: rectTop.width, height: rectTop.height)
		NSColor(calibratedRed: 0.86, green: 0.92, blue: 0.98, alpha: 1).setFill()
		NSBezierPath(rect: rect).fill()
		let font = NSFont.boldSystemFont(ofSize: 11)
		let para = NSMutableParagraphStyle(); para.alignment = .left
		// Updated header text with checkbox column indicator and explicit Name label
		NSAttributedString(string: "☐  Name • Description • Notes • Parts", attributes: [.font: font, .paragraphStyle: para]).draw(in: rect.insetBy(dx: 8, dy: 4))
		return height
	}
	
	private nonisolated static func drawPunchRow(record: PunchListRow, at origin: CGPoint, contentWidth: CGFloat, rowHeight: CGFloat, pageHeight: CGFloat, debug: Bool) -> CGFloat {
		let leftWidth = contentWidth * 0.60
		let rightWidth = contentWidth * 0.40

		let rectTop = CGRect(x: origin.x, y: origin.y, width: contentWidth, height: rowHeight)
		let rect = CGRect(x: rectTop.minX, y: pageHeight - rectTop.maxY, width: rectTop.width, height: rectTop.height)
		NSColor(white: 0.97, alpha: 1).setFill()
		NSBezierPath(rect: rect).fill()
		
		// Save graphics state for this row
		NSGraphicsContext.saveGraphicsState()
		
		let titleFont = NSFont.boldSystemFont(ofSize: 11)
		let bodyFont = NSFont.systemFont(ofSize: 10)
		let notesLabelFont = NSFont.systemFont(ofSize: 9)
		let labelColor = NSColor.darkGray
		let textColor = NSColor.black
		
		// Establish a top anchor for row content in page coords
		let rowTop = rect.maxY
		let partsHeight: CGFloat = 56
		let pad: CGFloat = 8
		let partsTopY = rect.minY + pad
		_ = partsTopY + partsHeight + pad
		let contentTop = rowTop - pad
		
		let mainTop = contentTop

		// Checkbox
		let boxSize: CGFloat = 18
		let boxTop = CGRect(x: rect.minX + 4, y: mainTop - boxSize, width: boxSize, height: boxSize)
		NSColor.black.setStroke()
		let path = NSBezierPath(rect: boxTop)
		path.lineWidth = 1
		path.stroke()
		if record.itemCompleted {
			let check = NSBezierPath()
			check.move(to: CGPoint(x: boxTop.minX + 3, y: boxTop.midY))
			check.line(to: CGPoint(x: boxTop.midX - 1, y: boxTop.minY + 3))
			check.line(to: CGPoint(x: boxTop.maxX - 3, y: boxTop.maxY - 3))
			check.lineWidth = 2
			check.stroke()
		}
		
		// Priority ball
		var leftX = rect.minX + 4 + boxSize + 10
		if record.priority > 0 {
			let ballSize: CGFloat = 18
			let ballCenter = CGPoint(x: leftX + ballSize/2, y: mainTop - ballSize/2)
			let ballPath = NSBezierPath(ovalIn: CGRect(x: ballCenter.x - ballSize/2, y: ballCenter.y - ballSize/2, width: ballSize, height: ballSize))
			priorityColor(record.priority).setFill()
			ballPath.fill()
			
			let priorityText = "\(record.priority)"
			let priorityFont = NSFont.boldSystemFont(ofSize: 10)
			let priorityAttr = NSAttributedString(string: priorityText, attributes: [.font: priorityFont, .foregroundColor: NSColor.white])
			let prioritySize = priorityAttr.size()
			let priorityRect = CGRect(x: ballCenter.x - prioritySize.width/2, y: ballCenter.y - prioritySize.height/2, width: prioritySize.width, height: prioritySize.height)
			priorityAttr.draw(in: priorityRect)
			
			leftX += ballSize + 6
		}
		
		// New layout: Name at top spanning full width, then Parts (left) | Notes (right) below
		let nameHeight: CGFloat = 18
		let betweenNameAndParts: CGFloat = 8
		
		// Measure strings
		let descString = record.itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
		let notesString = record.itemNotes.trimmingCharacters(in: .whitespacesAndNewlines)
		let measureAttr: [NSAttributedString.Key: Any] = [.font: bodyFont]
		
		// Name at top (spanning from after checkbox/priority to right edge)
		let nameWidth = rect.width - (leftX - rect.minX) - pad * 2
		let nameRect = CGRect(x: leftX + 2, y: mainTop - nameHeight, width: nameWidth, height: nameHeight)
		NSAttributedString(string: record.itemName, attributes: [.font: titleFont, .foregroundColor: textColor]).draw(in: nameRect)
		
		// Description below name if any (full width)
		var currentY = nameRect.minY - betweenNameAndParts
		let descH: CGFloat
		if !descString.isEmpty {
			let descMeasure = NSAttributedString(string: descString, attributes: measureAttr)
			let descBounds = descMeasure.boundingRect(with: CGSize(width: nameWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
			descH = ceil(descBounds.height)
			let descRect = CGRect(x: leftX + 2, y: currentY - descH, width: nameWidth, height: descH)
			let descAttr = NSAttributedString(string: descString, attributes: [.font: bodyFont, .foregroundColor: textColor])
			descAttr.draw(with: descRect, options: [.usesLineFragmentOrigin], context: nil)
			currentY = descRect.minY - betweenNameAndParts
		} else {
			descH = 0
		}
		
		// Calculate positioning for Parts (left) and Notes (right) sections
		_ = currentY

		// Parts box on left (60% width)
		let partsX = rect.minX + pad
		let partsBoxWidth = leftWidth - pad
		let partsY = rect.minY + pad
		let partsRect = CGRect(x: partsX, y: partsY, width: partsBoxWidth, height: partsHeight)
		NSColor.clear.setFill()
		NSBezierPath(rect: partsRect).stroke()
		let partsLabelAttr = NSAttributedString(string: "Parts:", attributes: [.font: notesLabelFont, .foregroundColor: labelColor])
		let partsLabelRect = CGRect(x: partsRect.minX + 6, y: partsRect.maxY - 12, width: partsRect.width - 12, height: 10)
		partsLabelAttr.draw(in: partsLabelRect)
		let partsText = buildPartsText(record)
		let partsAttr = NSAttributedString(string: partsText, attributes: [.font: bodyFont, .foregroundColor: textColor])
		let partsTextRect = partsRect.insetBy(dx: 6, dy: 4)
		partsAttr.draw(in: partsTextRect)
		// Parts guide lines
		NSColor.separatorColor.withAlphaComponent(0.25).setStroke()
		let partsGuide = NSBezierPath()
		var py = partsRect.minY + 12
		while py < partsRect.maxY {
			partsGuide.move(to: CGPoint(x: partsRect.minX + 6, y: py))
			partsGuide.line(to: CGPoint(x: partsRect.maxX - 6, y: py))
			py += 12
		}
		partsGuide.lineWidth = 0.25
		partsGuide.stroke()
		
		// Notes box on right (40% width)
		let notesX = rect.minX + leftWidth + pad
		let notesWidth = rightWidth - pad
		let notesY = rect.minY + pad
		let notesRect = CGRect(x: notesX, y: notesY, width: notesWidth, height: partsHeight)
		NSColor.clear.setFill()
		NSBezierPath(rect: notesRect).stroke()
		let notesLabelAttr = NSAttributedString(string: "Notes:", attributes: [.font: notesLabelFont, .foregroundColor: labelColor])
		let notesLabelRect = CGRect(x: notesRect.minX + 6, y: notesRect.maxY - 12, width: notesWidth - 12, height: 10)
		notesLabelAttr.draw(in: notesLabelRect)
		let notesAttr = NSAttributedString(string: notesString, attributes: [.font: bodyFont, .foregroundColor: textColor])
		let notesTextRect = notesRect.insetBy(dx: 6, dy: 4)
		notesAttr.draw(with: notesTextRect, options: [.usesLineFragmentOrigin], context: nil)
		// Notes guide lines
		NSColor.separatorColor.withAlphaComponent(0.25).setStroke()
		let notesGuide = NSBezierPath()
		var ny = notesRect.minY + 12
		while ny < notesRect.maxY {
			notesGuide.move(to: CGPoint(x: notesRect.minX + 6, y: ny))
			notesGuide.line(to: CGPoint(x: notesRect.maxX - 6, y: ny))
			ny += 12
		}
		notesGuide.lineWidth = 0.25
		notesGuide.stroke()
		
		// Debug layout outlines
		if debug {
			NSColor.systemRed.setStroke(); NSBezierPath(rect: rect).stroke()
			NSColor.systemBlue.setStroke(); NSBezierPath(rect: nameRect).stroke()
			NSColor.systemPurple.setStroke(); NSBezierPath(rect: partsRect).stroke()
			NSColor.systemOrange.setStroke(); NSBezierPath(rect: notesRect).stroke()
		}
		
		// Border
		NSColor.separatorColor.setStroke()
		let border = NSBezierPath(rect: rect)
		border.lineWidth = 0.5
		border.stroke()

		// Restore graphics state for this row
		NSGraphicsContext.restoreGraphicsState()
		
		return rowHeight
	}
#endif
	
	// MARK: Drawing (iOS)
#if !os(macOS)
	private nonisolated static func drawHeader_iOS(title: String, page: Int, vehicle: String, subcat: String, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat, headerHeight: CGFloat) {
		let titleFont = UIFont.boldSystemFont(ofSize: 14)
		let subFont = UIFont.systemFont(ofSize: 10)
		let left = NSMutableParagraphStyle(); left.alignment = .left
		let right = NSMutableParagraphStyle(); right.alignment = .right
		let subcatDisplay = subcat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "General" : subcat.trimmingCharacters(in: .whitespacesAndNewlines)
		let vehicleDisplay = FleetScope.isAll(vehicle) ? FleetScope.allDisplayLabel : vehicle
		let subtitle = "\(vehicleDisplay) • \(subcatDisplay)"
		let titleRect = CGRect(x: margin, y: margin, width: pageWidth - 2*margin, height: headerHeight/2)
		let subRect = CGRect(x: margin, y: margin + headerHeight/2 - 2, width: pageWidth - 2*margin, height: headerHeight/2)
		NSAttributedString(string: title, attributes: [.font: titleFont, .paragraphStyle: left]).draw(in: titleRect)
		NSAttributedString(string: "\(subtitle) • \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)) — Page \(page)", attributes: [.font: subFont, .paragraphStyle: right]).draw(in: subRect)
	}
	private nonisolated static func drawFooter_iOS(page: Int, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat, footerHeight: CGFloat) {
		let f = UIFont.systemFont(ofSize: 9)
		let center = NSMutableParagraphStyle(); center.alignment = .center
		let rect = CGRect(x: margin, y: pageHeight - margin - footerHeight, width: pageWidth - 2*margin, height: footerHeight)
		NSAttributedString(string: "Page \(page)", attributes: [.font: f, .paragraphStyle: center]).draw(in: rect)
	}
	
	private nonisolated static func drawPunchHeaders_iOS(at origin: CGPoint, pageWidth: CGFloat, margin: CGFloat) -> CGFloat {
		let width = pageWidth - 2*margin
		let height: CGFloat = 22
		let rect = CGRect(x: origin.x, y: origin.y, width: width, height: height)
		UIColor(red: 0.86, green: 0.92, blue: 0.98, alpha: 1).setFill()
		UIBezierPath(rect: rect).fill()
		let font = UIFont.boldSystemFont(ofSize: 11)
		let para = NSMutableParagraphStyle(); para.alignment = .left
		// Updated header text with checkbox column indicator and explicit Name label
		NSAttributedString(string: "☐  Name • Description • Notes • Parts", attributes: [.font: font, .paragraphStyle: para]).draw(in: rect.insetBy(dx: 8, dy: 4))
		return height
	}
	
	private nonisolated static func drawPunchRow_iOS(record: PunchListRow, at origin: CGPoint, contentWidth: CGFloat, rowHeight: CGFloat, debug: Bool) -> CGFloat {
		let leftWidth = contentWidth * 0.60
		let rightWidth = contentWidth * 0.40
		let rect = CGRect(x: origin.x, y: origin.y, width: contentWidth, height: rowHeight)
		UIColor(white: 0.97, alpha: 1).setFill()
		UIBezierPath(rect: rect).fill()
		
		let partsHeight: CGFloat = 56
		let pad: CGFloat = 8
		let contentTop = rect.maxY - pad
		
		// Save graphics state for this row
		if let ctx = UIGraphicsGetCurrentContext() { ctx.saveGState() }

		let titleFont = UIFont.boldSystemFont(ofSize: 11)
		let bodyFont = UIFont.systemFont(ofSize: 10)

		// Checkbox - increased size from 16 to 18
		let boxSize: CGFloat = 18
		let box = CGRect(x: rect.minX + 4, y: contentTop - boxSize, width: boxSize, height: boxSize)
		UIColor.black.setStroke()
		let path = UIBezierPath(rect: box)
		path.lineWidth = 1
		path.stroke()
		if record.itemCompleted {
			let check = UIBezierPath()
			check.move(to: CGPoint(x: box.minX + 3, y: box.midY))
			check.addLine(to: CGPoint(x: box.midX - 1, y: box.maxY - 3))
			check.addLine(to: CGPoint(x: box.maxX - 3, y: box.minY + 3))
			check.lineWidth = 2
			check.stroke()
		}
		
		// Priority ball
		var leftX = rect.minX + 4 + boxSize + 10
		if record.priority > 0 {
			let ballSize: CGFloat = 18
			let ballCenter = CGPoint(x: leftX + ballSize/2, y: contentTop - ballSize/2)
			let ballPath = UIBezierPath(ovalIn: CGRect(x: ballCenter.x - ballSize/2, y: ballCenter.y - ballSize/2, width: ballSize, height: ballSize))
			priorityColor(record.priority).setFill()
			ballPath.fill()
			
			let priorityText = "\(record.priority)"
			let priorityFont = UIFont.boldSystemFont(ofSize: 10)
			let priorityAttr = NSAttributedString(string: priorityText, attributes: [.font: priorityFont, .foregroundColor: UIColor.white])
			let prioritySize = priorityAttr.size()
			let priorityRect = CGRect(x: ballCenter.x - prioritySize.width/2, y: ballCenter.y - prioritySize.height/2, width: prioritySize.width, height: prioritySize.height)
			priorityAttr.draw(in: priorityRect)
			
			leftX += ballSize + 6
		}
		
		// New layout: Name at top spanning full width, then Parts (left) | Notes (right) below
		let nameHeight: CGFloat = 18
		let betweenNameAndParts: CGFloat = 8
		let mainTop = contentTop
		
		// Measure strings
		let descString = record.itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
		let notesString = record.itemNotes.trimmingCharacters(in: .whitespacesAndNewlines)
		let measureAttr: [NSAttributedString.Key: Any] = [.font: bodyFont]
		
		// Name at top (spanning from after checkbox/priority to right edge)
		let nameWidth = rect.width - (leftX - rect.minX) - pad * 2
		let nameRect = CGRect(x: leftX + 2, y: mainTop - nameHeight, width: nameWidth, height: nameHeight)
		NSAttributedString(string: record.itemName, attributes: [.font: titleFont, .foregroundColor: UIColor.black]).draw(in: nameRect)
		
		// Description below name if any (full width)
		var currentY = nameRect.minY - betweenNameAndParts
		let descH: CGFloat
		if !descString.isEmpty {
			let descMeasure = NSAttributedString(string: descString, attributes: measureAttr)
			let descBounds = descMeasure.boundingRect(with: CGSize(width: nameWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
			descH = ceil(descBounds.height)
			let descRect = CGRect(x: leftX + 2, y: currentY - descH, width: nameWidth, height: descH)
			let descAttr = NSAttributedString(string: descString, attributes: [.font: bodyFont, .foregroundColor: UIColor.black])
			descAttr.draw(with: descRect, options: [.usesLineFragmentOrigin], context: nil)
			currentY = descRect.minY - betweenNameAndParts
		} else {
			descH = 0
		}
		
		// Parts box on left (60% width)
		let partsX = rect.minX + pad
		let partsBoxWidth = leftWidth - pad
		let partsY = rect.minY + pad
		let partsRect = CGRect(x: partsX, y: partsY, width: partsBoxWidth, height: partsHeight)
		UIColor.clear.setFill()
		UIBezierPath(rect: partsRect).stroke()
		let partsLabelFont = UIFont.systemFont(ofSize: 9)
		let partsLabelAttr = NSAttributedString(string: "Parts:", attributes: [.font: partsLabelFont, .foregroundColor: UIColor.darkGray])
		let partsLabelRect = CGRect(x: partsRect.minX + 6, y: partsRect.maxY - 12, width: partsRect.width - 12, height: 10)
		partsLabelAttr.draw(in: partsLabelRect)
		let partsText = buildPartsText(record)
		let partsAttr = NSAttributedString(string: partsText, attributes: [.font: bodyFont, .foregroundColor: UIColor.black])
		let partsTextRect = partsRect.insetBy(dx: 6, dy: 4)
		partsAttr.draw(in: partsTextRect)
		// Parts guide lines
		UIColor.separator.withAlphaComponent(0.25).setStroke()
		let partsGuide = UIBezierPath()
		var py = partsRect.minY + 12
		while py < partsRect.maxY {
			partsGuide.move(to: CGPoint(x: partsRect.minX + 6, y: py))
			partsGuide.addLine(to: CGPoint(x: partsRect.maxX - 6, y: py))
			py += 12
		}
		partsGuide.lineWidth = 0.25
		partsGuide.stroke()
		
		// Notes box on right (40% width)
		let notesX = rect.minX + leftWidth + pad
		let notesWidth = rightWidth - pad
		let notesY = rect.minY + pad
		let notesLabelFont = UIFont.systemFont(ofSize: 9)
		let notesRect = CGRect(x: notesX, y: notesY, width: notesWidth, height: partsHeight)
		UIColor.clear.setFill()
		UIBezierPath(rect: notesRect).stroke()
		let notesLabelAttr = NSAttributedString(string: "Notes:", attributes: [.font: notesLabelFont, .foregroundColor: UIColor.darkGray])
		let notesLabelRect = CGRect(x: notesRect.minX + 6, y: notesRect.maxY - 12, width: notesWidth - 12, height: 10)
		notesLabelAttr.draw(in: notesLabelRect)
		let notesAttr = NSAttributedString(string: notesString, attributes: [.font: bodyFont, .foregroundColor: UIColor.black])
		let notesTextRect = notesRect.insetBy(dx: 6, dy: 4)
		notesAttr.draw(with: notesTextRect, options: [.usesLineFragmentOrigin], context: nil)
		// Notes guide lines
		UIColor.separator.withAlphaComponent(0.25).setStroke()
		let notesGuide = UIBezierPath()
		var ny = notesRect.minY + 12
		while ny < notesRect.maxY {
			notesGuide.move(to: CGPoint(x: notesRect.minX + 6, y: ny))
			notesGuide.addLine(to: CGPoint(x: notesRect.maxX - 6, y: ny))
			ny += 12
		}
		notesGuide.lineWidth = 0.25
		notesGuide.stroke()
		
		// Debug layout outlines
		if debug {
			UIColor.systemRed.setStroke(); UIBezierPath(rect: rect).stroke()
			UIColor.systemBlue.setStroke(); UIBezierPath(rect: nameRect).stroke()
			UIColor.systemPurple.setStroke(); UIBezierPath(rect: partsRect).stroke()
			UIColor.systemOrange.setStroke(); UIBezierPath(rect: notesRect).stroke()
		}
		
		// Border
		UIColor.separator.setStroke()
		let border = UIBezierPath(rect: rect)
		border.lineWidth = 0.5
		border.stroke()
		
		// Restore graphics state for this row
		if let ctx = UIGraphicsGetCurrentContext() { ctx.restoreGState() }
		
		return rowHeight
	}
#endif
	
	// MARK: Priority Color Helper
#if os(macOS)
	private nonisolated static func priorityColor(_ priority: Int) -> NSColor {
		switch priority {
		case 1: return NSColor.systemBlue
		case 2: return NSColor.systemGreen
		case 3: return NSColor.systemYellow
		case 4: return NSColor.systemOrange
		case 5: return NSColor.systemRed
		default: return NSColor.systemGray
		}
	}
#else
	private nonisolated static func priorityColor(_ priority: Int) -> UIColor {
		switch priority {
		case 1: return UIColor.systemBlue
		case 2: return UIColor.systemGreen
		case 3: return UIColor.systemYellow
		case 4: return UIColor.systemOrange
		case 5: return UIColor.systemRed
		default: return UIColor.systemGray
		}
	}
#endif
	
	private nonisolated static func buildPartsText(_ r: PunchListRow) -> String {
		func one(_ name: String, _ qty: Int, _ unit: String) -> String? {
			let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !trimmedName.isEmpty else { return nil }
			let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
			if qty > 0 {
				if trimmedUnit.isEmpty {
					return "x\(qty) \(trimmedName)"
				} else {
					return "x\(qty) \(trimmedUnit) \(trimmedName)"
				}
			} else {
				return trimmedName
			}
		}
		return [
			one(r.part1, r.part1Quantity, r.part1Unit),
			one(r.part2, r.part2Quantity, r.part2Unit),
			one(r.part3, r.part3Quantity, r.part3Unit),
			one(r.part4, r.part4Quantity, r.part4Unit),
			one(r.part5, r.part5Quantity, r.part5Unit)
		].compactMap { $0 }.joined(separator: "\n")
	}
}

	private struct PunchListRow {
		let itemName: String
		let itemDescription: String
		let itemNotes: String
		let itemCompleted: Bool
		let priority: Int
		let part1: String; let part1Quantity: Int; let part1Unit: String; let part1cost: Float
		let part2: String; let part2Quantity: Int; let part2Unit: String; let part2cost: Float
		let part3: String; let part3Quantity: Int; let part3Unit: String; let part3cost: Float
		let part4: String; let part4Quantity: Int; let part4Unit: String; let part4cost: Float
		let part5: String; let part5Quantity: Int; let part5Unit: String; let part5cost: Float
		init(from r: ProjectList) {
			itemName = r.itemName; itemDescription = r.itemDescription; itemNotes = r.itemNotes
			itemCompleted = r.itemCompleted; priority = r.priority
			part1 = r.part1; part1Quantity = r.part1Quantity; part1Unit = r.part1Unit; part1cost = r.part1cost
			part2 = r.part2; part2Quantity = r.part2Quantity; part2Unit = r.part2Unit; part2cost = r.part2cost
			part3 = r.part3; part3Quantity = r.part3Quantity; part3Unit = r.part3Unit; part3cost = r.part3cost
			part4 = r.part4; part4Quantity = r.part4Quantity; part4Unit = r.part4Unit; part4cost = r.part4cost
			part5 = r.part5; part5Quantity = r.part5Quantity; part5Unit = r.part5Unit; part5cost = r.part5cost
		}
	}

// MARK: - PDFKitView wrappers
// Named distinctly from the shared PDFKitView in PDFReportStyle.swift (this report predates the
// shared engine and doesn't take a zoomAction binding) to avoid a top-level redeclaration.
#if os(macOS)
private struct PunchListPDFKitView: NSViewRepresentable {
	let pdfDocument: PDFDocument
	init(showing doc: PDFDocument) { self.pdfDocument = doc }
	func makeNSView(context: Context) -> PDFView {
		let v = PrintablePDFView()
		v.document = pdfDocument
		v.autoScales = true
		v.displayMode = .singlePageContinuous
		v.displayDirection = .vertical
		return v
	}
	func updateNSView(_ nsView: PDFView, context: Context) {
		if nsView.document !== pdfDocument {
			nsView.document = pdfDocument
			nsView.autoScales = true
		}
	}
}
#else
// PDFView subclass that re-applies fit-to-page scaling on every bounds change.
// This handles sheet animation: layoutSubviews fires with the real frame, unlike
// UIViewRepresentable's updateUIView which fires before the frame is finalized.
private final class AutoScalePDFView: PDFView {
	override func layoutSubviews() {
		super.layoutSubviews()
		guard document != nil, bounds.width > 0, bounds.height > 0 else { return }
		let fit = scaleFactorForSizeToFit
		if fit > 0.001 && abs(scaleFactor - fit) > 0.001 {
			scaleFactor = fit
		}
	}
}

private struct PunchListPDFKitView: UIViewRepresentable {
	let pdfDocument: PDFDocument
	init(showing doc: PDFDocument) { self.pdfDocument = doc }
	func makeUIView(context: Context) -> PDFView {
		let v = AutoScalePDFView()
		v.document = pdfDocument
		v.autoScales = true
		v.displayMode = .singlePageContinuous
		v.displayDirection = .vertical
		return v
	}
	func updateUIView(_ uiView: PDFView, context: Context) {
		if uiView.document !== pdfDocument {
			uiView.document = pdfDocument
			uiView.autoScales = true
		}
		// Do NOT touch autoScales/scaleFactor here — AutoScalePDFView.layoutSubviews handles it
	}
}
#endif

#Preview {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: ProjectList.self, Settings1.self, configurations: config)
	let context = container.mainContext
	// Seed a couple of punch list items
	let now = Date()
	let r1 = ProjectList(createdAt: now, updatedAt: now, vehicleId: "Vehicle A", miles: 0, engHours: 0, itemName: "Replace filter", itemDescription: "Air filter under hood", itemNotes: "Use OEM part.", itemVendor: "", category: "Engine", subCategory: "Oil", itemCompleted: false, completedAt: now, saveInLogbook: false, savedToLogbook: false, itemCost: 0, laborCost: 0, part1: "Air Filter", part1cost: 18.5, part1Unit: "ea", part1Quantity: 1)
	let r2 = ProjectList(createdAt: now, updatedAt: now, vehicleId: "Vehicle A", miles: 0, engHours: 0, itemName: "Change oil", itemDescription: "5W-30 full synthetic", itemNotes: "Next change in 3 months.", itemVendor: "", category: "Engine", subCategory: "Oil", itemCompleted: true, completedAt: now, saveInLogbook: false, savedToLogbook: false, itemCost: 0, laborCost: 0, part1: "Oil", part1cost: 30, part1Unit: "qt", part1Quantity: 5, part2: "Filter", part2cost: 12, part2Unit: "ea", part2Quantity: 1)
	context.insert(r1); context.insert(r2)
	return NavigationStack {
		pdfReportPunchList(trackVehicleSelected: "Vehicle A", projectSubcategory: "Oil")
			.modelContainer(container)
	}
}

