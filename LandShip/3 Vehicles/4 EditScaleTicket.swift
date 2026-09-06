//
//  4 EditScaleTicket.swift
//  LandShip
//
//  Sheet-based form for adding or editing a single VehicleScaleTicket (CAT scale weigh record).
//  Presented from EditVehicle whenever the user taps a scale ticket row or the Add button.
//

import SwiftUI
import SwiftData

struct EditScaleTicket: View {
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	let vehicleId: String
	let ticket: VehicleScaleTicket?

	@State private var date: Date = Date()
	@State private var ticketNumber: String = ""
	@State private var weighNumber: String = ""
	@State private var location: String = ""
	@State private var tractorLicensePlate: String = ""
	@State private var trailerLicensePlate: String = ""
	@State private var companyName: String = ""
	@State private var tractorNumber: String = ""
	@State private var trailerNumber: String = ""
	@State private var cost: Float = 0.0
	@State private var steerAxleWeight: Int = 0
	@State private var driveAxleWeight: Int = 0
	@State private var trailerAxleWeight: Int = 0
	@State private var ticketImage: Data? = nil
	@State private var ticketImageDescription: String = ""

	@State private var isPresentingDeleteConfirm: Bool = false
	@State private var isPresentingTransferConfirm: Bool = false
	@State private var showTicketSaveError: Bool = false
	@State private var ticketSaveErrorMessage: String?

	private var grossWeight: Int { steerAxleWeight + driveAxleWeight + trailerAxleWeight }

	init(vehicleId: String, ticket: VehicleScaleTicket? = nil) {
		self.vehicleId = vehicleId
		self.ticket = ticket
		self._date = State(initialValue: ticket?.date ?? Date())
		self._ticketNumber = State(initialValue: ticket?.ticketNumber ?? "")
		self._weighNumber = State(initialValue: ticket?.weighNumber ?? "")
		self._location = State(initialValue: ticket?.location ?? "")
		self._tractorLicensePlate = State(initialValue: ticket?.tractorLicensePlate ?? "")
		self._trailerLicensePlate = State(initialValue: ticket?.trailerLicensePlate ?? "")
		self._companyName = State(initialValue: ticket?.companyName ?? "")
		self._tractorNumber = State(initialValue: ticket?.tractorNumber ?? "")
		self._trailerNumber = State(initialValue: ticket?.trailerNumber ?? "")
		let storedCost = ticket.map { $0.costDecimal > 0 ? $0.costDecimal : Double($0.cost) } ?? 0.0
		self._cost = State(initialValue: Float(storedCost))
		self._steerAxleWeight = State(initialValue: ticket?.steerAxleWeight ?? 0)
		self._driveAxleWeight = State(initialValue: ticket?.driveAxleWeight ?? 0)
		self._trailerAxleWeight = State(initialValue: ticket?.trailerAxleWeight ?? 0)
		self._ticketImage = State(initialValue: ticket?.ticketImage)
		self._ticketImageDescription = State(initialValue: ticket?.ticketImageDescription ?? "")
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "SCALE TICKET INFO")
						HStack { LabelDataPicker_Date(label: "Date", data: $date) }
						HStack { LabelDataTextview(label: "Ticket #", data: $ticketNumber) }
						HStack { LabelDataTextview(label: "Weigh #", data: $weighNumber) }
						HStack { LabelDataTextview(label: "Location", data: $location) }
						HStack { LabelDataTextview(label: "Company Name", data: $companyName) }
						HStack { LabelDataTextview_Numberpad_Currency(label: "Cost", data: $cost) }
					}
				}

				CardView {
					VStack {
						SectionText(label: "VEHICLE IDENTIFIERS")
						HStack { LabelDataTextview(label: "Tractor License #", data: $tractorLicensePlate) }
						HStack { LabelDataTextview(label: "Trailer License #", data: $trailerLicensePlate) }
						HStack { LabelDataTextview(label: "Tractor #", data: $tractorNumber) }
						HStack { LabelDataTextview(label: "Trailer #", data: $trailerNumber) }
					}
				}

				CardView {
					VStack {
						SectionText(label: "AXLE WEIGHTS")
						HStack { LabelDataTextview_Numberpad_Int(label: "Steer Axle (lbs)", data: $steerAxleWeight) }
						HStack { LabelDataTextview_Numberpad_Int(label: "Drive Axle (lbs)", data: $driveAxleWeight) }
						HStack { LabelDataTextview_Numberpad_Int(label: "Trailer Axle (lbs)", data: $trailerAxleWeight) }
						if grossWeight > 0 {
							HStack { LabelDataText(label: "Gross Weight", data: "\(grossWeight) lbs") }
						}
						if steerAxleWeight > 0 || driveAxleWeight > 0 {
							Button("Transfer Weights to Vehicle Record") {
								isPresentingTransferConfirm = true
							}
							.buttonStyle(GrowingButton(buttonColor: Color.blue))
							.confirmationDialog("Transfer weights to vehicle?", isPresented: $isPresentingTransferConfirm) {
								Button("Transfer") { transferToVehicle() }
							} message: {
								Text("This will overwrite the vehicle's front and rear Scale Weight Readings with the steer and drive axle values from this ticket.")
							}
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "TICKET GRAPHIC")
						HStack { Image_Edit(label: "Ticket", imageData: $ticketImage, imageDescription: $ticketImageDescription) }
					}
				}

				if ticket != nil {
					CardView {
						VStack {
							Button("Delete Scale Ticket", role: .destructive) {
								isPresentingDeleteConfirm = true
							}
							.buttonStyle(GrowingButton(buttonColor: Color.red))
							.confirmationDialog("Delete this scale ticket?", isPresented: $isPresentingDeleteConfirm) {
								Button("Delete", role: .destructive) {
									if let t = ticket {
										modelContext.delete(t)
										do {
											try modelContext.save()
											dismiss()
										} catch {
											ticketSaveErrorMessage = error.localizedDescription
											showTicketSaveError = true
										}
									} else {
										dismiss()
									}
								}
							} message: {
								Text("This action cannot be undone.")
							}
						}
					}
				}
			}
			.navigationTitle(ticket == nil ? "Add Scale Ticket" : "Edit Scale Ticket")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						saveTicket()
					}
				}
			}
			.alert("Couldn't Save", isPresented: $showTicketSaveError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(ticketSaveErrorMessage ?? "")
			}
		}
	}

	private func saveTicket() {
		if let existing = ticket {
			existing.date = date
			existing.ticketNumber = ticketNumber
			existing.weighNumber = weighNumber
			existing.location = location
			existing.tractorLicensePlate = tractorLicensePlate
			existing.trailerLicensePlate = trailerLicensePlate
			existing.companyName = companyName
			existing.tractorNumber = tractorNumber
			existing.trailerNumber = trailerNumber
			existing.costDecimal = Double(cost)
			existing.steerAxleWeight = steerAxleWeight
			existing.driveAxleWeight = driveAxleWeight
			existing.trailerAxleWeight = trailerAxleWeight
			existing.ticketImage = ticketImage
			existing.ticketImageDescription = ticketImageDescription
			existing.updatedAt = Date()
		} else {
			let newTicket = VehicleScaleTicket(
				vehicleId: vehicleId,
				date: date,
				ticketNumber: ticketNumber,
				weighNumber: weighNumber,
				location: location,
				tractorLicensePlate: tractorLicensePlate,
				trailerLicensePlate: trailerLicensePlate,
				companyName: companyName,
				tractorNumber: tractorNumber,
				trailerNumber: trailerNumber,
				costDecimal: Double(cost),
				steerAxleWeight: steerAxleWeight,
				driveAxleWeight: driveAxleWeight,
				trailerAxleWeight: trailerAxleWeight,
				ticketImage: ticketImage,
				ticketImageDescription: ticketImageDescription
			)
			modelContext.insert(newTicket)
		}
		do {
			try modelContext.save()
			dismiss()
		} catch {
			ticketSaveErrorMessage = error.localizedDescription
			showTicketSaveError = true
		}
	}

	private func transferToVehicle() {
		let vid = vehicleId
		let fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == vid })
		guard let vehicle = (try? modelContext.fetch(fd))?.first else { return }
		if steerAxleWeight > 0 { vehicle.scaleWeightFrontAxle = steerAxleWeight }
		if driveAxleWeight > 0 { vehicle.scaleWeightRearAxle = driveAxleWeight }
		let vehicleTotal = steerAxleWeight + driveAxleWeight
		if vehicleTotal > 0 { vehicle.weight = vehicleTotal }
		vehicle.dateWeighed = date
		do {
			try modelContext.save()
		} catch {
			ticketSaveErrorMessage = error.localizedDescription
			showTicketSaveError = true
		}
	}
}
