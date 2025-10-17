//
//  BackupRestore.swift
//  LandShip
//
//  Created by JP on 7/19/25.
//

import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ImageIO

// MARK: - BackupDocument (FileDocument exporting a folder)

struct BackupDocument: FileDocument {
	static var readableContentTypes: [UTType] { [.folder] }
	static var writableContentTypes: [UTType] { [.folder] }

	private var rootWrapper: FileWrapper

	init(root: FileWrapper) {
		self.rootWrapper = root
	}

	// Reader init (not used; supports import if you later add more restore flows)
	init(configuration: ReadConfiguration) throws {
		self.rootWrapper = FileWrapper(directoryWithFileWrappers: [:])
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		return rootWrapper
	}

	// A usable empty placeholder
	static var empty: BackupDocument {
		BackupDocument(root: FileWrapper(directoryWithFileWrappers: [:]))
	}
}

// Convenience to add a regular file into a directory FileWrapper by name
extension FileWrapper {
	func addFile(withName name: String, contents data: Data) {
		let file = FileWrapper(regularFileWithContents: data)
		file.preferredFilename = name
		self.addFileWrapper(file)
	}
}

// MARK: - BackupBuilder builds the folder structure to export

enum BackupBuilder {
	enum BackupError: Error {
		case containerUnavailable
		case failedToEnumerate(URL)
		case fetchFailed(String)
	}

	static func makeBackupWrapper(context: ModelContext) throws -> FileWrapper {
		let root = FileWrapper(directoryWithFileWrappers: [:])

		// Info file
		let infoText = """
		App: \(AppInfo.displayName)
		Version: \(AppInfo.version)
		Created: \(ISO8601DateFormatter().string(from: Date()))
		"""
		let infoData = Data(infoText.utf8)
		root.addFile(withName: "AppInfo.txt", contents: infoData)

		// Include Application Support (SwiftData lives here)
		if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
			let supportWrapper = try directoryWrapper(at: appSupport, displayName: "Application Support")
			root.addFileWrapper(supportWrapper)
		}

		// Include Documents (your generated PDFs, etc.)
		if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
			let docsWrapper = try directoryWrapper(at: docs, displayName: "Documents")
			root.addFileWrapper(docsWrapper)
		}

		// Also export human-browsable media files from SwiftData image blobs
		let mediaWrapper = try exportMediaFolder(context: context)
		if let mediaWrapper {
			root.addFileWrapper(mediaWrapper)
		}

		return root
	}

	// Recursively builds a FileWrapper from a directory on disk.
	private static func directoryWrapper(at url: URL, displayName: String? = nil) throws -> FileWrapper {
		let fm = FileManager.default
		var isDir: ObjCBool = false
		guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
			// If the directory doesn't exist, provide an empty wrapper with the intended name
			let empty = FileWrapper(directoryWithFileWrappers: [:])
			if let name = displayName { empty.preferredFilename = name }
			return empty
		}

		let wrapper = FileWrapper(directoryWithFileWrappers: [:])
		if let name = displayName { wrapper.preferredFilename = name }

		let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .nameKey, .isSymbolicLinkKey]
		let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles])
		while let itemURL = enumerator?.nextObject() as? URL {
			let resourceValues = try itemURL.resourceValues(forKeys: Set(resourceKeys))

			// Compute relative path name for placement inside this wrapper
			let relativePath = itemURL.path.replacingOccurrences(of: url.path + "/", with: "")
			// Skip if empty (root)
			guard !relativePath.isEmpty else { continue }

			if resourceValues.isSymbolicLink == true {
				// Skip symlinks inside container
				continue
			}

			if resourceValues.isDirectory == true {
				// Ensure hierarchy exists in wrapper
				try ensureDirectory(relativePath: relativePath, under: wrapper)
			} else if resourceValues.isRegularFile == true {
				// Read file data and place it in the correct sub-wrapper path
				let fileData = try Data(contentsOf: itemURL, options: .mappedIfSafe)
				try addFile(relativePath: relativePath, data: fileData, under: wrapper)
			}
		}

		return wrapper
	}

	// Ensure nested directory wrappers exist for a given relative path
	private static func ensureDirectory(relativePath: String, under root: FileWrapper) throws {
		let components = relativePath.split(separator: "/").map(String.init)
		guard !components.isEmpty else { return }

		var current = root
		for (index, part) in components.enumerated() {
			if index == components.count - 1 {
				if current.fileWrappers?[part] == nil {
					let newDir = FileWrapper(directoryWithFileWrappers: [:])
					newDir.preferredFilename = part
					current.addFileWrapper(newDir)
				}
			} else {
				if let next = current.fileWrappers?[part], next.isDirectory {
					current = next
				} else {
					let newDir = FileWrapper(directoryWithFileWrappers: [:])
					newDir.preferredFilename = part
					current.addFileWrapper(newDir)
					current = newDir
				}
			}
		}
	}

	// Add a file at a relative path into the wrapper tree, creating intermediate directories as needed
	private static func addFile(relativePath: String, data: Data, under root: FileWrapper) throws {
		var components = relativePath.split(separator: "/").map(String.init)
		guard let fileName = components.popLast() else { return }

		var current = root
		for part in components {
			if let next = current.fileWrappers?[part], next.isDirectory {
				current = next
			} else {
				let newDir = FileWrapper(directoryWithFileWrappers: [:])
				newDir.preferredFilename = part
				current.addFileWrapper(newDir)
				current = newDir
			}
		}
		current.addFile(withName: fileName, contents: data)
	}

	// MARK: - Media export

	private static func exportMediaFolder(context: ModelContext) throws -> FileWrapper? {
		// Fetch all entities that have image Data
		let vehicles: [Vehicle8]
		let systems: [VehicleSystems1]
		let vendors: [Vendors1]
		let records: [ServiceRecords1]
		let items: [MxItems3]
		let parts: [MxParts1]
		let fuelLogs: [FuelLog1]
		let tripLogs: [TripLog2]
		do {
			vehicles = try context.fetch(FetchDescriptor<Vehicle8>())
			systems = try context.fetch(FetchDescriptor<VehicleSystems1>())
			vendors = try context.fetch(FetchDescriptor<Vendors1>())
			records = try context.fetch(FetchDescriptor<ServiceRecords1>())
			items = try context.fetch(FetchDescriptor<MxItems3>())
			parts = try context.fetch(FetchDescriptor<MxParts1>())
			fuelLogs = try context.fetch(FetchDescriptor<FuelLog1>())
			tripLogs = try context.fetch(FetchDescriptor<TripLog2>())
		} catch {
			throw BackupError.fetchFailed(error.localizedDescription)
		}

		let hasAny =
			vehicles.contains { $0.image1 != nil || $0.image2 != nil || $0.image3 != nil }
			|| systems.contains { $0.systemImage != nil || $0.image1 != nil || $0.image2 != nil || $0.image3 != nil }
			|| vendors.contains { $0.image1 != nil || $0.image2 != nil || $0.image3 != nil }
			|| records.contains { $0.image != nil || $0.image1 != nil || $0.image2 != nil || $0.image3 != nil }
			|| items.contains { $0.image1 != nil || $0.image2 != nil || $0.image3 != nil }
			|| parts.contains { $0.partImage != nil || $0.image1 != nil || $0.image2 != nil || $0.image3 != nil }
			|| fuelLogs.contains { $0.image1 != nil || $0.image2 != nil || $0.image3 != nil }
			|| tripLogs.contains { $0.image1 != nil || $0.image2 != nil || $0.image3 != nil }

		guard hasAny else { return nil }

		let mediaRoot = FileWrapper(directoryWithFileWrappers: [:])
		mediaRoot.preferredFilename = "Media"

		// Subfolders
		let vehiclesFolder = FileWrapper(directoryWithFileWrappers: [:]); vehiclesFolder.preferredFilename = "Vehicles"
		let systemsFolder = FileWrapper(directoryWithFileWrappers: [:]); systemsFolder.preferredFilename = "Systems"
		let vendorsFolder = FileWrapper(directoryWithFileWrappers: [:]); vendorsFolder.preferredFilename = "Vendors"
		let recordsFolder = FileWrapper(directoryWithFileWrappers: [:]); recordsFolder.preferredFilename = "ServiceRecords"
		let itemsFolder = FileWrapper(directoryWithFileWrappers: [:]); itemsFolder.preferredFilename = "Items"
		let partsFolder = FileWrapper(directoryWithFileWrappers: [:]); partsFolder.preferredFilename = "Parts"
		let fuelFolder = FileWrapper(directoryWithFileWrappers: [:]); fuelFolder.preferredFilename = "FuelLogs"
		let tripsFolder = FileWrapper(directoryWithFileWrappers: [:]); tripsFolder.preferredFilename = "TripLogs"

		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd"

		// Vehicles
		for v in vehicles {
			let recordFolder = FileWrapper(directoryWithFileWrappers: [:])
			recordFolder.preferredFilename = sanitize(v.name.isEmpty ? "Vehicle" : v.name)
			addImageIfPresent(v.image1, baseName: "image1", description: v.image1Description, into: recordFolder)
			addImageIfPresent(v.image2, baseName: "image2", description: v.image2Description, into: recordFolder)
			addImageIfPresent(v.image3, baseName: "image3", description: v.image3Description, into: recordFolder)
			if let files = recordFolder.fileWrappers, !files.isEmpty {
				vehiclesFolder.addFileWrapper(recordFolder)
			}
		}

		// Systems
		for s in systems {
			let display = [s.vehicleId, s.systemName].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " - ")
			let recordFolder = FileWrapper(directoryWithFileWrappers: [:])
			recordFolder.preferredFilename = sanitize(display.isEmpty ? "System" : display)
			addImageIfPresent(s.systemImage, baseName: "systemImage", description: "", into: recordFolder)
			addImageIfPresent(s.image1, baseName: "image1", description: s.image1Description, into: recordFolder)
			addImageIfPresent(s.image2, baseName: "image2", description: s.image2Description, into: recordFolder)
			addImageIfPresent(s.image3, baseName: "image3", description: s.image3Description, into: recordFolder)
			if let files = recordFolder.fileWrappers, !files.isEmpty {
				systemsFolder.addFileWrapper(recordFolder)
			}
		}

		// Vendors
		for v in vendors {
			let recordFolder = FileWrapper(directoryWithFileWrappers: [:])
			recordFolder.preferredFilename = sanitize(v.vendorName.isEmpty ? "Vendor" : v.vendorName)
			addImageIfPresent(v.image1, baseName: "image1", description: v.image1Description, into: recordFolder)
			addImageIfPresent(v.image2, baseName: "image2", description: v.image2Description, into: recordFolder)
			addImageIfPresent(v.image3, baseName: "image3", description: v.image3Description, into: recordFolder)
			if let files = recordFolder.fileWrappers, !files.isEmpty {
				vendorsFolder.addFileWrapper(recordFolder)
			}
		}

		// Service Records
		for r in records {
			let datePart = dateFormatter.string(from: r.mxDate)
			let display = [r.vehicleId, r.mxName, datePart]
				.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
				.joined(separator: " - ")
			let recordFolder = FileWrapper(directoryWithFileWrappers: [:])
			recordFolder.preferredFilename = sanitize(display.isEmpty ? "ServiceRecord" : display)
			addImageIfPresent(r.image, baseName: "image", description: "", into: recordFolder)
			addImageIfPresent(r.image1, baseName: "image1", description: r.image1Description, into: recordFolder)
			addImageIfPresent(r.image2, baseName: "image2", description: r.image2Description, into: recordFolder)
			addImageIfPresent(r.image3, baseName: "image3", description: r.image3Description, into: recordFolder)
			if let files = recordFolder.fileWrappers, !files.isEmpty {
				recordsFolder.addFileWrapper(recordFolder)
			}
		}

		// Items
		for i in items {
			let display = [i.vehicleId, i.mxName]
				.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
				.joined(separator: " - ")
			let recordFolder = FileWrapper(directoryWithFileWrappers: [:])
			recordFolder.preferredFilename = sanitize(display.isEmpty ? "Item" : display)
			addImageIfPresent(i.image1, baseName: "image1", description: i.image1Description, into: recordFolder)
			addImageIfPresent(i.image2, baseName: "image2", description: i.image2Description, into: recordFolder)
			addImageIfPresent(i.image3, baseName: "image3", description: i.image3Description, into: recordFolder)
			if let files = recordFolder.fileWrappers, !files.isEmpty {
				itemsFolder.addFileWrapper(recordFolder)
			}
		}

		// Parts
		for p in parts {
			let display = [p.vehicleId, p.partName]
				.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
				.joined(separator: " - ")
			let recordFolder = FileWrapper(directoryWithFileWrappers: [:])
			recordFolder.preferredFilename = sanitize(display.isEmpty ? "Part" : display)
			addImageIfPresent(p.partImage, baseName: "partImage", description: "", into: recordFolder)
			addImageIfPresent(p.image1, baseName: "image1", description: p.image1Description, into: recordFolder)
			addImageIfPresent(p.image2, baseName: "image2", description: p.image2Description, into: recordFolder)
			addImageIfPresent(p.image3, baseName: "image3", description: p.image3Description, into: recordFolder)
			if let files = recordFolder.fileWrappers, !files.isEmpty {
				partsFolder.addFileWrapper(recordFolder)
			}
		}

		// Fuel Logs
		for f in fuelLogs {
			let datePart = dateFormatter.string(from: f.fuelDateTime)
			let display = [f.vehicleId, datePart, f.location.isEmpty ? f.logName : f.location]
				.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
				.joined(separator: " - ")
			let recordFolder = FileWrapper(directoryWithFileWrappers: [:])
			recordFolder.preferredFilename = sanitize(display.isEmpty ? "FuelLog" : display)
			addImageIfPresent(f.image1, baseName: "image1", description: f.image1Description, into: recordFolder)
			addImageIfPresent(f.image2, baseName: "image2", description: f.image2Description, into: recordFolder)
			addImageIfPresent(f.image3, baseName: "image3", description: f.image3Description, into: recordFolder)
			if let files = recordFolder.fileWrappers, !files.isEmpty {
				fuelFolder.addFileWrapper(recordFolder)
			}
		}

		// Trip Logs
		for t in tripLogs {
			let datePart = dateFormatter.string(from: t.tripDateTimeStart)
			let display = [t.vehicleId, t.logName, datePart]
				.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
				.joined(separator: " - ")
			let recordFolder = FileWrapper(directoryWithFileWrappers: [:])
			recordFolder.preferredFilename = sanitize(display.isEmpty ? "TripLog" : display)
			addImageIfPresent(t.image1, baseName: "image1", description: t.image1Description, into: recordFolder)
			addImageIfPresent(t.image2, baseName: "image2", description: t.image2Description, into: recordFolder)
			addImageIfPresent(t.image3, baseName: "image3", description: t.image3Description, into: recordFolder)
			if let files = recordFolder.fileWrappers, !files.isEmpty {
				tripsFolder.addFileWrapper(recordFolder)
			}
		}

		// Attach non-empty subfolders
		if let files = vehiclesFolder.fileWrappers, !files.isEmpty {
			mediaRoot.addFileWrapper(vehiclesFolder)
		}
		if let files = systemsFolder.fileWrappers, !files.isEmpty {
			mediaRoot.addFileWrapper(systemsFolder)
		}
		if let files = vendorsFolder.fileWrappers, !files.isEmpty {
			mediaRoot.addFileWrapper(vendorsFolder)
		}
		if let files = recordsFolder.fileWrappers, !files.isEmpty {
			mediaRoot.addFileWrapper(recordsFolder)
		}
		if let files = itemsFolder.fileWrappers, !files.isEmpty {
			mediaRoot.addFileWrapper(itemsFolder)
		}
		if let files = partsFolder.fileWrappers, !files.isEmpty {
			mediaRoot.addFileWrapper(partsFolder)
		}
		if let files = fuelFolder.fileWrappers, !files.isEmpty {
			mediaRoot.addFileWrapper(fuelFolder)
		}
		if let files = tripsFolder.fileWrappers, !files.isEmpty {
			mediaRoot.addFileWrapper(tripsFolder)
		}

		// If Media has no children, return nil
		if let files = mediaRoot.fileWrappers, !files.isEmpty {
			return mediaRoot
		} else {
			return nil
		}
	}

	// Add one image blob as a file, using detected extension and optional description suffix
	private static func addImageIfPresent(_ data: Data?, baseName: String, description: String, into folder: FileWrapper) {
		guard let data else { return }
		let ext = detectImageFileExtension(from: data) ?? "img"
		var name = baseName
		let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
		if !desc.isEmpty {
			name += " - " + sanitize(desc)
		}
		name += "." + ext
		folder.addFile(withName: name, contents: data)
	}

	// Very small sanitizer to keep filenames safe cross-platform
	private static func sanitize(_ s: String) -> String {
		let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:").union(.newlines)
		return s.components(separatedBy: invalid).joined().trimmingCharacters(in: .whitespacesAndNewlines)
	}

	// Try to infer a good file extension from image data
	private static func detectImageFileExtension(from data: Data) -> String? {
		guard let src = CGImageSourceCreateWithData(data as CFData, nil),
		      let uti = CGImageSourceGetType(src) else { return nil }
		guard let type = UTType(uti as String) else { return nil }
		// Prefer common extensions
		if type.conforms(to: .png) { return "png" }
		if type.conforms(to: .jpeg) { return "jpg" }
		if type.conforms(to: .heic) { return "heic" }
		if type.conforms(to: .tiff) { return "tiff" }
		if type.conforms(to: .gif) { return "gif" }
		// Fallback to preferred filename extension if available
		return type.preferredFilenameExtension
	}
}

// MARK: - BackupService (public API used by views)

enum BackupService {
	static func defaultBackupFilename() -> String {
		let name = AppInfo.displayName.replacingOccurrences(of: " ", with: "")
		let df = DateFormatter()
		df.dateFormat = "yyyy-MM-dd_HHmm"
		return "\(name)_Backup_\(df.string(from: Date()))"
	}

	static func makeBackupDocument(context: ModelContext) throws -> BackupDocument {
		let wrapper = try BackupBuilder.makeBackupWrapper(context: context)
		return BackupDocument(root: wrapper)
	}

	// Returns a success message on completion
	static func restoreFromBackupFolder(_ folderURL: URL) async throws -> String {
		// Security-scoped access if needed (iOS/macOS sandbox)
		let needsAccess = folderURL.startAccessingSecurityScopedResource()
		defer {
			if needsAccess { folderURL.stopAccessingSecurityScopedResource() }
		}

		let fm = FileManager.default

		// Resolve target locations
		guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first,
		      let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
		else {
			throw NSError(domain: "Restore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to resolve app directories."])
		}

		// Locate expected subfolders in backup
		let backupDocs = folderURL.appendingPathComponent("Documents", isDirectory: true)
		let backupSupport = folderURL.appendingPathComponent("Application Support", isDirectory: true)

		// Replace Documents
		if fm.fileExists(atPath: backupDocs.path) {
			try replaceContents(of: docs, with: backupDocs)
		}

		// Replace Application Support
		if fm.fileExists(atPath: backupSupport.path) {
			try replaceContents(of: appSupport, with: backupSupport)
		}

		return "Restore complete. For consistency, please relaunch the app."
	}

	// Replace the contents of target directory with contents of source directory
	private static func replaceContents(of targetDir: URL, with sourceDir: URL) throws {
		let fm = FileManager.default

		// Ensure target directory exists
		try fm.createDirectory(at: targetDir, withIntermediateDirectories: true, attributes: nil)

		// Remove everything currently in target
		if let items = try? fm.contentsOfDirectory(at: targetDir, includingPropertiesForKeys: nil, options: []) {
			for item in items {
				try fm.removeItem(at: item)
			}
		}

		// Copy everything from source into target
		if let items = try? fm.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: nil, options: []) {
			for item in items {
				let dest = targetDir.appendingPathComponent(item.lastPathComponent, isDirectory: false)
				try fm.copyItem(at: item, to: dest)
			}
		}
	}
}
