//
//  pdfReportFuel.swift
//  LandShip
//
//  A cross‑platform SwiftUI view that renders a paginated, printable PDF report
//  of fuel log entries using PDFKit. The view queries `FuelLog1` records via
//  SwiftData, generates a table-based PDF with headers and wrapped rows, and
//  presents the PDF with zoom controls and printing support on both iOS and macOS.
//
//  Key features:
//  - SwiftData @Query to fetch `FuelLog1` entries (optionally filtered by vehicle)
//  - Cross‑platform PDF generation (UIGraphicsPDFRenderer on iOS, CoreGraphics on macOS)
//  - Table layout with dynamic row height, multi-line wrapping, and alternating row fills
//  - Embedded PDF viewer (PDFView) with zoom in/out, fit, and 100% controls
//  - System print integration and on-disk PDF saving to the Documents directory
//
//  Usage:
//  - Initialize with a binding to the selected vehicle id. Pass "All Vehicles" to
//    include all logs, or a specific id to filter.
//  - The view auto-generates the PDF on first appearance and allows regeneration.
//
//  Dependencies:
//  - PDFKit, SwiftUI, SwiftData
//  - `FuelLog1` model, `Functions` utilities, and `PrefsFunctions` for user units
//
//  Notes:
//  - PDF coordinate systems differ between platforms; this file abstracts those
//    differences where necessary (e.g., by converting Y coordinates on macOS).
//  - Keep heavy drawing outside SwiftUI layout to avoid blocking the main thread.
//
//  Created by JP on 9/29/25. Heavily documented and organized by adding inline
//  explanations and API docs for maintainability.
//

import PDFKit
import SwiftUI
import SwiftData
import Foundation
#if os(macOS)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - pdfReportFuel

/// A SwiftUI view that builds and displays a PDF report of fuel logs.
///
/// This view:
/// - Fetches `FuelLog1` records via SwiftData
/// - Generates a table-based, paginated PDF with headers and wrapped rows
/// - Embeds a platform-appropriate `PDFView` for display
/// - Provides zoom and print controls via a toolbar
///
/// Initialize with a binding to the selected vehicle identifier. Use
/// "All Vehicles" to include all vehicles in the report.
struct pdfReportFuel: View {
	/// The fetched fuel log entries that populate the PDF table. When a specific
	/// vehicle is selected, the query is filtered accordingly in `init`.
	@Query private var dataSet: [FuelLog1]
	/// The currently selected vehicle id. Use "All Vehicles" to include all vehicles.
	@Binding var trackVehicleSelected: String
	/// SwiftData model context for loading user preferences and data.
	@Environment(\.modelContext) var modelContext
	/// Tracks whether the report targets all vehicles. Reserved for potential UI state.
	@State private var allVehiclesSelected: Bool = true /// if all vehicles, disable save update button

	/// The generated PDF document, displayed in `PDFKitView` when available.
	@State private var pdfDocument: PDFDocument?

	/// App-wide helper functions (date/number formatting, etc.).
	let functions: Functions = Functions()
	/// Helper for loading persisted user/unit preferences.
	let prefsFunc: PrefsFunctions = PrefsFunctions()

	/// One-shot zoom commands sent to the embedded `PDFView`.
	@State private var zoomAction: ZoomAction?

	/// Creates a report view bound to the selected vehicle id and configures the
	/// SwiftData query. When `trackVehicleSelected` is not "All Vehicles", the
	/// query is filtered to that vehicle; otherwise all logs are included.
	init(trackVehicleSelected: Binding<String>) {
		self._trackVehicleSelected = trackVehicleSelected
		let vehicleId = trackVehicleSelected.wrappedValue
		if vehicleId != "All Vehicles" {
			self._dataSet = Query(
				filter: #Predicate<FuelLog1> { $0.vehicleId == vehicleId },
				sort: [
					SortDescriptor(\.vehicleId, order: .forward),
					SortDescriptor(\.fuelDateTime, order: .reverse)
				]
			)
		} else {
			// all vehicles
			self._dataSet = Query(
				sort: [
					SortDescriptor(\.vehicleId, order: .forward),
					SortDescriptor(\.fuelDateTime, order: .reverse)
				]
			)
		}
	}

	/// Displays either the generated PDF (with zoom controls) or a progress view
	/// with a retry button while the PDF is being generated.
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
			// Generate on first appearance
			if pdfDocument == nil {
				generateAndShowPDF()
			}
		}
		.toolbar {
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
					printPDF()
				} label: {
					Label("Print", systemImage: "printer")
				}
				.keyboardShortcut("p", modifiers: .command)
				.disabled(pdfDocument == nil)
			}
		}
	}

	// MARK: - Actions & Lifecycle

	/// Loads user unit settings, generates the PDF data, updates the on-screen
	/// `PDFDocument`, and persists a copy to the Documents directory.
	private func generateAndShowPDF() {
		// Load settings as an array (see Functions.loadSettingsArray)
		let units = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1")
			?? Array(repeating: "", count: 13)

		guard let pdfData = generatePDFWithTable(units: units) else { return }
		if let doc = PDFDocument(data: pdfData) {
			self.pdfDocument = doc
			_ = savePDF(data: pdfData, fileName: "Fuel Log")
		}
	}

	/// Discrete zoom actions forwarded to the embedded `PDFView`.
	enum ZoomAction {
		case zoomIn
		case zoomOut
		case fit
		case actual
	}

	/// macOS wrapper around `PDFView` that responds to one-shot `ZoomAction`s.
	#if os(macOS)
	struct PDFKitView: NSViewRepresentable {
		let pdfDocument: PDFDocument
		@Binding var zoomAction: ZoomAction?

		init(showing pdfDoc: PDFDocument, zoomAction: Binding<ZoomAction?>) {
			self.pdfDocument = pdfDoc
			self._zoomAction = zoomAction
		}

		func makeNSView(context: Context) -> PDFView {
			let pdfView = PrintablePDFView()
			pdfView.document = pdfDocument
			pdfView.autoScales = true
			pdfView.displaysPageBreaks = true
			pdfView.displayMode = .singlePageContinuous
			pdfView.displayDirection = .vertical
			return pdfView
		}

		func updateNSView(_ nsView: PDFView, context: Context) {
			guard let action = zoomAction else { return }
			switch action {
			case .zoomIn:
				nsView.zoomIn(nil)
			case .zoomOut:
				nsView.zoomOut(nil)
			case .fit:
				nsView.autoScales = true
			case .actual:
				// 1.0 is 100% on macOS PDFView
				nsView.autoScales = false
				nsView.scaleFactor = 1.0
			}
			DispatchQueue.main.async {
				self.zoomAction = nil
			}
		}
	}
	#else
	/// iOS wrapper around `PDFView` that responds to one-shot `ZoomAction`s and
	/// configures sensible min/max scale factors for pinch and button zoom.
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
			// Reasonable min/max for pinch + buttons
			pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
			pdfView.maxScaleFactor = max(pdfView.minScaleFactor * 5, 4.0)
			return pdfView
		}

		func updateUIView(_ uiView: PDFView, context: Context) {
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
				// Ensure min is up to date with current bounds
				uiView.minScaleFactor = uiView.scaleFactorForSizeToFit
				uiView.scaleFactor = uiView.minScaleFactor
			case .actual:
				uiView.autoScales = false
				// 1.0 is 100% on iOS PDFView
				uiView.scaleFactor = 1.0
			}
			DispatchQueue.main.async {
				self.zoomAction = nil
			}
		}
	}
	#endif

	/// Produces the 12 display strings (one per column) for a given `FuelLog1` row,
	/// applying number formatting and unit labels.
	/// - Parameters:
	///   - record: The source fuel log entry.
	///   - units: Array of user unit strings used to annotate quantities.
	/// - Returns: An array of 12 strings matching the report columns.
	func valuesForRecord(_ record: FuelLog1, units: [String]) -> [String] {
		let vehicle = record.vehicleId
		let fuelDate = functions.formatDate_DDMMM_yyyy(date: record.fuelDateTime)
		let miles = NumberFormatter.localizedString(from: NSNumber(value: record.odometer), number: .decimal) + " \(units[UnitIndex.distance])"
		let local = record.location
		
		let qtyFormatter = NumberFormatter()
		qtyFormatter.numberStyle = .decimal
		qtyFormatter.minimumFractionDigits = 1
		qtyFormatter.maximumFractionDigits = 1
		var fuelAdded = qtyFormatter.string(from: NSNumber(value: record.fuelAdded)) ?? "\(record.fuelAdded)"
		fuelAdded = fuelAdded + " \(units[UnitIndex.fuel])"
		
		let levelStart = record.fuelLevelStartFraction.isEmpty ? functions.getFuelLevel(unit:record.fuelLevelStart1)
		: record.fuelLevelStartFraction
		
		let fuelPrice = functions.formatCurrency(dollars: record.fuelPrice)
		let fuelCost = functions.formatCurrency(dollars: record.fuelCost)
		let defPrice = functions.formatCurrency(dollars: record.defPrice)
		let fuelType = record.fuelType
		var defAdded = qtyFormatter.string(from: NSNumber(value: record.defAdded)) ?? "\(record.defAdded)"
		defAdded = defAdded + " \(units[UnitIndex.def])"
		var oilAdded = qtyFormatter.string(from: NSNumber(value: record.oilAdded)) ?? "\(record.oilAdded)"
		oilAdded = oilAdded + " \(units[UnitIndex.oil])"

		let fuelNotes = record.fuelNotes
		
		return [vehicle, fuelDate, miles, local, fuelAdded, levelStart, fuelPrice, fuelCost, fuelType, defAdded, defPrice, oilAdded, fuelNotes]
	}
	
	/// Generates a paginated PDF containing a table of fuel log entries.
	/// Uses Core Graphics on macOS and `UIGraphicsPDFRenderer` on iOS.
	/// - Parameter units: User-configured unit labels for distances, volumes, etc.
	/// - Returns: Raw PDF data or `nil` if generation fails.
	func generatePDFWithTable(units: [String]) -> Data? {
		// US Letter landscape (11" x 8.5") at 72 dpi
		let pageWidth: CGFloat = 792
		let pageHeight: CGFloat = 612
		let margin: CGFloat = 20

		// Space reserved for page header/footer
		let headerHeight: CGFloat = 36
		let footerHeight: CGFloat = 24

		let headerRows: [[String]] = [
			["VEHICLE", "FUEL\nDATE", "ODOM", "LOCALE", "FUEL\nADDED", "LEVEL\nSTART", "FUEL\nPRICE", "FUEL\nCOST", "FUEL\nTYPE", "DEF\nADDED", "DEF\nPRICE", "OIL\nADDED", "FUEL NOTES"]
		]

		let contentWidth = pageWidth - 2 * margin
		let minRowHeight: CGFloat = 32

		// Proportional widths for the 12 columns; must sum to ~1.0
		let columnWeights: [CGFloat] = [
			0.08, 0.05, 0.07, 0.09, 0.06, 0.06, 0.06, 0.05, 0.07, 0.06, 0.05, 0.06, 0.24
		]
		let columnWidths = columnWeights.map { $0 * contentWidth }

		let reportTitle = "Fuel Log Report"
		let vehicleTitle = (trackVehicleSelected == "All Vehicles") ? "All Vehicles" : trackVehicleSelected
		let dateTitle = functions.formatDate_DDMMMyy(date: Date())

		#if os(macOS)
		let data = NSMutableData()
		var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
		guard
			let consumer = CGDataConsumer(data: data as CFMutableData),
			let cgContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
		else { return nil }

		var pageNumber = 1

		func beginMacPage() {
			cgContext.beginPDFPage(nil)
			let nsGraphicsContext = NSGraphicsContext(cgContext: cgContext, flipped: false)
			NSGraphicsContext.saveGraphicsState()
			NSGraphicsContext.current = nsGraphicsContext

			// Header + footer
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

		func endMacPage() {
			NSGraphicsContext.restoreGraphicsState()
			cgContext.endPDFPage()
		}

		beginMacPage()

		var currentY: CGFloat = margin + headerHeight
		let maxContentBottom = pageHeight - margin - footerHeight

		let headerBlockHeight = drawTableHeaders(at: CGPoint(x: margin, y: currentY),
																					 columnWidths: columnWidths,
																					 headerRows: headerRows,
																					 minRowHeight: 24,
																					 pageHeight: pageHeight)
		currentY += headerBlockHeight

		for (index, record) in dataSet.enumerated() {
			let rowHeight = computeRowHeight(for: record, columnWidths: columnWidths, minRowHeight: minRowHeight, units: units)
			if currentY + rowHeight > maxContentBottom {
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
			drawTableRow(record: record,
									 at: CGPoint(x: margin, y: currentY),
									 columnWidths: columnWidths,
									 rowHeight: rowHeight,
									 rowIndex: index,
									 units: units,
									 pageHeight: pageHeight)
			currentY += rowHeight
		}

		endMacPage()
		cgContext.closePDF()
		return data as Data

		#else
		let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
		let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)
		let data = pdfRenderer.pdfData { context in
			var pageNumber = 1

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

			var currentY: CGFloat = margin + headerHeight
			let maxContentBottom = pageHeight - margin - footerHeight

			let headerBlockHeight = drawTableHeaders(at: CGPoint(x: margin, y: currentY),
																						 columnWidths: columnWidths,
																						 headerRows: headerRows,
																						 minRowHeight: 36)
			currentY += headerBlockHeight

			for (index, record) in dataSet.enumerated() {
				let rowHeight = computeRowHeight(for: record, columnWidths: columnWidths, minRowHeight: minRowHeight, units: units)
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
				drawTableRow(record: record, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, rowHeight: rowHeight, rowIndex: index, units: units)
				currentY += rowHeight
			}
		}
		return data
		#endif
	}

	/// Draws the page header including title, subtitle/date, and page number.
	/// Handles platform coordinate differences when needed.
	nonisolated func drawPageHeader(margin: CGFloat,
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

		// Top-left origin rects converted to Quartz
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

		// Right aligned page number in header (optional)
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

	/// Draws a centered page footer with the current page number.
	nonisolated func drawPageFooter(margin: CGFloat,
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

	/// Renders one or more header rows, fills the header background, and draws grid lines.
	/// - Returns: The total vertical height consumed by the header block.
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

		// If a row contains explicit line breaks, measure its height accordingly.
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

		var perRowHeights: [CGFloat] = []
		for (rowIndex, row) in headerRows.enumerated() {
			let attrs = (rowIndex == 0) ? topAttrs : bottomAttrs
			perRowHeights.append(measureRowHeight(row, attrs: attrs))
		}
		let totalHeaderHeight = perRowHeights.reduce(0, +)

		// Background for the entire header block
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

		// Grid lines (vertical and horizontal)
		separatorColor.setStroke()

		#if os(macOS)
		let gridPath = NSBezierPath()
		gridPath.lineWidth = 1.0

		// Vertical dividers (including left and right borders)
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

		// Horizontal lines between header rows and bottom border
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

		// Vertical dividers (including left and right borders)
		var runningX = headerRectTop.origin.x
		gridPath.move(to: CGPoint(x: runningX, y: headerRectTop.origin.y))
		gridPath.addLine(to: CGPoint(x: runningX, y: headerRectTop.origin.y + headerRectTop.height))
		for width in columnWidths {
			runningX += width
			gridPath.move(to: CGPoint(x: runningX, y: headerRectTop.origin.y))
			gridPath.addLine(to: CGPoint(x: runningX, y: headerRectTop.origin.y + headerRectTop.height))
		}

		// Horizontal lines between header rows and bottom border
		var runningY = headerRectTop.origin.y
		for rowIdx in 0..<perRowHeights.count {
			runningY += perRowHeights[rowIdx]
			gridPath.move(to: CGPoint(x: headerRectTop.origin.x, y: runningY))
			gridPath.addLine(to: CGPoint(x: headerRectTop.origin.x + totalWidth, y: runningY))
		}

		gridPath.stroke()
		#endif

		// Draw header text
		var rowStartYTop = origin.y
		for (rowIndex, row) in headerRows.enumerated() {
			let rowHeight = perRowHeights[rowIndex]
			var textX = origin.x
			for (colIndex, text) in row.enumerated() {
				let width = columnWidths[min(colIndex, columnWidths.count - 1)]
				let cellRectTop = CGRect(x: textX, y: rowStartYTop, width: width, height: rowHeight)
				let attrs = (rowIndex == 0) ? topAttrs : bottomAttrs
				#if os(macOS)
				let ph = pageHeight ?? 0
				let cellRect = CGRect(x: cellRectTop.origin.x,
				                      y: ph - cellRectTop.origin.y - cellRectTop.height,
				                      width: cellRectTop.width,
				                      height: cellRectTop.height)
				NSAttributedString(string: text, attributes: attrs)
					.draw(in: cellRect.insetBy(dx: 4, dy: 6))
				#else
				NSAttributedString(string: text, attributes: attrs)
					.draw(in: cellRectTop.insetBy(dx: 4, dy: 6))
				#endif
				textX += width
			}
			rowStartYTop += rowHeight
		}

		return totalHeaderHeight
	}

	/// Computes the height required to display a record row with word wrapping
	/// for each column, respecting minimum row height.
	func computeRowHeight(for record: FuelLog1, columnWidths: [CGFloat], minRowHeight: CGFloat, units: [String]) -> CGFloat {
		let values = valuesForRecord(record, units: units)
		let notesIndex = 12 // last column is FUEL NOTES

		#if os(macOS)
		let font = NSFont.systemFont(ofSize: 8)
		#else
		let font = UIFont.systemFont(ofSize: 8)
		#endif

		// Build per-column paragraph styles (notes column left-aligned, others centered)
		var paragraphStyles: [NSMutableParagraphStyle] = []
		for i in 0..<values.count {
			let p = NSMutableParagraphStyle()
			p.lineBreakMode = .byWordWrapping
			p.alignment = (i == notesIndex) ? .left : .center
			paragraphStyles.append(p)
		}

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

	/// Draws a single table row with wrapped text, alternating background fill,
	/// and full grid lines across all columns.
	func drawTableRow(record: FuelLog1, at origin: CGPoint, columnWidths: [CGFloat], rowHeight: CGFloat, rowIndex: Int, units: [String], pageHeight: CGFloat? = nil) {
		let values = valuesForRecord(record, units: units)
		let notesIndex = 12 // last column is FUEL NOTES

		#if os(macOS)
		let font = NSFont.systemFont(ofSize: 8)
		let separatorColor = NSColor.separatorColor
		// Light gray alternating fill
		let rowAltFill = NSColor(white: 0.96, alpha: 1.0)
		#else
		let font = UIFont.systemFont(ofSize: 8)
		let separatorColor = UIColor.separator
		// Light gray alternating fill
		let rowAltFill = UIColor(white: 0.96, alpha: 1.0)
		#endif

		// Build per-column paragraph styles (notes column left-aligned, others centered)
		var paragraphStyles: [NSMutableParagraphStyle] = []
		for i in 0..<values.count {
			let p = NSMutableParagraphStyle()
			p.lineBreakMode = .byWordWrapping
			p.alignment = (i == notesIndex) ? .left : .center
			paragraphStyles.append(p)
		}

		// Background for alternating rows (odd index)
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

		// Draw text in each column (wrapped)
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

		// Draw full-width row grid (vertical lines for all columns + bottom border)
		let totalWidth = columnWidths.reduce(0, +)
		separatorColor.setStroke()

		#if os(macOS)
		let rowPath = NSBezierPath()
		rowPath.lineWidth = 0.5

		// Left border
		func yConv(_ yTop: CGFloat) -> CGFloat { (pageHeight ?? 0) - yTop }
		rowPath.move(to: CGPoint(x: origin.x, y: yConv(origin.y)))
		rowPath.line(to: CGPoint(x: origin.x, y: yConv(origin.y + rowHeight)))

		// Vertical dividers for all columns
		var runningX = origin.x
		for width in columnWidths {
			runningX += width
			rowPath.move(to: CGPoint(x: runningX, y: yConv(origin.y)))
			rowPath.line(to: CGPoint(x: runningX, y: yConv(origin.y + rowHeight)))
		}

		// Bottom border of the row
		rowPath.move(to: CGPoint(x: origin.x, y: yConv(origin.y + rowHeight)))
		rowPath.line(to: CGPoint(x: origin.x + totalWidth, y: yConv(origin.y + rowHeight)))
		rowPath.stroke()
		#else
		let rowPath = UIBezierPath()
		rowPath.lineWidth = 0.5

		// Left border
		rowPath.move(to: CGPoint(x: origin.x, y: origin.y))
		rowPath.addLine(to: CGPoint(x: origin.x, y: origin.y + rowHeight))

		// Vertical dividers for all columns
		var runningX = origin.x
		for width in columnWidths {
			runningX += width
			rowPath.move(to: CGPoint(x: runningX, y: origin.y))
			rowPath.addLine(to: CGPoint(x: runningX, y: origin.y + rowHeight))
		}

		// Bottom border of the row
		rowPath.move(to: CGPoint(x: origin.x, y: origin.y + rowHeight))
		rowPath.addLine(to: CGPoint(x: origin.x + totalWidth, y: origin.y + rowHeight))
		rowPath.stroke()
		#endif
	}

	/// Saves the generated PDF to the app's Documents directory.
	/// - Parameters:
	///   - data: Raw PDF data to persist.
	///   - fileName: Base filename (without extension).
	/// - Returns: The destination URL on success, otherwise `nil`.
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

	/// Presents the system print UI for the current PDF document on iOS and macOS.
	private func printPDF() {
		guard let doc = pdfDocument else { return }
		#if os(macOS)
		let printInfo = NSPrintInfo.shared
		printInfo.horizontalPagination = .automatic
		printInfo.verticalPagination = .automatic
		printInfo.isHorizontallyCentered = true
		printInfo.isVerticallyCentered = true

		if let op = doc.printOperation(for: printInfo, scalingMode: .pageScaleDownToFit, autoRotate: true) {
			op.showsPrintPanel = true
			op.showsProgressPanel = true
			op.runModal(for: NSApp.keyWindow ?? NSWindow(), delegate: nil, didRun: nil, contextInfo: nil)
		}
		#else
		guard UIPrintInteractionController.isPrintingAvailable,
		      let data = doc.dataRepresentation() else { return }
		let printInfo = UIPrintInfo(dictionary: nil)
		printInfo.jobName = "Fuel Log"
		printInfo.outputType = .general

		let controller = UIPrintInteractionController.shared
		controller.printInfo = printInfo
		controller.printingItem = data
		controller.showsNumberOfCopies = true

		// On iPad, present from a source rect/view; on iPhone, simple present is fine.
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

// MARK: - Previews

/// Preview seeds an in-memory SwiftData container with sample `FuelLog1` rows and
/// a `Settings1` record so the PDF renders with realistic content and units.
#Preview("All Vehicles") {
	// In-memory SwiftData container for previews
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: FuelLog1.self, Settings1.self, configurations: config)

	// Seed sample data
	let context = container.mainContext
	func makeFuelLog(vehicleId: String, daysAgo: Int, odometer: Int, fuelAdded: Float, location: String) -> FuelLog1 {
		let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
		return FuelLog1(
			logId: UUID().uuidString,
			vehicleId: vehicleId,
			logName: "Fuel \(vehicleId) \(daysAgo)d ago",
			fuelNotes: "Some note for \(vehicleId) that could be long and should wrap across multiple lines in the PDF row to demonstrate wrapping behavior.",
			createdAt: date,
			updatedAt: date,
			fuelDateTime: date,
			odometer: odometer,
			location: location,
			engHours: 0,
			fuelQuantityStart: 10,
			fuelQuantityEnd: 20,
			fuelAdded: fuelAdded,
			defAdded: 0.2,
			oilAdded: 0.1,
			fuelLevelStart1: 0.5,
			fuelLevelEnd1: 1.0,
			fuelLevelStart: "1/2",
			fuelLevelEnd: "Full",
			fuelPrice: 3.79,
			fuelCost: 3.79 * fuelAdded,
			fuelType: "Gasoline",
			image1: nil,
			image1Description: "",
			image2: nil,
			image2Description: "",
			image3: nil,
			image3Description: ""
		)
	}
	let samples: [FuelLog1] = [
		makeFuelLog(vehicleId: "Vehicle A", daysAgo: 0, odometer: 12050, fuelAdded: 12.3, location: "Harbor"),
		makeFuelLog(vehicleId: "Vehicle A", daysAgo: 3, odometer: 11800, fuelAdded: 10.0, location: "Depot"),
		makeFuelLog(vehicleId: "Vehicle B", daysAgo: 1, odometer: 5400, fuelAdded: 8.7, location: "Station 9")
	]
	samples.forEach { context.insert($0) }

	// Seed settings so loadSettingsArray() finds a record with userName == "primary1"
	let settings = Settings1()
	settings.userName = "primary1"
	settings.unitVolumeFuel = "gal"
	settings.unitVolumeOil = "qt"
	settings.unitVolumeDEF = "gal"
	settings.unitTemp = "F"
	settings.unitSpeed = "mph"
	settings.unitPressure = "PSI"
	settings.unitMass = "lb"
	settings.unitDistance = "mi"
	settings.unitArea = "ft²"
	settings.unitLength = "ft"
	settings.unitWidth = "ft"
	settings.unitHeight = "ft"
	settings.unitWheelBase = "in"
	context.insert(settings)

	try? context.save()

	return pdfReportFuel(trackVehicleSelected: .constant("All Vehicles"))
		.modelContainer(container)
}

#Preview("Vehicle A") {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: FuelLog1.self, Settings1.self, configurations: config)
	let context = container.mainContext
	func makeFuelLog(vehicleId: String, daysAgo: Int, odometer: Int, fuelAdded: Float, location: String) -> FuelLog1 {
		let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
		return FuelLog1(
			logId: UUID().uuidString,
			vehicleId: vehicleId,
			logName: "Fuel \(vehicleId) \(daysAgo)d ago",
			fuelNotes: "Some note for \(vehicleId) that could be long and should wrap across multiple lines in the PDF row to demonstrate wrapping behavior.",
			createdAt: date,
			updatedAt: date,
			fuelDateTime: date,
			odometer: odometer,
			location: location,
			engHours: 0,
			fuelQuantityStart: 10,
			fuelQuantityEnd: 20,
			fuelAdded: fuelAdded,
			defAdded: 0.2,
			oilAdded: 0.1,
			fuelLevelStart1: 0.5,
			fuelLevelEnd1: 1.0,
			fuelLevelStart: "1/2",
			fuelLevelEnd: "Full",
			fuelPrice: 3.79,
			fuelCost: 3.79 * fuelAdded,
			fuelType: "Gasoline",
			image1: nil,
			image1Description: "",
			image2: nil,
			image2Description: "",
			image3: nil,
			image3Description: ""
		)
	}
	let samples: [FuelLog1] = [
		makeFuelLog(vehicleId: "Vehicle A", daysAgo: 0, odometer: 12050, fuelAdded: 12.3, location: "Harbor"),
		makeFuelLog(vehicleId: "Vehicle A", daysAgo: 3, odometer: 11800, fuelAdded: 10.0, location: "Depot"),
		makeFuelLog(vehicleId: "Vehicle B", daysAgo: 1, odometer: 5400, fuelAdded: 8.7, location: "Station 9")
	]
	samples.forEach { context.insert($0) }
	let settings = Settings1()
	settings.userName = "primary1"
	settings.unitVolumeFuel = "gal"
	settings.unitVolumeOil = "qt"
	settings.unitVolumeDEF = "gal"
	settings.unitTemp = "F"
	settings.unitSpeed = "mph"
	settings.unitPressure = "PSI"
	settings.unitMass = "lb"
	settings.unitDistance = "mi"
	settings.unitArea = "ft²"
	settings.unitLength = "ft"
	settings.unitWidth = "ft"
	settings.unitHeight = "ft"
	settings.unitWheelBase = "in"
	context.insert(settings)
	try? context.save()
	return pdfReportFuel(trackVehicleSelected: .constant("Vehicle A"))
		.modelContainer(container)
}

