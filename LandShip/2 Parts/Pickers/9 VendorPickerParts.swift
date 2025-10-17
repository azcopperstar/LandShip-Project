//
//  SystemsPicker.swift
//  LandShip
//
//  Created by JP on 8/13/25.
//

import SwiftUI
import SwiftData

struct VendorPickerParts: View {
	@Query var RequestingModel: [Vendors1] // model containing the picker requesting data
	@Binding var RequestingData: MxParts1 // model of data requested by picker, used to track change in picker

	var body: some View {
		// send systems model and mxItems model to innerview to load picker
		InnerViewParts_Vendor(RequestingModel: RequestingModel, RequestingData: $RequestingData)
	}
}

struct InnerViewParts_Vendor: View {
	let RequestingModel: [Vendors1]
	@Binding var RequestingData: MxParts1

	@State var selectedPicker = "" /// used to track the picker choice change

	var body: some View {
		
		Picker(selection: $selectedPicker, label: Text("")) {
			ForEach(RequestingModel) { requestingModel in
				Text(requestingModel.vendorName)
					.tag(requestingModel.vendorName)
			}
		}
		.onAppear(){
			selectedPicker = RequestingData.partSupplier // presets picker item
		}
		.onChange(of: selectedPicker) {oldValue, newValue in
			RequestingData.partSupplier = "\(String(describing: selectedPicker))" // returns picker choice back to view
		}
	}
}

#Preview {
//    SystemsPicker()
}
