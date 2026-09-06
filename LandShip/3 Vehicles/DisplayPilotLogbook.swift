//
//  DisplayPilotLogbook.swift
//  LandShip
//
//  A list-based browser for PilotLogbookEntry records — the pilot's own flight log, distinct
//  from Flight Log (TripLog2, which tracks the aircraft). Not vehicle-scoped: a pilot's logbook
//  spans every aircraft they've flown, so this shows the whole chronological history rather than
//  filtering to one aircraft. AeroTrax only (see Vertical.enabledFeatures). Mirrors
//  DisplayVendors.swift's structure (the app's other non-vehicle-scoped list screen).
//

import SwiftUI
import SwiftData

struct DisplayPilotLogbook: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.entitlements) private var entitlements

	@State private var newRecordToEdit: PilotLogbookEntry?
	@State private var showingCertification: Bool = false
	@State private var isShowingPDFReport: Bool = false

	private enum LogSort: String, CaseIterable, Identifiable {
		case dateDesc = "Date ↓"
		case dateAsc = "Date ↑"
		var id: String { rawValue }
		var sortDescriptor: SortDescriptor<PilotLogbookEntry> {
			switch self {
				case .dateDesc: return .init(\.date, order: .reverse)
				case .dateAsc: return .init(\.date, order: .forward)
			}
		}
	}
	@AppStorage("sort_pilotLogbook") private var selectedSort: LogSort = .dateDesc

	let functions = Functions()

	var body: some View {
		Color.clear
			.frame(height: 0)
			.safeAreaInset(edge: .top) {
				PageTitle_Col2_NoPhoto(label: "PILOT LOGBOOK")
			}

		QueryView(for: PilotLogbookEntry.self,
		          sort: [selectedSort.sortDescriptor],
		          content: { records in
			Group {
				if records.isEmpty {
					List {
						EmptyStateSection(
							title: "Add your first logbook entry",
							systemImage: "book.closed",
							description: "Log each flight — date, aircraft, route, and time breakdown — to build your currency and totals.\n\nTo add additional entries after this first one, select the '+' button at the top of the form.",
							actionTitle: "Add First Entry",
							action: { addNewRecord() }
						)
					}
				} else {
					Section {
						List {
							ForEach(records) { record in
								NavigationLink {
									EditPilotLogbookEntry(entry: record)
										.id(record.persistentModelID)
								} label: {
									VStack(alignment: .leading, spacing: 1) {
										Text(functions.formatDate_DDMMMyy(date: record.date))
											.font(.headline)
										Text(aircraftDisplay(record))
											.font(.subheadline)
											.foregroundStyle(.secondary)
										if !record.departureLocation.isEmpty || !record.arrivalLocation.isEmpty {
											Text("\(record.departureLocation) → \(record.arrivalLocation)")
												.font(.subheadline)
												.foregroundStyle(.secondary)
										}
										Text("Total Time: \(record.totalTime, specifier: "%.1f")")
											.font(.subheadline)
											.foregroundStyle(.secondary)
									}
									.cardStyle(backgroundColor: .blue.opacity(0.6))
								}
							}
							.onDelete(perform: delete)
						}
						.textModifier_ListDivider()
						.toolbar {
							ToolbarItem(placement: .automatic) {
								Button {
									isShowingPDFReport = true
								} label: {
#if os(macOS)
									Image(systemName: "doc.text")
#else
									VStack(spacing: 2) {
										Image(systemName: "doc.text")
										Text("Report").font(.caption2)
									}
#endif
								}
								.help("Report")
								.accessibilityLabel("Report")
							}
							ToolbarItem(placement: .automatic) {
								Button {
									showingCertification = true
								} label: {
#if os(macOS)
									Image(systemName: "person.text.rectangle")
#else
									VStack(spacing: 2) {
										Image(systemName: "person.text.rectangle")
										Text("Certificate").font(.caption2)
									}
#endif
								}
								.help("Certificate & Currency")
								.accessibilityLabel("Certificate & Currency")
							}
							ToolbarItem(placement: .automatic) {
								Menu {
									Picker("Sort by", selection: $selectedSort) {
										ForEach(LogSort.allCases) { sortCase in
											Text(sortCase.rawValue).tag(sortCase)
										}
									}
								} label: {
#if os(macOS)
									Image(systemName: "arrow.up.arrow.down")
#else
									VStack(spacing: 2) {
										Image(systemName: "arrow.up.arrow.down")
										Text("Sort").font(.caption2)
									}
#endif
								}
								.buttonStyle(GrowingButton(buttonColor: Color.gray))
								.help("Sort")
								.accessibilityLabel("Sort logbook entries")
							}
							ToolbarItem(placement: .automatic) {
								Button {
									addNewRecord()
								} label: {
#if os(macOS)
									Image(systemName: "plus.capsule")
#else
									VStack(spacing: 2) {
										Image(systemName: "plus.capsule")
										Text("Add").font(.caption2)
									}
#endif
								}
								.help("Add")
								.accessibilityLabel("Add")
							}
						}
					} header: {
						HStack(spacing: 6) {
							Image(systemName: "arrow.up.arrow.down")
							Text("Sort: \(selectedSort.rawValue)")
						}
						.font(.caption)
						.foregroundStyle(.secondary)
						.padding(.top, 4)
					}
				}
			}
		})
		.navigationDestination(item: $newRecordToEdit) { record in
			EditPilotLogbookEntry(entry: record)
				.id(record.persistentModelID)
		}
		.navigationDestination(isPresented: $isShowingPDFReport) {
			pdfReportPilotLogbook()
				.ignoresSafeArea()
		}
		.sheet(isPresented: $showingCertification) {
			NavigationStack {
				EditPilotCertification()
					.toolbar {
						ToolbarItem(placement: .cancellationAction) {
							Button("Close") { showingCertification = false }
						}
					}
			}
		}
	}

	private func aircraftDisplay(_ record: PilotLogbookEntry) -> String {
		if !record.vehicleId.isEmpty {
			return functions.getVehicleDisplayName(vehicleId: record.vehicleId, context: modelContext)
		}
		return record.aircraftIdentifier.isEmpty ? "—" : record.aircraftIdentifier
	}

	@MainActor
	private func addNewRecord() {
		guard entitlements.requestCreate(PilotLogbookEntry.self, in: modelContext) else { return }
		let newRecord = PilotLogbookEntry()
		modelContext.insert(newRecord)
		do {
			try modelContext.save()
			newRecordToEdit = newRecord
		} catch {
			print("Failed to save new logbook entry: \(error.localizedDescription)")
		}
	}

	@MainActor
	private func delete(at offsets: IndexSet) {
		do {
			let fetch = FetchDescriptor<PilotLogbookEntry>(sortBy: [selectedSort.sortDescriptor])
			let current = try modelContext.fetch(fetch)
			let toDelete = offsets.compactMap { idx in current.indices.contains(idx) ? current[idx] : nil }
			withAnimation {
				for item in toDelete {
					modelContext.delete(item)
				}
			}
			try modelContext.save()
		} catch {
			print("Failed to delete logbook entry(s): \(error.localizedDescription)")
		}
	}
}

#Preview("Pilot Logbook - Sample Data") {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: PilotLogbookEntry.self, PilotCertification.self, Vehicle8.self, configurations: config)
	let context = container.mainContext

	let vehicle = Vehicle8(name: "N12345", manufacturer: "Cessna", model: "172")
	context.insert(vehicle)

	let samples: [PilotLogbookEntry] = [
		PilotLogbookEntry(date: Date(), vehicleId: "N12345", departureLocation: "KPAO", arrivalLocation: "KSQL", totalTime: 1.2, picTime: 1.2, dayLandings: 3),
		PilotLogbookEntry(date: Date().addingTimeInterval(-86400 * 7), aircraftIdentifier: "N54321 (rental)", departureLocation: "KSQL", arrivalLocation: "KPAO", totalTime: 0.9, picTime: 0.9, nightTime: 0.9, nightLandings: 1)
	]
	samples.forEach { context.insert($0) }
	try? context.save()

	return NavigationStack {
		DisplayPilotLogbook()
	}
	.modelContainer(container)
}
