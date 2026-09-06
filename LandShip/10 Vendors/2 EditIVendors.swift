//
//  EditItems.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

/// EditIVendors.swift
///
/// Purpose:
/// A SwiftUI view that presents a detail-and-edit experience for a single `Vendors1` record.
/// It supports three primary modes:
/// 1) Details view for active vendors
/// 2) Editing view to modify vendor data
/// 3) A gated details message when the vendor is inactive and the user preference hides inactive records
///
/// Responsibilities:
/// - Display vendor information in a read-only layout.
/// - Provide an editing form with validation and normalization before saving to SwiftData.
/// - Persist changes using `modelContext.save()` and update timestamps.
/// - Offer destructive actions: delete and make inactive.
/// - Respect the `showInactiveVehicles` user preference when deciding whether to show content for inactive vendors.
///
/// Dependencies:
/// - SwiftUI for UI composition.
/// - SwiftData (`@Environment(\.modelContext)`) for persistence.
/// - AppStorage for reading the `showInactiveVehicles` preference.
/// - App-specific components: `CardView`, `SectionText`, `LabelDataText(view)`, `Image_Edit`, `Image_View_Details`,
///   `PageTitle_Col3_Photo`, `GrowingButton`, etc. These are assumed to be defined elsewhere in the project.
///
/// Usage:
/// - Initialize with a `Vendors1` model (`EditIVendors(vendors: someVendor)`).
/// - Optionally pass `startEditing: true` to enter edit mode immediately.
/// - The Save button will normalize and persist inputs; Cancel discards in-memory edits.
///
/// Notes:
/// - `updateItem()` performs input normalization (trimming, phone sanitization, URL normalization) before persisting.
/// - `makeInactive()` provides a non-destructive alternative to deletion and dismisses the view.
/// - The view mirrors the underlying model into `@State` to enable cancelable edits.

import SwiftUI
import SwiftData

/// A detail/edit screen for a single `Vendors1` entity.
///
/// This view toggles between read-only details and an edit form using the `isEditing` flag.
/// It also respects a user preference (`showInactiveVehicles`) that can hide inactive records
/// from the details view unless explicitly editing.
struct EditIVendors: View {
	// Backing model being displayed/edited; mirrored into local @State for cancelable edits.
	@State private var dataSet: Vendors1
	
	// User preference that determines whether inactive vendors are visible in read-only mode.
	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false
	
	// SwiftData model context used to persist changes and perform deletions.
	@Environment(\.modelContext) var modelContext
	
	// Dismiss action to close this view after destructive or save operations.
	@Environment(\.dismiss) private var dismiss

	// Controls presentation of confirmation dialogs for destructive actions.
	@State private var isPresentingConfirm: Bool = false

	// Controls presentation of the rename-cascade confirmation dialog, shown when saving
	// a vendor name change that would otherwise orphan records that reference it by name.
	@State private var showingRenameChoice: Bool = false

	// Toggles between details and edit modes.
	@State private var isEditing: Bool = false

	// MARK: - Save error feedback
	@State private var showVendorSaveError = false
	@State private var vendorSaveErrorMessage: String?
	
	// MARK: - Editable field buffer (mirrors `dataSet` so edits can be canceled)
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
	@State private var inactive: Bool = false

	/// Creates an editor for the given vendor.
	/// - Parameters:
	///   - vendors: The `Vendors1` record to display and edit.
	///   - startEditing: If true, the view starts in edit mode with state seeded from the model.
	init(vendors: Vendors1, startEditing: Bool = false) {
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
		self._inactive = State.init(initialValue: vendors.inactive)

		// Start in edit mode if requested
		self._isEditing = State(initialValue: startEditing)
	}
	
	var body: some View {
		// Branch 1: Inactive record is hidden by user preference — show gating message with minimal toolbar.
        if !isEditing && dataSet.inactive && !showInactiveVehicles {
            VStack(spacing: 16) {
                Text("This vendor is marked as Inactive.")
                    .font(.headline)
                Text("Enable ‘Show Inactive \(Vertical.current.assetPlural)’ in Settings to view details, or switch to Edit to change status.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top) {
                PageTitle_Col3_Photo(
                    label: "",
                    action: "details",
                    dbRecord: "vendor/shop")
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    LabelDataText_Toolbar(label: "DETAILS")
                }
                ToolbarItem(placement: .automatic) {
                    Button(isEditing ? "Cancel" : "Edit") {
                        isEditing.toggle()
                        if isEditing {
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
        // Branch 2: Edit mode — show form controls to modify the vendor.
        } else if isEditing {
			ScrollView {
				// General identity fields (name, type)
				CardView {
					VStack {
						SectionText(label: "GENERAL")
						HStack{LabelDataTextview(label: "Vendor Name", data: $vendorName)}
						Text("Renaming this vendor offers to update any records that reference it by name.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .trailing)
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
					}
				}

				// Freeform notes
				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "VENDOR/SHOP NOTES", prompt: "Enter notes...", data: $vendorNotes)
				}

				// Contacts and physical address
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

				// Communication channels (phone, email, website)
				CardView {
					VStack {
						SectionText(label: "COMMUNICATIONS")
						HStack{LabelDataTextview_Numberpad_Phone(label: "Phone", data: $vendorPhone)}
						HStack{LabelDataTextview(label: "Email", data: $vendorEmail)}
						HStack{LabelDataTextview(label: "Website", data: $vendorWebsite)}
					}
				}
				
				// Vendor images with editable captions
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
                // Record status (Active/Inactive)
                CardView {
                    VStack {
                        SectionText(label: "STATUS")
                        Toggle(isOn: $inactive) {
                            Text("Inactive")
                                .textLabelModified()
                        }
                    }
                }
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "edit",
					dbRecord: "vendor/shop")
			}

			.onAppear {
				// Ensure edit buffer is fresh if entering edit mode via deeplink or programmatically
				resetStateFromModel()
			}
			.toolbar {
				// Toolbar: mode indicator
				ToolbarItem(placement: .automatic) {
					LabelDataText_Toolbar(label: "EDIT")
				}
				// Toolbar: cancel edits and revert local state
				ToolbarItem(placement: .automatic) {
					Button("Cancel") {
						cancelEdits()
						isEditing = false
					}
					.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				// Toolbar: save edits (persists to SwiftData)
				ToolbarItem(placement: .automatic) {
					Button("Save") {
						let trimmedName = trimmed(vendorName)
						let oldName = dataSet.vendorName
						if oldName != trimmedName && hasLinkedRecords(oldName) {
							showingRenameChoice = true
						} else {
							updateItem()
							isEditing = false
						}
					}
					.buttonStyle(GrowingButton(buttonColor: Color.red))
					.disabled(vendorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
					.confirmationDialog(
						"Vendor Name Changed",
						isPresented: $showingRenameChoice,
						titleVisibility: .visible
					) {
						Button("Update Linked Records") {
							renameLinkedRecords(from: dataSet.vendorName, to: trimmed(vendorName))
							updateItem()
							isEditing = false
						}
						Button("Save Without Updating Links", role: .destructive) {
							updateItem()
							isEditing = false
						}
						Button("Cancel", role: .cancel) { }
					} message: {
						Text("Renaming \"\(dataSet.vendorName)\" to \"\(trimmed(vendorName))\" will break its links to other records unless they're updated to the new name. Update them now?")
					}
				}
			}
			.alert("Couldn't Save", isPresented: $showVendorSaveError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(vendorSaveErrorMessage ?? "")
			}

		// Branch 3: Details mode — read-only presentation of vendor data.
		} else {
			ScrollView {
				// Metadata (created/updated timestamps)
				VStack{CreatedUpdatedText(created: dataSet.createdAt, updated: dataSet.updatedAt)}
				// General identity fields
				CardView {
					VStack{
						SectionText(label: "GENERAL")
						HStack{LabelDataText(label: "Vendor Name", data: "\(dataSet.vendorName)")}
                        HStack{LabelDataText(label: "Status", data: dataSet.inactive ? "Inactive" : "Active")}
						if dataSet.vendorType != "" {
							HStack{LabelDataText(label: "Vendor Type", data: "\(dataSet.vendorType)")}
						}
					}
				}
				
				// Freeform notes (read-only)
				if dataSet.vendorNotes != "" {CardView {
					TextNoteDisplay_FullWidth(sectionText: "VENDOR/SHOP NOTES", data: dataSet.vendorNotes)}
				}

				// Contacts and physical address (read-only) — hidden when no fields have data
				if hasContactDetails {
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
				}
				
				// Communication channels (read-only) — hidden when no fields have data
				if hasCommunications {
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
				}
				
				// Vendor images (read-only) — hidden when no images are attached
				if hasGraphics {
					CardView {
					VStack {
						SectionText(label: "VENDORS GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
					}
					}
				}

			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "details",
					dbRecord: "vendor/shop")
			}

			.toolbar {
				// Toolbar: mode indicator
				ToolbarItem(placement: .automatic) {
					LabelDataText_Toolbar(label: "DETAILS")
				}
				// Toolbar: toggle between details and edit
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "Cancel" : "Edit") {
						isEditing.toggle()
						if isEditing {
							// ensure edit buffer is fresh when entering edit mode
							resetStateFromModel()
						}
					}
					.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				// Toolbar: destructive actions (delete / make inactive)
				ToolbarItem(placement: .automatic) {
					Button("Delete", role: .destructive) {
						isPresentingConfirm = true
					}
					.confirmationDialog("Confirm action", isPresented: $isPresentingConfirm) {
						Button("Delete record?", role: .destructive) {
							DeleteRecord()
						}
						Button("Make Inactive") {
							makeInactive()
						}
					} message: {
						Text("Confirm either deletion or deactivation of this vendor.  Deactivated vendors will still be available for reference, but will not be included in any reports or calculations.")
					}
					.buttonStyle(GrowingButton(buttonColor: Color.gray))
				}
			}
		}
	}

	// MARK: - Details section visibility
	// Each card section in Details mode is only rendered when at least one of its
	// fields holds data, so a section title never appears above an empty card.

	/// True when any contact or address field has data.
	private var hasContactDetails: Bool {
		!(dataSet.vendorContact1.isEmpty
		  && dataSet.vendorContact2.isEmpty
		  && dataSet.vendorContact3.isEmpty
		  && dataSet.vendorAddress.isEmpty
		  && dataSet.vendorCity.isEmpty
		  && dataSet.vendorState.isEmpty
		  && dataSet.vendorZip.isEmpty)
	}

	/// True when any communication channel has data.
	private var hasCommunications: Bool {
		!(dataSet.vendorPhone.isEmpty
		  && dataSet.vendorEmail.isEmpty
		  && dataSet.vendorWebsite.isEmpty)
	}

	/// True when at least one image is attached.
	private var hasGraphics: Bool {
		dataSet.image1 != nil || dataSet.image2 != nil || dataSet.image3 != nil
	}

	// MARK: - Actions
	
	/// Normalizes user input and persists changes to the underlying `Vendors1` model.
	/// - Normalization includes trimming whitespace, lowercasing email, digit-only phone, and ensuring URL scheme.
	/// - Updates `updatedAt` and mirrors all editable fields into `dataSet` before saving.
	private func updateItem() {
		// Trim and normalize inputs before saving
		let name = trimmed(vendorName)
		let type = trimmed(vendorType)
		let contact1 = trimmed(vendorContact1)
		let contact2 = trimmed(vendorContact2)
		let contact3 = trimmed(vendorContact3)
		let address = trimmed(vendorAddress)
		let city = trimmed(vendorCity)
		let state = trimmed(vendorState)
		let zip = trimmed(vendorZip)
		let phone = sanitizePhone(vendorPhone)
		let email = trimmed(vendorEmail).lowercased()
		let website = normalizeURL(trimmed(vendorWebsite))
		let notes = trimmed(vendorNotes)

		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.vendorName = name
		dataSet.vendorType = type
		dataSet.vendorContact1 = contact1
		dataSet.vendorContact2 = contact2
		dataSet.vendorContact3 = contact3
		dataSet.vendorAddress = address
		dataSet.vendorCity = city
		dataSet.vendorState = state
		dataSet.vendorZip = zip
		dataSet.vendorPhone = phone
		dataSet.vendorEmail = email
		dataSet.vendorWebsite = website
		dataSet.vendorNotes = notes
		dataSet.image1 = image1
		dataSet.image2 = image2
		dataSet.image3 = image3
		dataSet.image1Description = image1Description
		dataSet.image2Description = image2Description
		dataSet.image3Description = image3Description
        dataSet.inactive = inactive

		do {
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
			vendorSaveErrorMessage = error.localizedDescription
			showVendorSaveError = true
		}
	}

	/// True if any other record references `name` by vendor name. Used to decide whether the
	/// rename-cascade dialog is worth showing — a brand-new or never-referenced vendor has
	/// nothing to break, so saving proceeds silently.
	private func hasLinkedRecords(_ name: String) -> Bool {
		guard !name.isEmpty else { return false }
		func exists<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> Bool {
			var fd = descriptor
			fd.fetchLimit = 1
			return ((try? modelContext.fetch(fd)) ?? []).isEmpty == false
		}
		if exists(FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partSupplier == name || $0.partSource == name })) { return true }
		if exists(FetchDescriptor<MxItems3>(predicate: #Predicate { $0.vendor == name })) { return true }
		if exists(FetchDescriptor<ServiceRecords1>(predicate: #Predicate { $0.vendor == name })) { return true }
		if exists(FetchDescriptor<Additions>(predicate: #Predicate { $0.itemVendor == name })) { return true }
		if exists(FetchDescriptor<Subscriptions>(predicate: #Predicate { $0.itemVendor == name })) { return true }
		if exists(FetchDescriptor<ProjectList>(predicate: #Predicate { $0.itemVendor == name })) { return true }
		return false
	}

	/// Updates every other record type that references this vendor by name (LandShip's
	/// string-based linking convention — the same one used for vehicle renames), so existing
	/// links survive a vendor rename instead of silently orphaning.
	private func renameLinkedRecords(from oldName: String, to newName: String) {
		guard !oldName.isEmpty, oldName != newName else { return }

		func rename<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, _ apply: (T) -> Void) {
			guard let records = try? modelContext.fetch(descriptor), !records.isEmpty else { return }
			records.forEach(apply)
		}

		rename(FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partSupplier == oldName })) { $0.partSupplier = newName }
		rename(FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partSource == oldName })) { $0.partSource = newName }
		rename(FetchDescriptor<MxItems3>(predicate: #Predicate { $0.vendor == oldName })) { $0.vendor = newName }
		rename(FetchDescriptor<ServiceRecords1>(predicate: #Predicate { $0.vendor == oldName })) { $0.vendor = newName }
		rename(FetchDescriptor<Additions>(predicate: #Predicate { $0.itemVendor == oldName })) { $0.itemVendor = newName }
		rename(FetchDescriptor<Subscriptions>(predicate: #Predicate { $0.itemVendor == oldName })) { $0.itemVendor = newName }
		rename(FetchDescriptor<ProjectList>(predicate: #Predicate { $0.itemVendor == oldName })) { $0.itemVendor = newName }

		do {
			try modelContext.save()
		} catch {
			print("Failed to update linked records after vendor rename: \(error.localizedDescription)")
		}
	}

	/// Permanently deletes the current `Vendors1` record from the model context and dismisses the view.
	/// Use with care — this action cannot be undone.
	private func DeleteRecord(){
		do {
			modelContext.delete(dataSet)
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
		dismiss()
	}
	
	/// Marks the record as inactive, saves, and dismisses the view.
	/// This is a non-destructive alternative to deletion that preserves the record for reference.
	private func makeInactive() {
		// Mark the underlying model as inactive so the persisted record reflects the change.
		dataSet.inactive = true
		
		// Keep the view's local state in sync so any UI bound to `inactive` updates immediately.
		inactive = true
		
		// Record the modification time for auditing/sorting purposes.
		dataSet.updatedAt = Date()
		
		// Attempt to persist the change to the SwiftData model context.
		do {
			try modelContext.save()
		} catch {
			// In production, consider presenting a user-facing alert instead of just printing.
			print("Failed to mark inactive: \(error.localizedDescription)")
		}
		
		// Close the current view regardless of save success to maintain a consistent flow
		// after a destructive or terminal action. Adjust if you prefer to remain on screen
		// when persistence fails.
		dismiss()
	}

	// MARK: - Edit helpers
	
	/// Discards any in-memory changes by reloading local state from the persisted model.
	private func cancelEdits() {
		resetStateFromModel()
	}
	
	/// Reloads all editable `@State` properties from the current `dataSet` values.
	/// Call this when entering edit mode or canceling edits to ensure UI reflects persisted data.
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
        inactive = dataSet.inactive
	}
}

// MARK: - Normalization helpers
private extension EditIVendors {
	/// Trims leading and trailing whitespace/newlines from the provided string.
	func trimmed(_ s: String) -> String {
		s.trimmingCharacters(in: .whitespacesAndNewlines)
	}
	
	/// Removes all non-digit characters from a phone number string.
	/// - Returns: A string containing only decimal digits.
	func sanitizePhone(_ s: String) -> String {
		// Keep digits only; you can enhance with formatting (e.g., (###) ###-####) if desired.
		let digits = s.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
		return String(String.UnicodeScalarView(digits))
	}
	
	/// Ensures the provided URL string has an explicit scheme.
	/// - If the string is empty, returns it as-is.
	/// - If no `http://` or `https://` prefix is found, prefixes with `https://`.
	func normalizeURL(_ s: String) -> String {
		guard !s.isEmpty else { return s }
		let lower = s.lowercased()
		if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
			return s
		}
		// Default to https
		return "https://\(s)"
	}
}

#Preview {
//	EditItems_test(mxItems: , vehicleId: "test")
//		.modelContainer(for:[MxItems.self])
}
