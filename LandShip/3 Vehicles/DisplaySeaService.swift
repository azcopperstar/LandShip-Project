//
//  DisplaySeaService.swift
//  LandShip
//
//  A list-based browser for SeaServiceEntry records — the mariner's own sea service log
//  toward Merchant Mariner Credential requirements, distinct from Voyage Log (TripLog2, which
//  tracks the vessel). Not vehicle-scoped: a mariner's sea service spans every vessel they've
//  served on, so this shows the whole chronological history rather than filtering to one
//  vessel. NauticalTrax only (see Vertical.enabledFeatures). Mirrors DisplayPilotLogbook.swift.
//

import SwiftUI
import SwiftData

struct DisplaySeaService: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.entitlements) private var entitlements

	@State private var newRecordToEdit: SeaServiceEntry?
	@State private var showingCredential: Bool = false
	@State private var isShowingPDFReport: Bool = false

	private enum LogSort: String, CaseIterable, Identifiable {
		case dateDesc = "Date ↓"
		case dateAsc = "Date ↑"
		var id: String { rawValue }
		var sortDescriptor: SortDescriptor<SeaServiceEntry> {
			switch self {
				case .dateDesc: return .init(\.date, order: .reverse)
				case .dateAsc: return .init(\.date, order: .forward)
			}
		}
	}
	@AppStorage("sort_seaService") private var selectedSort: LogSort = .dateDesc

	let functions = Functions()

	var body: some View {
		Color.clear
			.frame(height: 0)
			.safeAreaInset(edge: .top) {
				PageTitle_Col2_NoPhoto(label: "SEA SERVICE LOG")
			}

		QueryView(for: SeaServiceEntry.self,
		          sort: [selectedSort.sortDescriptor],
		          content: { records in
			Group {
				if records.isEmpty {
					List {
						EmptyStateSection(
							title: "Add your first sea service entry",
							systemImage: "book.closed",
							description: "Log each voyage — date, vessel, waters, and days of service — to build your sea time toward a Merchant Mariner Credential.\n\nTo add additional entries after this first one, select the '+' button at the top of the form.",
							actionTitle: "Add First Entry",
							action: { addNewRecord() }
						)
					}
				} else {
					Section {
						List {
							ForEach(records) { record in
								NavigationLink {
									EditSeaServiceEntry(entry: record)
										.id(record.persistentModelID)
								} label: {
									VStack(alignment: .leading, spacing: 1) {
										Text(functions.formatDate_DDMMMyy(date: record.date))
											.font(.headline)
										Text(vesselDisplay(record))
											.font(.subheadline)
											.foregroundStyle(.secondary)
										if !record.capacityServed.isEmpty {
											Text(record.capacityServed)
												.font(.subheadline)
												.foregroundStyle(.secondary)
										}
										Text("Days of Service: \(record.daysOfService, specifier: "%.1f")")
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
									showingCredential = true
								} label: {
#if os(macOS)
									Image(systemName: "person.text.rectangle")
#else
									VStack(spacing: 2) {
										Image(systemName: "person.text.rectangle")
										Text("Credential").font(.caption2)
									}
#endif
								}
								.help("Credential & Currency")
								.accessibilityLabel("Credential & Currency")
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
								.accessibilityLabel("Sort sea service entries")
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
			EditSeaServiceEntry(entry: record)
				.id(record.persistentModelID)
		}
		.navigationDestination(isPresented: $isShowingPDFReport) {
			pdfReportSeaService()
				.ignoresSafeArea()
		}
		.sheet(isPresented: $showingCredential) {
			NavigationStack {
				EditMarinerCredential()
					.toolbar {
						ToolbarItem(placement: .cancellationAction) {
							Button("Close") { showingCredential = false }
						}
					}
			}
		}
	}

	private func vesselDisplay(_ record: SeaServiceEntry) -> String {
		if !record.vehicleId.isEmpty {
			return functions.getVehicleDisplayName(vehicleId: record.vehicleId, context: modelContext)
		}
		return record.vesselIdentifier.isEmpty ? "—" : record.vesselIdentifier
	}

	@MainActor
	private func addNewRecord() {
		guard entitlements.requestCreate(SeaServiceEntry.self, in: modelContext) else { return }
		let newRecord = SeaServiceEntry()
		modelContext.insert(newRecord)
		do {
			try modelContext.save()
			newRecordToEdit = newRecord
		} catch {
			print("Failed to save new sea service entry: \(error.localizedDescription)")
		}
	}

	@MainActor
	private func delete(at offsets: IndexSet) {
		do {
			let fetch = FetchDescriptor<SeaServiceEntry>(sortBy: [selectedSort.sortDescriptor])
			let current = try modelContext.fetch(fetch)
			let toDelete = offsets.compactMap { idx in current.indices.contains(idx) ? current[idx] : nil }
			withAnimation {
				for item in toDelete {
					modelContext.delete(item)
				}
			}
			try modelContext.save()
		} catch {
			print("Failed to delete sea service entry(s): \(error.localizedDescription)")
		}
	}
}
