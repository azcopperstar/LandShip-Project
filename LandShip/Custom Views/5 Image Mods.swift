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

func formattedImageSize(from data: Data?) -> String {
	guard let count = data?.count else { return "" }
	let kb = Double(count) / 1024.0
	return String(format: "Image size: %.0f KB", kb)
}

#if os(iOS)
extension UIImage {
	func resizeForCloudKit(maxDimension: CGFloat = 1024) -> UIImage? {
		let size = self.size
		let aspectRatio = size.width / size.height
		
		var newSize: CGSize
		if size.width > size.height {
			newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
		} else {
			newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
		}
		
		let renderer = UIGraphicsImageRenderer(size: newSize)
		return renderer.image { _ in
			self.draw(in: CGRect(origin: .zero, size: newSize))
		}
	}
}
#elseif os(macOS)
extension NSImage {
	func resizeForCloudKit(maxDimension: CGFloat = 1024) -> NSImage? {
		let size = self.size
		let aspectRatio = size.width / size.height
		
		var newSize: CGSize
		if size.width > size.height {
			newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
		} else {
			newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
		}
		
		let newImage = NSImage(size: newSize)
		newImage.lockFocus()
		self.draw(in: NSRect(origin: .zero, size: newSize),
							from: NSRect(origin: .zero, size: size),
							operation: .copy,
							fraction: 1.0)
		newImage.unlockFocus()
		return newImage
	}
}
#endif

// view modifiers for image views
struct ImageViewModifier_Thumbnail: ViewModifier {
	func body(content: Content) -> some View {
		content
			.scaledToFit()
			.frame(width: 100, height: 70)
			.clipShape(RoundedRectangle(cornerRadius: 8))
	}
}
struct ImageViewModifier_Details: ViewModifier {
	func body(content: Content) -> some View {
		content
			.scaledToFit()
			.frame(height: 200)
			.clipShape(RoundedRectangle(cornerRadius: 8))
	}
}
struct ImageViewModifier_Empty: ViewModifier {
	func body(content: Content) -> some View {
		content
			.scaledToFit()
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
	@State private var isLargeViewerPresented: Bool = false
	
	var body: some View {
		VStack(alignment: .leading) {
#if os(macOS)
			if let imageData = imageData, let uiImage = NSImage(data: imageData) {
				HStack { LabelDataText(label: "Vehicle Graphic \(label): ", data: "\(imageDescription)") }
				Image(nsImage: uiImage)
					.resizable()
					.imageViewModifier_Details()
					.contentShape(Rectangle())
					.onTapGesture { isLargeViewerPresented = true }
				Text(formattedImageSize(from: imageData))
					.font(.caption)
					.foregroundStyle(.secondary)
			}
#elseif os(iOS)
			if let imageData = imageData, let uiImage = UIImage(data: imageData) {
				HStack { LabelDataText(label: "Vehicle Graphic \(label)", data: "\(imageDescription)") }
				Image(uiImage: uiImage)
					.resizable()
					.imageViewModifier_Details()
					.contentShape(Rectangle())
					.onTapGesture { isLargeViewerPresented = true }
				Text(formattedImageSize(from: imageData))
					.font(.caption)
					.foregroundStyle(.secondary)
			}
#endif
		}
		.sheet(isPresented: $isLargeViewerPresented) {
			LargeImageViewer(imageData: imageData)
		}
	}
}

struct LargeImageViewer: View {
	var imageData: Data?
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		ZStack {
			Color.black.opacity(0.95)
				.ignoresSafeArea()

			Group {
#if os(macOS)
				if let imageData = imageData, let nsImage = NSImage(data: imageData) {
					Image(nsImage: nsImage)
						.resizable()
						.scaledToFit()
				} else {
					Image(systemName: "photo")
						.resizable()
						.scaledToFit()
						.foregroundStyle(.secondary)
						.padding()
				}
#elseif os(iOS)
				if let imageData = imageData, let uiImage = UIImage(data: imageData) {
					Image(uiImage: uiImage)
						.resizable()
						.scaledToFit()
				} else {
					Image(systemName: "photo")
						.resizable()
						.scaledToFit()
						.foregroundStyle(.secondary)
						.padding()
				}
#endif
			}
			.padding()

			VStack {
				HStack {
					Spacer()
					Button {
						dismiss()
					} label: {
						Image(systemName: "xmark.circle.fill")
							.font(.system(size: 28, weight: .bold))
							.foregroundStyle(.white.opacity(0.9))
					}
				}
				.padding()
				Spacer()
			}
		}
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
					.contentShape(Rectangle())
					.onTapGesture { isConfirmationDialogPresented = true }
				Text(formattedImageSize(from: imageData))
					.font(.caption)
					.foregroundStyle(.secondary)
			} else {
				Image(systemName: "photo.on.rectangle.angled")
					.resizable()
					.imageViewModifier_Empty()
					.contentShape(Rectangle())
					.onTapGesture { isConfirmationDialogPresented = true }
			}
#elseif os(iOS)
			if let imageData = imageData, let uiImage = UIImage(data: imageData) {
				Image(uiImage: uiImage)
					.resizable()
					.imageViewModifier_Details()
					.contentShape(Rectangle())
					.onTapGesture { isConfirmationDialogPresented = true }
				Text(formattedImageSize(from: imageData))
					.font(.caption)
					.foregroundStyle(.secondary)
			} else {
				Image(systemName: "photo.on.rectangle.angled")
					.resizable()
					.imageViewModifier_Empty()
					.contentShape(Rectangle())
					.onTapGesture { isConfirmationDialogPresented = true }
			}
#endif
		}

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
			// Resize the image first
			if let resizedImage = newValue.resizeForCloudKit(maxDimension: 1024),
				 let data = resizedImage.jpegData(compressionQuality: 0.6) { // Reduced from 0.9
				imageData = data
				isImageAvailable = true
				// removed debug print of image size
				if let data = imageData, data.count > 950_000 { // Leave some buffer under 1MB
					print("⚠️ Image too large: \(data.count / 1024)KB - may cause CloudKit sync issues")
				}
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
		if let data = try? await item?.loadTransferable(type: Data.self),
			 let originalImage = NSImage(data: data),
			 let resizedImage = originalImage.resizeForCloudKit(maxDimension: 1024) {
			// Convert to JPEG with compression
			if let tiffData = resizedImage.tiffRepresentation,
				 let bitmapImage = NSBitmapImageRep(data: tiffData),
				 let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) {
				self.imageData = jpegData
				// removed debug print of image size
			}
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

