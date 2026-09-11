//
//  DirectiveResolution.swift
//  LandShip
//
//  Resolves which AirworthinessDirective rows apply to an aircraft: those keyed directly
//  to the vehicle, plus those keyed to a part number currently installed on it. Many ADs
//  are issued against a part number, not an aircraft model — an AD on a specific fuel pump
//  applies to every aircraft that pump is installed on, so this deliberately does NOT filter
//  the part-keyed fetch by vehicleId; that's the entire point of keying by part number.
//  AeroTrax only.
//

import Foundation
import SwiftData

struct ResolvedDirective: Identifiable {
	enum MatchBasis: Equatable {
		case aircraft
		case installedPart(partName: String, partNumber: String, position: String)
	}

	let id: PersistentIdentifier
	let directive: AirworthinessDirective
	let matchBasis: MatchBasis
	/// True when `appliesToSerialNumbers` is non-empty — the app does not parse S/N
	/// ranges (no standard format, unbounded rabbit hole), so the match is advisory and
	/// the UI must say so rather than presenting it as a confirmed hit.
	let needsSerialCheck: Bool
}

extension Functions {
	/// Every directive applicable to `vehicleId`: those keyed directly to the aircraft,
	/// plus those keyed to a part number currently installed on it (via an open
	/// PartInstallation segment).
	func loadApplicableDirectives(context: ModelContext, vehicleId: String) -> [ResolvedDirective] {
		guard !vehicleId.isEmpty else { return [] }

		let aircraftFD = FetchDescriptor<AirworthinessDirective>(
			predicate: #Predicate<AirworthinessDirective> { $0.vehicleId == vehicleId },
			sortBy: [SortDescriptor(\AirworthinessDirective.nextDueDate)]
		)
		let aircraftDirectives = (try? context.fetch(aircraftFD)) ?? []

		var resolved: [ResolvedDirective] = aircraftDirectives.map {
			ResolvedDirective(id: $0.persistentModelID, directive: $0, matchBasis: .aircraft, needsSerialCheck: !$0.appliesToSerialNumbers.isEmpty)
		}
		var seenIds = Set(resolved.map { $0.id })

		let installed = loadInstalledParts(context: context, vehicleId: vehicleId)
		guard !installed.isEmpty else { return resolved }

		let partNames = Array(Set(installed.map { $0.partName }))
		let partsFD = FetchDescriptor<MxParts1>(predicate: #Predicate<MxParts1> { partNames.contains($0.partName) })
		let parts = (try? context.fetch(partsFD)) ?? []
		var partNumberByName: [String: String] = [:]
		for part in parts where !part.partNumber.isEmpty { partNumberByName[part.partName] = part.partNumber }

		let partNumbers = Array(Set(partNumberByName.values))
		guard !partNumbers.isEmpty else { return resolved }

		let partFD = FetchDescriptor<AirworthinessDirective>(
			predicate: #Predicate<AirworthinessDirective> { partNumbers.contains($0.appliesToPartNumber) },
			sortBy: [SortDescriptor(\AirworthinessDirective.nextDueDate)]
		)
		let partDirectives = (try? context.fetch(partFD)) ?? []

		for directive in partDirectives {
			guard !seenIds.contains(directive.persistentModelID) else { continue }
			guard let installation = installed.first(where: { partNumberByName[$0.partName] == directive.appliesToPartNumber }) else { continue }
			resolved.append(ResolvedDirective(
				id: directive.persistentModelID,
				directive: directive,
				matchBasis: .installedPart(partName: installation.partName, partNumber: directive.appliesToPartNumber, position: installation.position),
				needsSerialCheck: !directive.appliesToSerialNumbers.isEmpty
			))
			seenIds.insert(directive.persistentModelID)
		}

		return resolved.sorted { $0.directive.nextDueDate < $1.directive.nextDueDate }
	}

	/// Every directive applicable to a part number, regardless of aircraft — surfaced on
	/// the part's own detail view so an AD entered while a magneto was on N12345 is visible
	/// on the part record itself, not just buried in one aircraft's list.
	func loadDirectives(context: ModelContext, forPartNumber partNumber: String) -> [AirworthinessDirective] {
		guard !partNumber.isEmpty else { return [] }
		let fd = FetchDescriptor<AirworthinessDirective>(
			predicate: #Predicate<AirworthinessDirective> { $0.appliesToPartNumber == partNumber },
			sortBy: [SortDescriptor(\AirworthinessDirective.nextDueDate)]
		)
		return (try? context.fetch(fd)) ?? []
	}
}
