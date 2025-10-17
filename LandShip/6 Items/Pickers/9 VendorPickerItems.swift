//
//  SystemsPicker.swift
//  LandShip
//
//  Created by JP on 8/13/25.
//

import SwiftUI
import SwiftData

struct VendorPickerItems: View {
	@Query var RequestingModel: [Vendors1] // model containing the picker requesting data
	@Binding var RequestingData: MxItems3 // model of data requested by picker, used to track change in picker

	var body: some View {
		// send systems model and mxItems model to innerview to load picker
		InnerViewItems_Vendor(RequestingModel: RequestingModel, RequestingData: $RequestingData)
	}
}

struct InnerViewItems_Vendor: View {
	let RequestingModel: [Vendors1]
	@Binding var RequestingData: MxItems3

	@State var selectedPicker = "" /// used to track the picker choice change

	var body: some View {
		
		Picker(selection: $selectedPicker, label: Text("")) {
			ForEach(RequestingModel) { requestingModel in
				Text(requestingModel.vendorName)
					.tag(requestingModel.vendorName)
			}
		}
		.onAppear(){
			selectedPicker = RequestingData.vendor // presets picker item
		}
		.onChange(of: selectedPicker) {oldValue, newValue in
			RequestingData.vendor = "\(String(describing: selectedPicker))" // returns picker choice back to view
		}
	}
}

#Preview {
//    SystemsPicker()
}
