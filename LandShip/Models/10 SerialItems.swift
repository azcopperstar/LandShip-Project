//
//  10 SerialItems.swift
//  LandShip
//
//  A serial number record linked to a vehicle by vehicleId.
//  Each vehicle may have unlimited items with associated serial numbers.
//

import Foundation
import SwiftData

@Model
class VehicleSerialItem {
    var vehicleId: String = ""
    var itemName: String = ""
    var serialNumber: String = ""
    var createdAt: Date = Date()

    init(vehicleId: String = "", itemName: String = "", serialNumber: String = "") {
        self.vehicleId = vehicleId
        self.itemName = itemName
        self.serialNumber = serialNumber
        self.createdAt = Date()
    }
}
