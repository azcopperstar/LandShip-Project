//
//  Custom Views.swift
//  LandShip
//
//  Created by JP on 9/4/25.
//

import Foundation
import SwiftUI
import Combine
import PhotosUI

// view modifiers for image views
struct ImageViewModifier_Thumbnail: ViewModifier {
	func body(content: Content) -> some View {
		content
			.scaledToFill()
			.frame(width: 100, height: 70)
			.clipShape(RoundedRectangle(cornerRadius: 8))
	}
}
struct ImageViewModifier_Details: ViewModifier {
	func body(content: Content) -> some View {
		content
			.scaledToFill()
			.frame(height: 200)
			.clipShape(RoundedRectangle(cornerRadius: 8))
	}
}
struct ImageViewModifier_Empty: ViewModifier {
	func body(content: Content) -> some View {
		content
			.scaledToFill()
			.frame(width: 100, height: 70)
			.clipShape(RoundedRectangle(cornerRadius: 8))
	}
}
extension View {
	func imageViewModifier_Thumbnail() -> some View {
		self.modifier(ImageViewModifier_Thumbnail())}
	func imageViewModifier_Details() -> some View {
		self.modifier(ImageViewModifier_Details())}
	func imageViewModifier_Empty() -> some View {
		self.modifier(ImageViewModifier_Empty())}
}
// view modifiers for image views


struct Image_View_Thumbnail: View {
	var imageData: Data?
	var body: some View {
#if os(macOS)
		if let imageData = imageData, let uiImage = NSImage(data: imageData) {
			Image(nsImage: uiImage)
				.resizable()
				.imageViewModifier_Thumbnail()
		}
#elseif os(iOS)
		if let imageData = imageData, let uiImage = UIImage(data: imageData) {
			Image(uiImage: uiImage)
				.resizable()
				.imageViewModifier_Thumbnail()
		}
#endif
		Text("") /// used to extend list divider full left
			.frame(alignment: .leading)
	}
}

struct Image_View_Details: View {
	let label: String
	var imageData: Data?
	var imageDescription: String
	var body: some View {
#if os(macOS)
		if let imageData = imageData, let uiImage = NSImage(data: imageData) {
			HStack{LabelDataText(label: "Vehicle Graphic \(label): ", data: "\(imageDescription)")}
			Image(nsImage: uiImage)
				.resizable()
				.imageViewModifier_Details()
		}
#elseif os(iOS)
		if let imageData = imageData, let uiImage = UIImage(data: imageData) {
			HStack{LabelDataText(label: "Vehicle Graphic \(label)", data: "\(imageDescription)")}
			Image(uiImage: uiImage)
				.resizable()
				.imageViewModifier_Details()
		}
#endif
	}
}

struct Image_Edit: View {
	let label: String
	@Binding var imageData: Data?
	@Binding var imageDescription: String
	@State private var isImageAvailable: Bool = false
	@Environment(\.dismiss) private var dismiss
#if os(macOS)
	@State private var image: NSImage?
#elseif os(iOS)
	@State private var image: UIImage?
#endif
	@State private var isConfirmationDialogPresented: Bool = false
	@State private var isImagePickerPresented: Bool = false
	@State private var sourceType: SourceType = .camera
	@State private var selectedPhoto: PhotosPickerItem?

	enum SourceType {
		case camera
		case photoLibrary
	}
	
	var body: some View {
		VStack {
			if imageData != nil {
				HStack{LabelDataTextview(label: "Image Description", data: $imageDescription)}
			}
#if os(macOS)
			if let imageData = imageData, let uiImage = NSImage(data: imageData) {
				Image(nsImage: uiImage)
					.resizable()
					.imageViewModifier_Details()
			} else {
				Image(systemName: "photo.on.rectangle.angled")
					.resizable()
					.imageViewModifier_Empty()
			}
#elseif os(iOS)
			if let imageData = imageData, let uiImage = UIImage(data: imageData) {
				Image(uiImage: uiImage)
					.resizable()
					.imageViewModifier_Details()
			} else {
				Image(systemName: "photo.on.rectangle.angled")
					.resizable()
					.imageViewModifier_Empty()
			}
#endif
		}

		.onTapGesture{
			isConfirmationDialogPresented = true
		} // onTap end
#if os(iOS)
		// for iOS, open dialog to select photos or camera
		.confirmationDialog("Selection Options", isPresented: $isConfirmationDialogPresented) {
			Button("Camera"){
				sourceType = .camera
				isImagePickerPresented = true
			}
			Button("Photo Library"){
				sourceType = .photoLibrary
				isImagePickerPresented = true
			}
		}
		.sheet(isPresented: $isImagePickerPresented) {
			ImagePicker(
				isPresented: $isImagePickerPresented,
				image: $image,
				sourceType: sourceType == .camera ? .camera : .photoLibrary
			)
		}
		.onChange(of: image) { oldValue, newValue in
			guard let newValue else { return }
			// Convert picked UIImage to Data for storage
			if let data = newValue.jpegData(compressionQuality: 0.9) {
				imageData = data
				isImageAvailable = true
			}
		}
#endif
			
#if os(macOS)
		// if macOS, open PhotosPicker since no camera is available
		PhotosPicker(
			selection: $selectedPhoto,
			matching: .images,
			photoLibrary: .shared()
		) {
			if imageData == nil {
				Text("Select Photo From Library")
			}else{
				Text("Change Photo")
			}
		}
		.onChange(of: selectedPhoto) {
			Task {
				await loadImageData(from: selectedPhoto)
			}
		}
#endif
	}

#if os(macOS)
	private func loadImageData(from item: PhotosPickerItem?) async {
		if let data = try? await item?.loadTransferable(type: Data.self) {
			self.imageData = data
		}
	}
#endif

#if os(iOS)
	// ImagePicker struct is a SwiftUI wrapper around UIImagePickerController
	struct ImagePicker: UIViewControllerRepresentable {
		@Binding var isPresented: Bool  // Binding to control the presentation of the image picker
		@Binding var image: UIImage?    // Binding to hold the selected image
		var sourceType: UIImagePickerController.SourceType// Specifies the source type for the image picker (camera or photo library)
		
		// This method creates a Coordinator instance which handles the delegation of UIImagePickerController
		func makeCoordinator() -> Coordinator {
			Coordinator(parent: self)
		}
		
		// This method creates a UIImagePickerController instance and sets its delegate and source type
		func makeUIViewController(context: Context) -> UIImagePickerController {
			let picker = UIImagePickerController()
			picker.delegate = context.coordinator  // Set the delegate to handle image picker events
			picker.sourceType = sourceType // Set the source type (camera or photo library)
			return picker
		}
		
		// This method is used to update the UIImagePickerController when SwiftUI view updates, but not used in this example
		func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
		
		// Coordinator class to handle the delegate methods of UIImagePickerController
		class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
			var parent:ImagePicker  // Reference to the parent ImagePicker struct
			init(parent: ImagePicker) {
				self.parent = parent
			}
			
			// This delegate method is called when an image is selected
			func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
				if let uiImage = info[.originalImage] as? UIImage {// Retrieve the selected image
					parent.image = uiImage
				}
				parent.isPresented = false// Dismiss the image picker
			}
			
			// This delegate method is called when the image picker is cancelled
			func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
				parent.isPresented = false // Dismiss the image picker
			}
		}
	}
#endif
}
