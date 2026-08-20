/*
 File: 3 pdfReportParts.swift
 Purpose:
   A cross-platform SwiftUI view that generates and displays a paginated PDF report of parts
   inventory using PDFKit. The report is built from SwiftData models (MxParts1), rendered as a
   multi-column table with wrapped text, alternating row backgrounds, and repeating headers on
   new pages. The view also provides zoom controls and system print support.

 Key Features:
   - SwiftData @Query to fetch and filter parts by the selected vehicle.
   - Unified PDF generation logic with platform-specific drawing code paths for macOS and iOS.
   - Table layout with column weights, dynamic row height calculation, and text wrapping.
   - Repeating header rows, page headers/footers, and page number tracking.
   - Zoom controls (fit, actual size, zoom in/out) for the embedded PDF view.
   - Save-to-Documents and system print presentation.

 Platforms:
   - macOS: Uses NSViewRepresentable + PDFView and Core Graphics PDF context.
   - iOS: Uses UIViewRepresentable + PDFView and UIGraphicsPDFRenderer.

 Dependencies:
   - PDFKit for viewing and generating the PDF.
   - SwiftUI for the UI layer and toolbar controls.
   - SwiftData for querying the underlying MxParts1 model.
   - Foundation/AppKit/UIKit as appropriate per platform.

 Notes:
   - All drawing coordinates are handled carefully per platform; macOS drawing flips the y-axis
     when bridging to NSGraphicsContext/Quartz.
   - The layout aims to be deterministic and readable across different content sizes.
*/

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

/// A SwiftUI view that builds and shows a PDF report of parts inventory.
///
/// The report is constructed from SwiftData records (MxParts1) and rendered into a table with
/// wrapped text, alternating row backgrounds, and per-page headers/footers. The resulting
/// PDF is displayed using PDFKit and can be zoomed and printed.
struct pdfReportParts: View {
	/// The parts dataset backing the report. Automatically filtered by the selected vehicle.
	@Query private var dataSet: [MxParts1]
	/// The currently selected vehicle filter. Use "All Vehicles" to include every record.
	@Binding var trackVehicleSelected: String
	/// SwiftData model context (not directly used in generation but available for future edits).
	@Environment(\.modelContext) var modelContext

	/// Holds the generated PDF document for display and printing.
	@State private var pdfDocument: PDFDocument?

	/// App utility helpers for formatting and preferences.
	let functions: Functions = Functions()
	let prefsFunc: PrefsFunctions = PrefsFunctions()

	/// One-shot zoom command used to drive the embedded PDFKit view.
	@State private var zoomAction: ZoomAction?

	/// Initializes the view, wiring the SwiftData query to the provided vehicle filter.
	/// - Parameter trackVehicleSelected: A binding to the vehicle filter ("All Vehicles" for no filter).
	init(trackVehicleSelected: Binding<String>) {
		self._trackVehicleSelected = trackVehicleSelected
		let vehicleId = trackVehicleSelected.wrappedValue
		if vehicleId != "All Vehicles" {
			self._dataSet = Query(
				filter: #Predicate<MxParts1> { $0.vehicleId == vehicleId },
				sort: [
					SortDescriptor(\.vehicleId, order: .forward),
					SortDescriptor(\.partName, order: .forward)
				]
			)
		} else {
			// all vehicles
			self._dataSet = Query(
				sort: [
					SortDescriptor(\.vehicleId, order: .forward),
					SortDescriptor(\.partName, order: .forward)
				]
			)
		}
	}

	/// Builds the UI, showing either the rendered PDF with zoom controls or a progress/try-again UI.
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
			// Generate the PDF once when the view first appears. Subsequent toolbar actions can
			// regenerate the document if content or filters change.
			if pdfDocument == nil {
				generateAndShowPDF()
			}
		}
		.toolbar {
			// Toolbar: regeneration, zoom controls, and print.
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

	/// Generates the PDF data, updates the on-screen document, and writes a copy to Documents.
	/// If generation fails, the UI will keep the progress/try-again state.
	private func generateAndShowPDF() {
		// If you add unit handling later, you can load them here like fuel/trip reports.
		guard let pdfData = generatePDFWithTable() else { return }
		if let doc = PDFDocument(data: pdfData) {
			self.pdfDocument = doc
			_ = savePDF(data: pdfData, fileName: "Parts Inventory")
		}
	}

	/// Discrete zoom operations forwarded to the embedded PDFKit view.
	enum ZoomAction {
		case zoomIn
		case zoomOut
		case fit
		case actual
	}

	/// macOS wrapper for PDFView that responds to one-shot zoom commands.
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
				nsView.autoScales = false
				nsView.scaleFactor = 1.0
			}
			DispatchQueue.main.async {
				self.zoomAction = nil
			}
		}
	}
	#else
	/// iOS wrapper for PDFView that responds to one-shot zoom commands.
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
				uiView.minScaleFactor = uiView.scaleFactorForSizeToFit
				uiView.scaleFactor = uiView.minScaleFactor
			case .actual:
				uiView.autoScales = false
				uiView.scaleFactor = 1.0
			}
			DispatchQueue.main.async {
				self.zoomAction = nil
			}
		}
	}
	#endif

	/// Extracts and formats the 10-column values for a single parts record.
	/// - Parameter record: The parts record to present.
	/// - Returns: An ordered array matching the table columns.
	func valuesForRecord(_ record: MxParts1) -> [String] {
		let vehicle = record.vehicleId
		let system = record.vehicleSystem
		let part = record.partName
		let partNo = record.partNumber
		let supplier = record.partSupplier
		let qty = NumberFormatter.localizedString(from: NSNumber(value: record.partQuantity), number: .none)
		let unit = record.partUnit
		let unitPrice = functions.formatCurrency(dollars: record.costPerUnit)
		let totalCost = functions.formatCurrency(dollars: record.costPerUnit * Float(record.partQuantity))
		let notes = record.Notes
		return [part, partNo, system, supplier, qty, unit, unitPrice, totalCost, vehicle, notes]
	}
	
	/// Builds a paginated PDF containing the parts table with headers, alternating rows,
	/// and page decorations. Uses platform-specific renderers under the hood.
	/// - Returns: PDF data on success, or nil if an error occurs.
	func generatePDFWithTable() -> Data? {
		let pageWidth: CGFloat = 792
		let pageHeight: CGFloat = 612
		let margin: CGFloat = 20

		// Space reserved for page header/footer
		let headerHeight: CGFloat = 36
		let footerHeight: CGFloat = 24

		let headerRows: [[String]] = [
			["PART\nNAME", "PART\nNUMBER", "SYSTEM", "SUPPLIER", "QTY", "UNIT", "UNIT PRICE", "TOTAL COST", "VEHICLE", "NOTES"]
		]

		let contentWidth = pageWidth - 2 * margin
		let minRowHeight: CGFloat = 32

		// 10 columns for the report
		let columnWeights: [CGFloat] = [
			0.16, // PART
			0.10, // PART NO.
			0.08, // SYSTEM
			0.12, // SUPPLIER
			0.04, // QTY
			0.05, // UNIT
			0.07, // UNIT PRICE
			0.07, // TOTAL COST
			0.08, // VEHICLE
			0.23  // NOTES
		]
		let columnWidths = columnWeights.map { $0 * contentWidth }

		let reportTitle = "Parts Inventory Report"
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

		// Starts a new macOS PDF page and draws the header/footer for the given page number.
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
			let rowHeight = computeRowHeight(for: record, columnWidths: columnWidths, minRowHeight: minRowHeight)
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

			// Starts a new iOS PDF page and draws the header/footer for the given page number.
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

	/// Draws the page header including title, vehicle/date subtitle, and an optional page indicator.
	/// Coordinates differ per platform; macOS flips the y-axis for Quartz.
	/// - Parameters:
	///   - margin: Outer page margin.
	///   - pageWidth: Full page width in points.
	///   - pageHeight: Full page height in points.
	///   - headerHeight: Height reserved for the header region.
	///   - title: Report title text.
	///   - subtitle: Secondary line (vehicle filter).
	///   - dateText: Rendered date string.
	///   - pageNumber: Current page index (1-based).
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

	/// Draws the page footer with a centered page number.
	/// - Parameters:
	///   - margin: Outer page margin.
	///   - pageWidth: Full page width in points.
	///   - pageHeight: Full page height in points.
	///   - footerHeight: Height reserved for the footer region.
	///   - pageNumber: Current page index (1-based).
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

	/// Draws the table header block (one or more rows) with background fill and grid lines.
	/// Returns the total header block height actually rendered, which may exceed `minRowHeight`
	/// due to text wrapping.
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

		// Measures a single header row's required height based on attributed text wrapping.
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

	/// Computes the dynamic row height for a given record, accounting for per-column wrapping
	/// and insets. PART and NOTES are left-aligned; other columns are centered.
	/// - Parameters:
	///   - record: The parts record to size.
	///   - columnWidths: Column widths used for layout.
	///   - minRowHeight: Minimum height to enforce.
	/// - Returns: The computed row height in points.
	func computeRowHeight(for record: MxParts1, columnWidths: [CGFloat], minRowHeight: CGFloat) -> CGFloat {
		let values = valuesForRecord(record)
		let notesIndex = 9 // last column is NOTES

		#if os(macOS)
		let font = NSFont.systemFont(ofSize: 8)
		#else
		let font = UIFont.systemFont(ofSize: 8)
		#endif

		// Build per-column paragraph styles (notes column left-aligned, PART left-aligned)
		var paragraphStyles: [NSMutableParagraphStyle] = []
		for i in 0..<values.count {
			let p = NSMutableParagraphStyle()
			p.lineBreakMode = .byWordWrapping
			p.alignment = (i == notesIndex || i == 0) ? .left : .center // left align PART (0) and NOTES (9)
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

	/// Draws one table row including alternating background, wrapped text, and grid lines.
	/// - Parameters:
	///   - record: The parts record to draw.
	///   - origin: Top-left origin for the row (platform-adjusted internally for macOS).
	///   - columnWidths: Column widths used for layout.
	///   - rowHeight: Height determined by `computeRowHeight`.
	///   - rowIndex: Zero-based index used for alternating fill.
	///   - pageHeight: Optional page height for macOS y-axis conversion.
	func drawTableRow(record: MxParts1, at origin: CGPoint, columnWidths: [CGFloat], rowHeight: CGFloat, rowIndex: Int, pageHeight: CGFloat? = nil) {
		let values = valuesForRecord(record)
		let notesIndex = 9 // last column is NOTES

		#if os(macOS)
		let font = NSFont.systemFont(ofSize: 8)
		let separatorColor = NSColor.separatorColor
		let rowAltFill = NSColor(white: 0.96, alpha: 1.0)
		#else
		let font = UIFont.systemFont(ofSize: 8)
		let separatorColor = UIColor.separator
		let rowAltFill = UIColor(white: 0.96, alpha: 1.0)
		#endif

		// Build per-column paragraph styles (left-align PART and NOTES)
		var paragraphStyles: [NSMutableParagraphStyle] = []
		for i in 0..<values.count {
			let p = NSMutableParagraphStyle()
			p.lineBreakMode = .byWordWrapping
			p.alignment = (i == notesIndex || i == 0) ? .left : .center
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

	/// Saves the PDF to the user's Documents directory.
	/// - Parameters:
	///   - data: PDF data to write.
	///   - fileName: File name without extension.
	/// - Returns: The file URL on success, otherwise nil.
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

	/// Presents the platform print UI for the current PDF document, if available.
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
		printInfo.jobName = "Parts Inventory"
		printInfo.outputType = .general

		let controller = UIPrintInteractionController.shared
		controller.printInfo = printInfo
		controller.printingItem = data
		controller.showsNumberOfCopies = true

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

#Preview("All Vehicles") {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: MxParts1.self, configurations: config)
	let context = container.mainContext
	let samples: [MxParts1] = [
		MxParts1(vehicleId: "Vehicle A", vehicleSystem: "Engine", partName: "Oil Filter", partNumber: "OF-123", partManufacture: "ACME", partDescription: "Standard oil filter", Notes: "Keep 2 spare", costPerUnit: 12.5, partUnit: "ea", partSource: "Online", partQuantity: 3, partLocation: "Bay 1", partStatus: "In Stock", partSupplier: "PartsCo"),
		MxParts1(vehicleId: "Vehicle B", vehicleSystem: "Brakes", partName: "Brake Pad Set", partNumber: "BP-456", partManufacture: "BrakeMax", partDescription: "Front pads", Notes: "", costPerUnit: 45.0, partUnit: "set", partSource: "Local", partQuantity: 1, partLocation: "Shelf 3", partStatus: "Low", partSupplier: "Local Shop"),
		MxParts1(vehicleId: "Vehicle A", vehicleSystem: "Electrical", partName: "Battery", partNumber: "BAT-12V", partManufacture: "VoltCo", partDescription: "12V battery", Notes: "AGM", costPerUnit: 110.0, partUnit: "ea", partSource: "Online", partQuantity: 2, partLocation: "Bay 2", partStatus: "In Stock", partSupplier: "BatteryWorld")
	]
	samples.forEach { context.insert($0) }
	try? context.save()
	return pdfReportParts(trackVehicleSelected: .constant("All Vehicles"))
		.modelContainer(container)
}

#Preview("Vehicle A") {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: MxParts1.self, configurations: config)
	let context = container.mainContext
	let samples: [MxParts1] = [
		MxParts1(vehicleId: "Vehicle A", vehicleSystem: "Engine", partName: "Oil Filter", partNumber: "OF-123", partManufacture: "ACME", partDescription: "Standard oil filter", Notes: "Keep 2 spare", costPerUnit: 12.5, partUnit: "ea", partSource: "Online", partQuantity: 3, partLocation: "Bay 1", partStatus: "In Stock", partSupplier: "PartsCo"),
		MxParts1(vehicleId: "Vehicle A", vehicleSystem: "Electrical", partName: "Battery", partNumber: "BAT-12V", partManufacture: "VoltCo", partDescription: "12V battery", Notes: "AGM", costPerUnit: 110.0, partUnit: "ea", partSource: "Online", partQuantity: 2, partLocation: "Bay 2", partStatus: "In Stock", partSupplier: "BatteryWorld")
	]
	samples.forEach { context.insert($0) }
	try? context.save()
	return pdfReportParts(trackVehicleSelected: .constant("Vehicle A"))
		.modelContainer(container)
}

