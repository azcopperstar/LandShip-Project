//
//  pdfReportCheckListItems.swift
//  LandShip
//
//  Created by JP on 2/21/26.
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

// MARK: - Supporting Types

private struct CheckListItemData: Sendable {
	let itemName: String
	let itemDescription: String
	let itemNotes: String
	let itemCompleted: Bool
	let orderIndex: Int
	let itemID: String
	let parentItemUUID: String?
	let hasSubItems: Bool
	
	init(from item: CheckListItem) {
		self.itemName = item.itemName
		self.itemDescription = item.itemDescription
		self.itemNotes = item.itemNotes
		self.itemCompleted = item.itemCompleted
		self.orderIndex = item.orderIndex
		self.itemID = item.itemID
		self.parentItemUUID = item.parentItemUUID
		self.hasSubItems = item.hasSubItems
	}
}

// MARK: - Main View

struct pdfReportCheckListItems: View {
	// MARK: Data & State
	
	// The checklist we're generating a report for
	let checklist: CheckList
	
	// Fetch the checklist items we will render into the PDF
	@Query private var allItems: [CheckListItem]
	
	// The SwiftData model context
	@Environment(\.modelContext) var modelContext
	@Environment(\.entitlements) private var entitlements
	
	// Holds the generated PDF
	@State private var pdfDocument: PDFDocument?
	
	// Utility helpers
	let functions: Functions = Functions()
	let prefsFunc: PrefsFunctions = PrefsFunctions()
	
	// Zoom action binding
	@State private var zoomAction: ZoomAction?
	
	// MARK: - Zoom Action Enum
	
	enum ZoomAction {
		case zoomIn
		case zoomOut
		case fit
		case actual
	}
	
	#if canImport(UIKit) && !os(macOS)
	@State private var shareURL: URL?
	@State private var isSharing: Bool = false
	#endif
	
	@State private var isGenerating = false
	@State private var csvDocument = CSVDocument(text: "")
	@State private var isExportingCSV = false
	
	// MARK: Init
	
	init(checklist: CheckList) {
		self.checklist = checklist
		
		// Query all CheckListItem records, sorted by order index
		let sortByOrder = SortDescriptor(\CheckListItem.orderIndex, order: .forward)
		let predicate: Predicate<CheckListItem> = #Predicate { _ in true }
		self._allItems = Query(filter: predicate, sort: [sortByOrder])
	}
	
	// Filter items for this checklist
	private func filteredItems() -> [CheckListItem] {
		allItems.filter { $0.checklistName == checklist.checklistName }
			.sorted { $0.orderIndex < $1.orderIndex }
	}
	
	// MARK: Body
	
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
		.task { @MainActor in
			generateAndShowPDF()
		}
		.toolbar {
			ToolbarItem(placement: .automatic) {
				Button("Regenerate") {
					pdfDocument = nil
					generateAndShowPDF()
				}
			}
			ToolbarItem(placement: .automatic) {
				Button {
					csvDocument = CSVDocument(text: generateCSV())
					isExportingCSV = true
				} label: {
					Label("Export CSV", systemImage: "tablecells")
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
		.sheet(
			isPresented: Binding(
				get: { isSharing && !isGenerating },
				set: { newValue in
					if !newValue { isSharing = false }
					else { isSharing = true }
				}
			),
			content: {
				if let url = shareURL {
					ShareSheet(activityItems: [url])
				} else {
					EmptyView()
				}
			}
		)
		#endif
		.fileExporter(isPresented: $isExportingCSV, document: csvDocument, contentType: .commaSeparatedText, defaultFilename: checklist.checklistName.isEmpty ? "Checklist" : checklist.checklistName) { _ in }
	}

	// MARK: - CSV Export

	private func generateCSV() -> String {
		let items = filteredItems()
		let vehicleName = checklist.vehicleId.isEmpty ? "" : functions.getVehicleDisplayName(vehicleId: checklist.vehicleId, context: modelContext)
		let headers = [
			"Checklist Name", Vertical.current.assetSingular, "\(Vertical.current.assetSingular) Display Name", "Checklist Category",
			"Inactive", "Created At", "Updated At", "Item Name", "Item Description", "Item Notes",
			"Item Completed", "Completed At", "Order Index", "Item ID", "Parent Item ID", "Has Sub-Items", "Sub-Items Section Name",
			"Image 1 Description"
		]
		let rows: [[String]] = items.map { item in
			[
				checklist.checklistName, checklist.vehicleId, vehicleName, checklist.category,
				CSVField.bool(item.inactive), CSVField.date(item.createdAt), CSVField.date(item.updatedAt), item.itemName, item.itemDescription, item.itemNotes,
				CSVField.bool(item.itemCompleted), CSVField.date(item.completedAt), CSVField.int(item.orderIndex), item.itemID, item.parentItemUUID ?? "", CSVField.bool(item.hasSubItems), item.subItemsSectionName,
				item.image1Description
			]
		}
		return CSVBuilder.build(headers: headers, rows: rows)
	}

	// MARK: - PDF Generation
	
	@MainActor
	private func generateAndShowPDF() {
		guard !isGenerating else { return }
		isGenerating = true
		pdfDocument = nil
		
		// Capture items on main thread before going to background
		let itemsData = filteredItems().map { CheckListItemData(from: $0) }
		let checklistName = checklist.checklistName
		let vehicleId = checklist.vehicleId
		let category = checklist.category
		let checklistDescription = checklist.checklistDescription
		let checklistNotes = checklist.checklistNotes
		let completionLog = checklist.completionLog
		let headerBgHex = checklist.headerBgColorHex
		let headerFgHex = checklist.headerFgColorHex
		
		Task.detached {
			let title = "\(checklistName.uppercased()) CHECKLIST"
			
			#if os(macOS)
			let data = pdfReportCheckListItems.generatePDFmacOS(title: title, items: itemsData, vehicleId: vehicleId, category: category, checklistDescription: checklistDescription, checklistNotes: checklistNotes, completionLog: completionLog, headerBgHex: headerBgHex, headerFgHex: headerFgHex)
			#else
			let data = pdfReportCheckListItems.generatePDFiOS(title: title, items: itemsData, vehicleId: vehicleId, category: category, checklistDescription: checklistDescription, checklistNotes: checklistNotes, completionLog: completionLog, headerBgHex: headerBgHex, headerFgHex: headerFgHex)
			#endif
			
			await MainActor.run {
				self.isGenerating = false
				if let data = data {
					self.pdfDocument = PDFDocument(data: data)
				}
			}
		}
	}
	
	// MARK: - PDF Generation

	#if os(macOS)
	nonisolated private static func nsColorFromHex(_ hex: String, fallback: NSColor) -> NSColor {
		var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
		h = h.hasPrefix("#") ? String(h.dropFirst()) : h
		guard h.count == 6 || h.count == 8 else { return fallback }
		var value: UInt64 = 0
		guard Scanner(string: h).scanHexInt64(&value) else { return fallback }
		let r, g, b, a: CGFloat
		if h.count == 8 {
			r = CGFloat((value >> 24) & 0xFF) / 255
			g = CGFloat((value >> 16) & 0xFF) / 255
			b = CGFloat((value >> 8) & 0xFF) / 255
			a = CGFloat(value & 0xFF) / 255
		} else {
			r = CGFloat((value >> 16) & 0xFF) / 255
			g = CGFloat((value >> 8) & 0xFF) / 255
			b = CGFloat(value & 0xFF) / 255
			a = 1
		}
		return a < 0.05 ? fallback : NSColor(red: r, green: g, blue: b, alpha: a)
	}
	nonisolated private static func generatePDFmacOS(title: String, items: [CheckListItemData], vehicleId: String, category: String, checklistDescription: String, checklistNotes: String, completionLog: [Date], headerBgHex: String, headerFgHex: String) -> Data? {
		let pageSize = CGSize(width: 612, height: 792) // US Letter
		let marginTop: CGFloat = 50
		let marginLeft: CGFloat = 50
		let marginBottom: CGFloat = 50
		let marginRight: CGFloat = 50
		let contentWidth = pageSize.width - marginLeft - marginRight
		
		var pages: [[PDFElement]] = [[]]
		var currentY: CGFloat = marginTop
		
		// Title with configurable background
		let titleHeight: CGFloat = 30
		let titleBgColor = nsColorFromHex(headerBgHex, fallback: .systemBlue)
		let titleFgColor = nsColorFromHex(headerFgHex, fallback: .white)
		pages[pages.count - 1].append(PDFElement(
			text: nil,
			font: nil,
			color: nil,
			backgroundColor: titleBgColor,
			frame: CGRect(x: marginLeft, y: currentY, width: contentWidth, height: titleHeight)
		))
		pages[pages.count - 1].append(PDFElement(
			text: title,
			font: NSFont.boldSystemFont(ofSize: 18),
			color: titleFgColor,
			backgroundColor: nil,
			frame: CGRect(x: marginLeft + 10, y: currentY + 5, width: contentWidth - 20, height: titleHeight - 10)
		))
		currentY += titleHeight + 10
		
		// Checklist info
		var infoLines = [
			"\(Vertical.current.assetSingular): \(vehicleId)",
			"Description: \(checklistDescription)"
		]
		if !checklistNotes.isEmpty {
			infoLines.append("Notes: \(checklistNotes)")
		}
		let infoText = infoLines.joined(separator: "\n")
		
		// Calculate height based on text content
		let font = NSFont.systemFont(ofSize: 10)
		let attributes: [NSAttributedString.Key: Any] = [.font: font]
		let textSize = (infoText as NSString).boundingRect(
			with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
			options: [.usesLineFragmentOrigin, .usesFontLeading],
			attributes: attributes,
			context: nil
		)
		let infoHeight = ceil(textSize.height) + 10
		
		pages[pages.count - 1].append(PDFElement(
			text: infoText,
			font: font,
			color: .darkGray,
			backgroundColor: nil,
			frame: CGRect(x: marginLeft, y: currentY, width: contentWidth, height: infoHeight)
		))
		currentY += infoHeight + 10
		
		// Organize items into parent-child hierarchy
		var parentItems: [(item: CheckListItemData, subItems: [CheckListItemData])] = []
		var itemsDict: [String: CheckListItemData] = [:]
		
		// First pass: create dictionary of all items
		for item in items {
			itemsDict[item.itemID] = item
		}
		
		// Second pass: build parent-child structure
		var processedItems = Set<String>()
		for item in items {
			guard item.parentItemUUID == nil, !processedItems.contains(item.itemID) else { continue }
			
			// This is a parent item, find its children
			let children = items.filter { $0.parentItemUUID == item.itemID }
				.sorted { $0.orderIndex < $1.orderIndex }
			
			parentItems.append((item: item, subItems: children))
			processedItems.insert(item.itemID)
			for child in children {
				processedItems.insert(child.itemID)
			}
		}
		
		// Render each parent item and its sub-items
		for (item, subItems) in parentItems {
			let checkmark = item.itemCompleted ? "✓" : "☐"
			let itemText = "\(checkmark) \(item.itemName)"
			
			// Parent item with bold font if it has sub-items
			let itemFont = item.hasSubItems ? NSFont.boldSystemFont(ofSize: 11) : NSFont.systemFont(ofSize: 11)
			
			// Calculate actual height needed for item text (dynamic based on content)
			let itemAttributes: [NSAttributedString.Key: Any] = [.font: itemFont]
			let itemTextSize = (itemText as NSString).boundingRect(
				with: CGSize(width: contentWidth - 10, height: .greatestFiniteMagnitude),
				options: [.usesLineFragmentOrigin, .usesFontLeading],
				attributes: itemAttributes,
				context: nil
			)
			let itemHeight = ceil(itemTextSize.height) + 4 // Add 4 points padding
			
			// Calculate description height if present
			var descHeight: CGFloat = 0
			if !item.itemDescription.isEmpty {
				let descAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9)]
				let descTextSize = (item.itemDescription as NSString).boundingRect(
					with: CGSize(width: contentWidth - 25, height: .greatestFiniteMagnitude),
					options: [.usesLineFragmentOrigin, .usesFontLeading],
					attributes: descAttributes,
					context: nil
				)
				descHeight = ceil(descTextSize.height) + 4
			}
			
			// Calculate notes height if present
			var notesHeight: CGFloat = 0
			if !item.itemNotes.isEmpty {
				let notesAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 8)]
				let notesTextSize = (item.itemNotes as NSString).boundingRect(
					with: CGSize(width: contentWidth - 25, height: .greatestFiniteMagnitude),
					options: [.usesLineFragmentOrigin, .usesFontLeading],
					attributes: notesAttributes,
					context: nil
				)
				notesHeight = ceil(notesTextSize.height) + 4
			}
			
			// Calculate total row height
			let totalRowHeight = itemHeight + descHeight + notesHeight + 5 // spacing
			
			// Check if we need a new page
			if currentY + totalRowHeight > pageSize.height - marginBottom {
				pages.append([])
				currentY = marginTop
			}
			
			pages[pages.count - 1].append(PDFElement(
				text: itemText,
				font: itemFont,
				color: item.itemCompleted ? .gray : .black,
				backgroundColor: nil,
				frame: CGRect(x: marginLeft + 5, y: currentY + 2, width: contentWidth - 10, height: itemHeight)
			))
			currentY += itemHeight
			
			// Add description if present
			if !item.itemDescription.isEmpty {
				pages[pages.count - 1].append(PDFElement(
					text: item.itemDescription,
					font: NSFont.systemFont(ofSize: 9),
					color: .gray,
					backgroundColor: nil,
					frame: CGRect(x: marginLeft + 20, y: currentY, width: contentWidth - 25, height: descHeight)
				))
				currentY += descHeight
			}
			
			// Add notes if present
			if !item.itemNotes.isEmpty {
				pages[pages.count - 1].append(PDFElement(
					text: item.itemNotes,
					font: NSFont.systemFont(ofSize: 8),
					color: .darkGray,
					backgroundColor: nil,
					frame: CGRect(x: marginLeft + 20, y: currentY, width: contentWidth - 25, height: notesHeight)
				))
				currentY += notesHeight
			}
			
			currentY += 5 // spacing between items
			
			// Render sub-items with indentation
			for subItem in subItems {
				let subCheckmark = subItem.itemCompleted ? "✓" : "☐"
				let subItemText = "\(subCheckmark) \(subItem.itemName)"
				
				// Calculate actual height needed for sub-item text
				let subItemFont = NSFont.systemFont(ofSize: 10)
				let subItemAttributes: [NSAttributedString.Key: Any] = [.font: subItemFont]
				let subItemTextSize = (subItemText as NSString).boundingRect(
					with: CGSize(width: contentWidth - 40, height: .greatestFiniteMagnitude),
					options: [.usesLineFragmentOrigin, .usesFontLeading],
					attributes: subItemAttributes,
					context: nil
				)
				let subItemHeight = ceil(subItemTextSize.height) + 4
				
				// Calculate sub-item description height if present
				var subDescHeight: CGFloat = 0
				if !subItem.itemDescription.isEmpty {
					let subDescAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9)]
					let subDescTextSize = (subItem.itemDescription as NSString).boundingRect(
						with: CGSize(width: contentWidth - 55, height: .greatestFiniteMagnitude),
						options: [.usesLineFragmentOrigin, .usesFontLeading],
						attributes: subDescAttributes,
						context: nil
					)
					subDescHeight = ceil(subDescTextSize.height) + 4
				}
				
				// Calculate sub-item notes height if present
				var subNotesHeight: CGFloat = 0
				if !subItem.itemNotes.isEmpty {
					let subNotesAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 8)]
					let subNotesTextSize = (subItem.itemNotes as NSString).boundingRect(
						with: CGSize(width: contentWidth - 55, height: .greatestFiniteMagnitude),
						options: [.usesLineFragmentOrigin, .usesFontLeading],
						attributes: subNotesAttributes,
						context: nil
					)
					subNotesHeight = ceil(subNotesTextSize.height) + 4
				}
				
				let subTotalRowHeight = subItemHeight + subDescHeight + subNotesHeight + 5
				
				// Check if we need a new page
				if currentY + subTotalRowHeight > pageSize.height - marginBottom {
					pages.append([])
					currentY = marginTop
				}
				
				// Sub-item with indentation (30 points indent)
				pages[pages.count - 1].append(PDFElement(
					text: subItemText,
					font: subItemFont,
					color: subItem.itemCompleted ? .gray : .black,
					backgroundColor: nil,
					frame: CGRect(x: marginLeft + 35, y: currentY + 2, width: contentWidth - 40, height: subItemHeight)
				))
				currentY += subItemHeight
				
				// Add sub-item description if present
				if !subItem.itemDescription.isEmpty {
					pages[pages.count - 1].append(PDFElement(
						text: subItem.itemDescription,
						font: NSFont.systemFont(ofSize: 9),
						color: .gray,
						backgroundColor: nil,
						frame: CGRect(x: marginLeft + 50, y: currentY, width: contentWidth - 55, height: subDescHeight)
					))
					currentY += subDescHeight
				}
				
				// Add sub-item notes if present
				if !subItem.itemNotes.isEmpty {
					pages[pages.count - 1].append(PDFElement(
						text: subItem.itemNotes,
						font: NSFont.systemFont(ofSize: 8),
						color: .darkGray,
						backgroundColor: nil,
						frame: CGRect(x: marginLeft + 50, y: currentY, width: contentWidth - 55, height: subNotesHeight)
					))
					currentY += subNotesHeight
				}
				
				currentY += 5 // spacing between items
			}
		}
		
		// Add completion log if there are any completion dates (after all items)
		if !completionLog.isEmpty {
			currentY += 10 // Extra spacing before completion log
			
			let dateFormatter = DateFormatter()
			dateFormatter.dateStyle = .medium
			dateFormatter.timeStyle = .short
			
			let completionDates = completionLog
				.sorted(by: >)
				.prefix(10)
				.map { dateFormatter.string(from: $0) }
				.joined(separator: "\n")
			
			let logTitle = "Completion History (last \(min(completionLog.count, 10))):"
			let logText = "\(logTitle)\n\(completionDates)"
			
			let logAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9)]
			let logTextSize = (logText as NSString).boundingRect(
				with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
				options: [.usesLineFragmentOrigin, .usesFontLeading],
				attributes: logAttributes,
				context: nil
			)
			let logHeight = ceil(logTextSize.height) + 10
			
			// Check if we need a new page
			if currentY + logHeight > pageSize.height - marginBottom {
				pages.append([])
				currentY = marginTop
			}
			
			pages[pages.count - 1].append(PDFElement(
				text: logText,
				font: NSFont.systemFont(ofSize: 9),
				color: .systemBlue,
				backgroundColor: nil,
				frame: CGRect(x: marginLeft, y: currentY, width: contentWidth, height: logHeight)
			))
			currentY += logHeight + 10
		}
		
		return renderPDFPages(pages: pages, pageSize: pageSize)
	}
	#endif
	
	#if canImport(UIKit)
	nonisolated private static func uiColorFromHex(_ hex: String, fallback: UIColor) -> UIColor {
		var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
		h = h.hasPrefix("#") ? String(h.dropFirst()) : h
		guard h.count == 6 || h.count == 8 else { return fallback }
		var value: UInt64 = 0
		guard Scanner(string: h).scanHexInt64(&value) else { return fallback }
		let r, g, b, a: CGFloat
		if h.count == 8 {
			r = CGFloat((value >> 24) & 0xFF) / 255
			g = CGFloat((value >> 16) & 0xFF) / 255
			b = CGFloat((value >> 8) & 0xFF) / 255
			a = CGFloat(value & 0xFF) / 255
		} else {
			r = CGFloat((value >> 16) & 0xFF) / 255
			g = CGFloat((value >> 8) & 0xFF) / 255
			b = CGFloat(value & 0xFF) / 255
			a = 1
		}
		return a < 0.05 ? fallback : UIColor(red: r, green: g, blue: b, alpha: a)
	}
	nonisolated private static func generatePDFiOS(title: String, items: [CheckListItemData], vehicleId: String, category: String, checklistDescription: String, checklistNotes: String, completionLog: [Date], headerBgHex: String, headerFgHex: String) -> Data? {
		let pageSize = CGSize(width: 612, height: 792)
		let margins = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
		let contentWidth = pageSize.width - margins.left - margins.right
		
		var pages: [[PDFElement]] = [[]]
		var currentY: CGFloat = margins.top
		
		// Title with configurable background
		let titleHeight: CGFloat = 30
		let titleBgColor = uiColorFromHex(headerBgHex, fallback: .systemBlue)
		let titleFgColor = uiColorFromHex(headerFgHex, fallback: .white)
		pages[pages.count - 1].append(PDFElement(
			text: nil,
			font: nil,
			color: nil,
			backgroundColor: titleBgColor,
			frame: CGRect(x: margins.left, y: currentY, width: contentWidth, height: titleHeight)
		))
		pages[pages.count - 1].append(PDFElement(
			text: title,
			font: UIFont.boldSystemFont(ofSize: 18),
			color: titleFgColor,
			backgroundColor: nil,
			frame: CGRect(x: margins.left + 10, y: currentY + 5, width: contentWidth - 20, height: titleHeight - 10)
		))
		currentY += titleHeight + 10
		
		// Checklist info
		var infoLines = [
			"\(Vertical.current.assetSingular): \(vehicleId)",
			"Description: \(checklistDescription)"
		]
		if !checklistNotes.isEmpty {
			infoLines.append("Notes: \(checklistNotes)")
		}
		let infoText = infoLines.joined(separator: "\n")
		
		// Calculate height dynamically based on text content
		let font = UIFont.systemFont(ofSize: 10)
		let attributes: [NSAttributedString.Key: Any] = [.font: font]
		let textSize = (infoText as NSString).boundingRect(
			with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
			options: [.usesLineFragmentOrigin, .usesFontLeading],
			attributes: attributes,
			context: nil
		)
		let infoHeight = ceil(textSize.height) + 10
		
		pages[pages.count - 1].append(PDFElement(
			text: infoText,
			font: font,
			color: .darkGray,
			backgroundColor: nil,
			frame: CGRect(x: margins.left, y: currentY, width: contentWidth, height: infoHeight)
		))
		currentY += infoHeight + 10
		
		// Organize items into parent-child hierarchy
		var parentItems: [(item: CheckListItemData, subItems: [CheckListItemData])] = []
		var itemsDict: [String: CheckListItemData] = [:]
		
		// First pass: create dictionary of all items
		for item in items {
			itemsDict[item.itemID] = item
		}
		
		// Second pass: build parent-child structure
		var processedItems = Set<String>()
		for item in items {
			guard item.parentItemUUID == nil, !processedItems.contains(item.itemID) else { continue }
			
			// This is a parent item, find its children
			let children = items.filter { $0.parentItemUUID == item.itemID }
				.sorted { $0.orderIndex < $1.orderIndex }
			
			parentItems.append((item: item, subItems: children))
			processedItems.insert(item.itemID)
			for child in children {
				processedItems.insert(child.itemID)
			}
		}
		
		// Render each parent item and its sub-items
		for (item, subItems) in parentItems {
			let checkmark = item.itemCompleted ? "✓" : "☐"
			let itemText = "\(checkmark) \(item.itemName)"
			
			// Parent item with bold font if it has sub-items
			let itemFont = item.hasSubItems ? UIFont.boldSystemFont(ofSize: 11) : UIFont.systemFont(ofSize: 11)
			
			// Calculate actual height needed for item text (dynamic based on content)
			let itemAttributes: [NSAttributedString.Key: Any] = [.font: itemFont]
			let itemTextSize = (itemText as NSString).boundingRect(
				with: CGSize(width: contentWidth - 10, height: .greatestFiniteMagnitude),
				options: [.usesLineFragmentOrigin, .usesFontLeading],
				attributes: itemAttributes,
				context: nil
			)
			let itemHeight = ceil(itemTextSize.height) + 4 // Add 4 points padding
			
			// Calculate description height if present
			var descHeight: CGFloat = 0
			if !item.itemDescription.isEmpty {
				let descAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9)]
				let descTextSize = (item.itemDescription as NSString).boundingRect(
					with: CGSize(width: contentWidth - 25, height: .greatestFiniteMagnitude),
					options: [.usesLineFragmentOrigin, .usesFontLeading],
					attributes: descAttributes,
					context: nil
				)
				descHeight = ceil(descTextSize.height) + 4
			}
			
			// Calculate notes height if present
			var notesHeight: CGFloat = 0
			if !item.itemNotes.isEmpty {
				let notesAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8)]
				let notesTextSize = (item.itemNotes as NSString).boundingRect(
					with: CGSize(width: contentWidth - 25, height: .greatestFiniteMagnitude),
					options: [.usesLineFragmentOrigin, .usesFontLeading],
					attributes: notesAttributes,
					context: nil
				)
				notesHeight = ceil(notesTextSize.height) + 4
			}
			
			// Calculate total row height
			let totalRowHeight = itemHeight + descHeight + notesHeight + 5 // spacing
			
			// Check if we need a new page
			if currentY + totalRowHeight > pageSize.height - margins.bottom {
				pages.append([])
				currentY = margins.top
			}
			
			pages[pages.count - 1].append(PDFElement(
				text: itemText,
				font: itemFont,
				color: item.itemCompleted ? .gray : .black,
				backgroundColor: nil,
				frame: CGRect(x: margins.left + 5, y: currentY + 2, width: contentWidth - 10, height: itemHeight)
			))
			currentY += itemHeight
			
			// Add description if present
			if !item.itemDescription.isEmpty {
				pages[pages.count - 1].append(PDFElement(
					text: item.itemDescription,
					font: UIFont.systemFont(ofSize: 9),
					color: .gray,
					backgroundColor: nil,
					frame: CGRect(x: margins.left + 20, y: currentY, width: contentWidth - 25, height: descHeight)
				))
				currentY += descHeight
			}
			
			// Add notes if present
			if !item.itemNotes.isEmpty {
				pages[pages.count - 1].append(PDFElement(
					text: item.itemNotes,
					font: UIFont.systemFont(ofSize: 8),
					color: .darkGray,
					backgroundColor: nil,
					frame: CGRect(x: margins.left + 20, y: currentY, width: contentWidth - 25, height: notesHeight)
				))
				currentY += notesHeight
			}
			
			currentY += 5 // spacing between items
			
			// Render sub-items with indentation
			for subItem in subItems {
				let subCheckmark = subItem.itemCompleted ? "✓" : "☐"
				let subItemText = "\(subCheckmark) \(subItem.itemName)"
				
				// Calculate actual height needed for sub-item text
				let subItemFont = UIFont.systemFont(ofSize: 10)
				let subItemAttributes: [NSAttributedString.Key: Any] = [.font: subItemFont]
				let subItemTextSize = (subItemText as NSString).boundingRect(
					with: CGSize(width: contentWidth - 40, height: .greatestFiniteMagnitude),
					options: [.usesLineFragmentOrigin, .usesFontLeading],
					attributes: subItemAttributes,
					context: nil
				)
				let subItemHeight = ceil(subItemTextSize.height) + 4
				
				// Calculate sub-item description height if present
				var subDescHeight: CGFloat = 0
				if !subItem.itemDescription.isEmpty {
					let subDescAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9)]
					let subDescTextSize = (subItem.itemDescription as NSString).boundingRect(
						with: CGSize(width: contentWidth - 55, height: .greatestFiniteMagnitude),
						options: [.usesLineFragmentOrigin, .usesFontLeading],
						attributes: subDescAttributes,
						context: nil
					)
					subDescHeight = ceil(subDescTextSize.height) + 4
				}
				
				// Calculate sub-item notes height if present
				var subNotesHeight: CGFloat = 0
				if !subItem.itemNotes.isEmpty {
					let subNotesAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8)]
					let subNotesTextSize = (subItem.itemNotes as NSString).boundingRect(
						with: CGSize(width: contentWidth - 55, height: .greatestFiniteMagnitude),
						options: [.usesLineFragmentOrigin, .usesFontLeading],
						attributes: subNotesAttributes,
						context: nil
					)
					subNotesHeight = ceil(subNotesTextSize.height) + 4
				}
				
				let subTotalRowHeight = subItemHeight + subDescHeight + subNotesHeight + 5
				
				// Check if we need a new page
				if currentY + subTotalRowHeight > pageSize.height - margins.bottom {
					pages.append([])
					currentY = margins.top
				}
				
				// Sub-item with indentation (30 points indent)
				pages[pages.count - 1].append(PDFElement(
					text: subItemText,
					font: subItemFont,
					color: subItem.itemCompleted ? .gray : .black,
					backgroundColor: nil,
					frame: CGRect(x: margins.left + 35, y: currentY + 2, width: contentWidth - 40, height: subItemHeight)
				))
				currentY += subItemHeight
				
				// Add sub-item description if present
				if !subItem.itemDescription.isEmpty {
					pages[pages.count - 1].append(PDFElement(
						text: subItem.itemDescription,
						font: UIFont.systemFont(ofSize: 9),
						color: .gray,
						backgroundColor: nil,
						frame: CGRect(x: margins.left + 50, y: currentY, width: contentWidth - 55, height: subDescHeight)
					))
					currentY += subDescHeight
				}
				
				// Add sub-item notes if present
				if !subItem.itemNotes.isEmpty {
					pages[pages.count - 1].append(PDFElement(
						text: subItem.itemNotes,
						font: UIFont.systemFont(ofSize: 8),
						color: .darkGray,
						backgroundColor: nil,
						frame: CGRect(x: margins.left + 50, y: currentY, width: contentWidth - 55, height: subNotesHeight)
					))
					currentY += subNotesHeight
				}
				
				currentY += 5 // spacing between items
			}
		}
		
		// Add completion log if there are any completion dates (after all items)
		if !completionLog.isEmpty {
			currentY += 10 // Extra spacing before completion log
			
			let dateFormatter = DateFormatter()
			dateFormatter.dateStyle = .medium
			dateFormatter.timeStyle = .short
			
			let completionDates = completionLog
				.sorted(by: >)
				.prefix(10)
				.map { dateFormatter.string(from: $0) }
				.joined(separator: "\n")
			
			let logTitle = "Completion History (last \(min(completionLog.count, 10))):"
			let logText = "\(logTitle)\n\(completionDates)"
			
			let logAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9)]
			let logTextSize = (logText as NSString).boundingRect(
				with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
				options: [.usesLineFragmentOrigin, .usesFontLeading],
				attributes: logAttributes,
				context: nil
			)
			let logHeight = ceil(logTextSize.height) + 10
			
			// Check if we need a new page
			if currentY + logHeight > pageSize.height - margins.bottom {
				pages.append([])
				currentY = margins.top
			}
			
			pages[pages.count - 1].append(PDFElement(
				text: logText,
				font: UIFont.systemFont(ofSize: 9),
				color: .systemBlue,
				backgroundColor: nil,
				frame: CGRect(x: margins.left, y: currentY, width: contentWidth, height: logHeight)
			))
			currentY += logHeight + 10
		}
		
		return renderPDFPages(pages: pages, pageSize: pageSize)
	}
	#endif
	
	// MARK: - PDF Rendering
	
	nonisolated private static func renderPDFPages(pages: [[PDFElement]], pageSize: CGSize) -> Data? {
		let pdfData = NSMutableData()
		
		#if os(macOS)
		guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }
		var mediaBox = CGRect(origin: .zero, size: pageSize)
		guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
		
		for pageElements in pages {
			pdfContext.beginPDFPage(nil)
			
			// Set up NSGraphicsContext for AppKit drawing
			let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
			NSGraphicsContext.current = nsContext
			
			for element in pageElements {
				// Convert Y coordinate from top-origin to bottom-origin for macOS
				let flippedY = pageSize.height - element.frame.origin.y - element.frame.size.height
				let flippedFrame = CGRect(x: element.frame.origin.x, y: flippedY, width: element.frame.size.width, height: element.frame.size.height)
				
				// Draw background color
				if let bgColor = element.backgroundColor {
					pdfContext.saveGState()
					pdfContext.setFillColor(bgColor.cgColor)
					pdfContext.fill(flippedFrame)
					pdfContext.restoreGState()
				}
				
				// Draw text
				if let text = element.text, let font = element.font, let color = element.color {
					let attributes: [NSAttributedString.Key: Any] = [
						.font: font,
						.foregroundColor: color
					]
					let nsString = text as NSString
					nsString.draw(in: flippedFrame, withAttributes: attributes)
				}
			}
			
			pdfContext.endPDFPage()
		}
		
		pdfContext.closePDF()
		#else
		UIGraphicsBeginPDFContextToData(pdfData, CGRect(origin: .zero, size: pageSize), nil)
		
		for pageElements in pages {
			UIGraphicsBeginPDFPage()
			guard let context = UIGraphicsGetCurrentContext() else { continue }
			
			for element in pageElements {
				// Draw background color if present
				if let bgColor = element.backgroundColor {
					context.saveGState()
					context.setFillColor(bgColor.cgColor)
					context.fill(element.frame)
					context.restoreGState()
				}
				
				// Draw text if present
				if let text = element.text, let font = element.font, let color = element.color {
					let attributes: [NSAttributedString.Key: Any] = [
						.font: font,
						.foregroundColor: color
					]
					text.draw(in: element.frame, withAttributes: attributes)
				}
			}
		}
		
		UIGraphicsEndPDFContext()
		#endif
		
		return pdfData as Data
	}
	
	// MARK: - Actions
	
	private func printPDF() {
		guard let doc = pdfDocument else { return }
		guard entitlements.requestExport(.pdfPrint) else { return }

		#if os(macOS)
		let printOp = doc.printOperation(for: .shared, scalingMode: .pageScaleToFit, autoRotate: true)
		printOp?.run()
		#else
		let printController = UIPrintInteractionController.shared
		printController.printingItem = doc.dataRepresentation()
		printController.present(animated: true)
		#endif
	}
	
	#if os(macOS)
	private func saveAsPDF() {
		guard let data = pdfDocument?.dataRepresentation() else { return }
		guard entitlements.requestExport(.pdfExport) else { return }

		let savePanel = NSSavePanel()
		savePanel.allowedContentTypes = [.pdf]
		savePanel.nameFieldStringValue = "CheckList_\(checklist.checklistName).pdf"
		
		savePanel.begin { response in
			if response == .OK, let url = savePanel.url {
				do {
					try data.write(to: url)
				} catch {
					print("Error saving PDF: \(error)")
				}
			}
		}
	}
	#endif
	
	#if canImport(UIKit) && !os(macOS)
	private func sharePDFiOS() {
		guard let data = pdfDocument?.dataRepresentation() else { return }
		guard entitlements.requestExport(.pdfExport) else { return }

		let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("CheckList_\(checklist.checklistName).pdf")
		do {
			try data.write(to: tempURL)
			shareURL = tempURL
			isSharing = true
		} catch {
			print("Error creating temp PDF: \(error)")
		}
	}
	#endif
	
	// MARK: - PDFKit View Wrappers
	
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
				zoomAction = nil
			}
		}
	}
	#endif
}

// MARK: - PDF Element

private struct PDFElement {
	let text: String?
	let font: PlatformFont?
	let color: PlatformColor?
	let backgroundColor: PlatformColor?
	let frame: CGRect
	
	init(text: String?, font: PlatformFont?, color: PlatformColor?, backgroundColor: PlatformColor? = nil, frame: CGRect) {
		self.text = text
		self.font = font
		self.color = color
		self.backgroundColor = backgroundColor
		self.frame = frame
	}
	
	#if os(macOS)
	typealias PlatformFont = NSFont
	typealias PlatformColor = NSColor
	#else
	typealias PlatformFont = UIFont
	typealias PlatformColor = UIColor
	#endif
}

// MARK: - Share Sheet (iOS)

#if canImport(UIKit) && !os(macOS)
struct ShareSheet: UIViewControllerRepresentable {
	let activityItems: [Any]
	
	func makeUIViewController(context: Context) -> UIActivityViewController {
		UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
	}
	
	func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
