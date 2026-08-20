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

struct pdfReportProjectList: View {
	// MARK: Data & State

	// Fetch the service records we will render into the PDF.
	// This uses SwiftData's @Query and is configured in init based on selected vehicle.
	@Query private var dataSet: [ProjectList]
	
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
	
	@State private var showSubcategoryPicker: Bool = false
	@State private var selectedSubcategory: String? = nil
	@State private var showPunchListReport: Bool = false
	
	// Add this helper to create a stable identity for the current dataset
	private var dataSetKey: String {
		let sorted = dataSet.sorted { (lhs: ProjectList, rhs: ProjectList) -> Bool in
			if lhs.vehicleId != rhs.vehicleId { return lhs.vehicleId < rhs.vehicleId }
			if lhs.category != rhs.category { return lhs.category < rhs.category }
			if lhs.subCategory != rhs.subCategory { return lhs.subCategory < rhs.subCategory }
			if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
			return lhs.itemName < rhs.itemName
		}
		return sorted.map { "\($0.vehicleId)|\($0.category)|\($0.subCategory)|\($0.createdAt.timeIntervalSince1970)|\($0.itemName)" }.joined(separator: "#")
	}
	
	// MARK: Init (configure @Query based on vehicle selection)

	// Configure the query to either fetch all records or those for a specific vehicle.
	init(trackVehicleSelected: String) {
		self.trackVehicleSelected = trackVehicleSelected
		let vehicleId = trackVehicleSelected
		print("pdf-vehicleId: \(vehicleId)")

		// Precompute sort descriptors to reduce type-checker work
		let sortDescriptors: [SortDescriptor<ProjectList>] = [
			SortDescriptor(\.vehicleId, order: .forward),
			SortDescriptor(\.category, order: .forward),
			SortDescriptor(\.subCategory, order: .forward),
			SortDescriptor(\.createdAt, order: .reverse)
		]

		if vehicleId != "All Vehicles" {
			// Capture into a local to use inside #Predicate to keep inference simple
			let id = vehicleId
			let predicate: Predicate<ProjectList> = #Predicate { $0.vehicleId == id }
			self._dataSet = Query<ProjectList, [ProjectList]>(
				filter: predicate,
				sort: sortDescriptors
			)
		} else {
			self._dataSet = Query<ProjectList, [ProjectList]>(
				sort: sortDescriptors
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
		.onChange(of: dataSetKey) {
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
				.keyboardShortcut("p", modifiers: .command)
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

			ToolbarItem(placement: .automatic) {
				Button {
					showSubcategoryPicker = true
				} label: {
					Label("Punch List…", systemImage: "checklist")
				}
				.disabled(dataSet.isEmpty)
			}
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
		.sheet(isPresented: $showSubcategoryPicker) {
		    NavigationStack {
		        List {
		            // Build unique subcategory list from current dataset
		            let subs = Array(Set(dataSet.map { $0.subCategory })).sorted()
		            ForEach(subs, id: \.self) { sub in
		                Button(action: {
		                    selectedSubcategory = sub
		                    showSubcategoryPicker = false
		                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
		                        showPunchListReport = true
		                    }
		                }) {
		                    HStack {
		                        Image(systemName: "folder")
		                        Text(sub.isEmpty ? "(Untitled Project)" : sub)
		                    }
		                }
		            }
		        }
		        .navigationTitle("Select Project")
		        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showSubcategoryPicker = false } } }
		    }
		}
		.sheet(isPresented: Binding(get: { showPunchListReport && selectedSubcategory != nil }, set: { newVal in if !newVal { showPunchListReport = false } })) {
		    if let sub = selectedSubcategory {
		        pdfReportPunchList(trackVehicleSelected: trackVehicleSelected, projectSubcategory: sub)
		    } else {
		        Text("No project selected")
		    }
		}
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
            _ = savePDF(data: pdfData, fileName: "Project List")
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
			let pdfView = PrintablePDFView()
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

	// Produce the 12 column strings for a project record (in the same order as the table columns).
	// Columns: DATE, TITLE, DESCRIPTION, NOTES, VENDOR, LABOR, PARTS, COST, MILES, COMPLETED, LOGBOOK, IMAGE
	func valuesForRecord(_ record: ProjectList) -> [String] {
		let date = functions.formatDate_DDMMM_yyyy(date: record.createdAt)
		let title = record.itemName
		let description = record.itemDescription
		let notes = record.itemNotes
		let vendor = record.itemVendor
		
		// Labor cost: use strongly-typed property
		let laborStr = functions.formatCurrency(dollars: max(0, record.laborCost))

		// Parts - build a concatenated string of parts 1-5 with cost only, ignoring quantity and unit
        let fns = functions
        let partsStr: String = {
            func one(_ name: String, _ cost: Float) -> String? {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                let costPart = cost > 0 ? " — \(fns.formatCurrency(dollars: max(0, cost)))" : ""
                return "\(trimmed)\(costPart)"
            }
            let items = [
                one(record.part1, record.part1cost),
                one(record.part2, record.part2cost),
                one(record.part3, record.part3cost),
                one(record.part4, record.part4cost),
                one(record.part5, record.part5cost)
            ].compactMap { $0 }
            return items.joined(separator: "\n")
        }()

		// Compute total parts cost (unit cost * quantity; if quantity is 0, treat as unit cost)
		let partTotals: [Float] = [
			record.part1cost * (record.part1Quantity > 0 ? Float(record.part1Quantity) : 1),
			record.part2cost * (record.part2Quantity > 0 ? Float(record.part2Quantity) : 1),
			record.part3cost * (record.part3Quantity > 0 ? Float(record.part3Quantity) : 1),
			record.part4cost * (record.part4Quantity > 0 ? Float(record.part4Quantity) : 1),
			record.part5cost * (record.part5Quantity > 0 ? Float(record.part5Quantity) : 1)
		]
		let partsTotal = partTotals.reduce(0, +)

		// Cost, replaced to use parts total instead of record.itemCost
		let costStr = functions.formatCurrency(dollars: max(0, partsTotal))
		
		let milesStr = String(record.miles)

		// Completed: show Yes and the completion date when itemCompleted is true; otherwise No
        let completedStr: String = {
            guard record.itemCompleted else { return "No" }
            let dateText = functions.formatDate_DDMMMyy(date: record.completedAt)
            return "Yes — \(dateText)"
        }()

		// Logbook: strictly reflect savedToLogbook boolean
        let logbookStr: String = record.savedToLogbook ? "Yes" : "No"

		// Image placeholder: "(image)" or empty string
		let imagePlaceholder = record.image1 != nil ? "(image)" : ""

		return [date, title, description, notes, vendor, laborStr, partsStr, costStr, milesStr, completedStr, logbookStr, imagePlaceholder]
	}
	
	// MARK: - PDF generation (cross-platform)

	// Unified cross‑platform PDF generator that draws:
	// - Page header (title, subtitle with vehicle filter, date, page number)
	// - Section headers for vehicle, category, and subcategory groups
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

		// Table header labels for project list report (12 columns).
		let headerRows: [[String]] = [
			["DATE\nEDITED", "PROJECT\nITEM", "PROJECT\nDESCRIPTION", "PROJECT\nNOTES", "SHOP", "LABOR\nCOST", "PARTS\nUSED", "PARTS\nCOST", "ODO", "COMPLETE", "LOG", "IMAGE"]
		]

		// Content area width (inside margins) and a minimum row height for data rows.
		let contentWidth = pageWidth - 2 * margin
		let minRowHeight: CGFloat = 32

		// 12 column widths as a fraction of content width (sum approximately 1.0).
		let columnWeights: [CGFloat] = [
			0.07, // DATE
			0.14, // TITLE
			0.12, // DESCRIPTION
			0.10, // NOTES
			0.06, // VENDOR
			0.06, // LABOR
			0.08, // PARTS
			0.07, // COST
			0.06, // MILES
			0.10, // COMPLETED
			0.04, // LOGBOOK
			0.06  // IMAGE (we'll handle min width by content)
		]
		let columnWidths = columnWeights.map { $0 * contentWidth }

		// Header text content: report title, vehicle filter title, and current date.
		let reportTitle = "Project List"
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
			let nsGraphicsContext = NSGraphicsContext(cgContext: cgContext, flipped: false)
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

		// New helper for vehicle section header (macOS)
		func drawVehicleHeader(text: String, at origin: CGPoint, width: CGFloat, pageHeight: CGFloat?) -> CGFloat {
			let height: CGFloat = 24
			let fillColor = NSColor(calibratedRed: 0.5, green: 0.6, blue: 0.75, alpha: 1.0)
			let font = NSFont.boldSystemFont(ofSize: 12)
			let textColor = NSColor.black
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.alignment = .left

			let rectTop = CGRect(x: origin.x, y: origin.y, width: width, height: height)
			let ph = pageHeight ?? 0
			let rect = CGRect(x: rectTop.origin.x,
			                  y: ph - rectTop.origin.y - rectTop.height,
			                  width: rectTop.width,
			                  height: rectTop.height)
			fillColor.setFill()
			NSBezierPath(rect: rect).fill()

			let attrs: [NSAttributedString.Key: Any] = [
				.font: font,
				.foregroundColor: textColor,
				.paragraphStyle: paragraphStyle
			]
			let insetRect = rect.insetBy(dx: 8, dy: 6)
			NSAttributedString(string: text, attributes: attrs).draw(in: insetRect)
			return height
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

		// Variables to track current vehicle, category and subcategory for section headers.
		var currentVehicle: String? = nil
		var currentCategory: String? = nil
		var currentSubcategory: String? = nil

		var vehicleTotal: Float = 0
		var subcategoryTotal: Float = 0
		var categoryTotal: Float = 0
		var grandTotal: Float = 0

		// Iterate the dataset, computing each row’s height and page‑breaking as needed.
		for (index, record) in dataSet.enumerated() {
			let newVehicle = record.vehicleId
			let newCategory = record.category
			let newSubcategory = record.subCategory

			// Vehicle change: emit vehicle subtotal and handle page break
			if let cv = currentVehicle, cv != newVehicle {
				let needed = 20 as CGFloat
				if currentY + needed > maxContentBottom {
					endMacPage()
					pageNumber += 1
					beginMacPage()
					currentY = margin + headerHeight
					let h = drawTableHeaders(at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, headerRows: headerRows, minRowHeight: 24, pageHeight: pageHeight)
					currentY += h
					// Reprint vehicle header on new page
					currentY += drawVehicleHeader(text: newVehicle, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: pageHeight)
					// Reprint category header on new page if applicable
					if let cc = currentCategory {
						currentY += drawCategoryHeader(text: cc, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: pageHeight)
					}
				}
				currentY += drawTotalsRow(label: "Subtotal — \(cv)", amount: vehicleTotal, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, pageHeight: pageHeight)
				vehicleTotal = 0
			}

			// If subcategory changes and it's not the first row, emit subcategory subtotal
			if let cs = currentSubcategory, cs != newSubcategory {
				let needed = 20 as CGFloat
				if currentY + needed > maxContentBottom {
					endMacPage()
					pageNumber += 1
					beginMacPage()
					currentY = margin + headerHeight
					let h = drawTableHeaders(at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, headerRows: headerRows, minRowHeight: 24, pageHeight: pageHeight)
					currentY += h
					// Reprint vehicle header on new page
					if let cv = currentVehicle {
						currentY += drawVehicleHeader(text: cv, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: pageHeight)
					}
					// Reprint category header on new page
					if let cc = currentCategory {
						currentY += drawCategoryHeader(text: cc, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: pageHeight)
					}
				}
				currentY += drawTotalsRow(label: "Subtotal — Project: \(cs)", amount: subcategoryTotal, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, pageHeight: pageHeight)
				subcategoryTotal = 0
			}
			// If category changes and it's not the first row, emit category subtotal
			if let cc = currentCategory, cc != newCategory {
				let needed = 20 as CGFloat
				if currentY + needed > maxContentBottom {
					endMacPage()
					pageNumber += 1
					beginMacPage()
					currentY = margin + headerHeight
					let h = drawTableHeaders(at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, headerRows: headerRows, minRowHeight: 24, pageHeight: pageHeight)
					currentY += h
					// Reprint vehicle header on new page
					if let cv = currentVehicle {
						currentY += drawVehicleHeader(text: cv, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: pageHeight)
					}
				}
				currentY += drawTotalsRow(label: "Subtotal — \(cc)", amount: categoryTotal, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, pageHeight: pageHeight)
				categoryTotal = 0
			}

			// Compute heights for potential headers.
			let vehicleHeaderHeight: CGFloat = (currentVehicle != newVehicle) ? 24 : 0
			let categoryHeaderHeight: CGFloat = (currentCategory != newCategory) ? 22 : 0
			let subcategoryHeaderHeight: CGFloat = (currentSubcategory != newSubcategory) ? 18 : 0

			let rowHeight = computeRowHeight(for: record, columnWidths: columnWidths, minRowHeight: minRowHeight)

			// Check if we need to page break before adding headers + row.
			if currentY + vehicleHeaderHeight + categoryHeaderHeight + subcategoryHeaderHeight + rowHeight > maxContentBottom {
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

				// Reset current category and subcategory on new page but keep currentVehicle if continuing same vehicle
				currentCategory = nil
				currentSubcategory = nil

				// Reprint vehicle header on new page if continuing same vehicle
				if let cv = currentVehicle {
					currentY += drawVehicleHeader(text: cv, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: pageHeight)
				}
			}

			// Draw vehicle header if changed
			if currentVehicle != newVehicle {
				let vehHeight = drawVehicleHeader(text: newVehicle, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: pageHeight)
				currentY += vehHeight
				currentVehicle = newVehicle
				currentCategory = nil // Reset category when vehicle changes
				currentSubcategory = nil // Reset subcategory when vehicle changes
			}

			// Draw category header if changed
			if currentCategory != newCategory {
				let catHeight = drawCategoryHeader(text: newCategory, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: pageHeight)
				currentY += catHeight
				currentCategory = newCategory
				currentSubcategory = nil // Reset subcategory when category changes
			}

			// Draw subcategory header if changed and not same as category change
			if currentSubcategory != newSubcategory {
				let subcatHeight = drawSubcategoryHeader(text: newSubcategory, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: pageHeight)
				currentY += subcatHeight
				currentSubcategory = newSubcategory
			}

			// Add to totals (replaced to sum parts instead of itemCost)
			let rowPartsTotal: Float = {
				let t: [Float] = [
					record.part1cost * (record.part1Quantity > 0 ? Float(record.part1Quantity) : 1),
					record.part2cost * (record.part2Quantity > 0 ? Float(record.part2Quantity) : 1),
					record.part3cost * (record.part3Quantity > 0 ? Float(record.part3Quantity) : 1),
					record.part4cost * (record.part4Quantity > 0 ? Float(record.part4Quantity) : 1),
					record.part5cost * (record.part5Quantity > 0 ? Float(record.part5Quantity) : 1)
				]
				return t.reduce(0, +)
			}()
			vehicleTotal += rowPartsTotal
			subcategoryTotal += rowPartsTotal
			categoryTotal += rowPartsTotal
			grandTotal += rowPartsTotal

			// Draw row and advance.
			drawTableRow(record: record,
									 at: CGPoint(x: margin, y: currentY),
									 columnWidths: columnWidths,
									 rowHeight: rowHeight,
									 rowIndex: index,
									 pageHeight: pageHeight)
			currentY += rowHeight
		}

		// Emit trailing subtotals and grand total
		if let cs = currentSubcategory {
			if currentY + 20 > maxContentBottom {
				endMacPage()
				pageNumber += 1
				beginMacPage()
				currentY = margin + headerHeight
				currentY += drawTableHeaders(at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, headerRows: headerRows, minRowHeight: 24, pageHeight: pageHeight)
				if let cv = currentVehicle {
					currentY += drawVehicleHeader(text: cv, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: pageHeight)
				}
			}
			currentY += drawTotalsRow(label: "Subtotal — Project: \(cs)", amount: subcategoryTotal, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, pageHeight: pageHeight)
		}
		if let cc = currentCategory {
			if currentY + 20 > maxContentBottom {
				endMacPage()
				pageNumber += 1
				beginMacPage()
				currentY = margin + headerHeight
				currentY += drawTableHeaders(at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, headerRows: headerRows, minRowHeight: 24, pageHeight: pageHeight)
				if let cv = currentVehicle {
					currentY += drawVehicleHeader(text: cv, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: pageHeight)
				}
			}
			currentY += drawTotalsRow(label: "Subtotal — \(cc)", amount: categoryTotal, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, pageHeight: pageHeight)
		}
		if let cv = currentVehicle {
			if currentY + 20 > maxContentBottom {
				endMacPage()
				pageNumber += 1
				beginMacPage()
				currentY = margin + headerHeight
				currentY += drawTableHeaders(at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, headerRows: headerRows, minRowHeight: 24, pageHeight: pageHeight)
			}
			currentY += drawTotalsRow(label: "Subtotal — \(cv)", amount: vehicleTotal, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, pageHeight: pageHeight)
		}
		if currentY + 20 > maxContentBottom {
			endMacPage()
			pageNumber += 1
			beginMacPage()
			currentY = margin + headerHeight
			currentY += drawTableHeaders(at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, headerRows: headerRows, minRowHeight: 24, pageHeight: pageHeight)
			if let cv = currentVehicle {
				currentY += drawVehicleHeader(text: cv, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: pageHeight)
			}
		}
		currentY += drawTotalsRow(label: "Grand Total", amount: grandTotal, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, pageHeight: pageHeight)

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

			// New helper for vehicle section header (iOS)
			func drawVehicleHeader(text: String, at origin: CGPoint, width: CGFloat, pageHeight: CGFloat?) -> CGFloat {
				let height: CGFloat = 24
				let fillColor = UIColor(red: 0.5, green: 0.6, blue: 0.75, alpha: 1.0)
				let font = UIFont.boldSystemFont(ofSize: 12)
				let textColor = UIColor.black
				let paragraphStyle = NSMutableParagraphStyle()
				paragraphStyle.alignment = .left

				let rect = CGRect(x: origin.x, y: origin.y, width: width, height: height)
				fillColor.setFill()
				UIBezierPath(rect: rect).fill()

				let attrs: [NSAttributedString.Key: Any] = [
					.font: font,
					.foregroundColor: textColor,
					.paragraphStyle: paragraphStyle
				]
				let insetRect = rect.insetBy(dx: 8, dy: 6)
				NSAttributedString(string: text, attributes: attrs).draw(in: insetRect)
				return height
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

			// Variables to track current vehicle, category and subcategory for section headers.
			var currentVehicle: String? = nil
			var currentCategory: String? = nil
			var currentSubcategory: String? = nil

			var vehicleTotal: Float = 0
			var subcategoryTotal: Float = 0
			var categoryTotal: Float = 0
			var grandTotal: Float = 0

			// Iterate dataset and page break if row would overflow.
			for (index, record) in dataSet.enumerated() {
				let newVehicle = record.vehicleId
				let newCategory = record.category
				let newSubcategory = record.subCategory

				// Vehicle change: emit vehicle subtotal and handle page break
				if let cv = currentVehicle, cv != newVehicle {
					let needed = 20 as CGFloat
					if currentY + needed > maxContentBottom {
						pageNumber += 1
						beginIOSPage()
						currentY = margin + headerHeight
						let h = drawTableHeaders(at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, headerRows: headerRows, minRowHeight: 28)
						currentY += h
						// Reprint vehicle header on new page
						currentY += drawVehicleHeader(text: newVehicle, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: nil)
						// Reprint category header on new page if applicable
						if let cc = currentCategory {
							currentY += drawCategoryHeader(text: cc, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: nil)
						}
					}
					currentY += drawTotalsRow(label: "Subtotal — \(cv)", amount: vehicleTotal, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths)
					vehicleTotal = 0
				}

				// If subcategory changes and it's not the first row, emit subcategory subtotal
				if let cs = currentSubcategory, cs != newSubcategory {
					let needed = 20 as CGFloat
					if currentY + needed > maxContentBottom {
						pageNumber += 1
						beginIOSPage()
						currentY = margin + headerHeight
						let h = drawTableHeaders(at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, headerRows: headerRows, minRowHeight: 28)
						currentY += h
						// Reprint vehicle header on new page
						if let cv = currentVehicle {
							currentY += drawVehicleHeader(text: cv, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: nil)
						}
						// Reprint category header on new page
						if let cc = currentCategory {
							currentY += drawCategoryHeader(text: cc, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: nil)
						}
					}
					currentY += drawTotalsRow(label: "Subtotal — Project: \(cs)", amount: subcategoryTotal, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths)
					subcategoryTotal = 0
				}
				// If category changes and it's not the first row, emit category subtotal
				if let cc = currentCategory, cc != newCategory {
					let needed = 20 as CGFloat
					if currentY + needed > maxContentBottom {
						pageNumber += 1
						beginIOSPage()
						currentY = margin + headerHeight
						let h = drawTableHeaders(at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, headerRows: headerRows, minRowHeight: 28)
						currentY += h
						// Reprint vehicle header on new page
						if let cv = currentVehicle {
							currentY += drawVehicleHeader(text: cv, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: nil)
						}
					}
					currentY += drawTotalsRow(label: "Subtotal — \(cc)", amount: categoryTotal, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths)
					categoryTotal = 0
				}

				let vehicleHeaderHeight: CGFloat = (currentVehicle != newVehicle) ? 24 : 0
				let categoryHeaderHeight: CGFloat = (currentCategory != newCategory) ? 22 : 0
				let subcategoryHeaderHeight: CGFloat = (currentSubcategory != newSubcategory) ? 18 : 0

				let rowHeight = computeRowHeight(for: record, columnWidths: columnWidths, minRowHeight: minRowHeight)

				// Page break check for headers + row
				if currentY + vehicleHeaderHeight + categoryHeaderHeight + subcategoryHeaderHeight + rowHeight > maxContentBottom {
					pageNumber += 1
					beginIOSPage()
					currentY = margin + headerHeight
					let h = drawTableHeaders(at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, headerRows: headerRows, minRowHeight: 28)
					currentY += h

					currentCategory = nil
					currentSubcategory = nil

					// Reprint vehicle header on new page if continuing same vehicle
					if let cv = currentVehicle {
						currentY += drawVehicleHeader(text: cv, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: nil)
					}
				}

				// Draw vehicle header if changed
				if currentVehicle != newVehicle {
					let vehHeight = drawVehicleHeader(text: newVehicle, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: nil)
					currentY += vehHeight
					currentVehicle = newVehicle
					currentCategory = nil // Reset category when vehicle changes
					currentSubcategory = nil // Reset subcategory when vehicle changes
				}

				// Draw category header if changed
				if currentCategory != newCategory {
					let catHeight = drawCategoryHeader(text: newCategory, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: nil)
					currentY += catHeight
					currentCategory = newCategory
					currentSubcategory = nil // Reset subcategory when category changes
				}

				// Draw subcategory header if changed
				if currentSubcategory != newSubcategory {
					let subcatHeight = drawSubcategoryHeader(text: newSubcategory, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: nil)
					currentY += subcatHeight
					currentSubcategory = newSubcategory
				}

				// Add to totals (replaced to sum parts instead of itemCost)
				let rowPartsTotal: Float = {
					let t: [Float] = [
						record.part1cost * (record.part1Quantity > 0 ? Float(record.part1Quantity) : 1),
						record.part2cost * (record.part2Quantity > 0 ? Float(record.part2Quantity) : 1),
						record.part3cost * (record.part3Quantity > 0 ? Float(record.part3Quantity) : 1),
						record.part4cost * (record.part4Quantity > 0 ? Float(record.part4Quantity) : 1),
						record.part5cost * (record.part5Quantity > 0 ? Float(record.part5Quantity) : 1)
					]
					return t.reduce(0, +)
				}()
				vehicleTotal += rowPartsTotal
				subcategoryTotal += rowPartsTotal
				categoryTotal += rowPartsTotal
				grandTotal += rowPartsTotal

				drawTableRow(record: record, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, rowHeight: rowHeight, rowIndex: index)
				currentY += rowHeight
			}

			// Emit trailing subtotals and grand total
			if let cs = currentSubcategory {
				if currentY + 20 > maxContentBottom {
					pageNumber += 1
					beginIOSPage()
					currentY = margin + headerHeight
					currentY += drawTableHeaders(at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, headerRows: headerRows, minRowHeight: 28)
					if let cv = currentVehicle {
						currentY += drawVehicleHeader(text: cv, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: nil)
					}
				}
				currentY += drawTotalsRow(label: "Subtotal — Project: \(cs)", amount: subcategoryTotal, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths)
			}
			if let cc = currentCategory {
				if currentY + 20 > maxContentBottom {
					pageNumber += 1
					beginIOSPage()
					currentY = margin + headerHeight
					currentY += drawTableHeaders(at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, headerRows: headerRows, minRowHeight: 28)
					if let cv = currentVehicle {
						currentY += drawVehicleHeader(text: cv, at: CGPoint(x: margin, y: currentY), width: contentWidth, pageHeight: nil)
					}
				}
				currentY += drawTotalsRow(label: "Subtotal — \(cc)", amount: categoryTotal, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths)
			}
			if let cv = currentVehicle {
				if currentY + 20 > maxContentBottom {
					pageNumber += 1
					beginIOSPage()
					currentY = margin + headerHeight
					currentY += drawTableHeaders(at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, headerRows: headerRows, minRowHeight: 28)
				}
				currentY += drawTotalsRow(label: "Subtotal — \(cv)", amount: vehicleTotal, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths)
			}
			if currentY + 20 > maxContentBottom {
				pageNumber += 1
				beginIOSPage()
				currentY = margin + headerHeight
				currentY += drawTableHeaders(at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths, headerRows: headerRows, minRowHeight: 28)
			}
			currentY += drawTotalsRow(label: "Grand Total", amount: grandTotal, at: CGPoint(x: margin, y: currentY), columnWidths: columnWidths)
		}
		return data
		#endif
	}

	// MARK: - Page header/footer drawing (cross‑platform)

	// Draw page header: title (left), subtitle+date (left), and page number (right).
	// macOS variant converts to Quartz coordinates; iOS draws directly.
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

		let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .paragraphStyle: paragraphLeft, .foregroundColor: NSColor.black]
		let subAttrs: [NSAttributedString.Key: Any] = [.font: subFont, .paragraphStyle: paragraphLeft, .foregroundColor: NSColor.black]
		let rightAttrs: [NSAttributedString.Key: Any] = [.font: subFont, .paragraphStyle: paragraphRight, .foregroundColor: NSColor.black]

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

		let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .paragraphStyle: paragraphLeft, .foregroundColor: UIColor.black]
		let subAttrs: [NSAttributedString.Key: Any] = [.font: subFont, .paragraphStyle: paragraphLeft, .foregroundColor: UIColor.black]
		let rightAttrs: [NSAttributedString.Key: Any] = [.font: subFont, .paragraphStyle: paragraphRight, .foregroundColor: UIColor.black]

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
	nonisolated func drawPageFooter(margin: CGFloat,
	                    pageWidth: CGFloat,
	                    pageHeight: CGFloat,
	                    footerHeight: CGFloat,
	                    pageNumber: Int) {
		#if os(macOS)
		let footFont = NSFont.systemFont(ofSize: 9)
		let paragraphCenter = NSMutableParagraphStyle()
		paragraphCenter.alignment = .center
		let attrs: [NSAttributedString.Key: Any] = [.font: footFont, .paragraphStyle: paragraphCenter, .foregroundColor: NSColor.black]

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
		let attrs: [NSAttributedString.Key: Any] = [.font: footFont, .paragraphStyle: paragraphCenter, .foregroundColor: UIColor.black]

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
			.paragraphStyle: topParagraph,
			.foregroundColor: {
				#if os(macOS)
				return NSColor.black
				#else
				return UIColor.black
				#endif
			}()
		]
		let bottomAttrs: [NSAttributedString.Key: Any] = [
			.font: bottomFont,
			.paragraphStyle: bottomParagraph,
			.foregroundColor: {
				#if os(macOS)
				return NSColor.black
				#else
				return UIColor.black
				#endif
			}()
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
	func computeRowHeight(for record: ProjectList, columnWidths: [CGFloat], minRowHeight: CGFloat) -> CGFloat {
		let values = valuesForRecord(record)
		let imageIndex = 11

		#if os(macOS)
		let font = NSFont.systemFont(ofSize: 8)
		#else
		let font = UIFont.systemFont(ofSize: 8)
		#endif

		// Build per‑column paragraph styles:
		// Left: TITLE(1), DESCRIPTION(2), NOTES(3), VENDOR(4), PARTS(6)
		// Right: LABOR(5), COST(7), MILES(8)
		// Center: DATE(0), COMPLETED(9), LOGBOOK(10), IMAGE(11)
		var paragraphStyles: [NSMutableParagraphStyle] = []
		for i in 0..<values.count {
			let p = NSMutableParagraphStyle()
			p.lineBreakMode = .byWordWrapping
			switch i {
			case 1, 2, 3, 4, 6: // LEFT-aligned columns
				p.alignment = .left
			case 5, 7, 8: // RIGHT-aligned columns
				p.alignment = .right
			default: // DATE, COMPLETED, LOGBOOK, IMAGE centered
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
			var cellHeight = ceil(bounding.height) + 12 // vertical insets
			if index == imageIndex {
				// IMAGE column - ensure minimum height to fit thumbnail + padding
				cellHeight = max(cellHeight, 28 + 12)
			}
			maxHeight = max(maxHeight, cellHeight)
		}
		return maxHeight
	}

	// MARK: - Row drawing

	// Draw a single table row: optional alternating background, cell text with wrapping,
	// and per‑row vertical dividers plus bottom border.
	// macOS variant converts to Quartz coordinates; iOS draws directly.
	func drawTableRow(record: ProjectList, at origin: CGPoint, columnWidths: [CGFloat], rowHeight: CGFloat, rowIndex: Int, pageHeight: CGFloat? = nil) {
		let values = valuesForRecord(record)
		let imageIndex = 11

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

		// Build per‑column paragraph styles:
		// Left: TITLE(1), DESCRIPTION(2), NOTES(3), VENDOR(4), PARTS(6)
		// Right: LABOR(5), COST(7), MILES(8)
		// Center: DATE(0), COMPLETED(9), LOGBOOK(10), IMAGE(11)
		var paragraphStyles: [NSMutableParagraphStyle] = []
		for i in 0..<values.count {
			let p = NSMutableParagraphStyle()
			p.lineBreakMode = .byWordWrapping
			switch i {
			case 1, 2, 3, 4, 6: // Left aligned
				p.alignment = .left
			case 5, 7, 8: // Right aligned
				p.alignment = .right
			default: // Centered: 0,9,10,11
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

		// Draw text or image in each column (wrapped), with special handling for IMAGE column.
		var textX = origin.x
		for (index, value) in values.enumerated() {
			let width = columnWidths[min(index, columnWidths.count - 1)]
			let valueRectTop = CGRect(x: textX, y: origin.y, width: width, height: rowHeight)
			#if os(macOS)
			let ph = pageHeight ?? 0
			let valueRect = CGRect(x: valueRectTop.origin.x,
			                       y: ph - valueRectTop.origin.y - valueRectTop.height,
			                       width: valueRectTop.width,
			                       height: valueRectTop.height)
			#else
			let valueRect = valueRectTop
			#endif

			let attributes: [NSAttributedString.Key: Any] = [
				.font: font,
				.paragraphStyle: paragraphStyles[index],
				.foregroundColor: {
					#if os(macOS)
					return NSColor.black
					#else
					return UIColor.black
					#endif
				}()
			]

			if index == imageIndex {
				// Draw thumbnail image centered in cell if present
				if let imageData = record.image1 {
					#if os(macOS)
					if let nsImage = NSImage(data: imageData) {
						let maxSize = CGSize(width: 28, height: 28)
						let imageSize = nsImage.size
						let aspectWidth = maxSize.width / imageSize.width
						let aspectHeight = maxSize.height / imageSize.height
						let scale = min(aspectWidth, aspectHeight, 1.0)
						let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
						let drawOrigin = CGPoint(x: valueRect.origin.x + (valueRect.width - drawSize.width)/2,
																		y: valueRect.origin.y + (valueRect.height - drawSize.height)/2)
						let drawRect = CGRect(origin: drawOrigin, size: drawSize)
						nsImage.draw(in: drawRect)
					} else {
						// draw placeholder text if image is invalid
						NSAttributedString(string: value, attributes: attributes).draw(in: valueRect.insetBy(dx: 4, dy: 6))
					}
					#else
					if let uiImage = UIImage(data: imageData) {
						let maxSize = CGSize(width: 28, height: 28)
						let imageSize = uiImage.size
						let aspectWidth = maxSize.width / imageSize.width
						let aspectHeight = maxSize.height / imageSize.height
						let scale = min(aspectWidth, aspectHeight, 1.0)
						let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
						let drawOrigin = CGPoint(x: valueRect.origin.x + (valueRect.width - drawSize.width)/2,
																		y: valueRect.origin.y + (valueRect.height - drawSize.height)/2)
						let drawRect = CGRect(origin: drawOrigin, size: drawSize)
						uiImage.draw(in: drawRect)
					} else {
						// draw placeholder text if image is invalid
						NSAttributedString(string: value, attributes: attributes).draw(in: valueRect.insetBy(dx: 4, dy: 6))
					}
					#endif
				} else {
					// No image data: draw placeholder string (likely empty)
					#if os(macOS)
					NSAttributedString(string: value, attributes: attributes).draw(in: valueRect.insetBy(dx: 4, dy: 6))
					#else
					NSAttributedString(string: value, attributes: attributes).draw(in: valueRect.insetBy(dx: 4, dy: 6))
					#endif
				}
			} else {
				// Draw text for other columns
				#if os(macOS)
				NSAttributedString(string: value, attributes: attributes)
					.draw(in: valueRect.insetBy(dx: 4, dy: 6))
				#else
				NSAttributedString(string: value, attributes: attributes)
					.draw(in: valueRect.insetBy(dx: 4, dy: 6))
				#endif
			}

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

	// MARK: - Section Header Drawing Helpers

	// Draw category section header: full width band with distinct background and bold text.
	// Returns the height consumed by the header.
	func drawCategoryHeader(text: String, at origin: CGPoint, width: CGFloat, pageHeight: CGFloat?) -> CGFloat {
		let height: CGFloat = 22
		#if os(macOS)
		let fillColor = NSColor(calibratedRed: 0.7, green: 0.8, blue: 0.9, alpha: 1.0)
		let font = NSFont.boldSystemFont(ofSize: 11)
		let textColor = NSColor.black
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.alignment = .left

		let rectTop = CGRect(x: origin.x, y: origin.y, width: width, height: height)
		let ph = pageHeight ?? 0
		let rect = CGRect(x: rectTop.origin.x,
		                  y: ph - rectTop.origin.y - rectTop.height,
		                  width: rectTop.width,
		                  height: rectTop.height)
		fillColor.setFill()
		NSBezierPath(rect: rect).fill()

		// Changed inset from dx: 8 to dx: 16
		let insetRect = rect.insetBy(dx: 16, dy: 4)
		NSAttributedString(string: text, attributes: [
			.font: font,
			.foregroundColor: textColor,
			.paragraphStyle: paragraphStyle
		]).draw(in: insetRect)
		#else
		let fillColor = UIColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 1.0)
		let font = UIFont.boldSystemFont(ofSize: 11)
		let textColor = UIColor.black
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.alignment = .left

		let rect = CGRect(x: origin.x, y: origin.y, width: width, height: height)
		fillColor.setFill()
		UIBezierPath(rect: rect).fill()

		// Changed inset from dx: 8 to dx: 16
		let insetRect = rect.insetBy(dx: 16, dy: 4)
		NSAttributedString(string: text, attributes: [
			.font: font,
			.foregroundColor: textColor,
			.paragraphStyle: paragraphStyle
		]).draw(in: insetRect)
		#endif
		return height
	}

	// Draw subcategory section header: full width band with lighter background and bold text.
	// Returns the height consumed by the header.
	func drawSubcategoryHeader(text: String, at origin: CGPoint, width: CGFloat, pageHeight: CGFloat?) -> CGFloat {
		let height: CGFloat = 18
		#if os(macOS)
		let fillColor = NSColor(calibratedRed: 0.83, green: 0.88, blue: 0.95, alpha: 1.0)
		let font = NSFont.boldSystemFont(ofSize: 10)
		let textColor = NSColor.black
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.alignment = .left

		let rectTop = CGRect(x: origin.x, y: origin.y, width: width, height: height)
		let ph = pageHeight ?? 0
		let rect = CGRect(x: rectTop.origin.x,
		                  y: ph - rectTop.origin.y - rectTop.height,
		                  width: rectTop.width,
		                  height: rectTop.height)
		fillColor.setFill()
		NSBezierPath(rect: rect).fill()

		// Changed inset from dx: 8 to dx: 24
		let insetRect = rect.insetBy(dx: 24, dy: 3)
		NSAttributedString(string: text, attributes: [
			.font: font,
			.foregroundColor: textColor,
			.paragraphStyle: paragraphStyle
		]).draw(in: insetRect)
		#else
		let fillColor = UIColor(red: 0.83, green: 0.88, blue: 0.95, alpha: 1.0)
		let font = UIFont.boldSystemFont(ofSize: 10)
		let textColor = UIColor.black
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.alignment = .left

		let rect = CGRect(x: origin.x, y: origin.y, width: width, height: height)
		fillColor.setFill()
		UIBezierPath(rect: rect).fill()

		// Changed inset from dx: 8 to dx: 24
		let insetRect = rect.insetBy(dx: 24, dy: 3)
		NSAttributedString(string: text, attributes: [
			.font: font,
			.foregroundColor: textColor,
			.paragraphStyle: paragraphStyle
		]).draw(in: insetRect)
		#endif
		return height
	}

	// MARK: - Totals Row Drawing
	func drawTotalsRow(label: String, amount: Float, at origin: CGPoint, columnWidths: [CGFloat], pageHeight: CGFloat? = nil) -> CGFloat {
	    // Row style
	    let rowHeight: CGFloat = 20
	    #if os(macOS)
	    let font = NSFont.boldSystemFont(ofSize: 9)
	    let bgColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)
	    let textColor = NSColor.black
	    #else
	    let font = UIFont.boldSystemFont(ofSize: 9)
	    let bgColor = UIColor(white: 0.92, alpha: 1.0)
	    let textColor = UIColor.black
	    #endif

	    // Build the full row rect
	    let totalWidth = columnWidths.reduce(0, +)
	    let rowRectTop = CGRect(x: origin.x, y: origin.y, width: totalWidth, height: rowHeight)

	    // Fill background
	    #if os(macOS)
	    let ph = pageHeight ?? 0
	    let rowRect = CGRect(x: rowRectTop.origin.x,
	                         y: ph - rowRectTop.origin.y - rowRectTop.height,
	                         width: rowRectTop.width,
	                         height: rowRectTop.height)
	    bgColor.setFill()
	    NSBezierPath(rect: rowRect).fill()
	    #else
	    bgColor.setFill()
	    UIBezierPath(rect: rowRectTop).fill()
	    #endif

	    // Label in TITLE column (index 1)
	    let titleX = origin.x + columnWidths[0]
	    let titleWidth = columnWidths[1]

	    // Amount in COST column (index 7)
	    let costX = origin.x + columnWidths[0] + columnWidths[1] + columnWidths[2] + columnWidths[3] + columnWidths[4] + columnWidths[5] + columnWidths[6]
	    let costWidth = columnWidths[7]

	    // Attributes
	    let leftPara = NSMutableParagraphStyle()
	    leftPara.alignment = .left
	    let rightPara = NSMutableParagraphStyle()
	    rightPara.alignment = .right

	    #if os(macOS)
	    let labelAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor, .paragraphStyle: leftPara]
	    let amountAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor, .paragraphStyle: rightPara]

	    let titleRect = CGRect(x: titleX,
	                           y: (pageHeight ?? 0) - (origin.y + rowHeight),
	                           width: titleWidth,
	                           height: rowHeight)
	    NSAttributedString(string: label, attributes: labelAttrs).draw(in: titleRect.insetBy(dx: 4, dy: 4))

	    let amountString = functions.formatCurrency(dollars: max(0, amount))
	    let costRect = CGRect(x: costX,
	                          y: (pageHeight ?? 0) - (origin.y + rowHeight),
	                          width: costWidth,
	                          height: rowHeight)
	    NSAttributedString(string: amountString, attributes: amountAttrs).draw(in: costRect.insetBy(dx: 4, dy: 4))
	    #else
	    let labelAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor, .paragraphStyle: leftPara]
	    let amountAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor, .paragraphStyle: rightPara]

	    let titleRect = CGRect(x: titleX, y: origin.y, width: titleWidth, height: rowHeight)
	    NSAttributedString(string: label, attributes: labelAttrs).draw(in: titleRect.insetBy(dx: 4, dy: 4))

	    let amountString = functions.formatCurrency(dollars: max(0, amount))
	    let costRect = CGRect(x: costX, y: origin.y, width: costWidth, height: rowHeight)
	    NSAttributedString(string: amountString, attributes: amountAttrs).draw(in: costRect.insetBy(dx: 4, dy: 4))
	    #endif

	    return rowHeight
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
		panel.nameFieldStringValue = "Project List - \(vehicleTitle) - \(dateStamp).pdf"

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
		let fileName = "Project List - \(vehicleTitle) - \(dateStamp).pdf"

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
		printInfo.jobName = "Project List"
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
#Preview {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: ProjectList.self, Settings1.self, configurations: config)
	let context = container.mainContext
	// Helper to create a ProjectList with some fields set
	func makeProject(category: String, subCategory: String, daysAgo: Int, vehicleId: String, name: String, cost: Float, notes: String) -> ProjectList {
		let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
		return ProjectList(
			createdAt: date,
			updatedAt: date,
			vehicleId: vehicleId,
			miles: 0,
			itemName: name,
			itemDescription: "",
			itemNotes: notes,
			itemVendor: "",
			category: category,
			subCategory: subCategory,
			completedAt: date,
			itemCost: cost,
			image1: nil
		)
	}
	let samples: [ProjectList] = [
		makeProject(category: "Engine",     subCategory: "Oil",      daysAgo: 0,  vehicleId: "Vehicle A", name: "Oil Change",         cost: 120,   notes: "Next change in 3 months."),
		makeProject(category: "Engine",     subCategory: "Oil",      daysAgo: 10, vehicleId: "Vehicle A", name: "Oil Filter",         cost: 18.5,  notes: "OEM filter."),
		makeProject(category: "Engine",     subCategory: "Cooling",  daysAgo: 20, vehicleId: "Vehicle A", name: "Coolant Flush",       cost: 95,    notes: "Replaced coolant."),
		makeProject(category: "Brakes",     subCategory: "Front",    daysAgo: 15, vehicleId: "Vehicle A", name: "Front Pads",          cost: 210,   notes: "Resurfaced rotors."),
		makeProject(category: "Brakes",     subCategory: "Rear",     daysAgo: 18, vehicleId: "Vehicle A", name: "Rear Pads",           cost: 180,   notes: "New pads."),
		makeProject(category: "Electrical", subCategory: "Battery",  daysAgo: 5,  vehicleId: "Vehicle B", name: "Battery Replacement", cost: 170,   notes: "Starts faster."),
		makeProject(category: "Electrical", subCategory: "Lighting", daysAgo: 2,  vehicleId: "Vehicle B", name: "Headlight Bulb",      cost: 25,    notes: "Left bulb replaced."),
	]
	samples.forEach { context.insert($0) }
	let settings = Settings1()
	settings.userName = "primary1"
	context.insert(settings)
	try? context.save()
	return Group {
		pdfReportProjectList(trackVehicleSelected: "All Vehicles")
			.modelContainer(container)
		pdfReportProjectList(trackVehicleSelected: "Vehicle A")
			.modelContainer(container)
	}
}

