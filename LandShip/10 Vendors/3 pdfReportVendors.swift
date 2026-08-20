/*
 File: 3 pdfReportVendors.swift
 Purpose:
   A cross-platform SwiftUI view that generates and displays a paginated PDF report of
   vendors/shops using PDFKit. The report is built from SwiftData models (Vendors1), rendered
   as a multi-column table with wrapped text, alternating row backgrounds, and repeating
   headers on new pages. The view also provides zoom controls and system print support.

 Notes:
   - Vendors are not scoped to a vehicle, so unlike other reports in this app there is no
     vehicle filter — the report always includes every vendor, sorted alphabetically by name.
   - Mirrors the structure of pdfReportParts.swift for visual/operational consistency across
     report views (this project does not share PDF drawing code between report files).
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

/// A SwiftUI view that builds and shows a PDF report of vendors/shops.
struct pdfReportVendors: View {
	/// All vendors, sorted alphabetically by name. Vendors are global (not vehicle-scoped).
	@Query(sort: [SortDescriptor(\Vendors1.vendorName, order: .forward)]) private var dataSet: [Vendors1]

	/// SwiftData model context (not directly used in generation but available for future edits).
	@Environment(\.modelContext) var modelContext

	/// Holds the generated PDF document for display and printing.
	@State private var pdfDocument: PDFDocument?

	/// App utility helpers for formatting.
	let functions: Functions = Functions()

	/// One-shot zoom command used to drive the embedded PDFKit view.
	@State private var zoomAction: ZoomAction?

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

	/// Generates the PDF data, updates the on-screen document, and writes a copy to Documents.
	private func generateAndShowPDF() {
		guard let pdfData = generatePDFWithTable() else { return }
		if let doc = PDFDocument(data: pdfData) {
			self.pdfDocument = doc
			_ = savePDF(data: pdfData, fileName: "Vendors and Shops")
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

	/// Extracts and formats the 7-column values for a single vendor record.
	/// - Parameter record: The vendor record to present.
	/// - Returns: An ordered array matching the table columns.
	func valuesForRecord(_ record: Vendors1) -> [String] {
		let name = record.vendorName
		let type = record.vendorType
		let contact = record.vendorContact1
		let phone = record.vendorPhone
		let email = record.vendorEmail
		let cityState = [record.vendorCity, record.vendorState].filter { !$0.isEmpty }.joined(separator: ", ")
		let notes = record.vendorNotes
		return [name, type, contact, phone, email, cityState, notes]
	}

	/// Builds a paginated PDF containing the vendors table with headers, alternating rows,
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
			["VENDOR\nNAME", "TYPE", "CONTACT", "PHONE", "EMAIL", "CITY,\nSTATE", "NOTES"]
		]

		let contentWidth = pageWidth - 2 * margin
		let minRowHeight: CGFloat = 32

		// 7 columns for the report
		let columnWeights: [CGFloat] = [
			0.16, // VENDOR NAME
			0.10, // TYPE
			0.14, // CONTACT
			0.11, // PHONE
			0.17, // EMAIL
			0.10, // CITY, STATE
			0.22  // NOTES
		]
		let columnWidths = columnWeights.map { $0 * contentWidth }

		let reportTitle = "Vendors / Shops Report"
		let subtitle = "\(dataSet.count) Vendor\(dataSet.count == 1 ? "" : "s")"
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

			drawPageHeader(margin: margin,
			               pageWidth: pageWidth,
			               pageHeight: pageHeight,
			               headerHeight: headerHeight,
			               title: reportTitle,
			               subtitle: subtitle,
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
				               subtitle: subtitle,
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

	/// Draws the page header including title, subtitle, date, and an optional page indicator.
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

		func measureRowHeight(_ row: [String], attrs: [NSAttributedString.Key: Any]) -> CGFloat {
			var maxH: CGFloat = 0
			for (index, text) in row.enumerated() {
				let width = columnWidths[min(index, columnWidths.count - 1)] - 8
				let bounding = NSAttributedString(string: text, attributes: attrs)
					.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
												options: [.usesLineFragmentOrigin, .usesFontLeading],
												context: nil)
				maxH = max(maxH, ceil(bounding.height) + 12)
			}
			return max(minRowHeight, maxH)
		}

		var perRowHeights: [CGFloat] = []
		for (rowIndex, row) in headerRows.enumerated() {
			let attrs = (rowIndex == 0) ? topAttrs : bottomAttrs
			perRowHeights.append(measureRowHeight(row, attrs: attrs))
		}
		let totalHeaderHeight = perRowHeights.reduce(0, +)

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

		separatorColor.setStroke()

		#if os(macOS)
		let gridPath = NSBezierPath()
		gridPath.lineWidth = 1.0

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

		var runningX = headerRectTop.origin.x
		gridPath.move(to: CGPoint(x: runningX, y: headerRectTop.origin.y))
		gridPath.addLine(to: CGPoint(x: runningX, y: headerRectTop.origin.y + headerRectTop.height))
		for width in columnWidths {
			runningX += width
			gridPath.move(to: CGPoint(x: runningX, y: headerRectTop.origin.y))
			gridPath.addLine(to: CGPoint(x: runningX, y: headerRectTop.origin.y + headerRectTop.height))
		}

		var runningY = headerRectTop.origin.y
		for rowIdx in 0..<perRowHeights.count {
			runningY += perRowHeights[rowIdx]
			gridPath.move(to: CGPoint(x: headerRectTop.origin.x, y: runningY))
			gridPath.addLine(to: CGPoint(x: headerRectTop.origin.x + totalWidth, y: runningY))
		}

		gridPath.stroke()
		#endif

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
	/// and insets. VENDOR NAME and NOTES are left-aligned; other columns are centered.
	func computeRowHeight(for record: Vendors1, columnWidths: [CGFloat], minRowHeight: CGFloat) -> CGFloat {
		let values = valuesForRecord(record)
		let notesIndex = 6 // last column is NOTES

		#if os(macOS)
		let font = NSFont.systemFont(ofSize: 8)
		#else
		let font = UIFont.systemFont(ofSize: 8)
		#endif

		var paragraphStyles: [NSMutableParagraphStyle] = []
		for i in 0..<values.count {
			let p = NSMutableParagraphStyle()
			p.lineBreakMode = .byWordWrapping
			p.alignment = (i == notesIndex || i == 0) ? .left : .center
			paragraphStyles.append(p)
		}

		var maxHeight: CGFloat = minRowHeight
		for (index, text) in values.enumerated() {
			let width = columnWidths[min(index, columnWidths.count - 1)] - 8
			let attributes: [NSAttributedString.Key: Any] = [
				.font: font,
				.paragraphStyle: paragraphStyles[index]
			]
			let bounding = NSAttributedString(string: text, attributes: attributes)
				.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
											options: [.usesLineFragmentOrigin, .usesFontLeading],
											context: nil)
			let cellHeight = ceil(bounding.height) + 12
			maxHeight = max(maxHeight, cellHeight)
		}
		return maxHeight
	}

	/// Draws one table row including alternating background, wrapped text, and grid lines.
	func drawTableRow(record: Vendors1, at origin: CGPoint, columnWidths: [CGFloat], rowHeight: CGFloat, rowIndex: Int, pageHeight: CGFloat? = nil) {
		let values = valuesForRecord(record)
		let notesIndex = 6 // last column is NOTES

		#if os(macOS)
		let font = NSFont.systemFont(ofSize: 8)
		let separatorColor = NSColor.separatorColor
		let rowAltFill = NSColor(white: 0.96, alpha: 1.0)
		#else
		let font = UIFont.systemFont(ofSize: 8)
		let separatorColor = UIColor.separator
		let rowAltFill = UIColor(white: 0.96, alpha: 1.0)
		#endif

		var paragraphStyles: [NSMutableParagraphStyle] = []
		for i in 0..<values.count {
			let p = NSMutableParagraphStyle()
			p.lineBreakMode = .byWordWrapping
			p.alignment = (i == notesIndex || i == 0) ? .left : .center
			paragraphStyles.append(p)
		}

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

		let totalWidth = columnWidths.reduce(0, +)
		separatorColor.setStroke()

		#if os(macOS)
		let rowPath = NSBezierPath()
		rowPath.lineWidth = 0.5

		func yConv(_ yTop: CGFloat) -> CGFloat { (pageHeight ?? 0) - yTop }
		rowPath.move(to: CGPoint(x: origin.x, y: yConv(origin.y)))
		rowPath.line(to: CGPoint(x: origin.x, y: yConv(origin.y + rowHeight)))

		var runningX = origin.x
		for width in columnWidths {
			runningX += width
			rowPath.move(to: CGPoint(x: runningX, y: yConv(origin.y)))
			rowPath.line(to: CGPoint(x: runningX, y: yConv(origin.y + rowHeight)))
		}

		rowPath.move(to: CGPoint(x: origin.x, y: yConv(origin.y + rowHeight)))
		rowPath.line(to: CGPoint(x: origin.x + totalWidth, y: yConv(origin.y + rowHeight)))
		rowPath.stroke()
		#else
		let rowPath = UIBezierPath()
		rowPath.lineWidth = 0.5

		rowPath.move(to: CGPoint(x: origin.x, y: origin.y))
		rowPath.addLine(to: CGPoint(x: origin.x, y: origin.y + rowHeight))

		var runningX = origin.x
		for width in columnWidths {
			runningX += width
			rowPath.move(to: CGPoint(x: runningX, y: origin.y))
			rowPath.addLine(to: CGPoint(x: runningX, y: origin.y + rowHeight))
		}

		rowPath.move(to: CGPoint(x: origin.x, y: origin.y + rowHeight))
		rowPath.addLine(to: CGPoint(x: origin.x + totalWidth, y: origin.y + rowHeight))
		rowPath.stroke()
		#endif
	}

	/// Saves the PDF to the user's Documents directory.
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
		printInfo.jobName = "Vendors and Shops"
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

#Preview("Vendors Report") {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: Vendors1.self, configurations: config)
	let context = container.mainContext
	let samples: [Vendors1] = [
		Vendors1(inactive: false, createdAt: Date(), updatedAt: Date(), vendorName: "Joe's Garage", vendorType: "Service & Repair", vendorContact1: "Joe Smith", vendorContact2: "", vendorContact3: "", vendorAddress: "123 Main St", vendorCity: "Springfield", vendorState: "IL", vendorZip: "62704", vendorPhone: "555-123-4567", vendorEmail: "contact@joesgarage.example", vendorWebsite: "", vendorNotes: "Open Mon–Sat."),
		Vendors1(inactive: false, createdAt: Date(), updatedAt: Date(), vendorName: "AutoParts Plus", vendorType: "Parts Vendor", vendorContact1: "Sally Jones", vendorContact2: "", vendorContact3: "", vendorAddress: "456 Commerce Blvd", vendorCity: "Madison", vendorState: "WI", vendorZip: "53703", vendorPhone: "555-987-6543", vendorEmail: "sales@autopartsplus.example", vendorWebsite: "", vendorNotes: "Fleet discounts available.")
	]
	samples.forEach { context.insert($0) }
	try? context.save()
	return pdfReportVendors()
		.modelContainer(container)
}
