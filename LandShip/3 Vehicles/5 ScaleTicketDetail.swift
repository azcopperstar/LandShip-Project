//
//  5 ScaleTicketDetail.swift
//  LandShip
//
//  ScaleTicketRow: compact date+weight row that owns its own sheet for detail display.
//  ScaleTicketDetailView: read-only popup showing all fields for a single VehicleScaleTicket.
//
//  Each row manages its own sheet so there is no conflict with other sheets on the parent view.
//  The Edit button in the detail popup calls onEdit(_:) which lets the parent open EditScaleTicket.
//

import SwiftUI

// MARK: - Compact row + owned sheet

struct ScaleTicketRow: View {
	let ticket: VehicleScaleTicket
	let onEdit: (VehicleScaleTicket) -> Void
	let functions = Functions()

	@State private var showDetail = false

	var body: some View {
		Button {
			showDetail = true
		} label: {
			HStack {
				Text(functions.formatDate_DDMMMyy(date: ticket.date))
					.font(.subheadline)
					.bold()
					.foregroundStyle(.primary)
				Spacer()
				if ticket.grossWeight > 0 {
					Text("\(ticket.grossWeight) lbs")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				Image(systemName: "chevron.right")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
		.buttonStyle(.plain)
		.sheet(isPresented: $showDetail) {
			ScaleTicketDetailView(ticket: ticket) {
				showDetail = false
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
					onEdit(ticket)
				}
			}
		}
	}
}

// MARK: - Read-only detail popup

struct ScaleTicketDetailView: View {
	@Environment(\.dismiss) var dismiss
	let onEdit: () -> Void
	let functions: Functions = Functions()

	@State private var date: Date
	@State private var ticketNumber: String
	@State private var weighNumber: String
	@State private var location: String
	@State private var companyName: String
	@State private var cost: Int
	@State private var costDecimal: Double
	@State private var tractorLicensePlate: String
	@State private var trailerLicensePlate: String
	@State private var tractorNumber: String
	@State private var trailerNumber: String
	@State private var steerAxleWeight: Int
	@State private var driveAxleWeight: Int
	@State private var trailerAxleWeight: Int
	@State private var grossWeight: Int
	@State private var ticketImage: Data?
	@State private var ticketImageDescription: String

	init(ticket: VehicleScaleTicket, onEdit: @escaping () -> Void) {
		self.onEdit = onEdit
		self._date = State(initialValue: ticket.date)
		self._ticketNumber = State(initialValue: ticket.ticketNumber)
		self._weighNumber = State(initialValue: ticket.weighNumber)
		self._location = State(initialValue: ticket.location)
		self._companyName = State(initialValue: ticket.companyName)
		self._cost = State(initialValue: ticket.cost)
		self._costDecimal = State(initialValue: ticket.costDecimal)
		self._tractorLicensePlate = State(initialValue: ticket.tractorLicensePlate)
		self._trailerLicensePlate = State(initialValue: ticket.trailerLicensePlate)
		self._tractorNumber = State(initialValue: ticket.tractorNumber)
		self._trailerNumber = State(initialValue: ticket.trailerNumber)
		self._steerAxleWeight = State(initialValue: ticket.steerAxleWeight)
		self._driveAxleWeight = State(initialValue: ticket.driveAxleWeight)
		self._trailerAxleWeight = State(initialValue: ticket.trailerAxleWeight)
		self._grossWeight = State(initialValue: ticket.grossWeight)
		self._ticketImage = State(initialValue: ticket.ticketImage)
		self._ticketImageDescription = State(initialValue: ticket.ticketImageDescription)
	}

	private var hasIdentifiers: Bool {
		!tractorLicensePlate.isEmpty || !trailerLicensePlate.isEmpty ||
		!tractorNumber.isEmpty || !trailerNumber.isEmpty
	}

	private var effectiveCost: Float {
		costDecimal > 0 ? Float(costDecimal) : Float(cost)
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "SCALE TICKET INFO")
						HStack { LabelDataText(label: "Date", data: functions.formatDate_DDMMMyy(date: date)) }
						if !ticketNumber.isEmpty {
							HStack { LabelDataText(label: "Ticket #", data: ticketNumber) }
						}
						if !weighNumber.isEmpty {
							HStack { LabelDataText(label: "Weigh #", data: weighNumber) }
						}
						if !location.isEmpty {
							HStack { LabelDataText(label: "Location", data: location) }
						}
						if !companyName.isEmpty {
							HStack { LabelDataText(label: "Company", data: companyName) }
						}
						if effectiveCost > 0 {
							HStack { LabelDataCurrency(label: "Cost", data: effectiveCost, unit: "") }
						}
					}
				}

				if hasIdentifiers {
					CardView {
						VStack {
							SectionText(label: "\(Vertical.current.assetSingular.uppercased()) IDENTIFIERS")
							if !tractorLicensePlate.isEmpty {
								HStack { LabelDataText(label: "Tractor License #", data: tractorLicensePlate) }
							}
							if !trailerLicensePlate.isEmpty {
								HStack { LabelDataText(label: "Trailer License #", data: trailerLicensePlate) }
							}
							if !tractorNumber.isEmpty {
								HStack { LabelDataText(label: "Tractor #", data: tractorNumber) }
							}
							if !trailerNumber.isEmpty {
								HStack { LabelDataText(label: "Trailer #", data: trailerNumber) }
							}
						}
					}
				}

				if steerAxleWeight > 0 || driveAxleWeight > 0 || trailerAxleWeight > 0 {
					CardView {
						VStack {
							SectionText(label: "AXLE WEIGHTS")
							if steerAxleWeight > 0 {
								HStack { LabelDataText(label: "Steer Axle", data: "\(steerAxleWeight) lbs") }
							}
							if driveAxleWeight > 0 {
								HStack { LabelDataText(label: "Drive Axle(s)", data: "\(driveAxleWeight) lbs") }
							}
							if trailerAxleWeight > 0 {
								HStack { LabelDataText(label: "Trailer Axle(s)", data: "\(trailerAxleWeight) lbs") }
							}
							if grossWeight > 0 {
								HStack { LabelDataText(label: "Gross Weight", data: "\(grossWeight) lbs") }
							}
						}
					}
				}

				if ticketImage != nil {
					CardView {
						VStack {
							SectionText(label: "TICKET GRAPHIC")
							Image_View_Details(label: "Ticket", imageData: ticketImage, imageDescription: ticketImageDescription)
						}
					}
				}
			}
			.navigationTitle("Scale Ticket")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Close") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Edit") { onEdit() }
				}
			}
		}
	}
}
