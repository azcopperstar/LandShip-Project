//
//  EditPartCommercial.swift
//  LandShip
//
//  Sheet editor for MxParts1's commercial/inventory fields not already on the main
//  EditParts screen (cost/vendor/quantity are there already) — PO/invoice, warranty by
//  BOTH date and hours, and exchange/core return tracking, which the compliance
//  discussion flagged as the best ROI in the whole spec: cheap fields that prevent a
//  real, common, expensive loss (a rotable core deposit never returned). AeroTrax only.
//

import SwiftUI
import SwiftData

struct EditPartCommercial: View {
	let part: MxParts1

	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	@State private var poNumber: String
	@State private var invoiceNumber: String
	@State private var hasWarrantyExpiryDate: Bool
	@State private var warrantyExpiryDate: Date
	@State private var warrantyExpiryHours: Float
	@State private var isExchangeUnit: Bool
	@State private var hasCoreReturnDueDate: Bool
	@State private var coreReturnDueDate: Date
	@State private var hasCoreReturnedDate: Bool
	@State private var coreReturnedDate: Date
	@State private var coreDepositAmount: Float
	@State private var showSaveError = false
	@State private var saveErrorMessage: String?

	init(part: MxParts1) {
		self.part = part
		self._poNumber = State(initialValue: part.poNumber)
		self._invoiceNumber = State(initialValue: part.invoiceNumber)
		self._hasWarrantyExpiryDate = State(initialValue: part.warrantyExpiryDate != nil)
		self._warrantyExpiryDate = State(initialValue: part.warrantyExpiryDate ?? Date())
		self._warrantyExpiryHours = State(initialValue: part.warrantyExpiryHours)
		self._isExchangeUnit = State(initialValue: part.isExchangeUnit)
		self._hasCoreReturnDueDate = State(initialValue: part.coreReturnDueDate != nil)
		self._coreReturnDueDate = State(initialValue: part.coreReturnDueDate ?? Date())
		self._hasCoreReturnedDate = State(initialValue: part.coreReturnedDate != nil)
		self._coreReturnedDate = State(initialValue: part.coreReturnedDate ?? Date())
		self._coreDepositAmount = State(initialValue: part.coreDepositAmount)
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "PURCHASE")
						HStack{LabelDataTextview(label: "PO Number", data: $poNumber)}
						HStack{LabelDataTextview(label: "Invoice Number", data: $invoiceNumber)}
					}
				}

				CardView {
					VStack {
						SectionText(label: "WARRANTY")
						HStack{LabelDataToggle(label: "Has Warranty Expiry Date", data: $hasWarrantyExpiryDate)}
						if hasWarrantyExpiryDate {
							HStack{LabelDataPicker_Date(label: "Expires On", data: $warrantyExpiryDate)}
						}
						HStack{LabelDataTextview_Numberpad_Float(label: "Expires After (Hours)", data: $warrantyExpiryHours)}
					}
				}

				CardView {
					VStack {
						SectionText(label: "EXCHANGE / CORE RETURN")
						HStack{LabelDataToggle(label: "This Is an Exchange Unit", data: $isExchangeUnit)}
						if isExchangeUnit {
							HStack{LabelDataToggle(label: "Has Core Return Due Date", data: $hasCoreReturnDueDate)}
							if hasCoreReturnDueDate {
								HStack{LabelDataPicker_Date(label: "Core Due Back", data: $coreReturnDueDate)}
							}
							HStack{LabelDataToggle(label: "Core Returned", data: $hasCoreReturnedDate)}
							if hasCoreReturnedDate {
								HStack{LabelDataPicker_Date(label: "Core Returned On", data: $coreReturnedDate)}
							}
							HStack{LabelDataTextview_Numberpad_Currency(label: "Core Deposit", data: $coreDepositAmount)}
						}
					}
				}
			}
			.navigationTitle("Commercial")
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
		part.poNumber = poNumber
		part.invoiceNumber = invoiceNumber
		part.warrantyExpiryDate = hasWarrantyExpiryDate ? warrantyExpiryDate : nil
		part.warrantyExpiryHours = warrantyExpiryHours
		part.isExchangeUnit = isExchangeUnit
		part.coreReturnDueDate = hasCoreReturnDueDate ? coreReturnDueDate : nil
		part.coreReturnedDate = hasCoreReturnedDate ? coreReturnedDate : nil
		part.coreDepositAmount = coreDepositAmount
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
