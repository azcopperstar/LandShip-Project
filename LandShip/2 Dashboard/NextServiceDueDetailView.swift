// NextServiceDueDetailView.swift
import SwiftUI

struct NextServiceDueDetailView: View {
    let vehicleScope: String
    let distanceUnit: String
    let formatDate: (Date) -> String

    var body: some View {
        VStack(spacing: 12) {
            Text("Next Service Due")
                .font(.title2)
                .bold()

            HStack {
                Text("Vehicle scope:")
                    .font(.headline)
                Spacer()
                Text(vehicleScope.isEmpty ? "All Vehicles" : vehicleScope)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Distance unit:")
                    .font(.headline)
                Spacer()
                Text(distanceUnit.isEmpty ? "mi" : distanceUnit)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Today:")
                    .font(.headline)
                Spacer()
                Text(formatDate(Date()))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Next Service Due")
    }
}
