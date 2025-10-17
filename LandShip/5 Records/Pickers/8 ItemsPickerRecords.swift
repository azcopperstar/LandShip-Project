//
//  SystemsPicker.swift
//  LandShip
//
//  Created by JP on 8/13/25.
//

import SwiftUI
import SwiftData

struct ItemsPickerRecords: View {
	@Query var RequestingModel: [MxItems3] // model containing the picker requesting data
	@Binding var RequestingData: ServiceRecords1 // model of data requested by picker, used to track change in picker

	var body: some View {
		// send systems model and mxItems model to innerview to load picker
		InnerViewRecords_Items(RequestingModel: RequestingModel, RequestingData: $RequestingData)
	}
}

struct InnerViewRecords_Items: View {
	let RequestingModel: [MxItems3]
	@Binding var RequestingData: ServiceRecords1

	@State var selectedPicker = "" /// used to track the picker choice change

	var body: some View {
		
		Picker(selection: $selectedPicker, label: Text("")) {
			ForEach(RequestingModel) { requestingModel in
				Text(requestingModel.mxName)
					.tag(requestingModel.mxName)
			}
		}
		.onAppear(){
			selectedPicker = RequestingData.mxItemId // presets picker item
		}
		.onChange(of: selectedPicker) {oldValue, newValue in
			RequestingData.mxItemId = "\(String(describing: selectedPicker))" // returns picker choice back to view
//			print("RequestingData.mxItemId: \(RequestingData.mxItemId)")
		}
	}
}

#Preview {
//    SystemsPicker()
}
