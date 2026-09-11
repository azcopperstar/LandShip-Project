//
//  EditPartApproval.swift
//  LandShip
//
//  Sheet editor for MxParts1's airworthiness approval basis — "is it legal to install,"
//  distinct from identity. The actual release document belongs in Attachments (this sheet
//  only records which type it is), per the compliance discussion's "store the document
//  itself, not just a checkbox." AeroTrax only.
//

import SwiftUI
import SwiftData

struct EditPartApproval: View {
	let part: MxParts1

	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	@State private var approvalBasis: String
	@State private var releaseDocumentType: String
	@State private var stcNumber: String
	@State private var ownerProducedJustification: String
	@State private var sourceTraceability: String
	@State private var icaReference: String
	@State private var showSaveError = false
	@State private var saveErrorMessage: String?

	init(part: MxParts1) {
		self.part = part
		self._approvalBasis = State(initialValue: part.approvalBasis)
		self._releaseDocumentType = State(initialValue: part.releaseDocumentType)
		self._stcNumber = State(initialValue: part.stcNumber)
		self._ownerProducedJustification = State(initialValue: part.ownerProducedJustification)
		self._sourceTraceability = State(initialValue: part.sourceTraceability)
		self._icaReference = State(initialValue: part.icaReference)
	}

	private var selectedBasis: PartApprovalBasis? { PartApprovalBasis(rawValue: approvalBasis) }

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "AIRWORTHINESS APPROVAL BASIS")
						HStack {
							Text("Approval Basis").textLabelModified()
							Picker("", selection: $approvalBasis) {
								Text("—").tag("")
								ForEach(PartApprovalBasis.allCases) { basis in
									Text(basis.rawValue).tag(basis.rawValue)
								}
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						if let basis = selectedBasis {
							Text(basis.summary)
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
						}
						if selectedBasis == .stc {
							HStack{LabelDataTextview(label: "STC Number", data: $stcNumber)}
						}
						if selectedBasis == .ownerProduced {
							TextFieldNote_FullWidth_3lines(
								sectionText: "OWNER-PRODUCED JUSTIFICATION (14 CFR 21.9(a)(5))",
								prompt: "Describe how this part was produced and why it qualifies...",
								data: $ownerProducedJustification
							)
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "RELEASE DOCUMENT")
						HStack {
							Text("Document Type").textLabelModified()
							Picker("", selection: $releaseDocumentType) {
								Text("—").tag("")
								ForEach(ReleaseDocumentType.allCases) { type in
									Text(type.rawValue).tag(type.rawValue)
								}
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						Text("Attach the actual document in Attachments below — this only records which type it is.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
						HStack{LabelDataTextview(label: "ICA Reference", data: $icaReference)}
					}
				}

				CardView {
					TextFieldNote_FullWidth_3lines(
						sectionText: "SOURCE TRACEABILITY",
						prompt: "Chain back to a production approval holder...",
						data: $sourceTraceability
					)
				}
			}
			.navigationTitle("Approval Basis")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
				ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
			}
			.alert("Couldn't Save", isPresented: $showSaveError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(saveErrorMessage ?? "")
			}
		}
	}

	private func save() {
		part.approvalBasis = approvalBasis
		part.releaseDocumentType = releaseDocumentType
		part.stcNumber = stcNumber
		part.ownerProducedJustification = ownerProducedJustification
		part.sourceTraceability = sourceTraceability
		part.icaReference = icaReference
		part.updatedAt = Date()
		do {
			try modelContext.save()
			dismiss()
		} catch {
			saveErrorMessage = error.localizedDescription
			showSaveError = true
		}
	}
}
