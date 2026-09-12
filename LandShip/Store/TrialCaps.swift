//
//  TrialCaps.swift
//  LandShip
//

import SwiftData

/// Models subject to a free-trial record cap. Conformance (not a dictionary)
/// makes exemptions — e.g. Settings1 — a compile-time guarantee: an
/// unconforming type simply cannot be passed to a gate.
protocol TrialCapped: PersistentModel {
	static var trialLimit: Int { get }
	static var trialDisplayName: String { get }          // plural, user-facing: "Parts"
	static func trialFetchCount(in context: ModelContext) throws -> Int
	static var trialUsageKey: String { get }
}

extension TrialCapped {
	/// Live count. Never persist this — restore-from-backup and CloudKit sync
	/// both create records without going through this insert path, so a cached
	/// counter would go stale. Declared as a protocol requirement (not a bare
	/// extension method) so it dispatches dynamically through `any TrialCapped.Type`.
	static func trialFetchCount(in context: ModelContext) throws -> Int {
		try context.fetchCount(FetchDescriptor<Self>())
	}

	static var trialUsageKey: String { String(describing: Self.self) }
}

extension Vehicle8:           TrialCapped { static let trialLimit = 2;  static var trialDisplayName: String { Vertical.current.assetPlural } }
extension MxParts1:           TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Parts" }
extension FuelLog1:           TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Fuel Log entries" }
extension TripLog2:           TrialCapped { static let trialLimit = 10; static var trialDisplayName: String { "\(Vertical.current.travelLogLabel) entries" } }
extension ServiceRecords1:    TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Service Records" }
extension MxItems3:           TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Service Items" }
extension VehicleSystems1:    TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Systems" }
extension Vendors1:           TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Vendors" }
extension Additions:          TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Improvements" }
extension Subscriptions:      TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Expenditures" }
extension ProjectList:        TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Project items" }
extension CheckList:          TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Checklists" }
extension CheckListItem:      TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Checklist items" }
extension VehicleWarranty:    TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Warranties" }
extension VehicleScaleTicket: TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Scale Tickets" }
extension VehicleSerialItem:  TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Serial Numbers" }
extension AirworthinessDirective: TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Airworthiness Directives" }
extension InspectionCycle:    TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Inspections" }
extension ComponentTimes:     TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Component Times" }
extension HaulOutRecord:      TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Haul-Out Records" }
extension SurveyRecord:       TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Survey Records" }
extension PilotLogbookEntry:  TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Logbook Entries" }
extension SeaServiceEntry:    TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Sea Service Entries" }
extension PartInstallation:   TrialCapped { static let trialLimit = 10; static let trialDisplayName = "Installations" }
extension RecordAttachment:   TrialCapped { static let trialLimit = 5;  static let trialDisplayName = "Attachments" }
// Settings1, PilotCertification, MarinerCredential deliberately do NOT conform — singleton
// profile records, exempt from trial caps by construction.

/// Drives the paywall's usage table and the over-cap safety net. Mirrors
/// AppSchema.modelTypes (8 BackupRestore.swift) minus Settings1 — keep the two
/// lists in sync when models are added or removed.
enum TrialCaps {
	static let allCapped: [any TrialCapped.Type] = [
		Vehicle8.self, MxParts1.self, FuelLog1.self, TripLog2.self, ServiceRecords1.self,
		MxItems3.self, VehicleSystems1.self, Vendors1.self, Additions.self, Subscriptions.self,
		ProjectList.self, CheckList.self, CheckListItem.self,
		VehicleWarranty.self, VehicleScaleTicket.self, VehicleSerialItem.self,
		AirworthinessDirective.self, InspectionCycle.self, ComponentTimes.self,
		HaulOutRecord.self, SurveyRecord.self,
		PilotLogbookEntry.self, SeaServiceEntry.self,
		PartInstallation.self, RecordAttachment.self
	]
}
