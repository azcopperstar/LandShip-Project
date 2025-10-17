//
//  EditItems.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import SwiftUI
import SwiftData

struct EditSystems: View {
	@State private var dataSet: VehicleSystems1

	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) private var dismiss
	let functions: Functions = Functions()

	@State private var isPresentingConfirm: Bool = false
	@State private var isEditing: Bool = false
	
	@State fileprivate var createdAt = Date()
	@State fileprivate var updatedAt = Date()
	@State fileprivate var vehicleId = ""
	@State fileprivate var systemName = "System title..."
	@State fileprivate var systemDescription = ""
	@State fileprivate var systemType = ""
	@State fileprivate var systemManufacturer = ""
	@State fileprivate var systemModel = ""
	@State fileprivate var systemSerialNumber = ""
	@State fileprivate var systemPartNumber = ""
	@State fileprivate var systemLocation = ""
	@State fileprivate var systemStatus = ""
	@State fileprivate var systemNotes = ""
	@State fileprivate var image1: Data?
	@State fileprivate var image2: Data?
	@State fileprivate var image3: Data?
	@State fileprivate var image1Description: String = ""
	@State fileprivate var image2Description: String = ""
	@State fileprivate var image3Description: String = ""

	// Snapshot used to support Cancel while editing
	@State private var snapshot: SystemSnapshot?

	init(vehicleSystem: VehicleSystems1) {
		self.dataSet = vehicleSystem

		self._createdAt = State(initialValue: vehicleSystem.createdAt)
		self._updatedAt = State(initialValue: vehicleSystem.updatedAt)
		self._vehicleId = State(initialValue: vehicleSystem.vehicleId)
		self._systemName = State(initialValue: vehicleSystem.systemName)
		self._systemDescription = State(initialValue: vehicleSystem.systemDescription)
		self._systemType = State(initialValue: vehicleSystem.systemType)
		self._systemManufacturer = State(initialValue: vehicleSystem.systemManufacturer)
		self._systemModel = State(initialValue: vehicleSystem.systemModel)
		self._systemSerialNumber = State(initialValue: vehicleSystem.systemSerialNumber)
		self._systemPartNumber = State(initialValue: vehicleSystem.systemPartNumber)
		self._systemLocation = State(initialValue: vehicleSystem.systemLocation)
		self._systemStatus = State(initialValue: vehicleSystem.systemStatus)
		self._systemNotes = State(initialValue: vehicleSystem.systemNotes)
		self._image1 = State(initialValue: vehicleSystem.image1)
		self._image2 = State(initialValue: vehicleSystem.image2)
		self._image3 = State(initialValue: vehicleSystem.image3)
		self._image1Description = State(initialValue: vehicleSystem.image1Description)
		self._image2Description = State(initialValue: vehicleSystem.image2Description)
		self._image3Description = State(initialValue: vehicleSystem.image3Description)
	}

	var body: some View {
		Group {
			if isEditing {
				editContent
			} else {
				readContent
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.toolbar { toolbarContent }
	}

	// MARK: - Edit content
	private var editContent: some View {
		ScrollView {
			CardView {
				VStack {
					SectionText(label: "GENERAL")
					HStack{
						Text("Vehicle")
							.textLabelModified()
						VehiclePickerSystems(RequestingData: $dataSet)
							.onChange(of: dataSet.vehicleId) { _, _ in
								vehicleId = dataSet.vehicleId
							}
					}
					HStack{LabelDataTextview(label: "System Name", data: $systemName)}
					HStack{LabelDataTextview(label: "Description", data: $systemDescription)}
				}
			}
			
			CardView {
				VStack {
					SectionText(label: "DETAILS")
					HStack{LabelDataTextview(label: "System Type", data: $systemType)}
					HStack{LabelDataTextview(label: "Manufacture", data: $systemManufacturer)}
					HStack{LabelDataTextview(label: "Model", data: $systemModel)}
					HStack{LabelDataTextview(label: "Serial Number", data: $systemSerialNumber)}
					HStack{LabelDataTextview(label: "Part Number", data: $systemPartNumber)}
					HStack{LabelDataTextview(label: "Location", data: $systemLocation)}
					HStack{LabelDataTextview(label: "Status", data: $systemStatus)}
					HStack{LabelDataTextview(label: "Notes", data: $systemNotes)}
				}
			}
			
			CardView {
				VStack {
#if os(macOS)
					SectionText(label: "VEHICLE SYSTEMS GRAPHICS")
#elseif os(iOS)
					SectionText(label: "  VEHICLE SYSTEMS GRAPHICS\n(Click Image to Change)")
#endif
					HStack {Image_Edit(label: "1", imageData: $image1, imageDescription: $image1Description)}
					HStack {Image_Edit(label: "2", imageData: $image2, imageDescription: $image2Description)}
					HStack {Image_Edit(label: "3", imageData: $image3, imageDescription: $image3Description)}
				}
			}
		}
		.onAppear {
			// When we enter edit mode, ensure local state matches the latest model and capture a snapshot
			loadFromModel()
			snapshot = SystemSnapshot(from: self)
		}
	}

	// MARK: - Read content
	private var readContent: some View {
		ScrollView {
			VStack{CreatedUpdatedText(created: dataSet.createdAt, updated: dataSet.updatedAt)}
			
			CardView {
				VStack{
					SectionText(label: "GENERAL")
					HStack{LabelDataText(label: "Vehicle", data: dataSet.vehicleId)}
					HStack{LabelDataText(label: "System Name", data: "\(dataSet.systemName)")}
					if dataSet.systemDescription != "" {
						HStack{LabelDataText(label: "Description", data: "\(dataSet.systemDescription)")}
					}
				}
			}
			
			CardView {
				VStack{
					SectionText(label: "DETAILS")
					if dataSet.systemType != "" {
						HStack{LabelDataText(label: "System Type", data: "\(dataSet.systemType)")}
					}
					if dataSet.systemManufacturer != "" {
						HStack{LabelDataText(label: "Manufacturer", data: "\(dataSet.systemManufacturer)")}
					}
					if dataSet.systemModel != "" {
						HStack{LabelDataText(label: "Model #", data: "\(dataSet.systemModel)")}
					}
					if dataSet.systemSerialNumber != "" {
						HStack{LabelDataText(label: "Serial #", data: "\(dataSet.systemSerialNumber)")}
					}
					if dataSet.systemPartNumber != "" {
						HStack{LabelDataText(label: "Part #", data: "\(dataSet.systemPartNumber)")}
					}
					if dataSet.systemLocation != "" {
						HStack{LabelDataText(label: "Location", data: "\(dataSet.systemLocation)")}
					}
					if dataSet.systemStatus != "" {
						HStack{LabelDataText(label: "Status", data: "\(dataSet.systemStatus)")}
					}
					if dataSet.systemNotes != "" {
						HStack{LabelDataText(label: "Notes", data: "\(dataSet.systemNotes)")}
					}
				}
			}
			CardView {
				VStack {
					SectionText(label: "VEHICLE SYSTEMS GRAPHICS")
					Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
					Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
					Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
				}
			}
		}
		.listStyle(.automatic)
	}

	// MARK: - Toolbar
	@ToolbarContentBuilder
	private var toolbarContent: some ToolbarContent {
		if isEditing {
			ToolbarItem(placement: .automatic) {
				LabelDataText_Toolbar(label: "EDIT")
			}
			ToolbarItem(placement: .automatic) {
				Button("  Cancel  ") {
					cancelEditing()
				}
				.buttonStyle(GrowingButton(buttonColor: Color.green))
			}
			ToolbarItem(placement: .automatic) {
				Button("  Save  ") {
					isEditing = false
					updateItem()
				}
				.buttonStyle(GrowingButton(buttonColor: Color.red))
				.disabled(isSaveDisabled)
			}
		} else {
			ToolbarItem(placement: .automatic) {
				LabelDataText_Toolbar(label: "DETAILS")
			}
			ToolbarItem(placement: .automatic) {
				Button("  Edit  ") {
					isEditing = true
					// load current model values into editing state and capture snapshot
					loadFromModel()
					snapshot = SystemSnapshot(from: self)
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
					Text("Confirm deletion of this system record...")
				}
				.buttonStyle(GrowingButton(buttonColor: Color.gray))
			}
		}
	}

	// MARK: - Validation
	private var isSaveDisabled: Bool {
		systemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	// MARK: - Helpers
	private func loadFromModel() {
		createdAt = dataSet.createdAt
		updatedAt = dataSet.updatedAt
		vehicleId = dataSet.vehicleId
		systemName = dataSet.systemName
		systemDescription = dataSet.systemDescription
		systemType = dataSet.systemType
		systemManufacturer = dataSet.systemManufacturer
		systemModel = dataSet.systemModel
		systemSerialNumber = dataSet.systemSerialNumber
		systemPartNumber = dataSet.systemPartNumber
		systemLocation = dataSet.systemLocation
		systemStatus = dataSet.systemStatus
		systemNotes = dataSet.systemNotes
		image1 = dataSet.image1
		image2 = dataSet.image2
		image3 = dataSet.image3
		image1Description = dataSet.image1Description
		image2Description = dataSet.image2Description
		image3Description = dataSet.image3Description
	}

	private func restoreFromSnapshot() {
		guard let snap = snapshot else { return }
		createdAt = snap.createdAt
		updatedAt = snap.updatedAt
		vehicleId = snap.vehicleId
		systemName = snap.systemName
		systemDescription = snap.systemDescription
		systemType = snap.systemType
		systemManufacturer = snap.systemManufacturer
		systemModel = snap.systemModel
		systemSerialNumber = snap.systemSerialNumber
		systemPartNumber = snap.systemPartNumber
		systemLocation = snap.systemLocation
		systemStatus = snap.systemStatus
		systemNotes = snap.systemNotes
		image1 = snap.image1
		image2 = snap.image2
		image3 = snap.image3
		image1Description = snap.image1Description
		image2Description = snap.image2Description
		image3Description = snap.image3Description
	}

	private func cancelEditing() {
		restoreFromSnapshot()
		isEditing = false
	}

	@MainActor
	private func updateItem() {
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.vehicleId = vehicleId
		dataSet.systemName = systemName
		dataSet.systemDescription = systemDescription
		dataSet.systemType = systemType
		dataSet.systemManufacturer = systemManufacturer
		dataSet.systemModel = systemModel
		dataSet.systemSerialNumber = systemSerialNumber
		dataSet.systemPartNumber = systemPartNumber
		dataSet.systemLocation = systemLocation
		dataSet.systemStatus = systemStatus
		dataSet.systemNotes = systemNotes
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

	@MainActor
	private func DeleteRecord(){
		do {
			modelContext.delete(dataSet)
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
		dismiss()
	}
}

// MARK: - Snapshot for cancel support
private struct SystemSnapshot {
	let createdAt: Date
	let updatedAt: Date
	let vehicleId: String
	let systemName: String
	let systemDescription: String
	let systemType: String
	let systemManufacturer: String
	let systemModel: String
	let systemSerialNumber: String
	let systemPartNumber: String
	let systemLocation: String
	let systemStatus: String
	let systemNotes: String
	let image1: Data?
	let image2: Data?
	let image3: Data?
	let image1Description: String
	let image2Description: String
	let image3Description: String

	@MainActor
	init(from view: EditSystems) {
		self.createdAt = view.createdAt
		self.updatedAt = view.updatedAt
		self.vehicleId = view.vehicleId
		self.systemName = view.systemName
		self.systemDescription = view.systemDescription
		self.systemType = view.systemType
		self.systemManufacturer = view.systemManufacturer
		self.systemModel = view.systemModel
		self.systemSerialNumber = view.systemSerialNumber
		self.systemPartNumber = view.systemPartNumber
		self.systemLocation = view.systemLocation
		self.systemStatus = view.systemStatus
		self.systemNotes = view.systemNotes
		self.image1 = view.image1
		self.image2 = view.image2
		self.image3 = view.image3
		self.image1Description = view.image1Description
		self.image2Description = view.image2Description
		self.image3Description = view.image3Description
	}
}

#Preview {
//	EditItems_test(mxItems: , vehicleId: "test")
//		.modelContainer(for:[MxItems.self])
}
