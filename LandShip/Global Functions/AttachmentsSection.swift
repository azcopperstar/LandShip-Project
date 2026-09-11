//
//  AttachmentsSection.swift
//  LandShip
//
//  A reusable "Attachments" card for any owner record, backed by RecordAttachment's
//  polymorphic ownerType/ownerKey (Models/26) rather than a Data?+filename+type triple
//  duplicated per model. Not feature-gated — all three verticals want document storage,
//  it's just most useful for AeroTrax's 8130-3/invoice/ICA paperwork.
//
//  Deliberately bypasses the image-resize pipeline in Custom Views/5 Image Mods.swift —
//  that path re-encodes to JPEG at 0.6 quality, which would destroy a scanned PDF.
//

import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers

/// Client-side ceiling enforced at the picker. `.externalStorage` mirrors to a CKAsset,
/// bounded by the container's asset quota rather than the ~1 MB per-record field cap — the
/// app already relies on this for every image — but a 200 MB scanned POH is still a bad
/// idea to sync on cellular. An 8130-3 scan is well under 1 MB.
let attachmentMaxByteCount = 25 * 1024 * 1024

private func formattedByteCount(_ count: Int) -> String {
	ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
}

/// Drop into any editor as `AttachmentsSection(ownerType: "MxParts1", ownerKey: dataSet.partName)`.
/// `ownerKey` is that owner's existing name-link value, not a new identity scheme.
struct AttachmentsSection: View {
	let ownerType: String
	let ownerKey: String

	@Environment(\.modelContext) private var modelContext
	@Environment(\.entitlements) private var entitlements

	@State private var attachments: [RecordAttachment] = []
	@State private var isImporting = false
	@State private var viewingAttachment: RecordAttachment?
	@State private var oversizeMessage: String?
	@State private var importErrorMessage: String?

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				SectionText(label: "ATTACHMENTS")
				Spacer()
				Button {
					guard entitlements.requestCreate(RecordAttachment.self, in: modelContext) else { return }
					isImporting = true
				} label: {
					Image(systemName: "plus.capsule")
				}
			}
			if attachments.isEmpty {
				Text("No attachments. Add the release document, invoice, or a photo of the data plate.")
					.font(.subheadline)
					.foregroundStyle(.secondary)
			} else {
				ForEach(attachments) { attachment in
					Button {
						viewingAttachment = attachment
					} label: {
						HStack(alignment: .top) {
							Image(systemName: attachment.contentTypeIdentifier == UTType.pdf.identifier ? "doc.richtext" : "photo")
								.foregroundStyle(.secondary)
							VStack(alignment: .leading, spacing: 2) {
								Text(attachment.fileName).font(.subheadline).bold()
								if !attachment.attachmentKind.isEmpty {
									Text(attachment.attachmentKind).font(.caption).foregroundStyle(.secondary)
								}
								Text("\(formattedByteCount(attachment.fileByteCount)) · \(Functions().formatDate_DDMMMyy(date: attachment.documentDate))")
									.font(.caption)
									.foregroundStyle(.secondary)
							}
							Spacer()
						}
					}
					.buttonStyle(.plain)
					.padding(.vertical, 2)
					Divider()
				}
			}
		}
		.onAppear { loadAttachments() }
		.fileImporter(
			isPresented: $isImporting,
			allowedContentTypes: [.pdf, .image, .plainText],
			allowsMultipleSelection: false
		) { result in
			handleImport(result)
		}
		.sheet(item: $viewingAttachment, onDismiss: loadAttachments) { attachment in
			AttachmentViewer(attachment: attachment)
		}
		.alert("File Too Large", isPresented: Binding(
			get: { oversizeMessage != nil },
			set: { if !$0 { oversizeMessage = nil } }
		)) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(oversizeMessage ?? "")
		}
		.alert("Couldn't Add Attachment", isPresented: Binding(
			get: { importErrorMessage != nil },
			set: { if !$0 { importErrorMessage = nil } }
		)) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(importErrorMessage ?? "")
		}
	}

	private func loadAttachments() {
		let type = ownerType
		let key = ownerKey
		let fd = FetchDescriptor<RecordAttachment>(
			predicate: #Predicate { $0.ownerType == type && $0.ownerKey == key },
			sortBy: [SortDescriptor(\RecordAttachment.documentDate, order: .reverse)]
		)
		attachments = (try? modelContext.fetch(fd)) ?? []
	}

	private func handleImport(_ result: Result<[URL], Error>) {
		switch result {
			case .failure(let error):
				importErrorMessage = error.localizedDescription
			case .success(let urls):
				guard let url = urls.first else { return }
				let accessed = url.startAccessingSecurityScopedResource()
				defer { if accessed { url.stopAccessingSecurityScopedResource() } }
				do {
					let data = try Data(contentsOf: url)
					guard data.count <= attachmentMaxByteCount else {
						oversizeMessage = "\(url.lastPathComponent) is \(formattedByteCount(data.count)). Attachments are limited to \(formattedByteCount(attachmentMaxByteCount))."
						return
					}
					let typeId = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.identifier ?? ""
					let attachment = RecordAttachment(
						ownerType: ownerType,
						ownerKey: ownerKey,
						fileName: url.lastPathComponent,
						contentTypeIdentifier: typeId,
						fileByteCount: data.count,
						payload: data
					)
					modelContext.insert(attachment)
					try modelContext.save()
					loadAttachments()
				} catch {
					importErrorMessage = error.localizedDescription
				}
		}
	}
}

/// Full-screen viewer/editor for one attachment. PDFs reuse the shared PDFKitView from
/// PDFReportStyle.swift; images get a plain scaled Image (not Image_View_Details, which
/// is captioned for vehicle graphics specifically, not generic documents).
private struct AttachmentViewer: View {
	let attachment: RecordAttachment

	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	@State private var zoomAction: ZoomAction?
	@State private var isPresentingDeleteConfirm = false
	@State private var attachmentKind: String = ""
	@State private var documentDate: Date = Date()
	@State private var notes: String = ""

	var body: some View {
		NavigationStack {
			Group {
				if attachment.contentTypeIdentifier == UTType.pdf.identifier,
				   let data = attachment.payload, let doc = PDFDocument(data: data) {
					PDFKitView(showing: doc, zoomAction: $zoomAction)
				} else if attachment.contentTypeIdentifier == UTType.plainText.identifier,
						  let data = attachment.payload, let text = String(data: data, encoding: .utf8) {
					ScrollView { Text(text).font(.body.monospaced()).padding().frame(maxWidth: .infinity, alignment: .leading) }
				} else if let data = attachment.payload {
					attachmentImage(data)
				} else {
					Text("No preview available.")
						.foregroundStyle(.secondary)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				}
			}
			.safeAreaInset(edge: .bottom) {
				CardView {
					VStack {
						HStack {
							Text("Kind").textLabelModified()
							Picker("", selection: $attachmentKind) {
								Text("Release Document").tag("Release Document")
								Text("Certificate of Conformity").tag("Certificate of Conformity")
								Text("Invoice/PO").tag("Invoice/PO")
								Text("Logbook Page").tag("Logbook Page")
								Text("ICA").tag("ICA")
								Text("STC/Form 337").tag("STC/Form 337")
								Text("Manual Excerpt").tag("Manual Excerpt")
								Text("Photo").tag("Photo")
								Text("Other").tag("Other")
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						HStack{LabelDataPicker_Date(label: "Document Date", data: $documentDate)}
						TextFieldNote_FullWidth_3lines(sectionText: "NOTES", prompt: "Enter notes...", data: $notes)
					}
				}
				.padding()
			}
			.navigationTitle(attachment.fileName)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Close") { save(); dismiss() }
				}
				ToolbarItem(placement: .destructiveAction) {
					Button("Delete", role: .destructive) { isPresentingDeleteConfirm = true }
				}
			}
			.confirmationDialog("Delete this attachment?", isPresented: $isPresentingDeleteConfirm) {
				Button("Delete", role: .destructive) {
					modelContext.delete(attachment)
					try? modelContext.save()
					dismiss()
				}
				Button("Cancel", role: .cancel) {}
			}
		}
		.onAppear {
			attachmentKind = attachment.attachmentKind
			documentDate = attachment.documentDate
			notes = attachment.notes
		}
	}

	@ViewBuilder
	private func attachmentImage(_ data: Data) -> some View {
#if os(macOS)
		if let img = NSImage(data: data) {
			ScrollView { Image(nsImage: img).resizable().scaledToFit() }
		}
#elseif os(iOS)
		if let img = UIImage(data: data) {
			ScrollView { Image(uiImage: img).resizable().scaledToFit() }
		}
#endif
	}

	private func save() {
		attachment.attachmentKind = attachmentKind
		attachment.documentDate = documentDate
		attachment.notes = notes
		attachment.updatedAt = Date()
		try? modelContext.save()
	}
}
