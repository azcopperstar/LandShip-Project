//
//  SystemsPicker.swift
//  LandShip
//
//  Created by JP on 8/13/25.
//

import SwiftUI
import SwiftData

struct VehiclePickerTripLog_Towed: View {
	@Query var RequestingModel: [Vehicle8] // model containing the picker requesting data
	@Binding var RequestingData: TripLog2 // model of data requested by picker, used to track change in picker

	var body: some View {
		// send systems model and mxItems model to innerview to load picker
		InnerViewTripLog_Vehicle_Towed(RequestingModel: RequestingModel, RequestingData: $RequestingData)
	}
}

struct InnerViewTripLog_Vehicle_Towed: View {
	let RequestingModel: [Vehicle8]
	@Binding var RequestingData: TripLog2
	@State var selectedPicker = "" /// used to track the picker choice change

	var body: some View {
		
		Picker(selection: $selectedPicker, label: Text("")) {
			ForEach(RequestingModel) { requestingModel in
				Text(requestingModel.name)
					.tag(requestingModel.name)
			}
		}
		.onAppear(){
			selectedPicker = RequestingData.vehicleIdTowed // presets picker item
		}
		.onChange(of: selectedPicker) {oldValue, newValue in
			RequestingData.vehicleIdTowed = "\(String(describing: selectedPicker))" // returns picker choice back to view
		}
	}
}

#Preview {
}
