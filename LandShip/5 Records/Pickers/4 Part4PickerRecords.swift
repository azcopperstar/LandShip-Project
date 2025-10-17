//
//  SystemsPicker.swift
//  LandShip
//
//  Created by JP on 8/13/25.
//

import SwiftUI
import SwiftData

struct Part4PickerRecords: View {
	@Query var RequestingModel: [MxParts1] // model containing the picker requesting data
	@Binding var RequestingData: ServiceRecords1 // model of data requested by picker, used to track change in picker

	var body: some View {
		// send systems model and mxItems model to innerview to load picker
		InnerViewRecords_Part4(RequestingModel: RequestingModel, RequestingData: $RequestingData)
	}
}

struct InnerViewRecords_Part4: View {
	let RequestingModel: [MxParts1]
	@Binding var RequestingData: ServiceRecords1

	@State var selectedPicker = "" /// used to track the picker choice change

	var body: some View {
		
		Picker(selection: $selectedPicker, label: Text("")) {
			Text("").tag("")
			ForEach(RequestingModel) { requestingModel in
				Text(requestingModel.partName)
					.tag(requestingModel.partName)
			}
		}
		.onAppear(){
			selectedPicker = RequestingData.part4 // presets picker item
		}
		.onChange(of: selectedPicker) {oldValue, newValue in
					RequestingData.part4 = "\(String(describing: selectedPicker))" // returns picker choice back to view
//			print("RequestingData.part1: \(RequestingData.part1)")
		}
	}
}

#Preview {
//    SystemsPicker()
}
