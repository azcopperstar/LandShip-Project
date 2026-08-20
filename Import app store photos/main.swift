import Photos
import AppKit
import Foundation

// MARK: - App Store Sizes

struct ScreenshotSize {
	let name: String
	let width: Int
	let height: Int
}

enum Platform: String, CaseIterable {
	case iOS, macOS, all
}

let iOSSizes: [ScreenshotSize] = [
	ScreenshotSize(name: "iPhone_6_9",  width: 1320, height: 2868),
	ScreenshotSize(name: "iPhone_6_7",  width: 1290, height: 2796),
	ScreenshotSize(name: "iPhone_6_5",  width: 1284, height: 2778),
	ScreenshotSize(name: "iPhone_5_5",  width: 1242, height: 2208),
	ScreenshotSize(name: "iPad_13",     width: 2064, height: 2752),
	ScreenshotSize(name: "iPad_12_9",   width: 2048, height: 2732),
]

let macOSSizes: [ScreenshotSize] = [
	// Required
	ScreenshotSize(name: "Mac_1280x800",   width: 1280, height: 800),
	ScreenshotSize(name: "Mac_1440x900",   width: 1440, height: 900),
	// Retina (recommended)
	ScreenshotSize(name: "Mac_2560x1600",  width: 2560, height: 1600),
	ScreenshotSize(name: "Mac_2880x1800",  width: 2880, height: 1800),
]

// MARK: - Config

struct ExportConfig {
	var albumName: String       = "AppScreenshots"
	var platform: Platform      = .all
	var background: NSColor     = .black
	var outputDir: URL          = FileManager.default
		.homeDirectoryForCurrentUser
		.appendingPathComponent("Desktop/AppStoreScreenshots")
	
	var sizes: [ScreenshotSize] {
		switch platform {
			case .iOS:   return iOSSizes
			case .macOS: return macOSSizes
			case .all:   return iOSSizes + macOSSizes
		}
	}
}

// MARK: - Resize & Save

func saveResized(
	image: NSImage,
	to size: ScreenshotSize,
	filename: String,
	config: ExportConfig
) {
	let targetSize = NSSize(width: size.width, height: size.height)
	let newImage = NSImage(size: targetSize)
	
	newImage.lockFocus()
	
	// Background fill
	config.background.setFill()
	NSRect(origin: .zero, size: targetSize).fill()
	
	// Scale to fit, centered (preserves aspect ratio)
	let scale = min(
		targetSize.width  / image.size.width,
		targetSize.height / image.size.height
	)
	let scaledSize = NSSize(
		width:  image.size.width  * scale,
		height: image.size.height * scale
	)
	let origin = NSPoint(
		x: (targetSize.width  - scaledSize.width)  / 2,
		y: (targetSize.height - scaledSize.height) / 2
	)
	image.draw(
		in: NSRect(origin: origin, size: scaledSize),
		from: .zero,
		operation: .sourceOver,
		fraction: 1.0
	)
	
	newImage.unlockFocus()
	
	guard
		let tiff   = newImage.tiffRepresentation,
		let bitmap = NSBitmapImageRep(data: tiff),
		let png    = bitmap.representation(using: .png, properties: [:])
	else {
		print("  ⚠️  Failed to encode \(filename) for \(size.name)")
		return
	}
	
	// Group by platform subfolder
	let platformFolder = size.name.hasPrefix("Mac") ? "macOS" : "iOS"
	let destDir = config.outputDir
		.appendingPathComponent(platformFolder)
		.appendingPathComponent(size.name)
	
	do {
		try FileManager.default.createDirectory(
			at: destDir,
			withIntermediateDirectories: true
		)
		let dest = destDir.appendingPathComponent("\(filename).png")
		try png.write(to: dest)
		print("  ✅ \(platformFolder)/\(size.name)/\(filename).png")
	} catch {
		print("  ❌ Error saving \(filename) [\(size.name)]: \(error)")
	}
}

// MARK: - Photos Export

func processPhotosAlbum(config: ExportConfig) {
	let semaphore = DispatchSemaphore(value: 0)
	
	PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
		defer { semaphore.signal() }
		
		guard status == .authorized else {
			print("❌ Photos access denied.")
			return
		}
		
		// Find album
		let albumFetch = PHAssetCollection.fetchAssetCollections(
			with: .album, subtype: .any, options: nil
		)
		
		var targetCollection: PHAssetCollection?
		albumFetch.enumerateObjects { collection, _, stop in
			if collection.localizedTitle == config.albumName {
				targetCollection = collection
				stop.pointee = true
			}
		}
		
		guard let album = targetCollection else {
			print("❌ Album '\(config.albumName)' not found in Photos.")
			return
		}
		
		let assets = PHAsset.fetchAssets(in: album, options: nil)
		guard assets.count > 0 else {
			print("⚠️  Album '\(config.albumName)' is empty.")
			return
		}
		
		print("📸 Found \(assets.count) photo(s) in '\(config.albumName)'")
		print("🖥️  Platform: \(config.platform.rawValue) → \(config.sizes.count) size(s)\n")
		
		let manager = PHImageManager.default()
		let options = PHImageRequestOptions()
		options.isSynchronous          = true
		options.deliveryMode           = .highQualityFormat
		options.isNetworkAccessAllowed = true
		options.resizeMode             = .none
		
		assets.enumerateObjects { asset, index, _ in
			let filename = "screenshot_\(String(format: "%02d", index + 1))"
			print("Processing \(filename)...")
			
			manager.requestImage(
				for: asset,
				targetSize: PHImageManagerMaximumSize,
				contentMode: .aspectFit,
				options: options
			) { image, info in
				guard let image else {
					let err = info?[PHImageErrorKey] as? Error
					print("  ⚠️  Could not load image: \(err?.localizedDescription ?? "unknown")")
					return
				}
				for size in config.sizes {
					saveResized(image: image, to: size, filename: filename, config: config)
				}
			}
		}
		
		print("\n🎉 Done! Files saved to:\n   \(config.outputDir.path)")
	}
	
	semaphore.wait()
}

// MARK: - Entry Point

var config = ExportConfig()
config.albumName  = "AppScreenshots"    // Your Photos album name
config.platform   = .all               // .iOS, .macOS, or .all
config.background = .black             // Any NSColor

processPhotosAlbum(config: config)
