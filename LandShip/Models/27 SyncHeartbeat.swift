//
//  27 SyncHeartbeat.swift
//  LandShip
//

import Foundation
import SwiftData

/// A single hidden record, touched once per launch by SyncHeartbeatService, purely to
/// generate a CloudKit export attempt even if the user hasn't entered any real data.
/// Never shown in any UI list — AppSchema.modelTypes is the only other place this is
/// referenced.
@Model
class SyncHeartbeat {
	var id: String = "primary"
	var lastPingAt: Date = Date()
	var pingCount: Int = 0
	var createdAt: Date = Date()

	init() {}
}
