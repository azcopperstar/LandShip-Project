//
//  SystemsPicker.swift
//  LandShip
//
//  Created by JP on 8/13/25.
//

import SwiftUI
import SwiftData

struct SystemsPickerItems: View {
	@Query var vehicleSystems: [VehicleSystems1]
	@Binding var mxItems: MxItems3 // used to track change in picker

	var body: some View {
		// send systems model and mxItems model to innerview to load picker
		InnerViewItems(vehicleSystems: vehicleSystems, mxItems: $mxItems)
	}
}

struct InnerViewItems: View {
	let vehicleSystems: [VehicleSystems1] /// used to load the picker with items
	@Binding var mxItems: MxItems3 /// used to track the picker choice change
	@State var selectedSystem = "" /// used to track the picker choice change

	var body: some View {
		
		Picker(selection: $selectedSystem, label: Text("")) {
			ForEach(vehicleSystems) { vehicleSystem in
				Text(vehicleSystem.systemName)
					.tag(vehicleSystem.systemName)
			}
		}
		.onAppear(){
			selectedSystem = mxItems.vehicleSystem // presets picker item
		}
		.onChange(of: selectedSystem) {oldValue, newValue in
			mxItems.vehicleSystem = "\(String(describing: selectedSystem))" // returns picker choice back to view
		}
	}
}

#Preview {
//    SystemsPicker()
}
