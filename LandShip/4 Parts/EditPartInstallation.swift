//
//  EditPartInstallation.swift
//  LandShip
//
//  Sheet-based form for adding or editing one PartInstallation segment — an install→removal
//  event for a part on a vehicle. Presented from EditParts (fixedPartName set, vehicle picked
//  freely) or from EditVehicle (fixedVehicleId set, part picked freely) — never both fixed at
//  once, since exactly one side is already known from where the sheet was opened.
//
//  Opening/closing TSN/TSO/TSR/cycle balances are computed here via PartTimeMath, not typed
//  by the user — see PartTimeMath.swift for the one-segment-deep derivation this feeds.
//  AeroTrax only — see Vertical.enabledFeatures.partCompliance.
//

import SwiftUI
import SwiftData

struct EditPartInstallation: View {
	let installation: PartInstallation?
	let fixedPartName: String?
	let fixedVehicleId: String?

	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	@State private var partName: String
	@State private var vehicleId: String
	@State private var position: String
	@State private var nextHigherAssembly: String
	@State private var installDate: Date
	@State private var installMeterKnown: Bool
	@State private var installMeterHours: Float
	@State private var installMeterCycles: Int
	@State private var installedBy: String
	@State private var meterTimeBase: String
	@State private var zeroedTSNAtInstall: Bool
	@State private var zeroedTSOAtInstall: Bool
	@State private var zeroedTSRAtInstall: Bool
	@State private var isRemoved: Bool
	@State private var removalDate: Date
	@State private var removalMeterKnown: Bool
	@State private var removalMeterHours: Float
	@State private var removalMeterCycles: Int
	@State private var removalReason: String
	@State private var removedBy: String
	@State private var notes: String

	@State private var selectedPart: MxParts1?
	@State private var selectedVehicle: Vehicle8?

	@State private var isPresentingDeleteConfirm = false
	@State private var showSaveError = false
	@State private var saveErrorMessage: String?

	@Query private var allParts: [MxParts1]
	@Query private var allVehicles: [Vehicle8]

	init(installation: PartInstallation? = nil, fixedPartName: String? = nil, fixedVehicleId: String? = nil) {
		self.installation = installation
		self.fixedPartName = fixedPartName
		self.fixedVehicleId = fixedVehicleId
		self._partName = State(initialValue: installation?.partName ?? fixedPartName ?? "")
		self._vehicleId = State(initialValue: installation?.vehicleId ?? fixedVehicleId ?? "")
		self._position = State(initialValue: installation?.position ?? "")
		self._nextHigherAssembly = State(initialValue: installation?.nextHigherAssembly ?? "")
		self._installDate = State(initialValue: installation?.installDate ?? Date())
		self._installMeterKnown = State(initialValue: installation?.installMeterKnown ?? false)
		self._installMeterHours = State(initialValue: installation?.installMeterHours ?? 0)
		self._installMeterCycles = State(initialValue: installation?.installMeterCycles ?? 0)
		self._installedBy = State(initialValue: installation?.installedBy ?? "")
		self._meterTimeBase = State(initialValue: installation?.meterTimeBase ?? "")
		self._zeroedTSNAtInstall = State(initialValue: installation?.zeroedTSNAtInstall ?? false)
		self._zeroedTSOAtInstall = State(initialValue: installation?.zeroedTSOAtInstall ?? false)
		self._zeroedTSRAtInstall = State(initialValue: installation?.zeroedTSRAtInstall ?? false)
		self._isRemoved = State(initialValue: installation?.removalDate != nil)
		self._removalDate = State(initialValue: installation?.removalDate ?? Date())
		self._removalMeterKnown = State(initialValue: installation?.removalMeterKnown ?? false)
		self._removalMeterHours = State(initialValue: installation?.removalMeterHours ?? 0)
		self._removalMeterCycles = State(initialValue: installation?.removalMeterCycles ?? 0)
		self._removalReason = State(initialValue: installation?.removalReason ?? "")
		self._removedBy = State(initialValue: installation?.removedBy ?? "")
		self._notes = State(initialValue: installation?.notes ?? "")
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "INSTALLATION")

						if let fixedPartName {
							HStack{LabelDataText(label: "Part", data: fixedPartName)}
						} else {
							LabeledContent {
								ModelPicker<MxParts1>(
									selection: $selectedPart,
									title: "Part",
									includeEmptyChoice: true,
									emptyChoiceLabel: "—",
									autoSelectFirst: false,
									sort: [SortDescriptor(\.partName, order: .forward)],
									labelProvider: { $0.partName },
									onSelectionChanged: { sel in partName = sel?.partName ?? "" }
								)
								.fixedSize(horizontal: true, vertical: true)
							} label: {
								Text("Part").textLabelModified()
							}
						}

						if let fixedVehicleId {
							HStack{LabelDataText(label: Vertical.current.assetSingular, data: Functions().getVehicleDisplayName(vehicleId: fixedVehicleId, context: modelContext))}
						} else {
							LabeledContent {
								ModelPicker<Vehicle8>(
									selection: $selectedVehicle,
									title: Vertical.current.assetSingular,
									includeEmptyChoice: true,
									emptyChoiceLabel: "—",
									autoSelectFirst: false,
									sort: [SortDescriptor(\.name, order: .forward)],
									labelProvider: { v in "\(v.year) \(v.displayName)" },
									thumbnailData: { $0.image1 },
									onSelectionChanged: { sel in
										vehicleId = sel?.name ?? ""
										if meterTimeBase.isEmpty { meterTimeBase = sel?.hoursMeterType ?? "" }
										if installation == nil, !installMeterKnown, let hrs = sel?.engHours, hrs > 0 {
											installMeterHours = hrs
											installMeterKnown = true
										}
									}
								)
								.fixedSize(horizontal: true, vertical: true)
							} label: {
								Text(Vertical.current.assetSingular).textLabelModified()
							}
						}

						HStack{LabelDataTextview(label: "Position", data: $position)}
						HStack{LabelDataTextview(label: "Next Higher Assembly", data: $nextHigherAssembly)}
						HStack{LabelDataPicker_Date(label: "Install Date", data: $installDate)}
						HStack{LabelDataToggle(label: "Install Meter Recorded", data: $installMeterKnown)}
						if installMeterKnown {
							HStack{LabelDataTextview_Numberpad_Float(label: "Install Meter Hours", data: $installMeterHours)}
							HStack{LabelDataTextview_Numberpad_Int(label: "Install Meter Cycles", data: $installMeterCycles)}
						}
						HStack{LabelDataTextview(label: "Installed By", data: $installedBy)}
						HStack {
							Text("Time Base").textLabelModified()
							Picker("", selection: $meterTimeBase) {
								Text("—").tag("")
								ForEach(PartTimeBase.allCases) { base in
									Text(base.rawValue).tag(base.rawValue)
								}
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "OPENING BALANCE PROVENANCE")
						HStack{LabelDataToggle(label: "Rebuilt to Zero Time (TSN) — 43.2(b)", data: $zeroedTSNAtInstall)}
						HStack{LabelDataToggle(label: "Installed After Overhaul (TSO)", data: $zeroedTSOAtInstall)}
						HStack{LabelDataToggle(label: "Installed After Repair (TSR)", data: $zeroedTSRAtInstall)}
						Text("These declare what resets at this install — never inferred. Whichever counters aren't reset carry forward from this part's prior installation, or its carry-in values if this is the first.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
				}

				CardView {
					VStack {
						SectionText(label: "REMOVAL")
						HStack{LabelDataToggle(label: "Removed", data: $isRemoved)}
						if isRemoved {
							HStack{LabelDataPicker_Date(label: "Removal Date", data: $removalDate)}
							HStack{LabelDataToggle(label: "Removal Meter Recorded", data: $removalMeterKnown)}
							if removalMeterKnown {
								HStack{LabelDataTextview_Numberpad_Float(label: "Removal Meter Hours", data: $removalMeterHours)}
								HStack{LabelDataTextview_Numberpad_Int(label: "Removal Meter Cycles", data: $removalMeterCycles)}
							}
							HStack {
								Text("Removal Reason").textLabelModified()
								Picker("", selection: $removalReason) {
									Text("—").tag("")
									ForEach(RemovalReason.allCases) { reason in
										Text(reason.rawValue).tag(reason.rawValue)
									}
								}
								.pickerStyle(.automatic)
								.frame(maxWidth: .infinity, alignment: .trailing)
							}
							HStack{LabelDataTextview(label: "Removed By", data: $removedBy)}
						}
					}
				}

				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "NOTES", prompt: "Enter notes...", data: $notes)
				}

				if installation != nil {
					CardView {
						VStack {
							Button("Delete Installation Record", role: .destructive) {
								isPresentingDeleteConfirm = true
							}
							.buttonStyle(GrowingButton(buttonColor: Color.red))
							.confirmationDialog("Delete this installation record?", isPresented: $isPresentingDeleteConfirm) {
								Button("Delete", role: .destructive) { deleteInstallation() }
								Button("Cancel", role: .cancel) {}
							} message: {
								Text("This action cannot be undone.")
							}
						}
					}
				}
			}
			.onAppear {
				if fixedPartName == nil {
					selectedPart = allParts.first(where: { $0.partName == partName })
				}
				if fixedVehicleId == nil {
					selectedVehicle = allVehicles.first(where: { $0.name == vehicleId })
				}
			}
			.navigationTitle(installation == nil ? "Add Installation" : "Edit Installation")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") { saveInstallation() }
						.disabled(partName.trimmingCharacters(in: .whitespaces).isEmpty || vehicleId.isEmpty)
				}
			}
			.alert("Couldn't Save", isPresented: $showSaveError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(saveErrorMessage ?? "")
			}
		}
	}

	/// The most recently closed segment for this part, excluding the one being edited —
	/// its frozen closing balances are this installation's opening balances unless the
	/// zeroed-at-install toggles say otherwise. Assumes segments are entered in
	/// chronological order; out-of-order historical backfill isn't reconciled, matching
	/// the maturity of recomputeNextDue elsewhere in the app.
	private func previousClosedSegment() -> InstallSegment? {
		let history = Functions().loadInstallationHistory(context: modelContext, partName: partName)
			.filter { $0.removalDate != nil }
			.filter { installation == nil || $0.persistentModelID != installation!.persistentModelID }
		return history
			.sorted { ($0.removalDate ?? .distantPast) > ($1.removalDate ?? .distantPast) }
			.first
			.map(InstallSegment.init(model:))
	}

	private func saveInstallation() {
		let trimmedPart = partName.trimmingCharacters(in: .whitespaces)
		guard !trimmedPart.isEmpty, !vehicleId.isEmpty else { return }

		var partFD = FetchDescriptor<MxParts1>(predicate: #Predicate<MxParts1> { $0.partName == trimmedPart })
		partFD.fetchLimit = 1
		let part = (try? modelContext.fetch(partFD))?.first
		let carryIn = PartCarryIn(
			tsn: part?.carryInTSN ?? 0, csn: part?.carryInCSN ?? 0,
			tso: part?.carryInTSO ?? 0, cso: part?.carryInCSO ?? 0,
			tsr: part?.carryInTSR ?? 0, limitTimeBase: part?.limitTimeBase ?? ""
		)

		let opening = PartTimeMath.openingBalances(
			carryIn: carryIn,
			previousSegment: previousClosedSegment(),
			zeroTSN: zeroedTSNAtInstall,
			zeroTSO: zeroedTSOAtInstall,
			zeroTSR: zeroedTSRAtInstall
		)

		var closing: (tsn: Float, csn: Int, tso: Float, cso: Int, tsr: Float) = (0, 0, 0, 0, 0)
		if isRemoved {
			let segmentSoFar = InstallSegment(
				installDate: installDate, installMeterHours: installMeterHours, installMeterKnown: installMeterKnown,
				installMeterCycles: installMeterCycles,
				openingTSN: opening.tsn, openingCSN: opening.csn, openingTSO: opening.tso, openingCSO: opening.cso, openingTSR: opening.tsr,
				vehicleId: vehicleId, position: position, meterTimeBase: meterTimeBase
			)
			closing = PartTimeMath.closingBalances(for: segmentSoFar, removalMeterHours: removalMeterHours, removalMeterCycles: removalMeterCycles)
		}

		if let existing = installation {
			existing.partName = trimmedPart
			existing.vehicleId = vehicleId
			existing.position = position
			existing.nextHigherAssembly = nextHigherAssembly
			existing.installDate = installDate
			existing.installMeterHours = installMeterHours
			existing.installMeterKnown = installMeterKnown
			existing.installMeterCycles = installMeterCycles
			existing.installedBy = installedBy
			existing.meterTimeBase = meterTimeBase
			existing.openingTSN = opening.tsn
			existing.openingCSN = opening.csn
			existing.openingTSO = opening.tso
			existing.openingCSO = opening.cso
			existing.openingTSR = opening.tsr
			existing.zeroedTSNAtInstall = zeroedTSNAtInstall
			existing.zeroedTSOAtInstall = zeroedTSOAtInstall
			existing.zeroedTSRAtInstall = zeroedTSRAtInstall
			existing.removalDate = isRemoved ? removalDate : nil
			existing.removalMeterHours = isRemoved ? removalMeterHours : 0
			existing.removalMeterKnown = isRemoved ? removalMeterKnown : false
			existing.removalMeterCycles = isRemoved ? removalMeterCycles : 0
			existing.removalReason = isRemoved ? removalReason : ""
			existing.removedBy = isRemoved ? removedBy : ""
			existing.closingTSN = isRemoved ? closing.tsn : 0
			existing.closingCSN = isRemoved ? closing.csn : 0
			existing.closingTSO = isRemoved ? closing.tso : 0
			existing.closingCSO = isRemoved ? closing.cso : 0
			existing.closingTSR = isRemoved ? closing.tsr : 0
			existing.notes = notes
			existing.updatedAt = Date()
		} else {
			let new = PartInstallation(
				vehicleId: vehicleId,
				partName: trimmedPart,
				position: position,
				nextHigherAssembly: nextHigherAssembly,
				installDate: installDate,
				installMeterHours: installMeterHours,
				installMeterKnown: installMeterKnown,
				installMeterCycles: installMeterCycles,
				installedBy: installedBy,
				meterTimeBase: meterTimeBase,
				openingTSN: opening.tsn,
				openingCSN: opening.csn,
				openingTSO: opening.tso,
				openingCSO: opening.cso,
				openingTSR: opening.tsr,
				zeroedTSOAtInstall: zeroedTSOAtInstall,
				zeroedTSNAtInstall: zeroedTSNAtInstall,
				zeroedTSRAtInstall: zeroedTSRAtInstall,
				removalDate: isRemoved ? removalDate : nil,
				removalMeterHours: isRemoved ? removalMeterHours : 0,
				removalMeterKnown: isRemoved ? removalMeterKnown : false,
				removalMeterCycles: isRemoved ? removalMeterCycles : 0,
				removalReason: isRemoved ? removalReason : "",
				removedBy: isRemoved ? removedBy : "",
				closingTSN: isRemoved ? closing.tsn : 0,
				closingCSN: isRemoved ? closing.csn : 0,
				closingTSO: isRemoved ? closing.tso : 0,
				closingCSO: isRemoved ? closing.cso : 0,
				closingTSR: isRemoved ? closing.tsr : 0,
				notes: notes
			)
			modelContext.insert(new)
		}

		do {
			try modelContext.save()
			dismiss()
		} catch {
			saveErrorMessage = error.localizedDescription
			showSaveError = true
		}
	}

	private func deleteInstallation() {
		guard let existing = installation else { return }
		modelContext.delete(existing)
		do {
			try modelContext.save()
			dismiss()
		} catch {
			saveErrorMessage = error.localizedDescription
			showSaveError = true
		}
	}
}
