//
//  SystemsPicker.swift
//  LandShip
//
//  Created by JP on 8/13/25.
//

import SwiftUI
import SwiftData

struct SystemsPickerParts: View {
	@Query var vehicleSystems: [VehicleSystems1]
	@Binding var mxParts: MxParts1 // used to track change in picker

	var body: some View {
		// send systems model and mxItems model to innerview to load picker
		InnerViewParts(vehicleSystems: vehicleSystems, mxParts: $mxParts)
	}
}

struct InnerViewParts: View {
	let vehicleSystems: [VehicleSystems1] /// used to load the picker with items
	@Binding var mxParts: MxParts1 /// used to track the picker choice change
	@State var selectedSystem = "" /// used to track the picker choice change

	var body: some View {
		
		Picker(selection: $selectedSystem, label: Text("")) {
			ForEach(vehicleSystems) { vehicleSystem in
				Text(vehicleSystem.systemName)
					.tag(vehicleSystem.systemName)
			}
		}
		.onAppear(){
			selectedSystem = mxParts.vehicleSystem // presets picker item
		}
		.onChange(of: selectedSystem) {oldValue, newValue in
			mxParts.vehicleSystem = "\(String(describing: selectedSystem))" // returns picker choice back to view
		}
	}
}

#Preview {
//    SystemsPicker()
}
