//
//  CSVExportStyle.swift
//  LandShip
//
//  Shared CSV export engine, parallel to PDFReportStyle.swift's shared PDF engine. Every
//  report screen that has a "Report" (PDF) button gets a matching "Export CSV" button built
//  on this — full-fidelity export (every field of the model, plus resolved linked display
//  names such as a vehicle's name from its vehicleId) rather than the PDF's curated/grouped
//  subset, since a spreadsheet export is for raw analysis, not a printed page.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - RFC 4180-safe row building

enum CSVBuilder {
	/// Quotes a field if it contains a comma, quote, or newline, doubling any embedded quotes.
	static func escape(_ field: String) -> String {
		if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
			return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
		}
		return field
	}

	static func row(_ fields: [String]) -> String {
		fields.map(escape).joined(separator: ",")
	}

	/// Builds a full CSV string (header row + data rows), CRLF-terminated per RFC 4180.
	static func build(headers: [String], rows: [[String]]) -> String {
		var lines = [row(headers)]
		lines.append(contentsOf: rows.map(row))
		return lines.joined(separator: "\r\n") + "\r\n"
	}
}

// MARK: - Shared field formatters
//
// Kept here (not just in Functions) so CSV-building code in report files doesn't need a
// Functions instance just for these — mirrors pdfCurrencyString's placement in PDFReportStyle.

enum CSVField {
	static func date(_ date: Date) -> String {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH:mm"
		return formatter.string(from: date)
	}

	static func bool(_ value: Bool) -> String {
		value ? "Yes" : "No"
	}

	static func float(_ value: Float) -> String {
		value == 0 ? "" : String(value)
	}

	static func int(_ value: Int) -> String {
		value == 0 ? "" : String(value)
	}
}

// MARK: - .fileExporter document type

/// A minimal plain-text FileDocument so any report screen can export CSV via `.fileExporter`
/// without redeclaring this conformance itself.
struct CSVDocument: FileDocument {
	static var readableContentTypes: [UTType] { [.commaSeparatedText] }
	static var writableContentTypes: [UTType] { [.commaSeparatedText] }

	var text: String

	init(text: String) {
		self.text = text
	}

	init(configuration: ReadConfiguration) throws {
		if let data = configuration.file.regularFileContents {
			text = String(data: data, encoding: .utf8) ?? ""
		} else {
			text = ""
		}
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		FileWrapper(regularFileWithContents: Data(text.utf8))
	}
}
