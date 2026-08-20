/*
 File: pdfReportVehicles.swift
 Module: LandShip
 
 Summary
 -------
 A cross-platform SwiftUI view that generates and displays a PDF report of vehicles (Vehicle8).
 The view uses PDFKit via representable wrappers (NSViewRepresentable/UIViewRepresentable) to
 present the generated document and exposes simple zoom controls. The PDF layout is a paginated
 table with a header/footer, dynamic row heights, and an image+description column.
 
 Key Features
 ------------
 - SwiftData-powered query to render either a single selected vehicle or all vehicles
 - Cross-platform PDF generation (Core Graphics on macOS, UIGraphicsPDFRenderer on iOS)
 - Consistent table layout with weighted columns, wrapping text, and alternating row backgrounds
 - Thumbnail rendering for vehicle image data with graceful fallback placeholder
 - Built-in print support (NSPrintOperation on macOS; UIPrintInteractionController on iOS)
 - Zoom actions (fit/actual/zoom-in/zoom-out) forwarded to PDFKit views
 
 Data Flow
 ---------
 - An injected `@Query` provides the array of Vehicle8 to render; it is built based on
   `trackVehicleSelected` in `init`.
 - `generatePDFWithTable()` constructs the PDF data using drawing helpers for headers, rows, and grid.
 - The resulting Data is wrapped in PDFDocument and assigned to state (`pdfDocument`) for display.
 - A copy is saved to the app's Documents folder via `savePDF(data:fileName:)` for persistence.
 
 Dependencies
 ------------
 - Frameworks: PDFKit, SwiftUI, SwiftData, Foundation, ImageIO, AppKit/UIKit
 - Models: Vehicle8
 - Utilities: Functions (for date formatting)
 
 Notes
 -----
 - The drawing code accounts for coordinate system differences between macOS and iOS.
 - Row height computation measures wrapped text and image block height to avoid clipping.
 - This file focuses on rendering concerns; business logic remains in data models/utilities.
*/

import PDFKit
import SwiftUI
import SwiftData
import Foundation
import ImageIO
#if os(macOS)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// A SwiftUI view that builds and displays a PDF report of vehicles.
/// - Parameter trackVehicleSelected: A binding used to determine whether to render
///   all vehicles or a specific one by name.
struct pdfReportVehicles: View {
	// MARK: State, Environment & Query
	// The query is configured in init based on the selected vehicle name; if "All Vehicles"
	// or empty, it fetches all Vehicle8 records. The generated PDF is stored in state and
	// displayed via platform-specific PDFKit wrappers.
	@Query private var dataSet: [Vehicle8]
	// tracks vehicle selected between views
	@Binding var trackVehicleSelected: String
	@Environment(\.modelContext) var modelContext

	// Hold a generated PDF to present
	@State private var pdfDocument: PDFDocument?

	let functions: Functions = Functions()

	// zoom control
	@State private var zoomAction: ZoomAction?
	// navigation state for the PDF report (detail column)
	@State private var isShowingPDFReport: Bool = false
	init(trackVehicleSelected: Binding<String>) {
		self._trackVehicleSelected = trackVehicleSelected
		let vehicleName = trackVehicleSelected.wrappedValue
		if vehicleName != "All Vehicles" && !vehicleName.isEmpty {
			self._dataSet = Query(
				filter: #Predicate<Vehicle8> { $0.name == vehicleName },
				sort: [
					SortDescriptor(\.name, order: .forward)
				]
			)
		} else {
			// all vehicles
			self._dataSet = Query(
				sort: [
					SortDescriptor(\.name, order: .forward)
				]
			)
		}
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

	private func generateAndShowPDF() {
		guard let pdfData = generatePDFWithTable() else { return }
		if let doc = PDFDocument(data: pdfData) {
			self.pdfDocument = doc
			_ = savePDF(data: pdfData, fileName: "Vehicles")
		}
	}

	/// Simple zoom intents forwarded to the underlying PDFKit view.
	enum ZoomAction {
		case zoomIn
		case zoomOut
		case fit
		case actual
	}

	#if os(macOS)
	/// A lightweight PDFKit wrapper that binds a PDFDocument and applies zoom actions.
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
	/// A lightweight PDFKit wrapper that binds a PDFDocument and applies zoom actions.
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

	/// Represents a single table cell's content. The first column pairs an optional image
	/// (thumbnail) with a text description stacked vertically.
	struct ColumnContent {
		var text: String
		var imageData: Data? = nil
	}

	/// Produces the ordered column values for a given vehicle record.
	///
	/// Columns (9):
	/// 0. IMAGE + description
	/// 1. NAME
	/// 2. VEHICLE DETAILS (Year/Make/Model/Trim, line-broken)
	/// 3. ODOM(VIRTUAL)
	/// 4. ENG HRS
	/// 5. FUEL TYPE
	/// 6. ENGINE/TRANS
	/// 7. VIN/PLATE
	/// 8. NOTES
	nonisolated func valuesForRecord(_ record: Vehicle8) -> [ColumnContent] {
		let imageDesc = record.image1Description

		let name = record.name
		let ymmT = [
			String(record.year),
			record.manufacturer,
			record.model,
			record.trim
		]
		.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
		.joined(separator: "\n")

		let odometer = NumberFormatter.localizedString(from: NSNumber(value: record.mileage), number: .decimal)
		let vOdometer = NumberFormatter.localizedString(from: NSNumber(value: record.mileageVirtual), number: .decimal)
		let combineOdom = "\(odometer)\n(\(vOdometer))"

		let engHours = String(format: "%.1f", record.engHours)
		let fuel = record.fuelType

		let engineTrans = [record.engine, record.transmission]
			.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
			.joined(separator: "\n")

		let vin = record.vin
		let license = record.licensePlate
		let vinPlate = [vin, license]
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
			.joined(separator: "\n")

		let notes = record.notes

		return [
			ColumnContent(text: imageDesc, imageData: record.image1), // IMAGE + description
			ColumnContent(text: name),
			ColumnContent(text: ymmT),
			ColumnContent(text: combineOdom),
			ColumnContent(text: engHours),
			ColumnContent(text: fuel),
			ColumnContent(text: engineTrans),
			ColumnContent(text: vinPlate),
			ColumnContent(text: notes)
		]
	}
	
	/// Generates a multipage PDF table for the current `dataSet`.
	/// Handles pagination, header/footer drawing, and platform-specific rendering contexts.
	/// Returns raw PDF data that can be wrapped in a PDFDocument and/or saved to disk.
	func generatePDFWithTable() -> Data? {
		let pageWidth: CGFloat = 792
		let pageHeight: CGFloat = 612
		let margin: CGFloat = 20

		// Space reserved for page header/footer
		let headerHeight: CGFloat = 36
		let footerHeight: CGFloat = 24

		let headerRows: [[String]] = [
			["IMAGE", "VEHICLE\nNAME", "VEHICLE\nDETAILS", "ODOM\n(VIRTUAL)", "ENG\nHRS", "FUEL\nTYPE", "ENGINE\nTRANS", "VIN\nPLATE", "NOTES"]
		]

		let contentWidth = pageWidth - 2 * margin
		let minRowHeight: CGFloat = 32

		// 9 columns for the report (sum ≈ 1.0)
		let columnWeights: [CGFloat] = [
			0.14, // IMAGE
			0.12, // NAME
			0.12, // VEHICLE DETAILS
			0.10, // ODOM(VIRTUAL)
			0.06, // ENG HRS
			0.08, // FUEL TYPE
			0.12, // ENGINE/TRANS
			0.08, // VIN/PLATE
			0.18  // NOTES
		]
		let columnWidths = columnWeights.map { $0 * contentWidth }

		let reportTitle = "Vehicles Report"
		let vehicleTitle = (trackVehicleSelected == "All Vehicles" || trackVehicleSelected.isEmpty) ? "All Vehicles" : trackVehicleSelected
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

	/// Draws the page header including title, subtitle (vehicle scope), date, and page number.
	/// Accounts for coordinate differences between macOS and iOS.
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

	/// Draws a simple centered page number in the footer area.
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

	/// Draws the header rows for the table and returns the total header block height.
	/// Measures multi-line headers per column, fills background, and draws a grid.
	@discardableResult
	nonisolated func drawTableHeaders(at origin: CGPoint, columnWidths: [CGFloat], headerRows: [[String]], minRowHeight: CGFloat, pageHeight: CGFloat? = nil) -> CGFloat {
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

	// MARK: - macOS image decoding helpers (robust for HEIC/JPEG/PNG/etc.)
	/// Decodes image data into a CGImage using ImageIO with caching enabled for reliability.
	#if os(macOS)
	nonisolated private func cgImageFromData(_ data: Data) -> CGImage? {
		guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
		// Decode first image; caching improves PDF rendering reliability
		return CGImageSourceCreateImageAtIndex(src, 0, [
			kCGImageSourceShouldCache: true as CFBoolean
		] as CFDictionary)
	}
	/// Extracts the pixel dimensions from image data via ImageIO properties.
	nonisolated private func imagePixelSize(_ data: Data) -> CGSize? {
		guard let src = CGImageSourceCreateWithData(data as CFData, nil),
					let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
					let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
					let h = props[kCGImagePropertyPixelHeight] as? CGFloat,
					w > 0, h > 0 else { return nil }
		return CGSize(width: w, height: h)
	}
	#endif

	/// Computes the row height by measuring wrapped text across all columns and the
	/// image+description block in column 0, returning the maximum to avoid clipping.
	nonisolated func computeRowHeight(for record: Vehicle8, columnWidths: [CGFloat], minRowHeight: CGFloat) -> CGFloat {
		let columns = valuesForRecord(record)
		let notesIndex = 8

		#if os(macOS)
		let font = NSFont.systemFont(ofSize: 8)
		#else
		let font = UIFont.systemFont(ofSize: 8)
		#endif

		// All columns centered except NOTES (left)
		var paragraphStyles: [NSMutableParagraphStyle] = []
		for i in 0..<columns.count {
			let p = NSMutableParagraphStyle()
			p.lineBreakMode = .byWordWrapping
			p.alignment = (i == notesIndex) ? .left : .center
			paragraphStyles.append(p)
		}

		// Text columns height
		var maxTextHeight: CGFloat = minRowHeight
		for (index, col) in columns.enumerated() {
			let width = columnWidths[min(index, columnWidths.count - 1)] - 8 // horizontal inset
			let attributes: [NSAttributedString.Key: Any] = [
				.font: font,
				.paragraphStyle: paragraphStyles[index]
			]
			let bounding = NSAttributedString(string: col.text, attributes: attributes)
				.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
											options: [.usesLineFragmentOrigin, .usesFontLeading],
											context: nil)
			let cellHeight = ceil(bounding.height) + 12 // vertical insets
			maxTextHeight = max(maxTextHeight, cellHeight)
		}

		// Image + description height for column 0
		let imageColumnWidth = columnWidths[0]
		let innerWidth = imageColumnWidth - 8
		let maxImageHeight: CGFloat = 60 // target thumbnail height
		var imageHeight: CGFloat = 0
		if let data = columns[0].imageData {
			#if os(macOS)
			if let size = imagePixelSize(data) {
				let scale = min(innerWidth / size.width, maxImageHeight / size.height)
				imageHeight = max(0, min(maxImageHeight, size.height * scale))
			}
			#else
			if let img = UIImage(data: data) {
				let size = img.size
				if size.width > 0 && size.height > 0 {
					let scale = min(innerWidth / size.width, maxImageHeight / size.height)
					imageHeight = max(0, min(maxImageHeight, size.height * scale))
				}
			}
			#endif
		}
		// description text under image (columns[0].text)
		let descAttributes: [NSAttributedString.Key: Any] = [
			.font: font,
			.paragraphStyle: paragraphStyles[0]
		]
		let descBounding = NSAttributedString(string: columns[0].text, attributes: descAttributes)
			.boundingRect(with: CGSize(width: innerWidth, height: .greatestFiniteMagnitude),
										options: [.usesLineFragmentOrigin, .usesFontLeading],
										context: nil)
		let descHeight = ceil(descBounding.height)

		let imageBlockHeight = imageHeight + (imageHeight > 0 ? 4 : 0) + descHeight + 12 // padding similar to text cells

		return max(maxTextHeight, max(minRowHeight, imageBlockHeight))
	}

	/// Renders a single table row with alternating background, grid, and per-column content.
	/// Column 0 renders a thumbnail (or placeholder) above a description; other columns draw text.
	nonisolated func drawTableRow(record: Vehicle8, at origin: CGPoint, columnWidths: [CGFloat], rowHeight: CGFloat, rowIndex: Int, pageHeight: CGFloat? = nil) {
		let columns = valuesForRecord(record)
		let notesIndex = 8

		#if os(macOS)
		let font = NSFont.systemFont(ofSize: 8)
		let separatorColor = NSColor.separatorColor
		let rowAltFill = NSColor(white: 0.96, alpha: 1.0)
		#else
		let font = UIFont.systemFont(ofSize: 8)
		let separatorColor = UIColor.separator
		let rowAltFill = UIColor(white: 0.96, alpha: 1.0)
		#endif

		// All columns centered except NOTES (left)
		var paragraphStyles: [NSMutableParagraphStyle] = []
		for i in 0..<columns.count {
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

		// Draw content in each column
		var textX = origin.x
		for (index, col) in columns.enumerated() {
			let width = columnWidths[min(index, columnWidths.count - 1)]
			let valueRectTop = CGRect(x: textX, y: origin.y, width: width, height: rowHeight)
			let attributes: [NSAttributedString.Key: Any] = [
				.font: font,
				.paragraphStyle: paragraphStyles[index]
			]

			#if os(macOS)
			let ph = pageHeight ?? 0
			let cellRect = CGRect(x: valueRectTop.origin.x,
			                      y: ph - valueRectTop.origin.y - valueRectTop.height,
			                      width: valueRectTop.width,
			                      height: valueRectTop.height)
			let drawRect = cellRect.insetBy(dx: 4, dy: 6)
			#else
			let drawRect = valueRectTop.insetBy(dx: 4, dy: 6)
			#endif

			if index == 0 {
				// IMAGE + DESCRIPTION
				let innerWidth = drawRect.width
				let maxImageHeight: CGFloat = 60
				var usedImageHeight: CGFloat = 0
				var didDrawImage = false

				#if os(macOS)
				if let data = col.imageData, let cgImg = cgImageFromData(data) {
					let size = CGSize(width: cgImg.width, height: cgImg.height)
					if size.width > 0 && size.height > 0, let ctx = NSGraphicsContext.current?.cgContext {
						let scale = min(innerWidth / size.width, maxImageHeight / size.height)
						let drawH = max(0, min(maxImageHeight, size.height * scale))
						let drawW = size.width * scale
						let imageRect = CGRect(
							x: drawRect.origin.x + (innerWidth - drawW)/2,
							y: drawRect.origin.y + drawRect.height - drawH, // top of cell
							width: drawW,
							height: drawH
						)
						ctx.interpolationQuality = .high
						ctx.draw(cgImg, in: imageRect)
						usedImageHeight = drawH
						didDrawImage = true
					}
				}
				// Placeholder if no image data
				if !didDrawImage {
					let phRect = CGRect(
						x: drawRect.origin.x + 2,
						y: drawRect.origin.y + drawRect.height - maxImageHeight,
						width: innerWidth - 4,
						height: maxImageHeight
					)
					NSColor(white: 0.9, alpha: 1).setFill()
					NSBezierPath(rect: phRect).fill()
					let placeholderAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 7), .foregroundColor: NSColor.gray]
					let placeholder = NSAttributedString(string: "No Image", attributes: placeholderAttrs)
					placeholder.draw(in: phRect.insetBy(dx: 2, dy: 2))
					usedImageHeight = maxImageHeight
				}
				// Description under image
				let descRect = CGRect(
					x: drawRect.origin.x,
					y: drawRect.origin.y,
					width: drawRect.width,
					height: drawRect.height - (usedImageHeight + 4)
				)
				NSAttributedString(string: col.text, attributes: attributes).draw(in: descRect)
				#else
				if let data = col.imageData, let img = UIImage(data: data) {
					let size = img.size
					if size.width > 0 && size.height > 0 {
						let scale = min(innerWidth / size.width, maxImageHeight / size.height)
						let drawH = max(0, min(maxImageHeight, size.height * scale))
						let drawW = size.width * scale
						let imageRect = CGRect(
							x: drawRect.origin.x + (innerWidth - drawW)/2,
							y: drawRect.origin.y,
							width: drawW,
							height: drawH
						)
						img.draw(in: imageRect)
						usedImageHeight = drawH
						didDrawImage = true
					}
				}
				if !didDrawImage {
					let phRect = CGRect(
						x: drawRect.origin.x + 2,
						y: drawRect.origin.y,
						width: innerWidth - 4,
						height: maxImageHeight
					)
					UIColor(white: 0.9, alpha: 1).setFill()
					UIBezierPath(rect: phRect).fill()
					let placeholderAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 7), .foregroundColor: UIColor.gray]
					let placeholder = NSAttributedString(string: "No Image", attributes: placeholderAttrs)
					placeholder.draw(in: phRect.insetBy(dx: 2, dy: 2))
					usedImageHeight = maxImageHeight
				}
				let textOriginY = drawRect.origin.y + usedImageHeight + 4
				let descRect = CGRect(
					x: drawRect.origin.x,
					y: textOriginY,
					width: drawRect.width,
					height: drawRect.height - (usedImageHeight + 4)
				)
				NSAttributedString(string: col.text, attributes: attributes).draw(in: descRect)
				#endif
			} else {
				#if os(macOS)
				NSAttributedString(string: col.text, attributes: attributes)
					.draw(in: drawRect)
				#else
				NSAttributedString(string: col.text, attributes: attributes)
					.draw(in: drawRect)
				#endif
			}

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

	/// Saves the given PDF data into the app's Documents directory using the provided file name.
	/// - Returns: The file URL on success, or nil on failure.
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

	/// Presents the platform print UI for the current PDF document.
	/// Uses NSPrintOperation on macOS and UIPrintInteractionController on iOS.
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
		printInfo.jobName = "Vehicles"
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

// MARK: - Previews
/// A small preview host that seeds an in-memory SwiftData container and presents two previews:
/// one for all vehicles and one for a specific vehicle.
private struct VehiclesReportPreviewHost: View {
	let container: ModelContainer

	init() {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try! ModelContainer(for: Vehicle8.self, configurations: config)

		let context = container.mainContext

		// Build a tiny sample image into Data so the preview shows the image column working
		#if os(macOS)
		let sampleImageData: Data? = {
			let size = NSSize(width: 60, height: 40)
			let image = NSImage(size: size)
			image.lockFocus()
			NSColor.systemBlue.setFill()
			NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
			let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 10), .foregroundColor: NSColor.white]
			NSAttributedString(string: "IMG", attributes: attrs).draw(at: CGPoint(x: 15, y: 12))
			image.unlockFocus()
			return image.tiffRepresentation
		}()
		#else
		let sampleImageData: Data? = {
			let size = CGSize(width: 60, height: 40)
			UIGraphicsBeginImageContextWithOptions(size, true, 1)
			UIColor.systemBlue.setFill()
			UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
			let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor.white]
			let text = NSAttributedString(string: "IMG", attributes: attrs)
			text.draw(at: CGPoint(x: 15, y: 12))
			let image = UIGraphicsGetImageFromCurrentImageContext()
			UIGraphicsEndImageContext()
			return image?.pngData()
		}()
		#endif

		let samples: [Vehicle8] = [
			Vehicle8(name: "Vehicle A", manufacturer: "Acme", model: "Hauler", year: 2021, trim: "XL", mileage: 12050, engHours: 12.5, transmission: "6-spd Auto", engine: "3.0L V6", fuelType: "Diesel", notes: "Primary tow vehicle.", vin: "1A2B3C4D5E6F7G8H9", licensePlate: "ABC123", image1: sampleImageData, image1Description: "Front view"),
			Vehicle8(name: "Vehicle B", manufacturer: "Bravo", model: "Runner", year: 2018, trim: "Sport", mileage: 5400, engHours: 4.0, transmission: "CVT", engine: "2.0L I4", fuelType: "Gasoline", notes: "Compact and efficient.", vin: "9H8G7F6E5D4C3B2A1Z", licensePlate: "XYZ789", image1: nil, image1Description: "Side view")
		]
		samples.forEach { context.insert($0) }
		try? context.save()

		self.container = container
	}

	var body: some View {
		Group {
			// All Vehicles preview
			pdfReportVehicles(trackVehicleSelected: .constant("All Vehicles"))
				.previewDisplayName("All Vehicles")

			// Specific vehicle preview
			pdfReportVehicles(trackVehicleSelected: .constant("Vehicle A"))
				.previewDisplayName("Vehicle A")
		}
		.modelContainer(container)
	}
}

#Preview {
	VehiclesReportPreviewHost()
}

