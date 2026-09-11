//
//  26 RecordAttachment.swift
//  LandShip
//
//  A document attachment (8130-3, EASA Form 1, invoice, ICA excerpt, scanned logbook
//  page) polymorphically owned by any record type via ownerType/ownerKey rather than a
//  Data?+filename+type triple duplicated per model. ownerKey is that owner's existing
//  name-link value (MxParts1.partName, AirworthinessDirective.adNumber, etc.) — not a
//  new identity scheme. Used by parts, installations, directives, service records and
//  inspections; not feature-gated, since all three verticals want document storage.
//
//  payload bypasses the image-resize pipeline in Custom Views/5 Image Mods.swift entirely
//  (that path re-encodes to JPEG at 0.6 quality, which would destroy a scanned PDF).
//  fileByteCount is stored redundantly so list rows can show size without faulting the
//  externally-stored payload into memory.
//

import Foundation
import SwiftData

@Model
class RecordAttachment {
	var inactive: Bool = false
	var ownerType: String = ""       // "MxParts1", "PartInstallation", "AirworthinessDirective", …
	var ownerKey: String = ""        // the owner's name-link value
	var fileName: String = ""
	var contentTypeIdentifier: String = ""   // UTType identifier, e.g. "com.adobe.pdf"
	var attachmentKind: String = ""          // Release Document, Invoice, ICA, … (free-text/picker)
	var fileByteCount: Int = 0
	var documentDate: Date = Date()
	var notes: String = ""
	@Attribute(.externalStorage)
	var payload: Data?
	var createdAt: Date = Date()
	var updatedAt: Date = Date()

	init(
		ownerType: String = "",
		ownerKey: String = "",
		fileName: String = "",
		contentTypeIdentifier: String = "",
		attachmentKind: String = "",
		fileByteCount: Int = 0,
		documentDate: Date = Date(),
		notes: String = "",
		payload: Data? = nil,
		createdAt: Date = Date(),
		updatedAt: Date = Date()
	) {
		self.ownerType = ownerType
		self.ownerKey = ownerKey
		self.fileName = fileName
		self.contentTypeIdentifier = contentTypeIdentifier
		self.attachmentKind = attachmentKind
		self.fileByteCount = fileByteCount
		self.documentDate = documentDate
		self.notes = notes
		self.payload = payload
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}
}
