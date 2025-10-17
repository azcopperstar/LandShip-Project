//
//  pdfReportService.swift
//  LandShip
//
//  Created by JP on 9/30/25.
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

struct pdfReportService: View {
	// Fetch the service records we will render into the PDF
	@Query private var dataSet: [ServiceRecords1]
	// tracks vehicle selected between views
	@Binding var trackVehicleSelected: String
	@Environment(\.modelContext) var modelContext
	@State private var allVehiclesSelected: Bool = true /// if all vehicles, disable save update button

	// Hold a generated PDF to present
	@State private var pdfDocument: PDFDocument?

	let functions: Functions = Functions()
	let prefsFunc: PrefsFunctions = PrefsFunctions()

	// zoom control
	@State private var zoomAction: ZoomAction?

	#if canImport(UIKit) && !os(macOS)
	@State private var shareURL: URL?
	@State private var isSharing: Bool = false
	#endif

	init(trackVehicleSelected: Binding<String>) {
		self._trackVehicleSelected = trackVehicleSelected
		let vehicleId = trackVehicleSelected.wrappedValue
		if vehicleId != "All Vehicles" {
			self._dataSet = Query(
				filter: #Predicate<ServiceRecords1> { $0.vehicleId == vehicleId },
				sort: [
					SortDescriptor(\.vehicleId, order: .forward),
					SortDescriptor(\.mxDate, order: .reverse)
				]
			)
		} else {
			// all vehicles
			self._dataSet = Query(
				sort: [
					SortDescriptor(\.vehicleId, order: .forward),
					SortDescriptor(\.mxDate, order: .reverse)
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
				.disabled(pdfDocument == nil)
			}
			#if os(macOS)
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
		.sheet(isPresented: $isSharing, onDismiss: {
			// Clean up temp file after sharing completes
			if let url = shareURL {
				try? FileManager.default.removeItem(at: url)
			}
			shareURL = nil
		}) {
			if let url = shareURL {
				ActivityView(activityItems: [url])
			} else {
				Text("No PDF to share.")
			}
		}
		#endif
	}

	private func generateAndShowPDF() {
		// Load settings as an array (see Functions.loadSettingsArray)
		let units = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1")
			?? Array(repeating: "", count: 13)

		guard let pdfData = generatePDFWithTable(units: units) else { return }
		if let doc = PDFDocument(data: pdfData) {
			self.pdfDocument = doc
			_ = savePDF(data: pdfData, fileName: "Service Records")
		}
	}

	// Simple PDFKit wrapper you can present in your UI as needed.
	// macOS and iOS implementations are provided.

	enum ZoomAction {
		case zoomIn
		case zoomOut
		case fit
		case actual
	}

	#if os(macOS)
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

	// Build concise parts list and cost totals for a record
	private func partsInfo(for record: ServiceRecords1) -> (partsList: String, partsCost: Float) {
		struct PartLine { let name: String; let unit: String; let qty: Int; let cost: Float }
		var parts: [PartLine] = []
		if !record.part1.isEmpty && record.part1Quantity > 0 { parts.append(.init(name: record.part1, unit: record.part1Unit, qty: record.part1Quantity, cost: record.part1cost)) }
		if !record.part2.isEmpty && record.part2Quantity > 0 { parts.append(.init(name: record.part2, unit: record.part2Unit, qty: record.part2Quantity, cost: record.part2cost)) }
		if !record.part3.isEmpty && record.part3Quantity > 0 { parts.append(.init(name: record.part3, unit: record.part3Unit, qty: record.part3Quantity, cost: record.part3cost)) }
		if !record.part4.isEmpty && record.part4Quantity > 0 { parts.append(.init(name: record.part4, unit: record.part4Unit, qty: record.part4Quantity, cost: record.part4cost)) }
		if !record.part5.isEmpty && record.part5Quantity > 0 { parts.append(.init(name: record.part5, unit: record.part5Unit, qty: record.part5Quantity, cost: record.part5cost)) }

		let list = parts.map { p -> String in
			let qtyUnit = p.qty > 0 ? "\n\(p.qty) \(p.unit)" : ""
			let costEach = p.cost > 0 ? " @ \(functions.formatCurrency(dollars: p.cost))" : ""
			return "\(p.name)\(qtyUnit)\(costEach)"
		}.joined(separator: "\n\n")

		let cost: Float = parts.reduce(0) { partial, p in
			let qty = max(0, p.qty)
			let each = max(0, p.cost)
			return partial + Float(qty) * each
		}
		return (list, cost)
	}

	// Produce the 12 column strings for a record
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
	
	// Unified cross-platform PDF generator
	func generatePDFWithTable(units: [String]) -> Data? {
		let pageWidth: CGFloat = 792
		let pageHeight: CGFloat = 612
		let margin: CGFloat = 20

		// Space reserved for page header/footer
		let headerHeight: CGFloat = 36
		let footerHeight: CGFloat = 24 // Add footer, matching Fuel/Trip

		let distanceExpanded = functions.getUnits(unit: units[UnitIndex.distance])
		let headerRows: [[String]] = [
			["VEHICLE", "DATE", "ODOM\n(\(distanceExpanded))", "ENG\nHRS", "SERVICE\nITEM", "DESCRIPTION", "VENDOR", "LABOR", "PARTS", "TOTAL", "PARTS\nUSED", "NOTES"]
		]

		let contentWidth = pageWidth - 2 * margin
		let minRowHeight: CGFloat = 32

		// 12 columns for the report (sum ≈ 1.0)
		let columnWeights: [CGFloat] = [
			0.09, // VEHICLE
			0.05, // DATE
			0.06, // MILES
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

		let reportTitle = "Service Records Report"
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

			// Header + footer (footer added)
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
				// Header + footer (footer added)
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

	// Draw page header (cross-platform)
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

	// Draw page footer (cross-platform)
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

	// Cross-platform drawing helpers (font differs per platform)
	// Draws multi-row header and returns the total header height.
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

	// Compute a wrapped row height for the given record and columns
	func computeRowHeight(for record: ServiceRecords1, columnWidths: [CGFloat], minRowHeight: CGFloat) -> CGFloat {
		let values = valuesForRecord(record)
		let notesIndex = 11 // last column is NOTES

		#if os(macOS)
		let font = NSFont.systemFont(ofSize: 8)
		#else
		let font = UIFont.systemFont(ofSize: 8)
		#endif

		// Build per-column paragraph styles:
		// text-heavy columns left-aligned; others centered
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

	func drawTableRow(record: ServiceRecords1, at origin: CGPoint, columnWidths: [CGFloat], rowHeight: CGFloat, rowIndex: Int, pageHeight: CGFloat? = nil) {
		let values = valuesForRecord(record)
		let notesIndex = 11 // last column is NOTES

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

		// Build per-column paragraph styles
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
	// Show NSSavePanel to let the user pick name and location for the current PDF
	private func saveAsPDF() {
		guard let doc = pdfDocument, let data = doc.dataRepresentation() else { return }

		let panel = NSSavePanel()
		panel.allowedContentTypes = [.pdf]
		panel.canCreateDirectories = true
		panel.isExtensionHidden = false

		// Default name: include vehicle selection and date
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
				NSAlert(error: error).runModal()
			}
		}
	}
	#else
	// iOS/iPadOS "Save As…" via share sheet (Files, AirDrop, Mail, etc.)
	private func sharePDFiOS() {
		guard let doc = pdfDocument, let data = doc.dataRepresentation() else { return }
		// Create a temporary file URL
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
			self.isSharing = true
		} catch {
			print("Failed to write temp PDF: \(error)")
		}
	}
	#endif

	// Present system print UI for the current PDF
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
		printInfo.jobName = "Service Records"
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

#if canImport(UIKit) && !os(macOS)
private struct ActivityView: UIViewControllerRepresentable {
	let activityItems: [Any]
	var applicationActivities: [UIActivity]? = nil

	func makeUIViewController(context: Context) -> UIActivityViewController {
		let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
		// Exclude some irrelevant activities if desired:
		// controller.excludedActivityTypes = [.assignToContact, .addToReadingList]
		return controller
	}

	func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#Preview {
	// In-memory SwiftData container for previews
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: ServiceRecords1.self, Settings1.self, configurations: config)

	// Seed sample data
	let context = container.mainContext
	func makeService(vehicleId: String, daysAgo: Int, miles: Int, hours: Float, item: String, desc: String, vendor: String, labor: Float, parts: [(String, Float, String, Int)], notes: String) -> ServiceRecords1 {
		let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
		let p1 = parts.indices.contains(0) ? parts[0] : ("", 0, "", 0)
		let p2 = parts.indices.contains(1) ? parts[1] : ("", 0, "", 0)
		let p3 = parts.indices.contains(2) ? parts[2] : ("", 0, "", 0)
		let p4 = parts.indices.contains(3) ? parts[3] : ("", 0, "", 0)
		let p5 = parts.indices.contains(4) ? parts[4] : ("", 0, "", 0)
		return ServiceRecords1(
			createdAt: date,
			updatedAt: date,
			mxDate: date,
			vehicleId: vehicleId,
			Miles: miles,
			engHours: hours,
			mxName: item,
			mxItemId: "",
			mxDescription: desc,
			Notes: notes,
			vendor: vendor,
			laborCost: labor,
			part1: p1.0, part1cost: Float(p1.1), part1Unit: p1.2, part1Quantity: p1.3,
			part2: p2.0, part2cost: Float(p2.1), part2Unit: p2.2, part2Quantity: p2.3,
			part3: p3.0, part3cost: Float(p3.1), part3Unit: p3.2, part3Quantity: p3.3,
			part4: p4.0, part4cost: Float(p4.1), part4Unit: p4.2, part4Quantity: p4.3,
			part5: p5.0, part5cost: Float(p5.1), part5Unit: p5.2, part5Quantity: p5.3,
			image: nil,
			image1: nil, image1Description: "",
			image2: nil, image2Description: "",
			image3: nil, image3Description: ""
		)
	}
	let samples: [ServiceRecords1] = [
		makeService(vehicleId: "Vehicle A", daysAgo: 0, miles: 12050, hours: 12.5, item: "Oil Change", desc: "Changed engine oil and filter. Checked belts and hoses.", vendor: "Joe's Garage", labor: 120, parts: [("Oil Filter", 8.5, "ea", 1), ("5W-30", 7.0, "qt", 5)], notes: "Next change in 3 months."),
		makeService(vehicleId: "Vehicle A", daysAgo: 15, miles: 11820, hours: 10.0, item: "Brake Service", desc: "Replaced front pads, resurfaced rotors.", vendor: "BrakeCo", labor: 200, parts: [("Front Pads", 45.0, "set", 1), ("Brake Cleaner", 4.5, "can", 1)], notes: "Slight squeal at low speed observed."),
		makeService(vehicleId: "Vehicle B", daysAgo: 5, miles: 5400, hours: 4.0, item: "Battery", desc: "Replaced battery and cleaned terminals.", vendor: "AutoParts", labor: 60, parts: [("Battery Group 24", 110.0, "ea", 1)], notes: "Starts faster.")
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
		pdfReportService(trackVehicleSelected: .constant("All Vehicles"))
			.modelContainer(container)
			.previewDisplayName("All Vehicles")

		// Specific vehicle preview
		pdfReportService(trackVehicleSelected: .constant("Vehicle A"))
			.modelContainer(container)
			.previewDisplayName("Vehicle A")
	}
}

