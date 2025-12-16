/*
 pdfReportTrip.swift
 LandShip

 A SwiftUI view that generates a paginated, printable PDF report of trip logs
 using PDFKit and Core Graphics drawing primitives. The report presents a
 tabular layout with multi-row headers, alternating row backgrounds, per-page
 headers/footers, zoom controls for preview, and grand totals at the end.

 Overview
 --------
 - Data Source: SwiftData `TripLog2` records fetched via `@Query`, filtered by
   the bound `trackVehicleSelected` (either a specific vehicle or "All Vehicles").
 - Rendering: Cross-platform drawing paths for macOS and iOS. macOS uses
   `CGContext` with `NSGraphicsContext` bridging; iOS uses `UIGraphicsPDFRenderer`.
 - Layout: A fixed page size (letter landscape: 792x612 pt), margins, and a
   multi-column table. Rows auto-wrap text and expand to fit content.
 - Interactivity: A simple PDF preview (PDFView) with controls to zoom in/out,
   fit to page, and set actual size (100%). A toolbar button regenerates the PDF.
 - Output: The generated PDF is saved to the app's Documents directory and can
   be printed via the system print UI.

 Key Customization Points
 ------------------------
 - Columns & headers: Update `headerRows` and `columnWeights` in `generatePDFWithTable`.
 - Units & formatting: Provided by `PrefsFunctions` and `Functions` helpers.
 - Pagination: Page header/footer heights, margins, minimum row heights, and
   totals row height.

 Threading & Performance
 -----------------------
 PDF generation occurs synchronously on the main thread when the view appears or
 when the user taps Regenerate. For large datasets, consider dispatching the
 generation work off the main thread and assigning the resulting `PDFDocument`
 back on the main thread.

 Platform Notes
 --------------
 - macOS: Uses `PDFView` via `NSViewRepresentable` and manual PDF page creation
   (`CGContext.beginPDFPage`). Coordinates are converted for AppKit where needed.
 - iOS/iPadOS: Uses `PDFView` via `UIViewRepresentable` and
   `UIGraphicsPDFRenderer` for PDF creation.

 Usage
 -----
 Embed `pdfReportTrip` in your navigation flow and bind `trackVehicleSelected`.
 The view generates the PDF on first appearance and provides a toolbar for
 regeneration, zooming, and printing.
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

/// A SwiftUI view that builds and previews a printable PDF report of `TripLog2` entries.
/// - Note: The PDF is regenerated on first appearance and on demand via the toolbar.
struct pdfReportTrip: View {
	// MARK: - Properties
	
	/// The trip log entries to be rendered into the PDF table. Filtered by the selected vehicle.
	@Query private var dataSet: [TripLog2]
	
	/// The currently selected vehicle name (or "All Vehicles"). Controls the query filter.
	@Binding var trackVehicleSelected: String
	
	/// SwiftData model context used to resolve preferences and any needed data.
	@Environment(\.modelContext) var modelContext
	
	@State private var allVehiclesSelected: Bool = true /// if all vehicles, disable save update button
	
	/// The in-memory PDF document presented in the embedded PDFKit view.
	@State private var pdfDocument: PDFDocument?
	
	/// Helper functions for formatting dates, units, and domain-specific values.
	let functions: Functions = Functions()
	
	/// Helper for loading persisted user preference settings (units, etc.).
	let prefsFunc: PrefsFunctions = PrefsFunctions()
	
	/// A transient control message sent to the embedded PDFView to adjust zoom behavior.
	@State private var zoomAction: ZoomAction?

	// MARK: - Initialization
	/// Initializes the view and configures the SwiftData query to include either all vehicles
	/// or only the bound `trackVehicleSelected` vehicle.
	init(trackVehicleSelected: Binding<String>) {
		self._trackVehicleSelected = trackVehicleSelected
		let vehicleId = trackVehicleSelected.wrappedValue
		if vehicleId != "All Vehicles" {
			self._dataSet = Query(
				filter: #Predicate<TripLog2> { $0.vehicleId == vehicleId },
				sort: [
					SortDescriptor(\.vehicleId, order: .forward),
					SortDescriptor(\.tripDateTimeStart, order: .reverse)
				]
			)
		} else {
			// all vehicles
			self._dataSet = Query(
				sort: [
					SortDescriptor(\.vehicleId, order: .forward),
					SortDescriptor(\.tripDateTimeStart, order: .reverse)
				]
			)
		}
	}

	// MARK: - Body
	/// Hosts a PDF preview when available, otherwise shows a progress view and a retry button.
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
				.disabled(pdfDocument == nil)
			}
		}
	}

	// MARK: - Actions
	/// Generates the PDF data using `generatePDFWithTable(units:)`, saves it to disk, and
	/// updates `pdfDocument` for on-screen preview.
	private func generateAndShowPDF() {
		// Load settings as an array (see Functions.loadSettingsArray)
		let units = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1")
			?? Array(repeating: "", count: 13)

		guard let pdfData = generatePDFWithTable(units: units) else { return }
		if let doc = PDFDocument(data: pdfData) {
			self.pdfDocument = doc
			_ = savePDF(data: pdfData, fileName: "Trip Log")
		}
	}

	// MARK: - Supporting Types
	/// A set of discrete zoom commands forwarded to the platform PDFView wrapper.
	enum ZoomAction {
		case zoomIn
		case zoomOut
		case fit
		case actual
	}

	// MARK: - PDF Preview (macOS)
	#if os(macOS)
	/// Wraps `PDFView` for SwiftUI on macOS and applies zoom actions as they are issued.
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
	// MARK: - PDF Preview (iOS)
	/// Wraps `PDFView` for SwiftUI on iOS and applies zoom actions as they are issued.
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

	// MARK: - Table Data & Layout Helpers
	/// Builds the column strings for a single row in the report, combining locations and fuel info.
	/// - Parameters:
	///   - record: The trip log to render.
	///   - units: The user-selected units array, used for labeling quantities.
	/// - Returns: An ordered array of strings, matching the report's column order.
	func valuesForRecord(_ record: TripLog2, units: [String]) -> [String] {
		let vehicle = record.vehicleId
		let towed = record.vehicleTowed ? record.vehicleIdTowed : ""

		// depart / arrive
		let levelStart = record.fuelLevelStart.isEmpty ? functions.getFuelLevel(unit: record.fuelLevelStart1) : record.fuelLevelStart
		let levelEnd = record.fuelLevelEnd.isEmpty ? functions.getFuelLevel(unit: record.fuelLevelEnd1) : record.fuelLevelEnd

		let departure = "\(record.locationStart)\n\(functions.formatDate_HHmm_DDMMMyyyy(date: record.tripDateTimeStart))\nFuel Lvl: \(levelStart)"
		let arrival = "\(record.locationEnd)\n\(functions.formatDate_HHmm_DDMMMyyyy(date: record.tripDateTimeEnd))\nFuel Lvl: \(levelEnd)"
		// Elapsed time between start and end
		let durationText: String = {
			let interval = max(0, record.tripDateTimeEnd.timeIntervalSince(record.tripDateTimeStart))
			let f = DateComponentsFormatter()
			f.allowedUnits = [.hour, .minute]
			f.unitsStyle = .abbreviated // e.g., "5h 30m"
			return f.string(from: interval) ?? "-"
		}()

		let distance = NumberFormatter.localizedString(from: NSNumber(value: max(0, record.odometerEnd - record.odometerStart)), number: .decimal)

		// Fuel consumed: prefer field if present, else compute from quantities + enroute adds
		let enrouteAdds = record.fuelAdded1 + record.fuelAdded2 + record.fuelAdded3 + record.fuelAdded4 + record.fuelAdded5 + record.fuelAdded6
		let computedConsumedRaw = (record.fuelQuantityStart - record.fuelQuantityEnd) + enrouteAdds
		let consumedValue = record.fuelConsumed > 0 ? record.fuelConsumed : max(0, computedConsumedRaw)

		let qtyFormatter = NumberFormatter()
		qtyFormatter.numberStyle = .decimal
		qtyFormatter.minimumFractionDigits = 1
		qtyFormatter.maximumFractionDigits = 1

		let fuelAddedText = (qtyFormatter.string(from: NSNumber(value: max(0, enrouteAdds))) ?? "\(enrouteAdds)") + " \(units[UnitIndex.fuel])"
		let fuelConsumedText = (qtyFormatter.string(from: NSNumber(value: consumedValue)) ?? "\(consumedValue)") + " \(units[UnitIndex.fuel])"


		let notes = record.tripNotes

		// Columns: VEHICLE, DATE START, DATE END, TOWED, TIME ELAPSED, DISTANCE, LOCATIONS, FUEL LVL (START/END), FUEL ADDED, FUEL CONSUMED, NOTES
		return [vehicle, towed, departure, arrival, durationText, distance, fuelAddedText, fuelConsumedText, notes]
	}

	/// Computes raw metrics used by totals (duration, distance, and fuel consumed) for a record.
	private func computeMetrics(for record: TripLog2) -> (duration: TimeInterval, distance: Int, fuelConsumed: Float) {
		let duration = max(0, record.tripDateTimeEnd.timeIntervalSince(record.tripDateTimeStart))
		let distance = max(0, record.odometerEnd - record.odometerStart)
		let enrouteAdds = record.fuelAdded1 + record.fuelAdded2 + record.fuelAdded3 + record.fuelAdded4 + record.fuelAdded5 + record.fuelAdded6
		let computedConsumedRaw = (record.fuelQuantityStart - record.fuelQuantityEnd) + enrouteAdds
		let fuelConsumed = record.fuelConsumed > 0 ? record.fuelConsumed : max(0, computedConsumedRaw)
		return (duration, distance, fuelConsumed)
	}

	/// Formats a time interval as abbreviated hours and minutes (e.g., "5h 30m").
	private func formatDuration(_ seconds: TimeInterval) -> String {
		let f = DateComponentsFormatter()
		f.allowedUnits = [.hour, .minute]
		f.unitsStyle = .abbreviated
		return f.string(from: seconds) ?? "-"
	}

	/// Draws a highlighted totals row with duration, distance, and fuel consumed.
	/// - Parameters:
	///   - label: Leading label for the row (e.g., "Page Totals" or "Report Totals").
	///   - totals: Tuple of duration, distance, and fuel consumed.
	///   - origin: Top-left origin for the row in the current page coordinate space.
	///   - columnWidths: Per-column widths matching the table layout.
	///   - rowHeight: The fixed height for the totals row.
	///   - units: Units used to label fuel consumed.
	///   - pageHeight: On macOS, the full page height for y-axis conversion.
	private func drawTotalsRow(label: String = "Page Totals",
	                           totals: (duration: TimeInterval, distance: Int, fuelConsumed: Float),
	                           at origin: CGPoint,
	                           columnWidths: [CGFloat],
	                           rowHeight: CGFloat,
	                           units: [String],
	                           pageHeight: CGFloat? = nil) {
		let valuesCount = columnWidths.count
		let durationIndex = 4
		let distanceIndex = 5
		let fuelConsumedIndex = 9

		let durationText = formatDuration(totals.duration)
		let distanceText = NumberFormatter.localizedString(from: NSNumber(value: totals.distance), number: .decimal)
		let qtyFormatter = NumberFormatter()
		qtyFormatter.numberStyle = .decimal
		qtyFormatter.minimumFractionDigits = 1
		qtyFormatter.maximumFractionDigits = 1
		let fuelConsumedText = (qtyFormatter.string(from: NSNumber(value: totals.fuelConsumed)) ?? "\(totals.fuelConsumed)") + " \(units[UnitIndex.fuel])"

		#if os(macOS)
		let font = NSFont.boldSystemFont(ofSize: 8)
		let separatorColor = NSColor.separatorColor
		let backgroundFill = NSColor(calibratedRed: 0.93, green: 0.96, blue: 0.91, alpha: 1.0)
		#else
		let font = UIFont.boldSystemFont(ofSize: 8)
		let separatorColor = UIColor.separator
		let backgroundFill = UIColor(red: 0.93, green: 0.96, blue: 0.91, alpha: 1.0)
		#endif

		// Background fill across the full row width
		let totalWidth = columnWidths.reduce(0, +)
		#if os(macOS)
		let ph = pageHeight ?? 0
		let rowRectTop = CGRect(x: origin.x, y: origin.y, width: totalWidth, height: rowHeight)
		let rowRect = CGRect(x: rowRectTop.origin.x,
		                     y: ph - rowRectTop.origin.y - rowRectTop.height,
		                     width: rowRectTop.width,
		                     height: rowRectTop.height)
		backgroundFill.setFill()
		NSBezierPath(rect: rowRect).fill()
		#else
		let rowRect = CGRect(x: origin.x, y: origin.y, width: totalWidth, height: rowHeight)
		backgroundFill.setFill()
		UIBezierPath(rect: rowRect).fill()
		#endif

		// Paragraph styles: left align label in column 0, center others
		var paragraphStyles: [NSMutableParagraphStyle] = []
		for i in 0..<valuesCount {
			let p = NSMutableParagraphStyle()
			p.lineBreakMode = .byWordWrapping
			if i == 0 {
				p.alignment = .left
			} else {
				p.alignment = .center
			}
			paragraphStyles.append(p)
		}

		// Draw label and totals in their columns
		var textX = origin.x
		for col in 0..<valuesCount {
			let width = columnWidths[col]
			let valueRectTop = CGRect(x: textX, y: origin.y, width: width, height: rowHeight)
			let attributes: [NSAttributedString.Key: Any] = [
				.font: font,
				.paragraphStyle: paragraphStyles[col]
			]

			var text = ""
			if col == 0 {
				text = label
			} else if col == durationIndex {
				text = durationText
			} else if col == distanceIndex {
				text = distanceText
			} else if col == fuelConsumedIndex {
				text = fuelConsumedText
			}

			#if os(macOS)
			let ph = pageHeight ?? 0
			let valueRect = CGRect(x: valueRectTop.origin.x,
			                       y: ph - valueRectTop.origin.y - valueRectTop.height,
			                       width: valueRectTop.width,
			                       height: valueRectTop.height)
			NSAttributedString(string: text, attributes: attributes)
				.draw(in: valueRect.insetBy(dx: 4, dy: 6))
			#else
			NSAttributedString(string: text, attributes: attributes)
				.draw(in: valueRectTop.insetBy(dx: 4, dy: 6))
			#endif

			textX += width
		}

		// Draw bottom border of the totals row
		separatorColor.setStroke()
		#if os(macOS)
		let rowPath = NSBezierPath()
		rowPath.lineWidth = 0.5
		func yConv(_ yTop: CGFloat) -> CGFloat { (pageHeight ?? 0) - yTop }
		rowPath.move(to: CGPoint(x: origin.x, y: yConv(origin.y + rowHeight)))
		rowPath.line(to: CGPoint(x: origin.x + totalWidth, y: yConv(origin.y + rowHeight)))
		rowPath.stroke()
		#else
		let rowPath = UIBezierPath()
		rowPath.lineWidth = 0.5
		rowPath.move(to: CGPoint(x: origin.x, y: origin.y + rowHeight))
		rowPath.addLine(to: CGPoint(x: origin.x + totalWidth, y: origin.y + rowHeight))
		rowPath.stroke()
		#endif
	}
	
	// MARK: - PDF Generation
	/// Creates a multi-page PDF containing the report table with headers and a final totals row.
	/// Handles pagination and cross-platform drawing paths for macOS and iOS.
	func generatePDFWithTable(units: [String]) -> Data? {
		let pageWidth: CGFloat = 792
		let pageHeight: CGFloat = 612
		let margin: CGFloat = 20

		// Space reserved for page header/footer
		let headerHeight: CGFloat = 36
		let footerHeight: CGFloat = 24

		let distanceExpanded = functions.getUnits(unit: units[UnitIndex.distance])
		let headerRows: [[String]] = [
			["VEHICLE", "VEHICLE\nTOWED", "DEPARTURE", "ARRIVAL", "TIME\nENROUTE", "DIST\n(\(distanceExpanded))", "FUEL\nADD", "FUEL\nBURN", "TRIP NOTES"]
		]

		let contentWidth = pageWidth - 2 * margin
		let minRowHeight: CGFloat = 32
		let totalsRowHeight: CGFloat = 28 // used for grand totals only

		// 11 columns for the report (sum ≈ 1.0)
		let columnWeights: [CGFloat] = [
			0.09, // VEHICLE
			0.08, // TOWED
			0.10, // DEPARTURE
			0.10, // ARRIVAL
			0.08, // TIME ELAPSED
			0.06, // DISTANCE
//			0.07, // FUEL LVL START/END (combined)
			0.06, // FUEL ADDED
			0.06, // FUEL CONSUMED
			0.25  // TRIP NOTES (slightly increased to balance)
		]
		let columnWidths = columnWeights.map { $0 * contentWidth }

		let reportTitle = "Travel Log Report"
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
			var nsGraphicsContext = NSGraphicsContext(cgContext: cgContext, flipped: false)
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

		// Grand totals (across entire report)
		var grandTotalDuration: TimeInterval = 0
		var grandTotalDistance: Int = 0
		var grandTotalFuelConsumed: Float = 0

		for (index, record) in dataSet.enumerated() {
			let rowHeight = computeRowHeight(for: record, columnWidths: columnWidths, minRowHeight: minRowHeight, units: units)
			// Ensure there is space for the row; if not, new page
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

			// Draw row
			drawTableRow(record: record,
									 at: CGPoint(x: margin, y: currentY),
									 columnWidths: columnWidths,
									 rowHeight: rowHeight,
									 rowIndex: index,
									 units: units,
									 pageHeight: pageHeight)
			currentY += rowHeight

			// Accumulate grand totals
			let metrics = computeMetrics(for: record)
			grandTotalDuration += metrics.duration
			grandTotalDistance += metrics.distance
			grandTotalFuelConsumed += metrics.fuelConsumed
		}

		// Draw grand totals at bottom of the last page
		if !dataSet.isEmpty {
			// If there isn't enough room on the current page, start a new one (with headers)
			if currentY + totalsRowHeight > maxContentBottom {
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
			// Place the grand totals row at the bottom of the page, above the footer
			let grandTotalsY = maxContentBottom - totalsRowHeight
			drawTotalsRow(label: "Report Totals",
			              totals: (grandTotalDuration, grandTotalDistance, grandTotalFuelConsumed),
			              at: CGPoint(x: margin, y: grandTotalsY),
			              columnWidths: columnWidths,
			              rowHeight: totalsRowHeight,
			              units: units,
			              pageHeight: pageHeight)
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

			// Grand totals (across entire report)
			var grandTotalDuration: TimeInterval = 0
			var grandTotalDistance: Int = 0
			var grandTotalFuelConsumed: Float = 0

			for (index, record) in dataSet.enumerated() {
				let rowHeight = computeRowHeight(for: record, columnWidths: columnWidths, minRowHeight: minRowHeight, units: units)
				// Check space for row; if not, new page
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

				// Draw row
				drawTableRow(record: record, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, rowHeight: rowHeight, rowIndex: index, units: units)
				currentY += rowHeight

				// Accumulate grand totals
				let metrics = computeMetrics(for: record)
				grandTotalDuration += metrics.duration
				grandTotalDistance += metrics.distance
				grandTotalFuelConsumed += metrics.fuelConsumed
			}

			// Draw grand totals at bottom of the last page
			if !dataSet.isEmpty {
				// If there isn't enough room on the current page, start a new one (with headers)
				if currentY + totalsRowHeight > maxContentBottom {
					pageNumber += 1
					beginIOSPage()
					currentY = margin + headerHeight
					let h = drawTableHeaders(at: CGPoint(x: margin, y: currentY),
					                         columnWidths: columnWidths,
					                         headerRows: headerRows,
					                         minRowHeight: 20)
					currentY += h
				}
				// Place the grand totals row at the bottom of the page, above the footer
				let grandTotalsY = maxContentBottom - totalsRowHeight
				drawTotalsRow(label: "Report Totals",
				              totals: (grandTotalDuration, grandTotalDistance, grandTotalFuelConsumed),
				              at: CGPoint(x: margin, y: grandTotalsY),
				              columnWidths: columnWidths,
				              rowHeight: totalsRowHeight,
				              units: units)
			}
		}
		return data
		#endif
	}

	/// Draws the page header including title, subtitle (vehicle), date, and page number.
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

	/// Draws a footer with the current page number.
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

	/// Draws the multi-row table header, including background fill and grid lines.
	/// - Returns: The total header block height drawn.
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

	/// Measures and returns the row height needed to display wrapped text for all columns.
	func computeRowHeight(for record: TripLog2, columnWidths: [CGFloat], minRowHeight: CGFloat, units: [String]) -> CGFloat {
		let values = valuesForRecord(record, units: units)
		let notesIndex = 10 // last column is TRIP NOTES (after combining fuel levels)

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

	/// Draws a single data row, including alternating background fill and grid lines.
	func drawTableRow(record: TripLog2, at origin: CGPoint, columnWidths: [CGFloat], rowHeight: CGFloat, rowIndex: Int, units: [String], pageHeight: CGFloat? = nil) {
		let values = valuesForRecord(record, units: units)
		let notesIndex = 10 // last column is TRIP NOTES (after combining fuel levels)

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

	// MARK: - Persistence
	/// Saves the provided PDF data to the app's Documents directory using the given base filename.
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

	// MARK: - Printing
	/// Presents the platform print UI to print the currently generated PDF document.
	private func printPDF() {
		guard let doc = pdfDocument else { return }
		#if os(macOS)
		// Use a transient PDFView and a standard NSPrintOperation
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
		printInfo.jobName = "Trip Log"
		printInfo.outputType = .general

		let controller = UIPrintInteractionController.shared
		controller.printInfo = printInfo
		controller.printingItem = data
		controller.showsNumberOfCopies = true

		// On iPad, present from a source rect/view; on iPhone, simple present is fine.
		if UIDevice.current.userInterfaceIdiom == .pad {
			if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
			   let window = windowScene.windows.first,
			   let rootView = windowScene.windows.first?.rootViewController?.view {
				controller.present(from: rootView.bounds, in: rootView, animated: true, completionHandler: nil)
			} else {
				controller.present(animated: true, completionHandler: nil)
			}
		} else {
			controller.present(animated: true, completionHandler: nil)
		}
		#endif
	}

	// MARK: - Preview
	/*
	 Provides an in-memory SwiftData container with seeded `TripLog2` and `Settings1` data so the
	 preview can render the PDF for both All Vehicles and a specific vehicle. This is a self-contained
	 sample that exercises wrapping, pagination, computed fuel consumption, and totals.
	*/
}

#Preview {
	// In-memory SwiftData container for previews
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: TripLog2.self, Settings1.self, configurations: config)

	// Seed sample data
	let context = container.mainContext
	func makeTripLog(vehicleId: String, daysAgo: Int, odometerStart: Int, distance: Int, fuelStart: Float, fuelEnd: Float, notes: String, locStart: String, locEnd: String, adds: [Float], towed: Bool, towedId: String) -> TripLog2 {
		let start = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
		let end = Calendar.current.date(byAdding: .hour, value: 5, to: start) ?? start
		let odometerEnd = odometerStart + distance
		let (a1,a2,a3,a4,a5,a6) = (
			adds.indices.contains(0) ? adds[0] : 0,
			adds.indices.contains(1) ? adds[1] : 0,
			adds.indices.contains(2) ? adds[2] : 0,
			adds.indices.contains(3) ? adds[3] : 0,
			adds.indices.contains(4) ? adds[4] : 0,
			adds.indices.contains(5) ? adds[5] : 0
		)
		let log = TripLog2(
			vehicleId: vehicleId,
			logName: "Trip \(vehicleId) \(daysAgo)d ago",
			tripNotes: notes,
			createdAt: start,
			updatedAt: end,
			tripDateTimeStart: start,
			tripDateTimeEnd: end,
			odometerStart: odometerStart,
			odometerEnd: odometerEnd,
			engHoursStart: 0,
			engHoursEnd: 0,
			fuelQuantityStart: fuelStart,
			fuelQuantityEnd: fuelEnd,
			fuelConsumed: 0, // leave 0 to exercise computed consumption
			fuelLevelStart1: 0.5,
			fuelLevelEnd1: 1.0,
			fuelLevelStart: "1/2",
			fuelLevelEnd: "Full",
			fuelAdded1Log: "",
			fuelAdded1: a1,
			fuelAdded2Log: "",
			fuelAdded2: a2,
			fuelAdded3Log: "",
			fuelAdded3: a3,
			fuelAdded4Log: "",
			fuelAdded4: a4,
			fuelAdded5Log: "",
			fuelAdded5: a5,
			fuelAdded6Log: "",
			fuelAdded6: a6,
			locationStart: locStart,
			locationEnd: locEnd,
			vehicleTowed: towed,
			vehicleIdTowed: towedId,
			image1: nil,
			image1Description: "",
			image2: nil,
			image2Description: "",
			image3: nil,
			image3Description: ""
		)
		return log
	}
	let samples: [TripLog2] = [
		makeTripLog(vehicleId: "Vehicle A", daysAgo: 0, odometerStart: 12050, distance: 120, fuelStart: 15, fuelEnd: 8, notes: "Calm day, light traffic.", locStart: "Harbor", locEnd: "Depot", adds: [5.0], towed: true, towedId: "Trailer 1"),
		makeTripLog(vehicleId: "Vehicle A", daysAgo: 3, odometerStart: 11800, distance: 200, fuelStart: 20, fuelEnd: 10, notes: "Headwind increased burn.", locStart: "Depot", locEnd: "Harbor", adds: [0], towed: false, towedId: ""),
		makeTripLog(vehicleId: "Vehicle B", daysAgo: 1, odometerStart: 5400, distance: 60, fuelStart: 10, fuelEnd: 7, notes: "Short hop with one stop.", locStart: "Station 9", locEnd: "Station 11", adds: [2.0], towed: true, towedId: "Boat B")
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

	return Group {
		// All Vehicles preview
		pdfReportTrip(trackVehicleSelected: .constant("All Vehicles"))
			.modelContainer(container)
			.previewDisplayName("All Vehicles")

		// Specific vehicle preview
		pdfReportTrip(trackVehicleSelected: .constant("Vehicle A"))
			.modelContainer(container)
			.previewDisplayName("Vehicle A")
	}
}
