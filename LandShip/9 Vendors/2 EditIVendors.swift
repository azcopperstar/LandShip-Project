//
//  EditItems.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import SwiftUI
import SwiftData

struct EditIVendors: View {
	@State private var dataSet: Vendors1
	
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) private var dismiss

	@State private var isPresentingConfirm: Bool = false
	@State private var isEditing: Bool = false
	
	@State private var createdAt = Date()
	@State private var updatedAt = Date()
	@State private var vendorName: String = ""
	@State private var vendorType: String = ""
	@State private var vendorContact1: String = ""
	@State private var vendorContact2: String = ""
	@State private var vendorContact3: String = ""
	@State private var vendorAddress: String = ""
	@State private var vendorCity: String = ""
	@State private var vendorState: String = ""
	@State private var vendorZip: String = ""
	@State private var vendorPhone: String = ""
	@State private var vendorEmail: String = ""
	@State private var vendorWebsite: String = ""
	@State private var vendorNotes: String = ""
	@State private var image1: Data?
	@State private var image2: Data?
	@State private var image3: Data?
	@State private var image1Description: String = ""
	@State private var image2Description: String = ""
	@State private var image3Description: String = ""

	init(vendors: Vendors1) {
		self._dataSet = State(initialValue: vendors)
		self._createdAt = State.init(initialValue: vendors.createdAt)
		self._updatedAt = State.init(initialValue: vendors.updatedAt)
		self._vendorName = State.init(initialValue: vendors.vendorName)
		self._vendorType = State.init(initialValue: vendors.vendorType)
		self._vendorContact1 = State.init(initialValue: vendors.vendorContact1)
		self._vendorContact2 = State.init(initialValue: vendors.vendorContact2)
		self._vendorContact3 = State.init(initialValue: vendors.vendorContact3)
		self._vendorAddress = State.init(initialValue: vendors.vendorAddress)
		self._vendorCity = State.init(initialValue: vendors.vendorCity)
		self._vendorState = State.init(initialValue: vendors.vendorState)
		self._vendorZip = State.init(initialValue: vendors.vendorZip)
		self._vendorPhone = State.init(initialValue: vendors.vendorPhone)
		self._vendorEmail = State.init(initialValue: vendors.vendorEmail)
		self._vendorWebsite = State.init(initialValue: vendors.vendorWebsite)
		self._vendorNotes = State.init(initialValue: vendors.vendorNotes)
		self._image1 = State.init(initialValue: vendors.image1)
		self._image2 = State.init(initialValue: vendors.image2)
		self._image3 = State.init(initialValue: vendors.image3)
		self._image1Description = State.init(initialValue: vendors.image1Description)
		self._image2Description = State.init(initialValue: vendors.image2Description)
		self._image3Description = State.init(initialValue: vendors.image3Description)
	}
	
	var body: some View {
		if isEditing {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "GENERAL")
						HStack{LabelDataTextview(label: "Vendor Name", data: $vendorName)}
						HStack{
							Text("Vendor Type")
								.textLabelModified()
							Picker("", selection: $vendorType) {
								Text("Parts Vendor").tag("Parts Vendor")
								Text("Service & Repair").tag("Service & Repair")
								Text("Auto Dealership").tag("Auto Dealership")
								Text("").tag("")
							}
							.pickerStyle(.menu)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						HStack{LabelDataTextview(label: "Notes", data: $vendorNotes)}
					}
				}

				CardView {
					VStack {
						SectionText(label: "CONTACTS & ADDRESSES")
						HStack{LabelDataTextview(label: "Contact 1", data: $vendorContact1)}
						HStack{LabelDataTextview(label: "Contact 2", data: $vendorContact2)}
						HStack{LabelDataTextview(label: "Contact 3", data: $vendorContact3)}
						HStack{LabelDataTextview(label: "Address", data: $vendorAddress)}
						HStack{LabelDataTextview(label: "City", data: $vendorCity)}
						HStack{LabelDataTextview(label: "State", data: $vendorState)}
						HStack{LabelDataTextview(label: "Zip", data: $vendorZip)}
					}
				}

				CardView {
					VStack {
						SectionText(label: "COMMUNICATIONS")
						HStack{LabelDataTextview_Numberpad_Phone(label: "Phone", data: $vendorPhone)}
						HStack{LabelDataTextview(label: "Email", data: $vendorEmail)}
						HStack{LabelDataTextview(label: "Website", data: $vendorWebsite)}
					}
				}
				
				CardView {
					VStack {
#if os(macOS)
						SectionText(label: "VENDORS GRAPHICS")
#elseif os(iOS)
						SectionText(label: "  VENDORS GRAPHICS\n(Click Image to Change)")
#endif
						HStack {Image_Edit(label: "1", imageData: $image1, imageDescription: $image1Description)}
						HStack {Image_Edit(label: "2", imageData: $image2, imageDescription: $image2Description)}
						HStack {Image_Edit(label: "3", imageData: $image3, imageDescription: $image3Description)}
					}
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.toolbar {
				ToolbarItem(placement: .automatic) {
					LabelDataText_Toolbar(label: "EDIT")
				}
				ToolbarItem(placement: .automatic) {
					Button("  Cancel  ") {
						cancelEdits()
						isEditing = false
					}
					.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("  Save  ") {
						updateItem()
						isEditing = false
					}
					.buttonStyle(GrowingButton(buttonColor: Color.red))
					.disabled(vendorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
				}
			}
			
		} else {
			ScrollView {
				VStack{CreatedUpdatedText(created: dataSet.createdAt, updated: dataSet.updatedAt)}
				CardView {
					VStack{
						SectionText(label: "GENERAL")
						HStack{LabelDataText(label: "Vendor Name", data: "\(dataSet.vendorName)")}
						if dataSet.vendorType != "" {
							HStack{LabelDataText(label: "Vendor Type", data: "\(dataSet.vendorType)")}
						}
						if dataSet.vendorNotes != "" {
							HStack{LabelDataText(label: "Vendor Notes", data: "\(dataSet.vendorNotes)")}
						}
					}
				}
				
				CardView {
					VStack{
						SectionText(label: "CONTACTS & ADDRESSES")
						if dataSet.vendorContact1 != "" {
							HStack{LabelDataText(label: "Contact 1", data: "\(dataSet.vendorContact1)")}
						}
						if dataSet.vendorContact2 != "" {
							HStack{LabelDataText(label: "Contact 2", data: "\(dataSet.vendorContact2)")}
						}
						if dataSet.vendorContact3 != "" {
							HStack{LabelDataText(label: "Contact 3", data: "\(dataSet.vendorContact3)")}
						}
						if dataSet.vendorAddress != "" {
							HStack{LabelDataText(label: "Address", data: "\(dataSet.vendorAddress)")}
						}
						if dataSet.vendorCity != "" {
							HStack{LabelDataText(label: "City", data: "\(dataSet.vendorCity)")}
						}
						if dataSet.vendorState != "" {
							HStack{LabelDataText(label: "State", data: "\(dataSet.vendorState)")}
						}
						if dataSet.vendorZip != "" {
							HStack{LabelDataText(label: "Zip Code", data: "\(dataSet.vendorZip)")}
						}
					}
				}
				
				CardView {
					VStack{
						SectionText(label: "COMMUNICATIONS")
						if dataSet.vendorPhone != "" {
							HStack{LabelDataText(label: "Phone", data: "\(dataSet.vendorPhone)")}
						}
						if dataSet.vendorEmail != "" {
							HStack{LabelDataText(label: "Email", data: "\(dataSet.vendorEmail)")}
						}
						if dataSet.vendorWebsite != "" {
							HStack{LabelDataText(label: "Website", data: "\(dataSet.vendorWebsite)")}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "VENDORS GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
					}
				}

			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.toolbar {
				ToolbarItem(placement: .automatic) {
					LabelDataText_Toolbar(label: "DETAILS")
				}
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "  Cancel  " : "  Edit  ") {
						isEditing.toggle()
						if isEditing {
							// ensure edit buffer is fresh when entering edit mode
							resetStateFromModel()
						}
					}
					.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("  Delete  ", role: .destructive) {
						isPresentingConfirm = true
					}
					.confirmationDialog("Confirm action", isPresented: $isPresentingConfirm) {
						Button("Delete record?", role: .destructive) {
							DeleteRecord()
						}
					} message: {
						Text("Confirm deletion of this Vendor record...")
					}
					.buttonStyle(GrowingButton(buttonColor: Color.gray))
				}
			}
		}
	}

	// MARK: - Actions
	private func updateItem() {
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.vendorName = vendorName
		dataSet.vendorType = vendorType
		dataSet.vendorContact1 = vendorContact1
		dataSet.vendorContact2 = vendorContact2
		dataSet.vendorContact3 = vendorContact3
		dataSet.vendorAddress = vendorAddress
		dataSet.vendorCity = vendorCity
		dataSet.vendorState = vendorState
		dataSet.vendorZip = vendorZip
		dataSet.vendorPhone = vendorPhone
		dataSet.vendorEmail = vendorEmail
		dataSet.vendorWebsite = vendorWebsite
		dataSet.vendorNotes = vendorNotes
		dataSet.image1 = image1
		dataSet.image2 = image2
		dataSet.image3 = image3
		dataSet.image1Description = image1Description
		dataSet.image2Description = image2Description
		dataSet.image3Description = image3Description

		do {
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
	}
	
	private func DeleteRecord(){
		do {
			modelContext.delete(dataSet)
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
		dismiss()
	}

	// MARK: - Edit helpers
	private func cancelEdits() {
		resetStateFromModel()
	}
	private func resetStateFromModel() {
		createdAt = dataSet.createdAt
		updatedAt = dataSet.updatedAt
		vendorName = dataSet.vendorName
		vendorType = dataSet.vendorType
		vendorContact1 = dataSet.vendorContact1
		vendorContact2 = dataSet.vendorContact2
		vendorContact3 = dataSet.vendorContact3
		vendorAddress = dataSet.vendorAddress
		vendorCity = dataSet.vendorCity
		vendorState = dataSet.vendorState
		vendorZip = dataSet.vendorZip
		vendorPhone = dataSet.vendorPhone
		vendorEmail = dataSet.vendorEmail
		vendorWebsite = dataSet.vendorWebsite
		vendorNotes = dataSet.vendorNotes
		image1 = dataSet.image1
		image2 = dataSet.image2
		image3 = dataSet.image3
		image1Description = dataSet.image1Description
		image2Description = dataSet.image2Description
		image3Description = dataSet.image3Description
	}
}

#Preview {
//	EditItems_test(mxItems: , vehicleId: "test")
//		.modelContainer(for:[MxItems.self])
}
