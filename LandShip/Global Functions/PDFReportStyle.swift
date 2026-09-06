//
//  PDFReportStyle.swift
//  LandShip
//
//  Shared PDF report styling and table-drawing engine. Reports build a title, a set of
//  weighted columns, and rows of PDFCell values; PDFReportRenderer measures, paginates,
//  and draws them identically on macOS and iOS. New reports should adopt this instead of
//  copy-pasting Core Graphics drawing code.
//

import Foundation
import SwiftUI
import SwiftData
import PDFKit
import ImageIO
#if os(macOS)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

#if os(macOS)
typealias PlatformColor = NSColor
typealias PlatformFont = NSFont
#else
typealias PlatformColor = UIColor
typealias PlatformFont = UIFont
#endif

/// Cross-platform italic system font — NSFont has no `italicSystemFont(ofSize:)` convenience
/// the way UIFont does, so this fills the gap for the one place (the disclaimer footer note)
/// that needs italics.
private func platformItalicSystemFont(ofSize size: CGFloat) -> PlatformFont {
	#if os(macOS)
	let base = NSFont.systemFont(ofSize: size)
	guard let descriptor = base.fontDescriptor.withSymbolicTraits(.italic) as NSFontDescriptor?,
	      let italic = NSFont(descriptor: descriptor, size: size) else { return base }
	return italic
	#else
	return UIFont.italicSystemFont(ofSize: size)
	#endif
}

// MARK: - Page sizes

enum PDFPageSize {
	static let letterPortrait = CGSize(width: 612, height: 792)
	static let letterLandscape = CGSize(width: 792, height: 612)
}

// MARK: - Palette

/// A platform-neutral color so the palette can be defined once and read by both AppKit and UIKit call sites.
struct PDFColor {
	let red: CGFloat
	let green: CGFloat
	let blue: CGFloat
	let alpha: CGFloat

	var platform: PlatformColor {
		PlatformColor(red: red, green: green, blue: blue, alpha: alpha)
	}
}

/// Shared visual identity for every PDF report. Seeded from the color literals that were
/// already duplicated across the 11 legacy report files, so nothing looks unfamiliar.
enum PDFPalette {
	static let titleText = PDFColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1.0)
	static let subtitleText = PDFColor(red: 0.35, green: 0.38, blue: 0.42, alpha: 1.0)
	static let accentRule = PDFColor(red: 0.20, green: 0.47, blue: 0.78, alpha: 1.0)
	static let headerFill = PDFColor(red: 0.86, green: 0.92, blue: 0.98, alpha: 1.0)
	static let headerText = PDFColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1.0)
	static let rowAltFill = PDFColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)
	static let grid = PDFColor(red: 0.80, green: 0.80, blue: 0.82, alpha: 1.0)
	static let border = PDFColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1.0)
	static let groupHeading = PDFColor(red: 0.20, green: 0.47, blue: 0.78, alpha: 1.0)
	static let fieldLabel = PDFColor(red: 0.42, green: 0.44, blue: 0.47, alpha: 1.0)
	static let bodyText = PDFColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
	static let mutedText = PDFColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1.0)
	static let placeholderFill = PDFColor(red: 0.90, green: 0.90, blue: 0.90, alpha: 1.0)
	static let footerText = PDFColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1.0)
}

// MARK: - Style

/// Metrics and type scale for a report. Reports may override individual values; `.standard`
/// is tuned for a portrait US-Letter page with five-ish category columns.
struct PDFReportStyle {
	var pageSize: CGSize = PDFPageSize.letterPortrait
	var margin: CGFloat = 24
	var headerHeight: CGFloat = 46
	var footerHeight: CGFloat = 22

	var titleSize: CGFloat = 15
	var subtitleSize: CGFloat = 9
	var columnHeaderSize: CGFloat = 9
	var columnHeaderMinHeight: CGFloat = 22
	var groupHeadingSize: CGFloat = 7.5
	var fieldLabelSize: CGFloat = 6.5
	var bodySize: CGFloat = 7
	var footerSize: CGFloat = 7.5
	var footerNoteSize: CGFloat = 6.5

	var cellInsetH: CGFloat = 5
	var cellInsetV: CGFloat = 8
	var minRowHeight: CGFloat = 40
	var thumbnailMaxHeight: CGFloat = 64

	var gridLineWidth: CGFloat = 0.5
	var borderLineWidth: CGFloat = 1.0
	var fieldLineSpacing: CGFloat = 1.5

	static let standard = PDFReportStyle()
}

// MARK: - Table model

struct PDFTableColumn {
	var title: String
	var weight: CGFloat
	var alignment: NSTextAlignment = .left

	init(_ title: String, weight: CGFloat, alignment: NSTextAlignment = .left) {
		self.title = title
		self.weight = weight
		self.alignment = alignment
	}
}

/// A labeled block of fields drawn as stacked "Label: value" lines, optionally under a heading.
struct PDFFieldGroup {
	var heading: String?
	var fields: [(label: String, value: String)]

	init(heading: String? = nil, fields: [(label: String, value: String)]) {
		self.heading = heading
		self.fields = fields
	}
}

enum PDFCell {
	case text(String)
	case groups([PDFFieldGroup])
	/// Thumbnail (or placeholder) plus caption, followed by stacked field groups. Used for
	/// the lead column of a record-comparison table.
	case imageWithGroups(Data?, caption: String, groups: [PDFFieldGroup])
}

// MARK: - Platform image decoding

/// Isolates the one place image decode/draw genuinely differs between ImageIO (macOS) and UIImage (iOS).
enum PDFImageDecoder {
	#if os(macOS)
	static func pixelSize(_ data: Data) -> CGSize? {
		guard let src = CGImageSourceCreateWithData(data as CFData, nil),
					let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
					let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
					let h = props[kCGImagePropertyPixelHeight] as? CGFloat,
					w > 0, h > 0 else { return nil }
		return CGSize(width: w, height: h)
	}

	@discardableResult
	static func draw(_ data: Data, in rect: CGRect) -> Bool {
		guard let src = CGImageSourceCreateWithData(data as CFData, nil),
					let cgImg = CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCache: true as CFBoolean] as CFDictionary),
					let gctx = NSGraphicsContext.current?.cgContext else { return false }
		gctx.interpolationQuality = .high
		gctx.draw(cgImg, in: rect)
		return true
	}
	#else
	static func pixelSize(_ data: Data) -> CGSize? {
		guard let img = UIImage(data: data), img.size.width > 0, img.size.height > 0 else { return nil }
		return img.size
	}

	@discardableResult
	static func draw(_ data: Data, in rect: CGRect) -> Bool {
		guard let img = UIImage(data: data) else { return false }
		img.draw(in: rect)
		return true
	}
	#endif
}

// MARK: - Platform path fill/stroke

/// Isolates the other genuine platform difference: NSBezierPath vs UIBezierPath.
enum PDFPath {
	#if os(macOS)
	static func fill(rect: CGRect, color: PlatformColor) {
		color.setFill()
		NSBezierPath(rect: rect).fill()
	}

	static func strokeLines(_ segments: [(CGPoint, CGPoint)], color: PlatformColor, lineWidth: CGFloat) {
		guard !segments.isEmpty else { return }
		color.setStroke()
		let path = NSBezierPath()
		path.lineWidth = lineWidth
		for (a, b) in segments {
			path.move(to: a)
			path.line(to: b)
		}
		path.stroke()
	}
	#else
	static func fill(rect: CGRect, color: PlatformColor) {
		color.setFill()
		UIBezierPath(rect: rect).fill()
	}

	static func strokeLines(_ segments: [(CGPoint, CGPoint)], color: PlatformColor, lineWidth: CGFloat) {
		guard !segments.isEmpty else { return }
		color.setStroke()
		let path = UIBezierPath()
		path.lineWidth = lineWidth
		for (a, b) in segments {
			path.move(to: a)
			path.addLine(to: b)
		}
		path.stroke()
	}
	#endif
}

// MARK: - Coordinate conversion

/// Converts top-left-origin layout rects into the active context's native space. macOS PDF
/// contexts are bottom-left origin; iOS's UIGraphicsPDFRenderer is already top-left, so this
/// is the identity there. All layout math in this file is written in top-left coordinates and
/// passed through here immediately before drawing.
struct PDFDrawingContext {
	let pageHeight: CGFloat

	func rect(_ topLeft: CGRect) -> CGRect {
		#if os(macOS)
		return CGRect(x: topLeft.origin.x,
		              y: pageHeight - topLeft.origin.y - topLeft.height,
		              width: topLeft.width,
		              height: topLeft.height)
		#else
		return topLeft
		#endif
	}

	func point(_ topLeft: CGPoint) -> CGPoint {
		#if os(macOS)
		return CGPoint(x: topLeft.x, y: pageHeight - topLeft.y)
		#else
		return topLeft
		#endif
	}
}

// MARK: - Renderer

enum PDFReportRenderer {

	// MARK: Text measurement/attribution helpers

	/// Pinning an explicit line height (rather than letting TextKit derive one from font
	/// metrics) keeps the measure pass (`boundingRect`) and the draw pass (`draw(in:)`) in
	/// agreement — without it, wrapped text measures a hair short and the last line's
	/// descenders get clipped against the row border.
	private static func paragraphStyle(alignment: NSTextAlignment, lineHeight: CGFloat) -> NSMutableParagraphStyle {
		let paragraph = NSMutableParagraphStyle()
		paragraph.alignment = alignment
		paragraph.lineBreakMode = .byWordWrapping
		paragraph.minimumLineHeight = lineHeight
		paragraph.maximumLineHeight = lineHeight
		return paragraph
	}

	private static func attributedText(_ text: String, font: PlatformFont, color: PDFColor, alignment: NSTextAlignment) -> NSAttributedString {
		let paragraph = paragraphStyle(alignment: alignment, lineHeight: ceil(font.pointSize * 1.25))
		return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color.platform, .paragraphStyle: paragraph])
	}

	private static func fieldLineAttributedString(label: String, value: String, style: PDFReportStyle) -> NSAttributedString {
		let labelFont = PlatformFont.systemFont(ofSize: style.fieldLabelSize)
		let valueFont = PlatformFont.systemFont(ofSize: style.bodySize)
		let paragraph = paragraphStyle(alignment: .left, lineHeight: ceil(max(labelFont.pointSize, valueFont.pointSize) * 1.25))
		let result = NSMutableAttributedString(string: "\(label): ", attributes: [.font: labelFont, .foregroundColor: PDFPalette.fieldLabel.platform, .paragraphStyle: paragraph])
		result.append(NSAttributedString(string: value, attributes: [.font: valueFont, .foregroundColor: PDFPalette.bodyText.platform, .paragraphStyle: paragraph]))
		return result
	}

	private static func groupHeadingAttributedString(_ text: String, style: PDFReportStyle) -> NSAttributedString {
		attributedText(text.uppercased(), font: .boldSystemFont(ofSize: style.groupHeadingSize), color: PDFPalette.groupHeading, alignment: .left)
	}

	private static func height(of text: NSAttributedString, width: CGFloat) -> CGFloat {
		guard width > 0 else { return 0 }
		let bounding = text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
		                                  options: [.usesLineFragmentOrigin, .usesFontLeading],
		                                  context: nil)
		// Small residual safety margin on top of the pinned line height above.
		return ceil(bounding.height) + 2
	}

	private static func drawText(_ text: NSAttributedString, in rectTopLeft: CGRect, ctx: PDFDrawingContext) {
		guard rectTopLeft.width > 0, rectTopLeft.height > 0 else { return }
		text.draw(in: ctx.rect(rectTopLeft))
	}

	// MARK: Stacked field-group lines (shared by measure and draw passes)

	private struct StackedLine {
		let text: NSAttributedString
		let topPadding: CGFloat
		let rule: Bool
	}

	private static func lines(for groups: [PDFFieldGroup], style: PDFReportStyle) -> [StackedLine] {
		var result: [StackedLine] = []
		for (groupIndex, group) in groups.enumerated() {
			if let heading = group.heading, !heading.isEmpty {
				result.append(StackedLine(text: groupHeadingAttributedString(heading, style: style),
				                           topPadding: groupIndex == 0 ? 0 : 5,
				                           rule: true))
			}
			for field in group.fields {
				result.append(StackedLine(text: fieldLineAttributedString(label: field.label, value: field.value, style: style),
				                           topPadding: style.fieldLineSpacing,
				                           rule: false))
			}
		}
		return result
	}

	private static func measureStackedLines(_ lines: [StackedLine], width: CGFloat) -> CGFloat {
		var total: CGFloat = 0
		for line in lines {
			total += line.topPadding
			total += height(of: line.text, width: width)
			if line.rule { total += 3 } // 1pt gap before the rule + 2pt after
		}
		return total
	}

	private static func drawStackedLines(_ lines: [StackedLine], in rectTopLeft: CGRect, ctx: PDFDrawingContext) {
		var y = rectTopLeft.origin.y
		for line in lines {
			y += line.topPadding
			let h = height(of: line.text, width: rectTopLeft.width)
			drawText(line.text, in: CGRect(x: rectTopLeft.origin.x, y: y, width: rectTopLeft.width, height: h), ctx: ctx)
			if line.rule {
				let ruleY = y + h + 1
				let a = ctx.point(CGPoint(x: rectTopLeft.origin.x, y: ruleY))
				let b = ctx.point(CGPoint(x: rectTopLeft.origin.x + rectTopLeft.width, y: ruleY))
				PDFPath.strokeLines([(a, b)], color: PDFPalette.accentRule.platform, lineWidth: 0.5)
				y = ruleY + 2
			} else {
				y += h
			}
		}
	}

	// MARK: Image + groups (lead column)

	private struct ImageGroupsLayout {
		let imageHeight: CGFloat
		let caption: NSAttributedString?
		let captionHeight: CGFloat
		let groupLines: [StackedLine]
		let groupsHeight: CGFloat
		let totalHeight: CGFloat
	}

	private static func layoutImageWithGroups(data: Data?, caption: String, groups: [PDFFieldGroup], width: CGFloat, style: PDFReportStyle) -> ImageGroupsLayout {
		// No image data means no thumbnail and no placeholder box — the row just skips
		// straight to the caption/groups instead of reserving blank space for a "No Image" box.
		var imageHeight: CGFloat = 0
		if let data, let size = PDFImageDecoder.pixelSize(data), size.width > 0, size.height > 0 {
			let scale = min(width / size.width, style.thumbnailMaxHeight / size.height)
			imageHeight = max(0, min(style.thumbnailMaxHeight, size.height * scale))
		}

		var captionAttr: NSAttributedString?
		var captionHeight: CGFloat = 0
		let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
		if !trimmedCaption.isEmpty {
			let attr = attributedText(trimmedCaption, font: .systemFont(ofSize: style.fieldLabelSize), color: PDFPalette.mutedText, alignment: .center)
			captionAttr = attr
			captionHeight = height(of: attr, width: width)
		}

		let groupLines = lines(for: groups, style: style)
		let groupsHeight = measureStackedLines(groupLines, width: width)

		var total = imageHeight
		if captionAttr != nil { total += 3 + captionHeight }
		if !groupLines.isEmpty { total += 5 + groupsHeight }

		return ImageGroupsLayout(imageHeight: imageHeight, caption: captionAttr, captionHeight: captionHeight,
		                          groupLines: groupLines, groupsHeight: groupsHeight, totalHeight: total)
	}

	private static func drawImageWithGroups(data: Data?, caption: String, groups: [PDFFieldGroup], in rectTopLeft: CGRect, ctx: PDFDrawingContext, style: PDFReportStyle) {
		let layout = layoutImageWithGroups(data: data, caption: caption, groups: groups, width: rectTopLeft.width, style: style)
		var y = rectTopLeft.origin.y

		if let data, let size = PDFImageDecoder.pixelSize(data), size.width > 0, size.height > 0 {
			let scale = min(rectTopLeft.width / size.width, style.thumbnailMaxHeight / size.height)
			let drawW = size.width * scale
			let imageRect = CGRect(x: rectTopLeft.origin.x + (rectTopLeft.width - drawW) / 2, y: y, width: drawW, height: layout.imageHeight)
			PDFImageDecoder.draw(data, in: ctx.rect(imageRect))
		}
		// No image data: skip the placeholder entirely — layout.imageHeight is already 0 so
		// no blank space is reserved for it.
		y += layout.imageHeight

		if let captionAttr = layout.caption {
			y += 3
			drawText(captionAttr, in: CGRect(x: rectTopLeft.origin.x, y: y, width: rectTopLeft.width, height: layout.captionHeight), ctx: ctx)
			y += layout.captionHeight
		}

		if !layout.groupLines.isEmpty {
			y += 5
			drawStackedLines(layout.groupLines, in: CGRect(x: rectTopLeft.origin.x, y: y, width: rectTopLeft.width, height: layout.groupsHeight), ctx: ctx)
		}
	}

	// MARK: Rows

	private static func measureRow(_ cells: [PDFCell], columnWidths: [CGFloat], columns: [PDFTableColumn], style: PDFReportStyle) -> CGFloat {
		var maxHeight: CGFloat = style.minRowHeight
		for (index, cell) in cells.enumerated() {
			let width = columnWidths[min(index, columnWidths.count - 1)]
			let innerWidth = width - style.cellInsetH * 2
			let contentHeight: CGFloat
			switch cell {
				case .text(let string):
					let alignment = columns[min(index, columns.count - 1)].alignment
					contentHeight = height(of: attributedText(string, font: .systemFont(ofSize: style.bodySize), color: PDFPalette.bodyText, alignment: alignment), width: innerWidth)
				case .groups(let groups):
					contentHeight = measureStackedLines(lines(for: groups, style: style), width: innerWidth)
				case .imageWithGroups(let data, let caption, let groups):
					contentHeight = layoutImageWithGroups(data: data, caption: caption, groups: groups, width: innerWidth, style: style).totalHeight
			}
			maxHeight = max(maxHeight, contentHeight + style.cellInsetV * 2)
		}
		return maxHeight
	}

	private static func drawRow(_ cells: [PDFCell], columns: [PDFTableColumn], columnWidths: [CGFloat], origin: CGPoint, rowHeight: CGFloat, rowIndex: Int, ctx: PDFDrawingContext, style: PDFReportStyle) {
		let totalWidth = columnWidths.reduce(0, +)
		if rowIndex % 2 == 1 {
			PDFPath.fill(rect: ctx.rect(CGRect(x: origin.x, y: origin.y, width: totalWidth, height: rowHeight)), color: PDFPalette.rowAltFill.platform)
		}

		var x = origin.x
		for (index, cell) in cells.enumerated() {
			let width = columnWidths[min(index, columnWidths.count - 1)]
			let innerRect = CGRect(x: x, y: origin.y, width: width, height: rowHeight).insetBy(dx: style.cellInsetH, dy: style.cellInsetV)
			switch cell {
				case .text(let string):
					let alignment = columns[min(index, columns.count - 1)].alignment
					drawText(attributedText(string, font: .systemFont(ofSize: style.bodySize), color: PDFPalette.bodyText, alignment: alignment), in: innerRect, ctx: ctx)
				case .groups(let groups):
					drawStackedLines(lines(for: groups, style: style), in: innerRect, ctx: ctx)
				case .imageWithGroups(let data, let caption, let groups):
					drawImageWithGroups(data: data, caption: caption, groups: groups, in: innerRect, ctx: ctx, style: style)
			}
			x += width
		}

		var segments: [(CGPoint, CGPoint)] = []
		var runningX = origin.x
		segments.append((CGPoint(x: runningX, y: origin.y), CGPoint(x: runningX, y: origin.y + rowHeight)))
		for width in columnWidths {
			runningX += width
			segments.append((CGPoint(x: runningX, y: origin.y), CGPoint(x: runningX, y: origin.y + rowHeight)))
		}
		segments.append((CGPoint(x: origin.x, y: origin.y + rowHeight), CGPoint(x: origin.x + totalWidth, y: origin.y + rowHeight)))
		PDFPath.strokeLines(segments.map { (ctx.point($0.0), ctx.point($0.1)) }, color: PDFPalette.grid.platform, lineWidth: style.gridLineWidth)
	}

	// MARK: Column headers

	private static func measureColumnHeaders(columns: [PDFTableColumn], columnWidths: [CGFloat], style: PDFReportStyle) -> CGFloat {
		var maxHeight: CGFloat = 0
		for (index, column) in columns.enumerated() {
			let width = columnWidths[index] - style.cellInsetH * 2
			let attr = attributedText(column.title, font: .boldSystemFont(ofSize: style.columnHeaderSize), color: PDFPalette.headerText, alignment: .center)
			maxHeight = max(maxHeight, height(of: attr, width: width))
		}
		return max(maxHeight + style.cellInsetV, style.columnHeaderMinHeight)
	}

	private static func drawColumnHeaders(columns: [PDFTableColumn], columnWidths: [CGFloat], origin: CGPoint, rowHeight: CGFloat, ctx: PDFDrawingContext, style: PDFReportStyle) {
		let totalWidth = columnWidths.reduce(0, +)
		PDFPath.fill(rect: ctx.rect(CGRect(x: origin.x, y: origin.y, width: totalWidth, height: rowHeight)), color: PDFPalette.headerFill.platform)

		var x = origin.x
		for (index, column) in columns.enumerated() {
			let width = columnWidths[index]
			let cellRect = CGRect(x: x, y: origin.y, width: width, height: rowHeight).insetBy(dx: style.cellInsetH, dy: style.cellInsetV / 2)
			drawText(attributedText(column.title, font: .boldSystemFont(ofSize: style.columnHeaderSize), color: PDFPalette.headerText, alignment: .center), in: cellRect, ctx: ctx)
			x += width
		}

		var segments: [(CGPoint, CGPoint)] = []
		var runningX = origin.x
		segments.append((CGPoint(x: runningX, y: origin.y), CGPoint(x: runningX, y: origin.y + rowHeight)))
		for width in columnWidths {
			runningX += width
			segments.append((CGPoint(x: runningX, y: origin.y), CGPoint(x: runningX, y: origin.y + rowHeight)))
		}
		segments.append((CGPoint(x: origin.x, y: origin.y + rowHeight), CGPoint(x: origin.x + totalWidth, y: origin.y + rowHeight)))
		PDFPath.strokeLines(segments.map { (ctx.point($0.0), ctx.point($0.1)) }, color: PDFPalette.border.platform, lineWidth: style.borderLineWidth)
	}

	// MARK: Page header/footer

	private static func drawPageHeader(title: String, subtitle: String, pageNumber: Int, totalPages: Int, ctx: PDFDrawingContext, style: PDFReportStyle) {
		let margin = style.margin
		let width = style.pageSize.width - 2 * margin

		drawText(attributedText(title, font: .boldSystemFont(ofSize: style.titleSize), color: PDFPalette.titleText, alignment: .left),
		         in: CGRect(x: margin, y: margin, width: width * 0.7, height: style.headerHeight * 0.55), ctx: ctx)

		drawText(attributedText(subtitle, font: .systemFont(ofSize: style.subtitleSize), color: PDFPalette.subtitleText, alignment: .left),
		         in: CGRect(x: margin, y: margin + style.headerHeight * 0.55, width: width * 0.7, height: style.headerHeight * 0.4), ctx: ctx)

		drawText(attributedText("Page \(pageNumber) of \(totalPages)", font: .systemFont(ofSize: style.subtitleSize), color: PDFPalette.mutedText, alignment: .right),
		         in: CGRect(x: margin, y: margin, width: width, height: style.headerHeight * 0.55), ctx: ctx)

		let ruleY = margin + style.headerHeight - 2
		let a = ctx.point(CGPoint(x: margin, y: ruleY))
		let b = ctx.point(CGPoint(x: margin + width, y: ruleY))
		PDFPath.strokeLines([(a, b)], color: PDFPalette.accentRule.platform, lineWidth: 1.2)
	}

	/// Height of the wrapped disclaimer line, or 0 when there's no note — used both to reserve
	/// space above the standard footer during pagination and to draw it in that same space.
	private static func footerNoteHeight(_ footerNote: String?, width: CGFloat, style: PDFReportStyle) -> CGFloat {
		guard let footerNote, !footerNote.isEmpty else { return 0 }
		let attr = attributedText(footerNote, font: platformItalicSystemFont(ofSize: style.footerNoteSize), color: PDFPalette.mutedText, alignment: .center)
		return height(of: attr, width: width) + 4
	}

	private static func drawPageFooter(pageNumber: Int, totalPages: Int, footerNote: String?, ctx: PDFDrawingContext, style: PDFReportStyle) {
		let margin = style.margin
		let width = style.pageSize.width - 2 * margin
		let y = style.pageSize.height - margin - style.footerHeight

		if let footerNote, !footerNote.isEmpty {
			let noteHeight = footerNoteHeight(footerNote, width: width, style: style) - 4
			drawText(attributedText(footerNote, font: platformItalicSystemFont(ofSize: style.footerNoteSize), color: PDFPalette.mutedText, alignment: .center),
			         in: CGRect(x: margin, y: y - noteHeight - 4, width: width, height: noteHeight), ctx: ctx)
		}

		drawText(attributedText("\(AppInfo.displayName) • \(VersionStrings.fullVersionStringWithAppName)", font: .systemFont(ofSize: style.footerSize), color: PDFPalette.footerText, alignment: .left),
		         in: CGRect(x: margin, y: y, width: width * 0.7, height: style.footerHeight), ctx: ctx)

		drawText(attributedText("Page \(pageNumber) of \(totalPages)", font: .systemFont(ofSize: style.footerSize), color: PDFPalette.footerText, alignment: .right),
		         in: CGRect(x: margin, y: y, width: width, height: style.footerHeight), ctx: ctx)
	}

	// MARK: Summary block
	//
	// Reuses the same stacked-field-group rendering built for table cells (`lines`/
	// `measureStackedLines`/`drawStackedLines`): each group's heading (e.g. a vehicle name, or
	// "ALL VEHICLES" for the grand total) gets the same bold/accent-ruled treatment a table
	// cell's group heading gets, so per-vehicle breakdowns and the trailing total both read
	// clearly without inventing separate styling.

	/// Total block height including its own border/padding. Independent of pagination — callers
	/// decide whether it fits on the current page or needs one of its own.
	private static func measureSummary(_ summary: PDFReportSummary, width: CGFloat, style: PDFReportStyle) -> CGFloat {
		let titleH = style.titleSize + 10
		let innerWidth = width - 24
		let contentH = measureStackedLines(lines(for: summary.groups, style: style), width: innerWidth)
		return titleH + contentH + 16 // top+bottom padding inside the border box
	}

	private static func drawSummary(_ summary: PDFReportSummary, origin: CGPoint, width: CGFloat, ctx: PDFDrawingContext, style: PDFReportStyle) {
		let height = measureSummary(summary, width: width, style: style)
		let boxRect = CGRect(x: origin.x, y: origin.y, width: width, height: height)
		let corners = [boxRect.origin,
		               CGPoint(x: boxRect.maxX, y: boxRect.minY),
		               CGPoint(x: boxRect.maxX, y: boxRect.maxY),
		               CGPoint(x: boxRect.minX, y: boxRect.maxY)]
		let borderSegments = (0..<4).map { (ctx.point(corners[$0]), ctx.point(corners[($0 + 1) % 4])) }
		PDFPath.strokeLines(borderSegments, color: PDFPalette.border.platform, lineWidth: style.borderLineWidth)

		let innerX = origin.x + 12
		let innerWidth = width - 24
		var y = origin.y + 8

		drawText(attributedText(summary.title, font: .boldSystemFont(ofSize: style.titleSize - 3), color: PDFPalette.titleText, alignment: .left),
		         in: CGRect(x: innerX, y: y, width: innerWidth, height: style.titleSize + 2), ctx: ctx)
		y += style.titleSize + 8

		let contentLines = lines(for: summary.groups, style: style)
		let contentHeight = measureStackedLines(contentLines, width: innerWidth)
		drawStackedLines(contentLines, in: CGRect(x: innerX, y: y, width: innerWidth, height: contentHeight), ctx: ctx)
	}

	// MARK: Page assembly (shared by both platform backends)

	/// One physical page's worth of drawing instructions, decided up front during pagination.
	private struct PageContent {
		var rowIndices: [Int]
		var showColumnHeaders: Bool
		var summaryStartY: CGFloat? // set when the summary block should be drawn on this page
	}

	private static func drawPageContent(title: String, subtitle: String, pageNumber: Int, totalPages: Int,
	                                     columns: [PDFTableColumn], columnWidths: [CGFloat], columnHeaderHeight: CGFloat,
	                                     page: PageContent, rows: [[PDFCell]], rowHeights: [CGFloat],
	                                     top: CGFloat, summary: PDFReportSummary?, footerNote: String?, ctx: PDFDrawingContext, style: PDFReportStyle) {
		drawPageHeader(title: title, subtitle: subtitle, pageNumber: pageNumber, totalPages: totalPages, ctx: ctx, style: style)
		drawPageFooter(pageNumber: pageNumber, totalPages: totalPages, footerNote: footerNote, ctx: ctx, style: style)

		var y = top
		if page.showColumnHeaders {
			drawColumnHeaders(columns: columns, columnWidths: columnWidths, origin: CGPoint(x: style.margin, y: y), rowHeight: columnHeaderHeight, ctx: ctx, style: style)
			y += columnHeaderHeight
		}

		for index in page.rowIndices {
			let h = rowHeights[index]
			drawRow(rows[index], columns: columns, columnWidths: columnWidths, origin: CGPoint(x: style.margin, y: y), rowHeight: h, rowIndex: index, ctx: ctx, style: style)
			y += h
		}

		if let summary, let summaryY = page.summaryStartY {
			let contentWidth = style.pageSize.width - 2 * style.margin
			drawSummary(summary, origin: CGPoint(x: style.margin, y: summaryY), width: contentWidth, ctx: ctx, style: style)
		}
	}

	#if os(macOS)
	private static func renderPages(title: String, subtitle: String, columns: [PDFTableColumn], columnWidths: [CGFloat],
	                                 columnHeaderHeight: CGFloat, rows: [[PDFCell]], rowHeights: [CGFloat],
	                                 pages: [PageContent], top: CGFloat, summary: PDFReportSummary?, footerNote: String?, style: PDFReportStyle) -> Data? {
		let data = NSMutableData()
		var mediaBox = CGRect(origin: .zero, size: style.pageSize)
		guard let consumer = CGDataConsumer(data: data as CFMutableData),
		      let cgContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

		let ctx = PDFDrawingContext(pageHeight: style.pageSize.height)
		let totalPages = pages.count

		for (pageIndex, page) in pages.enumerated() {
			cgContext.beginPDFPage(nil)
			NSGraphicsContext.saveGraphicsState()
			NSGraphicsContext.current = NSGraphicsContext(cgContext: cgContext, flipped: false)

			drawPageContent(title: title, subtitle: subtitle, pageNumber: pageIndex + 1, totalPages: totalPages,
			                 columns: columns, columnWidths: columnWidths, columnHeaderHeight: columnHeaderHeight,
			                 page: page, rows: rows, rowHeights: rowHeights, top: top, summary: summary, footerNote: footerNote, ctx: ctx, style: style)

			NSGraphicsContext.restoreGraphicsState()
			cgContext.endPDFPage()
		}
		cgContext.closePDF()
		return data as Data
	}
	#else
	private static func renderPages(title: String, subtitle: String, columns: [PDFTableColumn], columnWidths: [CGFloat],
	                                 columnHeaderHeight: CGFloat, rows: [[PDFCell]], rowHeights: [CGFloat],
	                                 pages: [PageContent], top: CGFloat, summary: PDFReportSummary?, footerNote: String?, style: PDFReportStyle) -> Data? {
		let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: style.pageSize))
		let ctx = PDFDrawingContext(pageHeight: style.pageSize.height)
		let totalPages = pages.count
		return renderer.pdfData { rendererContext in
			for (pageIndex, page) in pages.enumerated() {
				rendererContext.beginPage()
				drawPageContent(title: title, subtitle: subtitle, pageNumber: pageIndex + 1, totalPages: totalPages,
				                 columns: columns, columnWidths: columnWidths, columnHeaderHeight: columnHeaderHeight,
				                 page: page, rows: rows, rowHeights: rowHeights, top: top, summary: summary, footerNote: footerNote, ctx: ctx, style: style)
			}
		}
	}
	#endif

	// MARK: Public entry point

	/// Measures every row, paginates, and draws the full report. Returns raw PDF data, or
	/// `nil` if the underlying graphics context could not be created.
	/// - Parameter summary: An optional totals block drawn after the last row — appended to the
	///   final page if it fits in the remaining space, otherwise given a page of its own. Pass
	///   `nil` (the default) for reports with nothing to total.
	/// - Parameter footerNote: An optional small italic line drawn above the standard footer on
	///   every page — e.g. a regulatory disclaimer for AeroTrax/NauticalTrax reports. `nil` (the
	///   default) reproduces every existing report's footer exactly as before this parameter existed.
	static func render(title: String, subtitle: String, columns: [PDFTableColumn], rows: [[PDFCell]], summary: PDFReportSummary? = nil, footerNote: String? = nil, style: PDFReportStyle = .standard) -> Data? {
		let contentWidth = style.pageSize.width - 2 * style.margin
		let columnWidths = columns.map { max(0, $0.weight * contentWidth) }

		let columnHeaderHeight = measureColumnHeaders(columns: columns, columnWidths: columnWidths, style: style)
		let rowHeights = rows.map { measureRow($0, columnWidths: columnWidths, columns: columns, style: style) }

		let noteHeight = footerNoteHeight(footerNote, width: contentWidth, style: style)
		let top = style.margin + style.headerHeight
		let bottom = style.pageSize.height - style.margin - style.footerHeight - noteHeight
		let availableHeight = bottom - top - columnHeaderHeight

		var pages: [PageContent] = []
		var current: [Int] = []
		var currentHeight: CGFloat = 0
		for (index, rowHeight) in rowHeights.enumerated() {
			if !current.isEmpty && currentHeight + rowHeight > availableHeight {
				pages.append(PageContent(rowIndices: current, showColumnHeaders: true, summaryStartY: nil))
				current = []
				currentHeight = 0
			}
			current.append(index)
			currentHeight += rowHeight
		}
		pages.append(PageContent(rowIndices: current, showColumnHeaders: true, summaryStartY: nil)) // always at least one page, even with zero rows

		if let summary, !summary.groups.isEmpty {
			let summaryHeight = measureSummary(summary, width: contentWidth, style: style)
			let summaryGap: CGFloat = 12
			let lastPageContentHeight = pages[pages.count - 1].rowIndices.reduce(0) { $0 + rowHeights[$1] }
			let remainingOnLastPage = availableHeight - lastPageContentHeight
			if remainingOnLastPage >= summaryHeight + summaryGap {
				pages[pages.count - 1].summaryStartY = top + columnHeaderHeight + lastPageContentHeight + summaryGap
			} else {
				// Doesn't fit — give the summary a page of its own, with no repeated column headers.
				let summaryOnlyTop = style.margin + style.headerHeight
				pages.append(PageContent(rowIndices: [], showColumnHeaders: false, summaryStartY: summaryOnlyTop))
			}
		}

		return renderPages(title: title, subtitle: subtitle, columns: columns, columnWidths: columnWidths,
		                    columnHeaderHeight: columnHeaderHeight, rows: rows, rowHeights: rowHeights,
		                    pages: pages, top: top, summary: summary, footerNote: footerNote, style: style)
	}
}

// MARK: - Report summary model

/// A small totals block a report can append after its last row — e.g. Fuel Log's total fuel
/// added, total cost, total DEF cost. Reuses `PDFFieldGroup` (the same type table cells use for
/// "Label: value" groups) so a group's heading gets the same bold/accent-ruled treatment.
///
/// Each report builds its own summary from the same records it already fetched for its table —
/// there is no cross-report/cross-category aggregation.
///
/// When the report's scope is a single vehicle, `groups` is typically one unheaded group with
/// that vehicle's own totals. When scope is "All Vehicles", `groups` should be one heading-per-
/// vehicle group per vehicle (heading = vehicle display name) followed by a final group headed
/// "ALL VEHICLES" (or similar) with the same fields summed across every vehicle — the per-vehicle
/// breakdown the totals are drawn from, not just the grand total alone.
struct PDFReportSummary {
	var title: String = "REPORT SUMMARY"
	var groups: [PDFFieldGroup]
}

/// Builds `PDFReportSummary.groups` for a vehicle-scoped report: one group per vehicle (heading
/// = vehicle display name, sorted alphabetically) plus a trailing "ALL VEHICLES" group with the
/// same fields summed across every vehicle, when `scope` is "All Vehicles" (or empty) — or a
/// single unheaded group with just this scope's own totals otherwise. `metrics` computes the
/// same fields for any subset of records, so the per-vehicle breakdown and the grand total are
/// always shaped identically. Shared by every vehicle-scoped report so this logic isn't
/// duplicated in each one.
///
/// `metrics` returns `nil` for a field to drop it — e.g. a non-diesel vehicle's DEF total is 0,
/// so that vehicle's group simply omits the DEF fields rather than showing "$0.00". A group that
/// ends up with zero fields (every metric was 0/nil for that vehicle) is dropped entirely.
func pdfVehicleScopedSummaryGroups<T>(scope: String, records: [T], vehicleId: (T) -> String,
                                       context: ModelContext, metrics: ([T]) -> [(label: String, value: String?)]) -> [PDFFieldGroup] {
	func resolvedFields(_ subset: [T]) -> [(label: String, value: String)] {
		metrics(subset).compactMap { label, value in
			guard let value else { return nil }
			return (label, value)
		}
	}
	guard scope == "All Vehicles" || scope.isEmpty else {
		let fields = resolvedFields(records)
		return fields.isEmpty ? [] : [PDFFieldGroup(fields: fields)]
	}
	let grouped = Dictionary(grouping: records, by: vehicleId)
	let functions = Functions()
	let perVehicle = grouped.compactMap { vid, recs -> (name: String, group: PDFFieldGroup)? in
		let fields = resolvedFields(recs)
		guard !fields.isEmpty else { return nil }
		let name = vid.isEmpty ? "Unassigned" : functions.getVehicleDisplayName(vehicleId: vid, context: context)
		return (name, PDFFieldGroup(heading: name, fields: fields))
	}.sorted { $0.name < $1.name }.map(\.group)
	let totalFields = resolvedFields(records)
	guard !totalFields.isEmpty else { return perVehicle }
	return perVehicle + [PDFFieldGroup(heading: FleetScope.allDisplayLabel.uppercased(), fields: totalFields)]
}

/// Formats a Float as US currency, matching `Functions.formatCurrency(dollars:)`. Kept here (not
/// just in `Functions`) so report files building a `PDFReportSummary` don't need a `Functions`
/// instance just for this.
func pdfCurrencyString(_ value: Float) -> String {
	let formatter = NumberFormatter()
	formatter.numberStyle = .currency
	formatter.locale = Locale(identifier: "en_US")
	return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
}

// MARK: - Shared PDFKit presentation

/// Zoom intents forwarded to the underlying PDFKit view.
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
		// The SwiftUI view identity doesn't change between regenerations (same `if let doc =
		// pdfDocument` branch), so this — not makeNSView — is where a newly generated document
		// must be swapped in.
		if nsView.document !== pdfDocument {
			nsView.document = pdfDocument
			nsView.autoScales = true
		}
		guard let action = zoomAction else { return }
		switch action {
			case .zoomIn: nsView.zoomIn(nil)
			case .zoomOut: nsView.zoomOut(nil)
			case .fit: nsView.autoScales = true
			case .actual:
				nsView.autoScales = false
				nsView.scaleFactor = 1.0
		}
		DispatchQueue.main.async { self.zoomAction = nil }
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
		// The SwiftUI view identity doesn't change between regenerations (same `if let doc =
		// pdfDocument` branch), so this — not makeUIView — is where a newly generated document
		// must be swapped in.
		if uiView.document !== pdfDocument {
			uiView.document = pdfDocument
			uiView.autoScales = true
			uiView.minScaleFactor = uiView.scaleFactorForSizeToFit
			uiView.scaleFactor = uiView.minScaleFactor
		}
		guard let action = zoomAction else { return }
		switch action {
			case .zoomIn:
				uiView.autoScales = false
				uiView.scaleFactor = min(uiView.scaleFactor * 1.1, uiView.maxScaleFactor)
			case .zoomOut:
				uiView.autoScales = false
				uiView.scaleFactor = max(uiView.scaleFactor / 1.1, uiView.minScaleFactor)
			case .fit:
				uiView.autoScales = true
				uiView.minScaleFactor = uiView.scaleFactorForSizeToFit
				uiView.scaleFactor = uiView.minScaleFactor
			case .actual:
				uiView.autoScales = false
				uiView.scaleFactor = 1.0
		}
		DispatchQueue.main.async { self.zoomAction = nil }
	}
}
#endif

// MARK: - Shared vehicle scope picker

/// A toolbar control letting a report scope itself to "All Vehicles" or one specific vehicle.
/// Every report's `scope`/`trackVehicleSelected` state should be driven by this instead of a
/// one-off Menu, so vehicle filtering looks and behaves identically everywhere.
///
/// This only mutates `scope` — the report is still responsible for reacting to it (typically
/// via `.onChange(of: scope) { regenerate() }`), since only the report knows how to re-fetch
/// its own record type.
struct VehicleScopePicker: View {
	@Binding var scope: String
	@Environment(\.modelContext) private var modelContext
	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false

	var body: some View {
		Menu {
			Button(FleetScope.allDisplayLabel) { scope = FleetScope.allSentinel }
			ForEach(pickerVehicles, id: \.name) { vehicle in
				Button(vehicle.displayName.isEmpty ? vehicle.name : vehicle.displayName) {
					scope = vehicle.name
				}
			}
		} label: {
			Label(currentLabel, systemImage: Vertical.current.assetIcon)
		}
		.accessibilityLabel("\(Vertical.current.assetSingular) Filter")
	}

	/// Mirrors ChooseVehicle's own filtering, but always offers whatever vehicle is currently
	/// selected even if it's since been deactivated — switching away from an inactive vehicle
	/// shouldn't require re-enabling "Show Inactive" first.
	private var pickerVehicles: [Vehicle8] {
		allVehicles.filter { showInactiveVehicles || !$0.inactive || $0.name == scope }
	}

	private var allVehicles: [Vehicle8] {
		let descriptor = FetchDescriptor<Vehicle8>(sortBy: [SortDescriptor(\.sortOrder, order: .forward)])
		return (try? modelContext.fetch(descriptor)) ?? []
	}

	private var currentLabel: String {
		guard !FleetScope.isAll(scope) else { return FleetScope.allDisplayLabel }
		let selected = scope
		let descriptor = FetchDescriptor<Vehicle8>(predicate: #Predicate<Vehicle8> { $0.name == selected })
		guard let vehicle = try? modelContext.fetch(descriptor).first else { return scope }
		return vehicle.displayName.isEmpty ? vehicle.name : vehicle.displayName
	}
}

// MARK: - Shared file save / print

enum PDFReportFile {
	/// Saves the given PDF data into the app's Documents directory using the provided file name.
	/// Not user-initiated — called from every `generateAndShowPDF()` purely to drop a copy
	/// alongside viewing, so the trial gate here is silent (no paywall) rather than interactive.
	@discardableResult
	static func save(data: Data, fileName: String) -> URL? {
		guard Entitlement.cachedIsFullVersion else { return nil }
		guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
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

	/// Presents the platform print UI for the given PDF document.
	@MainActor
	static func printDocument(_ document: PDFDocument, jobName: String) {
		guard EntitlementStore.shared.requestExport(.pdfPrint) else { return }
		#if os(macOS)
		let printInfo = NSPrintInfo.shared
		printInfo.horizontalPagination = .automatic
		printInfo.verticalPagination = .automatic
		printInfo.isHorizontallyCentered = true
		printInfo.isVerticallyCentered = true

		if let op = document.printOperation(for: printInfo, scalingMode: .pageScaleDownToFit, autoRotate: true) {
			op.showsPrintPanel = true
			op.showsProgressPanel = true
			op.runModal(for: NSApp.keyWindow ?? NSWindow(), delegate: nil, didRun: nil, contextInfo: nil)
		}
		#else
		guard UIPrintInteractionController.isPrintingAvailable,
		      let data = document.dataRepresentation() else { return }
		let printInfo = UIPrintInfo(dictionary: nil)
		printInfo.jobName = jobName
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
