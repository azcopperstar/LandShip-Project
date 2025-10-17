//
//  SystemsPicker.swift
//  LandShip
//
//  Created by JP on 8/13/25.
//

import SwiftUI
import SwiftData

struct VehiclePickerSystems: View {
	@Query var RequestingModel: [Vehicle8] // model containing the picker requesting data
	@Binding var RequestingData: VehicleSystems1 // model of data requested by picker, used to track change in picker

	var body: some View {
		// send systems model and mxItems model to innerview to load picker
		InnerViewSystems_Vehicle(RequestingModel: RequestingModel, RequestingData: $RequestingData)
	}
}

struct InnerViewSystems_Vehicle: View {
	let RequestingModel: [Vehicle8]
	@Binding var RequestingData: VehicleSystems1

	@State var selectedPicker = "" /// used to track the picker choice change

	var body: some View {
		
		Picker(selection: $selectedPicker, label: Text("")) {
			ForEach(RequestingModel) { requestingModel in
				Text(requestingModel.name)
					.tag(requestingModel.name)
			}
			Text("All Vehicles")
				.tag("All Vehicles")
		}
		.onAppear(){
			selectedPicker = RequestingData.vehicleId // presets picker item
		}
		.onChange(of: selectedPicker) {oldValue, newValue in
			RequestingData.vehicleId = "\(String(describing: selectedPicker))" // returns picker choice back to view
		}
	}
}

#Preview {
//    SystemsPicker()
}
