//
//  pdfReportService.swift
//  LandShip
//
//  Created by JP on 9/30/25.
//
//  Overview:
//  This SwiftUI view generates, displays, prints, and exports a PDF report of service records
//  stored via SwiftData. It is fully cross‑platform (macOS and iOS/iPadOS) using PDFKit for
//  rendering, and conditionally compiled UI wrappers for PDFView. The report includes a header,
//  footer, multi‑column table with auto‑wrapping cells, alternating row backgrounds, and page
//  breaks with repeated table headers.
//
//  Key responsibilities:
//  - Fetch ServiceRecords1 objects from SwiftData, filtered by a selected vehicle or all vehicles.
//  - Generate a PDF (vector content) with headers, footers, and a data table.
//  - Display the PDF using PDFKitView with zoom controls and fit/actual size options.
//  - Allow printing, sharing, and “Save As…” depending on platform.
//  - Provide a SwiftUI Preview with in‑memory SwiftData and seeded sample data.
//
//  Important types used from elsewhere in the project (not defined in this file):
//  - ServiceRecords1: SwiftData model representing a service record.
//  - Settings1: SwiftData model representing user preferences/units.
//  - Functions: Utility type providing formatting helpers (dates, currency, units).
//  - PrefsFunctions: Utility type providing settings loading (e.g., loadSettingsArray).
//
//  Note on coordinate systems:
//  - iOS drawing uses a UIKit coordinate system (origin at top‑left by default for text drawing).
//  - macOS drawing here uses manual conversions from a top‑left conceptual origin to Quartz’s
//    bottom‑left origin for correct placement, especially for header/footer and table backgrounds.
//
//  Note on performance:
//  - The PDF is generated once on appear or on demand, then kept in memory as PDFDocument.
//  - Zooming is delegated to PDFView via a binding that triggers the appropriate action.
//

import PDFKit
import SwiftUI
import SwiftData
import Foundation
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Main View

struct pdfReportService: View {
	// MARK: Data & State

	// Fetch the service records we will render into the PDF.
	// This uses SwiftData's @Query and is configured in init based on selected vehicle.
	@Query private var dataSet: [ServiceRecords1]
	
	// Tracks the currently selected vehicle across views. When "All Vehicles" is selected,
	// the query is not filtered; otherwise it is filtered by vehicleId (see init).
//	@Binding var trackVehicleSelected: String
	let trackVehicleSelected: String

	// The SwiftData model context (injected from environment) used to fetch settings and other data.
	@Environment(\.modelContext) var modelContext

	// Tracks whether all vehicles are selected; used elsewhere in the app to govern button state.
	@State private var allVehiclesSelected: Bool = true

	// Holds the generated PDF, which is displayed in the embedded PDFKitView.
	@State private var pdfDocument: PDFDocument?

	// Utility helpers from elsewhere in the project for formatting and preferences.
	let functions: Functions = Functions()
	let prefsFunc: PrefsFunctions = PrefsFunctions()

	// Zoom action binding used to control the embedded PDFView instance (zoom in/out, fit, actual).
	@State private var zoomAction: ZoomAction?

	#if canImport(UIKit) && !os(macOS)
	// iOS/iPadOS only: temporary file URL for sharing the PDF and a flag to present/dismiss the sheet.
	@State private var shareURL: URL?
	@State private var isSharing: Bool = false
	#endif

	// Add this near your other @State vars
	@State private var isGenerating = false
	@State private var lastGeneratedKey: String? = nil
	@State private var unitsCached: [String] = Array(repeating: "", count: 13)
	@State private var didLoadUnits: Bool = false
	@State private var generationScheduled: Bool = false
	@State private var lastPDFHash: Int? = nil
	// Add this helper to create a stable identity for the current dataset
	private var dataSetKey: String {
		let sorted = dataSet.sorted { lhs, rhs in
			if lhs.vehicleId != rhs.vehicleId { return lhs.vehicleId < rhs.vehicleId }
			if lhs.mxDate != rhs.mxDate { return lhs.mxDate < rhs.mxDate }
			if lhs.Miles != rhs.Miles { return lhs.Miles < rhs.Miles }
			if lhs.engHours != rhs.engHours { return lhs.engHours < rhs.engHours }
			return lhs.mxName < rhs.mxName
		}
		return sorted.map { "\($0.vehicleId)|\($0.mxDate.timeIntervalSince1970)|\($0.Miles)|\($0.engHours)|\($0.mxName)" }
			.joined(separator: "#")
	}
	
	// MARK: Init (configure @Query based on vehicle selection)

	// Configure the query to either fetch all records or those for a specific vehicle.
	init(trackVehicleSelected: String) {
		self.trackVehicleSelected = trackVehicleSelected
		let vehicleId = trackVehicleSelected
		print ("pdf-vehicleId: \(vehicleId)")

		if vehicleId != "All Vehicles" {
			// Filter by the selected vehicle and sort by vehicleId then date descending.
			self._dataSet = Query(
				filter: #Predicate<ServiceRecords1> { $0.vehicleId == vehicleId },
				sort: [
					SortDescriptor(\.vehicleId, order: .forward),
					SortDescriptor(\.mxDate, order: .reverse)
				]
			)
		} else {
			// All vehicles: sort by vehicleId then date descending.
			self._dataSet = Query(
				sort: [
					SortDescriptor(\.vehicleId, order: .forward),
					SortDescriptor(\.mxDate, order: .reverse)
				]
			)
		}
	}

	// MARK: Body

	var body: some View {
		Group {
			// If a PDFDocument is available, embed it in our PDFKitView with zoom controls.
			if let doc = pdfDocument {
				PDFKitView(showing: doc, zoomAction: $zoomAction)
					.ignoresSafeArea()
			} else {
				// If not yet generated or failed, show progress and a retry button.
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
			scheduleGeneration()
		}
		.onChange(of: dataSetKey) { _ in
			scheduleGeneration()
		}
		.toolbar {
			// Provide a toolbar with regenerate, zoom controls, and print/share/save actions.
			ToolbarItem(placement: .automatic) {
				Button("Regenerate") {
					print("[Toolbar] Regenerate tapped")
					// Force a new render regardless of previous dataset key
					lastGeneratedKey = nil
					triggerGenerationIfNeeded()
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
					printPDF()
				} label: {
					Label("Print", systemImage: "printer")
				}
				.disabled(pdfDocument == nil)
			}
			#if os(macOS)
			// On macOS, present an NSSavePanel for “Save As…”.
			ToolbarItem(placement: .automatic) {
				Button {
					saveAsPDF()
				} label: {
					Label("Save As…", systemImage: "square.and.arrow.down")
				}
				.keyboardShortcut("S", modifiers: [.command, .shift])
				.disabled(pdfDocument == nil)
			}
			#else
			// On iOS/iPadOS, present the system share sheet.
			ToolbarItem(placement: .automatic) {
				Button {
					sharePDFiOS()
				} label: {
					Label("Share…", systemImage: "square.and.arrow.up")
				}
				.disabled(pdfDocument == nil)
			}
			#endif
		}
		#if canImport(UIKit) && !os(macOS)
        // iOS/iPadOS only: gate the sheet while generating to avoid feedback loops
        .sheet(
            isPresented: Binding(
                get: { isSharing && !isGenerating },
                set: { newValue in
                    // When the system dismisses the sheet, reflect it back to isSharing
                    if !newValue { isSharing = false }
                    else { isSharing = true }
                }
            ),
            onDismiss: {
                print("[Sheet] onDismiss")
                // Clean up temp file after sharing completes.
                if let url = shareURL {
                    try? FileManager.default.removeItem(at: url)
                }
                shareURL = nil
            }
        ) {
            if let url = shareURL {
                ActivityView(activityItems: [url])
                    .onAppear { print("[Sheet] content appeared with URL: \(url.lastPathComponent)") }
            } else {
                Text("No PDF to share.")
                    .onAppear { print("[Sheet] content appeared with no URL") }
            }
        }
		#endif
	}

	// Debounced generation to avoid rapid successive triggers from view updates
	private func scheduleGeneration() {
		print("scheduleGeneration fired")
		guard !generationScheduled else { return }
		generationScheduled = true
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
			generationScheduled = false
			triggerGenerationIfNeeded()
			print("triggerGenerationIfNeeded fired") 
		}
	}

	// Triggers generation only when needed based on the dataset signature and generation state.
	private func triggerGenerationIfNeeded() {
		// Avoid re-entry and avoid regenerating for the same dataset
		guard lastGeneratedKey != dataSetKey, !isGenerating else { return }
		isGenerating = true
		defer { isGenerating = false }
		generateAndShowPDF()
		lastGeneratedKey = dataSetKey
	}

	// MARK: High-level PDF generation and display

	// Generates the PDF data from the current dataset and shows it in the UI. Also writes a copy to disk.
	private func generateAndShowPDF() {
		// Load settings once and cache to avoid touching modelContext repeatedly (prevents @Query churn)
    
		print("/Generating PDF/", dataSet.count)
		
		if !didLoadUnits {
            let loaded = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1")
                ?? Array(repeating: "", count: 13)
            unitsCached = loaded
            didLoadUnits = true
        }
        let units = unitsCached

        // Create the PDF data; if successful, set pdfDocument and persist a copy to Documents.
        guard let pdfData = generatePDFWithTable(units: units) else { return }
        let hash = pdfData.hashValue
        guard hash != lastPDFHash else { return }
        if let doc = PDFDocument(data: pdfData) {
            self.pdfDocument = doc
            lastPDFHash = hash
            _ = savePDF(data: pdfData, fileName: "Service Records")
        }
	}

	// MARK: - Zoom model

	// Simple enum of zoom actions that our PDFKitView interprets to adjust the PDFView.
	enum ZoomAction {
		case zoomIn
		case zoomOut
		case fit
		case actual
	}

	// MARK: - PDFKitView wrappers (macOS and iOS variants)

	#if os(macOS)
	// macOS wrapper around PDFView using NSViewRepresentable.
	struct PDFKitView: NSViewRepresentable {
		let pdfDocument: PDFDocument
		@Binding var zoomAction: ZoomAction?

		init(showing pdfDoc: PDFDocument, zoomAction: Binding<ZoomAction?>) {
			self.pdfDocument = pdfDoc
			self._zoomAction = zoomAction
		}

		func makeNSView(context: Context) -> PDFView {
			let pdfView = PDFView()
			pdfView.document = pdfDocument
			pdfView.autoScales = true
			pdfView.displaysPageBreaks = true
			pdfView.displayMode = .singlePageContinuous
			pdfView.displayDirection = .vertical
			return pdfView
		}

		func updateNSView(_ nsView: PDFView, context: Context) {
			// Respond to a requested zoom action, then clear it.
			guard let action = zoomAction else { return }
			switch action {
			case .zoomIn:
				nsView.zoomIn(nil)
			case .zoomOut:
				nsView.zoomOut(nil)
			case .fit:
				nsView.autoScales = true
			case .actual:
				// 1.0 is 100% on macOS PDFView.
				nsView.autoScales = false
				nsView.scaleFactor = 1.0
			}
			DispatchQueue.main.async {
				self.zoomAction = nil
			}
		}
	}
	#else
	// iOS/iPadOS wrapper around PDFView using UIViewRepresentable.
	struct PDFKitView: UIViewRepresentable {
		let pdfDocument: PDFDocument
		@Binding var zoomAction: ZoomAction?

		init(showing pdfDoc: PDFDocument, zoomAction: Binding<ZoomAction?>) {
			self.pdfDocument = pdfDoc
			self._zoomAction = zoomAction
		}

		func makeUIView(context: Context) -> PDFView {
			let pdfView = PDFView()
			pdfView.document = pdfDocument
			pdfView.autoScales = true
			pdfView.displaysPageBreaks = true
			pdfView.displayMode = .singlePageContinuous
			pdfView.displayDirection = .vertical
			// Reasonable min/max for pinch + buttons.
			pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
			pdfView.maxScaleFactor = max(pdfView.minScaleFactor * 5, 4.0)
			return pdfView
		}

		func updateUIView(_ uiView: PDFView, context: Context) {
			// Respond to a requested zoom action, then clear it.
			guard let action = zoomAction else { return }
			switch action {
			case .zoomIn:
				let next = min(uiView.scaleFactor * 1.1, uiView.maxScaleFactor)
				uiView.autoScales = false
				uiView.scaleFactor = next
			case .zoomOut:
				let next = max(uiView.scaleFactor / 1.1, uiView.minScaleFactor)
				uiView.autoScales = false
				uiView.scaleFactor = next
			case .fit:
				uiView.autoScales = true
				// Ensure min is up to date with current bounds.
				uiView.minScaleFactor = uiView.scaleFactorForSizeToFit
				uiView.scaleFactor = uiView.minScaleFactor
			case .actual:
				uiView.autoScales = false
				// 1.0 is 100% on iOS PDFView.
				uiView.scaleFactor = 1.0
			}
			DispatchQueue.main.async {
				self.zoomAction = nil
			}
		}
	}
	#endif

	// MARK: - Row content helpers

	// Build concise parts list and cost totals for a record.
	// Returns:
	// - partsList: multi‑line text listing parts, quantities/units, and per‑unit costs.
	// - partsCost: numeric total of parts cost (qty * costEach).
	private func partsInfo(for record: ServiceRecords1) -> (partsList: String, partsCost: Float) {
		// Local light-weight struct to hold a normalized part line.
		struct PartLine { let name: String; let unit: String; let qty: Int; let cost: Float }
		var parts: [PartLine] = []

		// Collect up to 5 parts from the record if present.
		if !record.part1.isEmpty && record.part1Quantity > 0 { parts.append(.init(name: record.part1, unit: record.part1Unit, qty: record.part1Quantity, cost: record.part1cost)) }
		if !record.part2.isEmpty && record.part2Quantity > 0 { parts.append(.init(name: record.part2, unit: record.part2Unit, qty: record.part2Quantity, cost: record.part2cost)) }
		if !record.part3.isEmpty && record.part3Quantity > 0 { parts.append(.init(name: record.part3, unit: record.part3Unit, qty: record.part3Quantity, cost: record.part3cost)) }
		if !record.part4.isEmpty && record.part4Quantity > 0 { parts.append(.init(name: record.part4, unit: record.part4Unit, qty: record.part4Quantity, cost: record.part4cost)) }
		if !record.part5.isEmpty && record.part5Quantity > 0 { parts.append(.init(name: record.part5, unit: record.part5Unit, qty: record.part5Quantity, cost: record.part5cost)) }

		// Build a descriptive list; include qty/unit and cost per unit when available.
		let list = parts.map { p -> String in
			let qtyUnit = p.qty > 0 ? "\n\(p.qty) \(p.unit)" : ""
			let costEach = p.cost > 0 ? " @ \(functions.formatCurrency(dollars: p.cost))" : ""
			return "\(p.name)\(qtyUnit)\(costEach)"
		}.joined(separator: "\n\n")

		// Compute the parts total (qty * costEach), clamping to non‑negative values.
		let cost: Float = parts.reduce(0) { partial, p in
			let qty = max(0, p.qty)
			let each = max(0, p.cost)
			return partial + Float(qty) * each
		}
		return (list, cost)
	}

	// Produce the 12 column strings for a record (in the same order as the table columns).
	// Columns: VEHICLE, DATE, ODOM, ENG HRS, SERVICE ITEM, DESCRIPTION, VENDOR, LABOR, PARTS, TOTAL, PARTS USED, NOTES
	func valuesForRecord(_ record: ServiceRecords1) -> [String] {
		let vehicle = record.vehicleId
		let date = functions.formatDate_DDMMM_yyyy(date: record.mxDate)
		let miles = NumberFormatter.localizedString(from: NSNumber(value: record.Miles), number: .decimal)
		let hours = String(format: "%.1f", record.engHours)

		let serviceItem = record.mxName
		let description = record.mxDescription
		let vendor = record.vendor

		let (partsList, partsCost) = partsInfo(for: record)
		let labor = functions.formatCurrency(dollars: max(0, record.laborCost))
		let parts = functions.formatCurrency(dollars: max(0, partsCost))
		let total = functions.formatCurrency(dollars: max(0, record.laborCost + partsCost))

		let notes = record.Notes

		return [vehicle, date, miles, hours, serviceItem, description, vendor, labor, parts, total, partsList, notes]
	}
	
	// MARK: - PDF generation (cross‑platform)

	// Unified cross‑platform PDF generator that draws:
	// - Page header (title, subtitle with vehicle filter, date, page number)
	// - Multi‑row table header with background and grid
	// - Data rows with alternating background, wrapping text, and grid lines
	// - Page footer with page number
	//
	// The layout uses a fixed “page” rectangle (landscape letter by default: 792x612),
	// and top‑left conceptual coordinates for text blocks. macOS drawing converts these to
	// Quartz coordinate space; iOS drawing uses UIKit’s direct drawing.
	func generatePDFWithTable(units: [String]) -> Data? {
		// Page size (landscape US Letter) and margins.
		let pageWidth: CGFloat = 792
		let pageHeight: CGFloat = 612
		let margin: CGFloat = 20

		// Space reserved for page header/footer (outside the table).
		let headerHeight: CGFloat = 36
		let footerHeight: CGFloat = 24 // Footer matches style used in other reports.

		// Units for ODOM (distance) column obtained from user settings.
		let distanceExpanded = functions.getUnits(unit: units[UnitIndex.distance])

		// Table header labels; allowing multi‑line headers with '\n' for compactness.
		let headerRows: [[String]] = [
			["VEHICLE", "DATE", "ODOM\n(\(distanceExpanded))", "ENG\nHRS", "SERVICE\nITEM", "DESCRIPTION", "VENDOR", "LABOR", "PARTS", "TOTAL", "PARTS\nUSED", "NOTES"]
		]

		// Content area width (inside margins) and a minimum row height for data rows.
		let contentWidth = pageWidth - 2 * margin
		let minRowHeight: CGFloat = 32

		// 12 column widths as a fraction of content width (sum approximately 1.0).
		let columnWeights: [CGFloat] = [
			0.09, // VEHICLE
			0.05, // DATE
			0.06, // ODOM
			0.05, // ENG HRS
			0.11, // SERVICE ITEM
			0.11, // DESCRIPTION
			0.07, // VENDOR
			0.06, // LABOR
			0.06, // PARTS
			0.06, // TOTAL
			0.09, // PARTS LIST
			0.20  // NOTES
		]
		let columnWidths = columnWeights.map { $0 * contentWidth }

		// Header text content: report title, vehicle filter title, and current date.
		let reportTitle = "Service Records Report"
		let vehicleTitle = (trackVehicleSelected == "All Vehicles") ? "All Vehicles" : trackVehicleSelected
		let dateTitle = functions.formatDate_DDMMMyy(date: Date())

		#if os(macOS)
		// macOS: Create a CGContext with a PDF data consumer.
		let data = NSMutableData()
		var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
		guard
			let consumer = CGDataConsumer(data: data as CFMutableData),
			let cgContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
		else { return nil }

		var pageNumber = 1

		// Helper: begin a new page and draw header/footer.
		func beginMacPage() {
			cgContext.beginPDFPage(nil)
			var nsGraphicsContext = NSGraphicsContext(cgContext: cgContext, flipped: false)
			NSGraphicsContext.saveGraphicsState()
			NSGraphicsContext.current = nsGraphicsContext

			// Header and footer.
			drawPageHeader(margin: margin,
			               pageWidth: pageWidth,
			               pageHeight: pageHeight,
			               headerHeight: headerHeight,
			               title: reportTitle,
			               subtitle: vehicleTitle,
			               dateText: dateTitle,
			               pageNumber: pageNumber)
			drawPageFooter(margin: margin,
			               pageWidth: pageWidth,
			               pageHeight: pageHeight,
			               footerHeight: footerHeight,
			               pageNumber: pageNumber)
		}

		// Helper: end the current page and restore graphics state.
		func endMacPage() {
			NSGraphicsContext.restoreGraphicsState()
			cgContext.endPDFPage()
		}

		beginMacPage()

		// Track our current y position (top‑down concept) and compute a bottom bound for content.
		var currentY: CGFloat = margin + headerHeight
		let maxContentBottom = pageHeight - margin - footerHeight

		// Draw table headers and move currentY by the header block height.
		let headerBlockHeight = drawTableHeaders(at: CGPoint(x: margin, y: currentY),
																					 columnWidths: columnWidths,
																					 headerRows: headerRows,
																					 minRowHeight: 24,
																					 pageHeight: pageHeight)
		currentY += headerBlockHeight

		// Iterate the dataset, computing each row’s height and page‑breaking as needed.
		for (index, record) in dataSet.enumerated() {
			let rowHeight = computeRowHeight(for: record, columnWidths: columnWidths, minRowHeight: minRowHeight)
			if currentY + rowHeight > maxContentBottom {
				// New page: end, increment page number, begin, and redraw headers.
				endMacPage()
				pageNumber += 1
				beginMacPage()
				currentY = margin + headerHeight
				let h = drawTableHeaders(at: CGPoint(x: margin, y: currentY),
																 columnWidths: columnWidths,
																 headerRows: headerRows,
																 minRowHeight: 24,
																 pageHeight: pageHeight)
				currentY += h
			}
			// Draw row and advance.
			drawTableRow(record: record,
									 at: CGPoint(x: margin, y: currentY),
									 columnWidths: columnWidths,
									 rowHeight: rowHeight,
									 rowIndex: index,
									 pageHeight: pageHeight)
			currentY += rowHeight
		}

		// Finish the page and close the PDF.
		endMacPage()
		cgContext.closePDF()
		return data as Data

		#else
		// iOS/iPadOS: Use UIGraphicsPDFRenderer for simple PDF creation.
		let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
		let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)
		let data = pdfRenderer.pdfData { context in
			var pageNumber = 1

			// Helper: begin a new page and draw header/footer.
			func beginIOSPage() {
				context.beginPage()
				drawPageHeader(margin: margin,
				               pageWidth: pageWidth,
				               pageHeight: pageHeight,
				               headerHeight: headerHeight,
				               title: reportTitle,
				               subtitle: vehicleTitle,
				               dateText: dateTitle,
				               pageNumber: pageNumber)
				drawPageFooter(margin: margin,
				               pageWidth: pageWidth,
				               pageHeight: pageHeight,
				               footerHeight: footerHeight,
				               pageNumber: pageNumber)
			}

			beginIOSPage()

			// Track y position and content bottom bound for page breaking.
			var currentY: CGFloat = margin + headerHeight
			let maxContentBottom = pageHeight - margin - footerHeight

			// Draw table headers and advance currentY.
			let headerBlockHeight = drawTableHeaders(at: CGPoint(x: margin, y: currentY),
																						 columnWidths: columnWidths,
																						 headerRows: headerRows,
																						 minRowHeight: 36)
			currentY += headerBlockHeight

			// Iterate dataset and page break if row would overflow.
			for (index, record) in dataSet.enumerated() {
				let rowHeight = computeRowHeight(for: record, columnWidths: columnWidths, minRowHeight: minRowHeight)
				if currentY + rowHeight > maxContentBottom {
					pageNumber += 1
					beginIOSPage()
					currentY = margin + headerHeight
					let h = drawTableHeaders(at: CGPoint(x: margin, y: currentY),
																	 columnWidths: columnWidths,
																	 headerRows: headerRows,
																	 minRowHeight: 20)
					currentY += h
				}
				drawTableRow(record: record, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, rowHeight: rowHeight, rowIndex: index)
				currentY += rowHeight
			}
		}
		return data
		#endif
	}

	// MARK: - Page header/footer drawing (cross‑platform)

	// Draw page header: title (left), subtitle+date (left), and page number (right).
	// macOS variant converts to Quartz coordinates; iOS draws directly.
	func drawPageHeader(margin: CGFloat,
	                    pageWidth: CGFloat,
	                    pageHeight: CGFloat,
	                    headerHeight: CGFloat,
	                    title: String,
	                    subtitle: String,
	                    dateText: String,
	                    pageNumber: Int) {
		#if os(macOS)
		let titleFont = NSFont.boldSystemFont(ofSize: 14)
		let subFont = NSFont.systemFont(ofSize: 10)
		let paragraphLeft = NSMutableParagraphStyle()
		paragraphLeft.alignment = .left
		let paragraphRight = NSMutableParagraphStyle()
		paragraphRight.alignment = .right

		let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .paragraphStyle: paragraphLeft]
		let subAttrs: [NSAttributedString.Key: Any] = [.font: subFont, .paragraphStyle: paragraphLeft]
		let rightAttrs: [NSAttributedString.Key: Any] = [.font: subFont, .paragraphStyle: paragraphRight]

		// Define top‑left origin rects and convert to Quartz coordinates for drawing.
		let titleRectTop = CGRect(x: margin, y: margin, width: pageWidth - 2*margin, height: headerHeight/2)
		let subtitleRectTop = CGRect(x: margin, y: margin + headerHeight/2 - 2, width: pageWidth - 2*margin, height: headerHeight/2)

		let titleRect = CGRect(x: titleRectTop.origin.x,
		                       y: pageHeight - titleRectTop.origin.y - titleRectTop.height,
		                       width: titleRectTop.width,
		                       height: titleRectTop.height)
		let subtitleRect = CGRect(x: subtitleRectTop.origin.x,
		                          y: pageHeight - subtitleRectTop.origin.y - subtitleRectTop.height,
		                          width: subtitleRectTop.width,
		                          height: subtitleRectTop.height)

		NSAttributedString(string: title, attributes: titleAttrs).draw(in: titleRect)
		let subtitleCombined = "\(subtitle) • \(dateText)"
		NSAttributedString(string: subtitleCombined, attributes: subAttrs).draw(in: subtitleRect)

		// Right‑aligned page number in header.
		let pageRectTop = CGRect(x: margin, y: margin, width: pageWidth - 2*margin, height: headerHeight/2)
		let pageRect = CGRect(x: pageRectTop.origin.x,
		                      y: pageHeight - pageRectTop.origin.y - pageRectTop.height,
		                      width: pageRectTop.width,
		                      height: pageRectTop.height)
		NSAttributedString(string: "Page \(pageNumber)", attributes: rightAttrs).draw(in: pageRect)
		#else
		let titleFont = UIFont.boldSystemFont(ofSize: 14)
		let subFont = UIFont.systemFont(ofSize: 10)
		let paragraphLeft = NSMutableParagraphStyle()
		paragraphLeft.alignment = .left
		let paragraphRight = NSMutableParagraphStyle()
		paragraphRight.alignment = .right

		let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .paragraphStyle: paragraphLeft]
		let subAttrs: [NSAttributedString.Key: Any] = [.font: subFont, .paragraphStyle: paragraphLeft]
		let rightAttrs: [NSAttributedString.Key: Any] = [.font: subFont, .paragraphStyle: paragraphRight]

		let titleRect = CGRect(x: margin, y: margin, width: pageWidth - 2*margin, height: headerHeight/2)
		let subtitleRect = CGRect(x: margin, y: margin + headerHeight/2 - 2, width: pageWidth - 2*margin, height: headerHeight/2)

		NSAttributedString(string: title, attributes: titleAttrs).draw(in: titleRect)
		let subtitleCombined = "\(subtitle) • \(dateText)"
		NSAttributedString(string: subtitleCombined, attributes: subAttrs).draw(in: subtitleRect)

		let pageRect = CGRect(x: margin, y: margin, width: pageWidth - 2*margin, height: headerHeight/2)
		NSAttributedString(string: "Page \(pageNumber)", attributes: rightAttrs).draw(in: pageRect)
		#endif
	}

	// Draw page footer: centered page number.
	// macOS variant converts to Quartz coordinates; iOS draws directly.
	func drawPageFooter(margin: CGFloat,
	                    pageWidth: CGFloat,
	                    pageHeight: CGFloat,
	                    footerHeight: CGFloat,
	                    pageNumber: Int) {
		#if os(macOS)
		let footFont = NSFont.systemFont(ofSize: 9)
		let paragraphCenter = NSMutableParagraphStyle()
		paragraphCenter.alignment = .center
		let attrs: [NSAttributedString.Key: Any] = [.font: footFont, .paragraphStyle: paragraphCenter]

		let footerRectTop = CGRect(x: margin, y: pageHeight - margin - footerHeight, width: pageWidth - 2*margin, height: footerHeight)
		let footerRect = CGRect(x: footerRectTop.origin.x,
		                        y: pageHeight - footerRectTop.origin.y - footerRectTop.height,
		                        width: footerRectTop.width,
		                        height: footerRectTop.height)
		NSAttributedString(string: "Page \(pageNumber)", attributes: attrs).draw(in: footerRect)
		#else
		let footFont = UIFont.systemFont(ofSize: 9)
		let paragraphCenter = NSMutableParagraphStyle()
		paragraphCenter.alignment = .center
		let attrs: [NSAttributedString.Key: Any] = [.font: footFont, .paragraphStyle: paragraphCenter]

		let footerRect = CGRect(x: margin, y: pageHeight - margin - footerHeight, width: pageWidth - 2*margin, height: footerHeight)
		NSAttributedString(string: "Page \(pageNumber)", attributes: attrs).draw(in: footerRect)
		#endif
	}

	// MARK: - Table header drawing

	// Draws one or more header rows and returns the total header block height.
	// - origin: top‑left origin where the header block starts.
	// - columnWidths: widths for each column, matching data columns.
	// - headerRows: array of rows, each an array of strings (supports '\n' line breaks).
	// - minRowHeight: minimum height per header row to ensure readability.
	// - pageHeight: macOS only, used to convert to Quartz coordinates.
	@discardableResult
	func drawTableHeaders(at origin: CGPoint, columnWidths: [CGFloat], headerRows: [[String]], minRowHeight: CGFloat, pageHeight: CGFloat? = nil) -> CGFloat {
		#if os(macOS)
		let topFont = NSFont.boldSystemFont(ofSize: 10)
		let bottomFont = NSFont.boldSystemFont(ofSize: 9)
		let headerFill = NSColor(calibratedRed: 0.86, green: 0.92, blue: 0.98, alpha: 1.0)
		let separatorColor = NSColor.separatorColor
		#else
		let topFont = UIFont.boldSystemFont(ofSize: 10)
		let bottomFont = UIFont.boldSystemFont(ofSize: 9)
		let headerFill = UIColor(red: 0.86, green: 0.92, blue: 0.98, alpha: 1.0)
		let separatorColor = UIColor.separator
		#endif

		// Centered, wrapping paragraph styles for header rows.
		let topParagraph = NSMutableParagraphStyle()
		topParagraph.alignment = .center
		topParagraph.lineBreakMode = .byWordWrapping

		let bottomParagraph = NSMutableParagraphStyle()
		bottomParagraph.alignment = .center
		bottomParagraph.lineBreakMode = .byWordWrapping

		let topAttrs: [NSAttributedString.Key: Any] = [
			.font: topFont,
			.paragraphStyle: topParagraph
		]
		let bottomAttrs: [NSAttributedString.Key: Any] = [
			.font: bottomFont,
			.paragraphStyle: bottomParagraph
		]

		// Measure height of each header row given the column widths and wrapping.
		func measureRowHeight(_ row: [String], attrs: [NSAttributedString.Key: Any]) -> CGFloat {
			var maxH: CGFloat = 0
			for (index, text) in row.enumerated() {
				let width = columnWidths[min(index, columnWidths.count - 1)] - 8 // horizontal insets
				let bounding = NSAttributedString(string: text, attributes: attrs)
					.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
												options: [.usesLineFragmentOrigin, .usesFontLeading],
												context: nil)
				maxH = max(maxH, ceil(bounding.height) + 12) // vertical insets
			}
			return max(minRowHeight, maxH)
		}

		// Compute per‑row heights and total header height.
		var perRowHeights: [CGFloat] = []
		for (rowIndex, row) in headerRows.enumerated() {
			let attrs = (rowIndex == 0) ? topAttrs : bottomAttrs
			perRowHeights.append(measureRowHeight(row, attrs: attrs))
		}
		let totalHeaderHeight = perRowHeights.reduce(0, +)

		// Fill background for the header block.
		let totalWidth = columnWidths.reduce(0, +)
		let headerRectTop = CGRect(x: origin.x, y: origin.y, width: totalWidth, height: totalHeaderHeight)

		#if os(macOS)
		let ph = pageHeight ?? 0
		let headerRect = CGRect(x: headerRectTop.origin.x,
		                        y: ph - headerRectTop.origin.y - headerRectTop.height,
		                        width: headerRectTop.width,
		                        height: headerRectTop.height)
		headerFill.setFill()
		NSBezierPath(rect: headerRect).fill()
		#else
		headerFill.setFill()
		UIBezierPath(rect: headerRectTop).fill()
		#endif

		// Draw vertical and horizontal grid lines over the header.
		separatorColor.setStroke()

		#if os(macOS)
		let gridPath = NSBezierPath()
		gridPath.lineWidth = 1.0

		// Vertical dividers (including left and right borders).
		var runningX = headerRectTop.origin.x
		let topY = headerRectTop.origin.y
		let bottomY = headerRectTop.origin.y + headerRectTop.height
		func yConv(_ y: CGFloat) -> CGFloat { (pageHeight ?? 0) - y }

		gridPath.move(to: CGPoint(x: runningX, y: yConv(topY)))
		gridPath.line(to: CGPoint(x: runningX, y: yConv(bottomY)))
		for width in columnWidths {
			runningX += width
			gridPath.move(to: CGPoint(x: runningX, y: yConv(topY)))
			gridPath.line(to: CGPoint(x: runningX, y: yConv(bottomY)))
		}

		// Horizontal lines between header rows and bottom border.
		var runningYTop = headerRectTop.origin.y
		for rowIdx in 0..<perRowHeights.count {
			runningYTop += perRowHeights[rowIdx]
			gridPath.move(to: CGPoint(x: headerRectTop.origin.x, y: yConv(runningYTop)))
			gridPath.line(to: CGPoint(x: headerRectTop.origin.x + totalWidth, y: yConv(runningYTop)))
		}

		gridPath.stroke()
		#else
		let gridPath = UIBezierPath()
		gridPath.lineWidth = 1.0

		// Vertical dividers (including left and right borders).
		var runningX = headerRectTop.origin.x
		gridPath.move(to: CGPoint(x: runningX, y: headerRectTop.origin.y))
		gridPath.addLine(to: CGPoint(x: runningX, y: headerRectTop.origin.y + headerRectTop.height))
		for width in columnWidths {
			runningX += width
			gridPath.move(to: CGPoint(x: runningX, y: headerRectTop.origin.y))
			gridPath.addLine(to: CGPoint(x: runningX, y: headerRectTop.origin.y + headerRectTop.height))
		}

		// Horizontal lines between header rows and bottom border.
		var runningY = headerRectTop.origin.y
		for rowIdx in 0..<perRowHeights.count {
			runningY += perRowHeights[rowIdx]
			gridPath.move(to: CGPoint(x: headerRectTop.origin.x, y: runningY))
			gridPath.addLine(to: CGPoint(x: headerRectTop.origin.x + totalWidth, y: runningY))
		}

		gridPath.stroke()
		#endif

		// Draw header text in each cell, respecting per‑row heights and column widths.
		var rowStartYTop = origin.y
		for (rowIndex, row) in headerRows.enumerated() {
			let rowHeight = perRowHeights[rowIndex]
			var textX = origin.x
			for (colIndex, text) in row.enumerated() {
				let width = columnWidths[min(colIndex, columnWidths.count - 1)]
				let cellRectTop = CGRect(x: textX, y: rowStartYTop, width: width, height: rowHeight)
				#if os(macOS)
				let ph = pageHeight ?? 0
				let cellRect = CGRect(x: cellRectTop.origin.x,
				                      y: ph - cellRectTop.origin.y - cellRectTop.height,
				                      width: cellRectTop.width,
				                      height: cellRectTop.height)
				NSAttributedString(string: text, attributes: topAttrs)
					.draw(in: cellRect.insetBy(dx: 4, dy: 6))
				#else
				NSAttributedString(string: text, attributes: topAttrs)
					.draw(in: cellRectTop.insetBy(dx: 4, dy: 6))
				#endif
				textX += width
			}
			rowStartYTop += rowHeight
		}

		return totalHeaderHeight
	}

	// MARK: - Row height measurement

	// Compute the wrapped row height for a given record based on its text content and column widths.
	// Uses a small font and per‑column paragraph styles (left for text‑heavy columns, centered otherwise).
	func computeRowHeight(for record: ServiceRecords1, columnWidths: [CGFloat], minRowHeight: CGFloat) -> CGFloat {
		let values = valuesForRecord(record)
		let notesIndex = 11 // last column is NOTES (kept for reference if needed in future)

		#if os(macOS)
		let font = NSFont.systemFont(ofSize: 8)
		#else
		let font = UIFont.systemFont(ofSize: 8)
		#endif

		// Build per‑column paragraph styles: left for DESCRIPTION, PARTS LIST, NOTES; center otherwise.
		var paragraphStyles: [NSMutableParagraphStyle] = []
		for i in 0..<values.count {
			let p = NSMutableParagraphStyle()
			p.lineBreakMode = .byWordWrapping
			if [5, 10, 11].contains(i) {
				p.alignment = .left // DESCRIPTION, PARTS LIST, NOTES
			} else {
				p.alignment = .center
			}
			paragraphStyles.append(p)
		}

		// Measure maximum cell height across all columns for this row.
		var maxHeight: CGFloat = minRowHeight
		for (index, text) in values.enumerated() {
			let width = columnWidths[min(index, columnWidths.count - 1)] - 8 // horizontal inset
			let attributes: [NSAttributedString.Key: Any] = [
				.font: font,
				.paragraphStyle: paragraphStyles[index]
			]
			let bounding = NSAttributedString(string: text, attributes: attributes)
				.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
											options: [.usesLineFragmentOrigin, .usesFontLeading],
											context: nil)
			let cellHeight = ceil(bounding.height) + 12 // vertical insets
			maxHeight = max(maxHeight, cellHeight)
		}
		return maxHeight
	}

	// MARK: - Row drawing

	// Draw a single table row: optional alternating background, cell text with wrapping,
	// and per‑row vertical dividers plus bottom border.
	// macOS variant converts to Quartz coordinates; iOS draws directly.
	func drawTableRow(record: ServiceRecords1, at origin: CGPoint, columnWidths: [CGFloat], rowHeight: CGFloat, rowIndex: Int, pageHeight: CGFloat? = nil) {
		let values = valuesForRecord(record)
		let notesIndex = 11 // last column is NOTES (kept for reference if needed in future)

		#if os(macOS)
		let font = NSFont.systemFont(ofSize: 8)
		let separatorColor = NSColor.separatorColor
		// Light gray alternating fill for odd rows.
		let rowAltFill = NSColor(white: 0.96, alpha: 1.0)
		#else
		let font = UIFont.systemFont(ofSize: 8)
		let separatorColor = UIColor.separator
		// Light gray alternating fill for odd rows.
		let rowAltFill = UIColor(white: 0.96, alpha: 1.0)
		#endif

		// Build per‑column paragraph styles.
		var paragraphStyles: [NSMutableParagraphStyle] = []
		for i in 0..<values.count {
			let p = NSMutableParagraphStyle()
			p.lineBreakMode = .byWordWrapping
			if [5, 10, 11].contains(i) {
				p.alignment = .left // DESCRIPTION, PARTS LIST, NOTES
			} else {
				p.alignment = .center
			}
			paragraphStyles.append(p)
		}

		// Fill background for alternating rows (odd index).
		if rowIndex % 2 == 1 {
			let totalWidth = columnWidths.reduce(0, +)
			#if os(macOS)
			let ph = pageHeight ?? 0
			let rowRectTop = CGRect(x: origin.x, y: origin.y, width: totalWidth, height: rowHeight)
			let rowRect = CGRect(x: rowRectTop.origin.x,
			                     y: ph - rowRectTop.origin.y - rowRectTop.height,
			                     width: rowRectTop.width,
			                     height: rowRectTop.height)
			rowAltFill.setFill()
			NSBezierPath(rect: rowRect).fill()
			#else
			let rowRect = CGRect(x: origin.x, y: origin.y, width: totalWidth, height: rowHeight)
			rowAltFill.setFill()
			UIBezierPath(rect: rowRect).fill()
			#endif
		}

		// Draw text in each column (wrapped).
		var textX = origin.x
		for (index, value) in values.enumerated() {
			let width = columnWidths[min(index, columnWidths.count - 1)]
			let valueRectTop = CGRect(x: textX, y: origin.y, width: width, height: rowHeight)
			let attributes: [NSAttributedString.Key: Any] = [
				.font: font,
				.paragraphStyle: paragraphStyles[index]
			]
			#if os(macOS)
			let ph = pageHeight ?? 0
			let valueRect = CGRect(x: valueRectTop.origin.x,
			                       y: ph - valueRectTop.origin.y - valueRectTop.height,
			                       width: valueRectTop.width,
			                       height: valueRectTop.height)
			NSAttributedString(string: value, attributes: attributes)
				.draw(in: valueRect.insetBy(dx: 4, dy: 6))
			#else
			NSAttributedString(string: value, attributes: attributes)
				.draw(in: valueRectTop.insetBy(dx: 4, dy: 6))
			#endif
			textX += width
		}

		// Draw full‑width row grid (vertical lines for all columns + bottom border).
		let totalWidth = columnWidths.reduce(0, +)
		separatorColor.setStroke()

		#if os(macOS)
		let rowPath = NSBezierPath()
		rowPath.lineWidth = 0.5

		// Left border.
		func yConv(_ yTop: CGFloat) -> CGFloat { (pageHeight ?? 0) - yTop }
		rowPath.move(to: CGPoint(x: origin.x, y: yConv(origin.y)))
		rowPath.line(to: CGPoint(x: origin.x, y: yConv(origin.y + rowHeight)))

		// Vertical dividers for all columns.
		var runningX = origin.x
		for width in columnWidths {
			runningX += width
			rowPath.move(to: CGPoint(x: runningX, y: yConv(origin.y)))
			rowPath.line(to: CGPoint(x: runningX, y: yConv(origin.y + rowHeight)))
		}

		// Bottom border of the row.
		rowPath.move(to: CGPoint(x: origin.x, y: yConv(origin.y + rowHeight)))
		rowPath.line(to: CGPoint(x: origin.x + totalWidth, y: yConv(origin.y + rowHeight)))
		rowPath.stroke()
		#else
		let rowPath = UIBezierPath()
		rowPath.lineWidth = 0.5

		// Left border.
		rowPath.move(to: CGPoint(x: origin.x, y: origin.y))
		rowPath.addLine(to: CGPoint(x: origin.x, y: origin.y + rowHeight))

		// Vertical dividers for all columns.
		var runningX = origin.x
		for width in columnWidths {
			runningX += width
			rowPath.move(to: CGPoint(x: runningX, y: origin.y))
			rowPath.addLine(to: CGPoint(x: runningX, y: origin.y + rowHeight))
		}

		// Bottom border of the row.
		rowPath.move(to: CGPoint(x: origin.x, y: origin.y + rowHeight))
		rowPath.addLine(to: CGPoint(x: origin.x + totalWidth, y: origin.y + rowHeight))
		rowPath.stroke()
		#endif
	}

	// MARK: - File I/O helpers

	// Save raw PDF data to the app's Documents directory using a simple file name.
	// Returns the file URL if successful, nil on error.
	func savePDF(data: Data, fileName: String) -> URL? {
		let fileManager = FileManager.default
		guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
			return nil
		}
		let fileURL = documentDirectory.appendingPathComponent("\(fileName).pdf")

		do {
			try data.write(to: fileURL)
			return fileURL
		} catch {
			print("Error saving PDF: \(error.localizedDescription)")
			return nil
		}
	}

	#if os(macOS)
	// MARK: macOS: “Save As…” via NSSavePanel

	// Presents a save panel and writes the current PDFDocument to the chosen location.
	private func saveAsPDF() {
		guard let doc = pdfDocument, let data = doc.dataRepresentation() else { return }

		let panel = NSSavePanel()
		panel.allowedContentTypes = [.pdf]
		panel.canCreateDirectories = true
		panel.isExtensionHidden = false

		// Default name: include vehicle selection and date/time stamp.
		let vehicleTitle = (trackVehicleSelected == "All Vehicles") ? "All Vehicles" : trackVehicleSelected
		let dateStamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
			.replacingOccurrences(of: "/", with: "-")
			.replacingOccurrences(of: ":", with: "-")
			.replacingOccurrences(of: ",", with: "")
		panel.nameFieldStringValue = "Service Records - \(vehicleTitle) - \(dateStamp).pdf"

		panel.begin { response in
			guard response == .OK, let url = panel.url else { return }
			do {
				try data.write(to: url)
			} catch {
				// Display an alert if the write fails.
				NSAlert(error: error).runModal()
			}
		}
	}
	#else
	// MARK: iOS/iPadOS: Share (Files, AirDrop, Mail, etc.)

	// Writes the current PDFDocument to a temporary file and presents a share sheet.
	private func sharePDFiOS() {
		guard let doc = pdfDocument, let data = doc.dataRepresentation() else { return }
		// Compose a descriptive file name.
		let vehicleTitle = (trackVehicleSelected == "All Vehicles") ? "All Vehicles" : trackVehicleSelected
		let dateStamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
			.replacingOccurrences(of: "/", with: "-")
			.replacingOccurrences(of: ":", with: "-")
			.replacingOccurrences(of: ",", with: "")
		let fileName = "Service Records - \(vehicleTitle) - \(dateStamp).pdf"

		let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
		do {
			try data.write(to: tempURL, options: .atomic)
			self.shareURL = tempURL
			print("[Share] Presenting sheet for: \(tempURL.lastPathComponent)")
			self.isSharing = true
		} catch {
			print("Failed to write temp PDF: \(error)")
		}
	}
	#endif

	// MARK: - Printing

	// Present system print UI for the current PDF.
	// macOS: NSPrintOperation with a temporary PDFView.
	// iOS/iPadOS: UIPrintInteractionController with data from PDFDocument.
	private func printPDF() {
		guard let doc = pdfDocument else { return }
		#if os(macOS)
		// Use a transient PDFView and a standard NSPrintOperation for printing.
		let pdfView = PDFView()
		pdfView.document = doc

		let printInfo = NSPrintInfo.shared
		printInfo.horizontalPagination = .automatic
		printInfo.verticalPagination = .automatic
		printInfo.isHorizontallyCentered = true
		printInfo.isVerticallyCentered = true

		let op = NSPrintOperation(view: pdfView, printInfo: printInfo)
		op.showsPrintPanel = true
		op.showsProgressPanel = true
		op.run()
		#else
		guard UIPrintInteractionController.isPrintingAvailable,
		      let data = doc.dataRepresentation() else { return }
		let printInfo = UIPrintInfo(dictionary: nil)
		printInfo.jobName = "Service Records"
		printInfo.outputType = .general

		let controller = UIPrintInteractionController.shared
		controller.printInfo = printInfo
		controller.printingItem = data
		controller.showsNumberOfCopies = true

		// On iPad, present from a source rect/view; on iPhone, a simple present is fine.
		if UIDevice.current.userInterfaceIdiom == .pad {
			if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
			   let window = windowScene.windows.first,
			   let rootView = window.rootViewController?.view {
				controller.present(from: rootView.bounds, in: rootView, animated: true, completionHandler: nil)
			} else {
				controller.present(animated: true, completionHandler: nil)
			}
		} else {
			controller.present(animated: true, completionHandler: nil)
		}
		#endif
	}

}

// MARK: - iOS Activity (Share) View

#if canImport(UIKit) && !os(macOS)
private struct ActivityView: UIViewControllerRepresentable {
	let activityItems: [Any]
	var applicationActivities: [UIActivity]? = nil

	func makeUIViewController(context: Context) -> UIActivityViewController {
		let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
		// Optionally exclude activities:
		// controller.excludedActivityTypes = [.assignToContact, .addToReadingList]
		return controller
	}

	func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - SwiftUI Preview

//#Preview {
//	// In‑memory SwiftData container for previews so we can seed sample data quickly.
//	let config = ModelConfiguration(isStoredInMemoryOnly: true)
//	let container = try! ModelContainer(for: ServiceRecords1.self, Settings1.self, configurations: config)
//
//	// Seed sample service data for visual verification of layout and wrapping behavior.
//	let context = container.mainContext
//	func makeService(vehicleId: String, daysAgo: Int, miles: Int, hours: Float, item: String, desc: String, vendor: String, labor: Float, parts: [(String, Float, String, Int)], notes: String) -> ServiceRecords1 {
//		let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
//		let p1 = parts.indices.contains(0) ? parts[0] : ("", 0, "", 0)
//		let p2 = parts.indices.contains(1) ? parts[1] : ("", 0, "", 0)
//		let p3 = parts.indices.contains(2) ? parts[2] : ("", 0, "", 0)
//		let p4 = parts.indices.contains(3) ? parts[3] : ("", 0, "", 0)
//		let p5 = parts.indices.contains(4) ? parts[4] : ("", 0, "", 0)
//		return ServiceRecords1(
//			createdAt: date,
//			updatedAt: date,
//			mxDate: date,
//			vehicleId: vehicleId,
//			Miles: miles,
//			engHours: hours,
//			mxName: item,
//			mxItemId: "",
//			mxDescription: desc,
//			Notes: notes,
//			vendor: vendor,
//			laborCost: labor,
//			part1: p1.0, part1cost: Float(p1.1), part1Unit: p1.2, part1Quantity: p1.3,
//			part2: p2.0, part2cost: Float(p2.1), part2Unit: p2.2, part2Quantity: p2.3,
//			part3: p3.0, part3cost: Float(p3.1), part3Unit: p3.2, part3Quantity: p3.3,
//			part4: p4.0, part4cost: Float(p4.1), part4Unit: p4.2, part4Quantity: p4.3,
//			part5: p5.0, part5cost: Float(p5.1), part5Unit: p5.2, part5Quantity: p5.3,
//			image: nil,
//			image1: nil, image1Description: "",
//			image2: nil, image2Description: "",
//			image3: nil, image3Description: ""
//		)
//	}
//	let samples: [ServiceRecords1] = [
//		makeService(vehicleId: "Vehicle A", daysAgo: 0, miles: 12050, hours: 12.5, item: "Oil Change", desc: "Changed engine oil and filter. Checked belts and hoses.", vendor: "Joe's Garage", labor: 120, parts: [("Oil Filter", 8.5, "ea", 1), ("5W-30", 7.0, "qt", 5)], notes: "Next change in 3 months."),
//		makeService(vehicleId: "Vehicle A", daysAgo: 15, miles: 11820, hours: 10.0, item: "Brake Service", desc: "Replaced front pads, resurfaced rotors.", vendor: "BrakeCo", labor: 200, parts: [("Front Pads", 45.0, "set", 1), ("Brake Cleaner", 4.5, "can", 1)], notes: "Slight squeal at low speed observed."),
//		makeService(vehicleId: "Vehicle B", daysAgo: 5, miles: 5400, hours: 4.0, item: "Battery", desc: "Replaced battery and cleaned terminals.", vendor: "AutoParts", labor: 60, parts: [("Battery Group 24", 110.0, "ea", 1)], notes: "Starts faster.")
//	]
//	samples.forEach { context.insert($0) }
//
//	// Seed settings so loadSettingsArray() finds a record with userName == "primary1".
//	let settings = Settings1()
//	settings.userName = "primary1"
//	settings.unitVolumeFuel = "gal"
//	settings.unitVolumeOil = "qt"
//	settings.unitVolumeDEF = "gal"
//	settings.unitTemp = "F"
//	settings.unitSpeed = "mph"
//	settings.unitPressure = "PSI"
//	settings.unitMass = "lb"
//	settings.unitDistance = "mi"
//	settings.unitArea = "ft²"
//	settings.unitLength = "ft"
//	settings.unitWidth = "ft"
//	settings.unitHeight = "ft"
//	settings.unitWheelBase = "in"
//	context.insert(settings)
//
//	try? context.save()
//
//	Group {
//		// All Vehicles preview.
//		pdfReportService(trackVehicleSelected: "All Vehicles")
//			.modelContainer(container)
//			.previewDisplayName("All Vehicles")
//
//		// Specific vehicle preview.
//		pdfReportService(trackVehicleSelected: "Vehicle A")
//			.modelContainer(container)
//			.previewDisplayName("Vehicle A")
//	}
//}






