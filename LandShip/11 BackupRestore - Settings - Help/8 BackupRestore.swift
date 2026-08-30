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

	nonisolated(unsafe) private var rootWrapper: FileWrapper

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

// Wraps a non-Sendable value (e.g. FileWrapper) so it can cross an actor boundary once,
// used only to hand a finished, no-longer-mutated object back from a detached Task.
private struct UncheckedBox<Value>: @unchecked Sendable {
	let value: Value
}

// MARK: - BackupBuilder builds the folder structure to export

enum BackupBuilder {
	enum BackupError: Error {
		case containerUnavailable
		case failedToEnumerate(URL)
		case fetchFailed(String)
	}

	// MARK: Media snapshots (fetched on the caller's actor, e.g. MainActor, since ModelContext isn't Sendable)

	struct MediaImageSnapshot: Sendable {
		let baseName: String
		let description: String
		let data: Data
	}

	struct MediaRecordSnapshot: Sendable {
		let displayName: String
		let images: [MediaImageSnapshot]
	}

	struct MediaCategorySnapshot: Sendable {
		let folderName: String
		let records: [MediaRecordSnapshot]
	}

	/// Fetches all image-bearing entities and captures just their names/descriptions/image
	/// bytes as plain Sendable values. Must be called on the actor that owns `context`
	/// (SwiftData's ModelContext is not Sendable and cannot be touched from a background task).
	static func collectMediaSnapshots(context: ModelContext) throws -> [MediaCategorySnapshot] {
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

		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd"

		func images(_ entries: [(baseName: String, data: Data?, description: String)]) -> [MediaImageSnapshot] {
			entries.compactMap { entry in
				guard let data = entry.data else { return nil }
				return MediaImageSnapshot(baseName: entry.baseName, description: entry.description, data: data)
			}
		}

		let vehicleRecords: [MediaRecordSnapshot] = vehicles.compactMap { v in
			let imgs = images([
				("image1", v.image1, v.image1Description),
				("image2", v.image2, v.image2Description),
				("image3", v.image3, v.image3Description),
			])
			guard !imgs.isEmpty else { return nil }
			return MediaRecordSnapshot(displayName: v.name.isEmpty ? "Vehicle" : v.name, images: imgs)
		}

		let systemRecords: [MediaRecordSnapshot] = systems.compactMap { s in
			let display = [s.vehicleId, s.systemName].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " - ")
			let imgs = images([
				("systemImage", s.systemImage, ""),
				("image1", s.image1, s.image1Description),
				("image2", s.image2, s.image2Description),
				("image3", s.image3, s.image3Description),
			])
			guard !imgs.isEmpty else { return nil }
			return MediaRecordSnapshot(displayName: display.isEmpty ? "System" : display, images: imgs)
		}

		let vendorRecords: [MediaRecordSnapshot] = vendors.compactMap { v in
			let imgs = images([
				("image1", v.image1, v.image1Description),
				("image2", v.image2, v.image2Description),
				("image3", v.image3, v.image3Description),
			])
			guard !imgs.isEmpty else { return nil }
			return MediaRecordSnapshot(displayName: v.vendorName.isEmpty ? "Vendor" : v.vendorName, images: imgs)
		}

		let serviceRecordRecords: [MediaRecordSnapshot] = records.compactMap { r in
			let datePart = dateFormatter.string(from: r.mxDate)
			let display = [r.vehicleId, r.mxName, datePart]
				.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
				.joined(separator: " - ")
			let imgs = images([
				("image", r.image, ""),
				("image1", r.image1, r.image1Description),
				("image2", r.image2, r.image2Description),
				("image3", r.image3, r.image3Description),
			])
			guard !imgs.isEmpty else { return nil }
			return MediaRecordSnapshot(displayName: display.isEmpty ? "ServiceRecord" : display, images: imgs)
		}

		let itemRecords: [MediaRecordSnapshot] = items.compactMap { i in
			let display = [i.vehicleId, i.mxName]
				.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
				.joined(separator: " - ")
			let imgs = images([
				("image1", i.image1, i.image1Description),
				("image2", i.image2, i.image2Description),
				("image3", i.image3, i.image3Description),
			])
			guard !imgs.isEmpty else { return nil }
			return MediaRecordSnapshot(displayName: display.isEmpty ? "Item" : display, images: imgs)
		}

		let partRecords: [MediaRecordSnapshot] = parts.compactMap { p in
			let display = [p.vehicleId, p.partName]
				.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
				.joined(separator: " - ")
			let imgs = images([
				("partImage", p.partImage, ""),
				("image1", p.image1, p.image1Description),
				("image2", p.image2, p.image2Description),
				("image3", p.image3, p.image3Description),
			])
			guard !imgs.isEmpty else { return nil }
			return MediaRecordSnapshot(displayName: display.isEmpty ? "Part" : display, images: imgs)
		}

		let fuelLogRecords: [MediaRecordSnapshot] = fuelLogs.compactMap { f in
			let datePart = dateFormatter.string(from: f.fuelDateTime)
			let display = [f.vehicleId, datePart, f.location.isEmpty ? f.logName : f.location]
				.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
				.joined(separator: " - ")
			let imgs = images([
				("image1", f.image1, f.image1Description),
				("image2", f.image2, f.image2Description),
				("image3", f.image3, f.image3Description),
			])
			guard !imgs.isEmpty else { return nil }
			return MediaRecordSnapshot(displayName: display.isEmpty ? "FuelLog" : display, images: imgs)
		}

		let tripLogRecords: [MediaRecordSnapshot] = tripLogs.compactMap { t in
			let datePart = dateFormatter.string(from: t.tripDateTimeStart)
			let display = [t.vehicleId, t.logName, datePart]
				.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
				.joined(separator: " - ")
			let imgs = images([
				("image1", t.image1, t.image1Description),
				("image2", t.image2, t.image2Description),
				("image3", t.image3, t.image3Description),
			])
			guard !imgs.isEmpty else { return nil }
			return MediaRecordSnapshot(displayName: display.isEmpty ? "TripLog" : display, images: imgs)
		}

		let categories: [MediaCategorySnapshot] = [
			MediaCategorySnapshot(folderName: "Vehicles", records: vehicleRecords),
			MediaCategorySnapshot(folderName: "Systems", records: systemRecords),
			MediaCategorySnapshot(folderName: "Vendors", records: vendorRecords),
			MediaCategorySnapshot(folderName: "ServiceRecords", records: serviceRecordRecords),
			MediaCategorySnapshot(folderName: "Items", records: itemRecords),
			MediaCategorySnapshot(folderName: "Parts", records: partRecords),
			MediaCategorySnapshot(folderName: "FuelLogs", records: fuelLogRecords),
			MediaCategorySnapshot(folderName: "TripLogs", records: tripLogRecords),
		]
		return categories.filter { !$0.records.isEmpty }
	}

	/// Builds the exportable folder structure. Pure FileManager/Data work — safe to call
	/// off the main thread (e.g. from a detached Task) since it never touches SwiftData.
	static func makeBackupWrapper(mediaSnapshots: [MediaCategorySnapshot]) throws -> FileWrapper {
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
		if let mediaWrapper = buildMediaFolder(from: mediaSnapshots) {
			root.addFileWrapper(mediaWrapper)
		}

		return root
	}

	// Recursively builds a FileWrapper from a directory on disk.
	// Includes hidden (dot-prefixed) files/folders so the backup is a true full copy of the
	// directory — restore's copy step doesn't skip hidden files either, so skipping them only
	// on export would silently produce incomplete backups.
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
		let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: resourceKeys, options: [])
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

	// MARK: - Media export (pure FileWrapper assembly from already-collected snapshots)

	private static func buildMediaFolder(from categories: [MediaCategorySnapshot]) -> FileWrapper? {
		let nonEmpty = categories.filter { !$0.records.isEmpty }
		guard !nonEmpty.isEmpty else { return nil }

		let mediaRoot = FileWrapper(directoryWithFileWrappers: [:])
		mediaRoot.preferredFilename = "Media"

		for category in nonEmpty {
			let categoryFolder = FileWrapper(directoryWithFileWrappers: [:])
			categoryFolder.preferredFilename = category.folderName
			for record in category.records {
				let recordFolder = FileWrapper(directoryWithFileWrappers: [:])
				recordFolder.preferredFilename = sanitize(record.displayName)
				for image in record.images {
					addImageIfPresent(image.data, baseName: image.baseName, description: image.description, into: recordFolder)
				}
				if let files = recordFolder.fileWrappers, !files.isEmpty {
					categoryFolder.addFileWrapper(recordFolder)
				}
			}
			if let files = categoryFolder.fileWrappers, !files.isEmpty {
				mediaRoot.addFileWrapper(categoryFolder)
			}
		}

		guard let files = mediaRoot.fileWrappers, !files.isEmpty else { return nil }
		return mediaRoot
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

	/// Must be called on the actor that owns `context` (typically MainActor) — SwiftData's
	/// ModelContext is not Sendable and can't be fetched from off the main thread.
	static func collectMediaSnapshots(context: ModelContext) throws -> [BackupBuilder.MediaCategorySnapshot] {
		try BackupBuilder.collectMediaSnapshots(context: context)
	}

	/// Builds the exportable backup document. The heavy recursive file-system read is done on a
	/// detached background task so tapping "Backup…" doesn't freeze the UI while it runs.
	static func makeBackupDocument(mediaSnapshots: [BackupBuilder.MediaCategorySnapshot]) async throws -> BackupDocument {
		let box = try await Task.detached(priority: .userInitiated) { () -> UncheckedBox<FileWrapper> in
			let wrapper = try BackupBuilder.makeBackupWrapper(mediaSnapshots: mediaSnapshots)
			return UncheckedBox(value: wrapper)
		}.value
		return BackupDocument(root: box.value)
	}

	/// Whether the currently-running ModelContainer was created in CloudKit-backed mode at
	/// launch (set by LandShipApp). The container's mode is fixed for the app's lifetime, so
	/// this reflects whether the on-disk store actually carries CloudKit mirroring metadata —
	/// not just whether the network happens to be reachable right now. Exposed so the UI can
	/// decide whether to offer a choice of restore mode.
	static func isCloudKitActive() -> Bool {
		UserDefaults.standard.string(forKey: "StartupStoreMode") == "cloud"
	}

	/// Returns a success message on completion.
	/// - Parameter forceExactSnapshot: When iCloud sync is active, restoring normally skips the
	///   raw local database (letting CloudKit repopulate it fresh) to avoid pushing stale/deleted
	///   data back out to every synced device. Pass `true` to override that and force an exact
	///   raw restore of the local database anyway — useful when restoring onto a different iCloud
	///   account, or when iCloud's own data didn't come back correctly and the backup snapshot
	///   needs to be forced back in. Ignored (has no effect) when iCloud sync isn't active, since
	///   an exact restore is already what happens in that case.
	static func restoreFromBackupFolder(_ folderURL: URL, forceExactSnapshot: Bool = false) async throws -> String {
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

		let hasDocs = fm.fileExists(atPath: backupDocs.path)
		let hasSupport = fm.fileExists(atPath: backupSupport.path)

		// If neither expected subfolder is present, this isn't a valid backup folder — fail
		// loudly instead of silently "succeeding" with nothing restored.
		guard hasDocs || hasSupport else {
			throw NSError(domain: "Restore", code: 2, userInfo: [
				NSLocalizedDescriptionKey: "The selected folder doesn't look like a \(AppInfo.displayName) backup — no \u{201C}Documents\u{201D} or \u{201C}Application Support\u{201D} folder was found inside it."
			])
		}

		if hasDocs {
			try replaceContents(of: docs, with: backupDocs)
		}

		guard hasSupport || isCloudKitActive() else {
			return "Your Documents have been restored. \(AppInfo.displayName) must restart now to finish loading them."
		}

		// The local SwiftData store carries its own CloudKit mirroring metadata (change tokens,
		// per-record sync state). Overwriting it with an old snapshot restores that stale belief
		// about what's already synced too — on relaunch the mirroring engine can reconcile against
		// it and push old/deleted records back out to every other device on the account.
		//
		// So by default, when iCloud sync is active, don't touch the local store from the backup
		// at all. Instead, clear it so SwiftData does a full, fresh import from CloudKit on
		// relaunch — CloudKit's current state is treated as authoritative. `forceExactSnapshot`
		// opts out of that and restores the raw snapshot anyway (see the doc comment above).
		if isCloudKitActive() && !forceExactSnapshot {
			try resetLocalStoreForCloudKitRepopulation(appSupportDir: appSupport)
			return "Your Documents have been restored. Because iCloud sync is active, your vehicle and service data will re-download fresh from iCloud instead of the backup snapshot. \(AppInfo.displayName) must restart now to begin that."
		} else if hasSupport {
			try replaceContents(of: appSupport, with: backupSupport)
			if isCloudKitActive() {
				return "Your data has been restored exactly as saved in the backup, overriding iCloud sync. This can conflict with other devices signed into the same iCloud account until they resync. \(AppInfo.displayName) must restart now to finish loading it."
			} else {
				return "Your data has been restored. \(AppInfo.displayName) must restart now to finish loading it safely."
			}
		} else {
			return "Your Documents have been restored. \(AppInfo.displayName) must restart now to finish loading them."
		}
	}

	/// Clears the local store directory (via the same stage-and-rollback path as a normal
	/// restore) without copying anything back in, so SwiftData starts fresh and CloudKit
	/// mirroring fully re-imports from the private database on next launch.
	private static func resetLocalStoreForCloudKitRepopulation(appSupportDir: URL) throws {
		let fm = FileManager.default
		let emptySource = fm.temporaryDirectory.appendingPathComponent("empty-restore-source-\(UUID().uuidString)", isDirectory: true)
		try fm.createDirectory(at: emptySource, withIntermediateDirectories: true, attributes: nil)
		defer { try? fm.removeItem(at: emptySource) }
		try replaceContents(of: appSupportDir, with: emptySource)
	}

	// Replace the contents of target directory with contents of source directory.
	// Stages the target's original contents aside first so a partial failure mid-copy can be
	// rolled back, instead of leaving the target (which may be the live SwiftData store) in a
	// half-deleted, half-restored state.
	private static func replaceContents(of targetDir: URL, with sourceDir: URL) throws {
		let fm = FileManager.default

		// Ensure target directory exists
		try fm.createDirectory(at: targetDir, withIntermediateDirectories: true, attributes: nil)

		let stagingDir = targetDir.deletingLastPathComponent()
			.appendingPathComponent(".restore-rollback-\(UUID().uuidString)", isDirectory: true)
		try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true, attributes: nil)

		// Move (not delete) the target's current contents into staging.
		var stagedItems: [(original: URL, staged: URL)] = []
		if let existing = try? fm.contentsOfDirectory(at: targetDir, includingPropertiesForKeys: nil, options: []) {
			for item in existing {
				let staged = stagingDir.appendingPathComponent(item.lastPathComponent)
				try fm.moveItem(at: item, to: staged)
				stagedItems.append((original: item, staged: staged))
			}
		}

		do {
			if let items = try? fm.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: nil, options: []) {
				for item in items {
					let dest = targetDir.appendingPathComponent(item.lastPathComponent, isDirectory: false)
					try fm.copyItem(at: item, to: dest)
				}
			}
			// Success — the staged originals are no longer needed.
			try? fm.removeItem(at: stagingDir)
		} catch {
			// Roll back: discard whatever partially copied in, restore the originals from staging.
			if let partial = try? fm.contentsOfDirectory(at: targetDir, includingPropertiesForKeys: nil, options: []) {
				for item in partial { try? fm.removeItem(at: item) }
			}
			for staged in stagedItems {
				try? fm.moveItem(at: staged.staged, to: staged.original)
			}
			try? fm.removeItem(at: stagingDir)
			throw error
		}
	}

    // MARK: - Backup summary (for post-export dialog)

    /// Builds a human-readable summary of a backup folder for display in a dialog.
    /// - Parameters:
    ///   - url: The URL of the exported backup folder.
    ///   - maxDepth: How deep to enumerate subfolders (default 2).
    ///   - maxItemsPerFolder: Maximum number of items to list per folder before truncating (default 50).
    /// - Returns: A multi-line string describing the backup location, folder name, and contents.
    static func summarizeBackupFolder(at url: URL, maxDepth: Int = 2, maxItemsPerFolder: Int = 50) -> String {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return "Backup folder not found at: \(url.path)"
        }

        let folderName = url.lastPathComponent
        let parentPath = url.deletingLastPathComponent().path

        var lines: [String] = []
        lines.append("Backup saved to:")
        lines.append(parentPath)
        lines.append("")
        lines.append("Folder: \(folderName)")

        // Top-level contents heading
        lines.append("Contents:")
        let contentsLines = describeFolder(url: url, depth: 0, maxDepth: maxDepth, maxItems: maxItemsPerFolder)
        if contentsLines.isEmpty {
            lines.append("  (empty)")
        } else {
            lines.append(contentsOf: contentsLines)
        }

        return lines.joined(separator: "\n")
    }

    /// Recursively describes a folder's contents up to `maxDepth`.
    /// Produces lines prefixed with indentation for readability.
    private static func describeFolder(url: URL, depth: Int, maxDepth: Int, maxItems: Int) -> [String] {
        let fm = FileManager.default
        let indent = String(repeating: "  ", count: depth + 1)

        guard let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return ["\(indent)• (unreadable)"]
        }

        var lines: [String] = []
        let displayItems = items.prefix(maxItems)

        for item in displayItems {
            let resourceValues = try? item.resourceValues(forKeys: Set([.isDirectoryKey, .fileSizeKey]))
            let isDir = resourceValues?.isDirectory ?? false
            if isDir {
                lines.append("\(indent)• \(item.lastPathComponent)/")
                if depth < maxDepth {
                    let childLines = describeFolder(url: item, depth: depth + 1, maxDepth: maxDepth, maxItems: maxItems)
                    lines.append(contentsOf: childLines)
                }
            } else {
                let size = resourceValues?.fileSize ?? 0
                let sizeText = size > 0 ? " (\(formatBytes(size)))" : ""
                lines.append("\(indent)• \(item.lastPathComponent)\(sizeText)")
            }
        }

        if items.count > displayItems.count {
            let remaining = items.count - displayItems.count
            lines.append("\(indent)… and \(remaining) more")
        }

        return lines
    }

    /// Formats a byte count into a short human-readable string.
    static func formatBytes(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        let formatted = String(format: value < 10 && unitIndex > 0 ? "%.1f" : "%.0f", value)
        return "\(formatted) \(units[unitIndex])"
    }
}

// MARK: - AutoBackupService (unattended, interval-based backups)

/// One backup folder found in the app-managed auto-backup directory.
struct AutoBackupEntry: Identifiable, Sendable {
	var id: URL { url }
	let url: URL
	let date: Date?
	let sizeText: String
}

/// Creates, lists, and prunes automatic backups on a user-chosen schedule (see
/// `AutoBackupInterval`), stored in an app-managed folder rather than a
/// user-picked location — there's no file picker to drive unattended, so this
/// writes directly into the app's own Documents/Backups folder. Because that
/// folder isn't exposed outside the app (no Files-app sharing is enabled),
/// `ManageAutoBackupsView` provides Restore/Share/Delete so these backups
/// remain reachable and can still be copied off-device via the share sheet.
enum AutoBackupService {
	/// Whether enough time has passed since the last *automatic* backup for the
	/// currently configured interval — tracked separately from manual backups,
	/// so a manual backup never delays or masks the automatic schedule. If no
	/// automatic backup has ever been made (and a non-Off interval is chosen),
	/// this is due immediately, creating the first one on the next check.
	static func isDue() -> Bool {
		guard let minimumElapsed = currentInterval().minimumElapsed else { return false }
		let last = UserDefaults.standard.double(forKey: StorageKey.lastAutoBackupDate)
		guard last > 0 else { return true }
		return Date().timeIntervalSince(Date(timeIntervalSince1970: last)) >= minimumElapsed
	}

	static func currentInterval() -> AutoBackupInterval {
		let raw = UserDefaults.standard.string(forKey: StorageKey.autoBackupInterval) ?? AutoBackupInterval.off.rawValue
		return AutoBackupInterval(rawValue: raw) ?? .off
	}

	private static func retentionCount() -> Int {
		let stored = UserDefaults.standard.object(forKey: StorageKey.autoBackupRetentionCount) as? Int
		return max(1, stored ?? 5)
	}

	/// Builds and writes an automatic backup, then prunes older ones beyond the
	/// configured retention count. `mediaSnapshots` must already be collected
	/// on the main actor (see `BackupService.collectMediaSnapshots`) before
	/// calling this, since the heavy work here runs off the main thread.
	static func run(mediaSnapshots: [BackupBuilder.MediaCategorySnapshot]) async {
		do {
			let retain = retentionCount()
			try await Task.detached(priority: .utility) {
				let wrapper = try BackupBuilder.makeBackupWrapper(mediaSnapshots: mediaSnapshots)
				let folder = try autoBackupsFolder()
				let dest = folder.appendingPathComponent(BackupService.defaultBackupFilename(), isDirectory: true)
				try wrapper.write(to: dest, options: [.atomic], originalContentsURL: nil)
				pruneOldBackups(keeping: retain)
			}.value
			// Only updates the automatic-backup timestamp — "last backup" (StorageKey.lastBackupDate)
			// is reserved for manual backups, tracked separately in ContentView.
			UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: StorageKey.lastAutoBackupDate)
			print("[LandShip] Automatic backup created")
		} catch {
			print("[LandShip] Automatic backup failed: \(error.localizedDescription)")
		}
	}

	static func listAutoBackups() -> [AutoBackupEntry] {
		guard let folder = try? autoBackupsFolder() else { return [] }
		let fm = FileManager.default
		guard let items = try? fm.contentsOfDirectory(
			at: folder,
			includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
			options: [.skipsHiddenFiles]
		) else { return [] }

		let entries: [AutoBackupEntry] = items.compactMap { url in
			let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
			guard values?.isDirectory == true else { return nil }
			return AutoBackupEntry(
				url: url,
				date: values?.contentModificationDate,
				sizeText: BackupService.formatBytes(folderSize(at: url))
			)
		}
		return entries.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
	}

	static func deleteAutoBackup(at url: URL) {
		try? FileManager.default.removeItem(at: url)
	}

	private static func autoBackupsFolder() throws -> URL {
		let fm = FileManager.default
		guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
			throw NSError(domain: "AutoBackup", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to resolve the Documents directory."])
		}
		let folder = docs.appendingPathComponent("Backups", isDirectory: true)
		if !fm.fileExists(atPath: folder.path) {
			try fm.createDirectory(at: folder, withIntermediateDirectories: true)
		}
		return folder
	}

	private static func pruneOldBackups(keeping retain: Int) {
		guard let folder = try? autoBackupsFolder() else { return }
		let fm = FileManager.default
		guard let items = try? fm.contentsOfDirectory(
			at: folder,
			includingPropertiesForKeys: [.contentModificationDateKey],
			options: [.skipsHiddenFiles]
		) else { return }

		let sorted = items.sorted { a, b in
			let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
			let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
			return da > db
		}
		if sorted.count > retain {
			for extra in sorted.dropFirst(retain) {
				try? fm.removeItem(at: extra)
			}
		}
	}

	private static func folderSize(at url: URL) -> Int {
		let fm = FileManager.default
		guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
		var total = 0
		for case let fileURL as URL in enumerator {
			if let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
				total += size
			}
		}
		return total
	}
}

// MARK: - ManageAutoBackupsView (list/restore/share/delete automatic backups)

struct ManageAutoBackupsView: View {
	var onRestoreRequested: (URL) -> Void

	@State private var entries: [AutoBackupEntry] = []
	@State private var pendingDeleteURL: URL?
	@State private var showDeleteConfirm = false

	var body: some View {
		List {
			if entries.isEmpty {
				ContentUnavailableView(
					"No Automatic Backups Yet",
					systemImage: "clock.arrow.circlepath",
					description: Text("Once automatic backups are enabled above and due, they’ll appear here.")
				)
			} else {
				ForEach(entries) { entry in
					VStack(alignment: .leading, spacing: 6) {
						Text(entry.date?.formatted(date: .abbreviated, time: .shortened) ?? entry.url.lastPathComponent)
							.font(.subheadline).bold()
						Text(entry.sizeText)
							.font(.caption)
							.foregroundStyle(.secondary)
						HStack(spacing: 20) {
							Button {
								onRestoreRequested(entry.url)
							} label: {
								Label("Restore", systemImage: "arrow.counterclockwise")
							}
							ShareLink(item: entry.url) {
								Label("Share…", systemImage: "square.and.arrow.up")
							}
							Spacer()
							Button(role: .destructive) {
								pendingDeleteURL = entry.url
								showDeleteConfirm = true
							} label: {
								Label("Delete", systemImage: "trash")
							}
						}
						.buttonStyle(.borderless)
						.font(.caption)
					}
					.padding(.vertical, 4)
				}
			}
		}
		.navigationTitle("Automatic Backups")
		.onAppear(perform: refresh)
		.alert("Delete This Backup?", isPresented: $showDeleteConfirm) {
			Button("Delete", role: .destructive) {
				if let url = pendingDeleteURL {
					AutoBackupService.deleteAutoBackup(at: url)
					refresh()
				}
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("This permanently removes this automatic backup from the device. This cannot be undone.")
		}
	}

	private func refresh() {
		entries = AutoBackupService.listAutoBackups()
	}
}

// MARK: - BackupSummarySheet (post-export dialog)

/// Scrollable presentation of the backup summary text, so the full file list
/// remains reachable (and the close button stays accessible) regardless of
/// how many files were backed up.
struct BackupSummarySheet: View {
    var message: String
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(message)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Backup Complete")
            .toolbar {
#if os(macOS)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                        .keyboardShortcut("w", modifiers: .command)
                        .keyboardShortcut(.cancelAction)
                }
#else
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { onDismiss() }
                }
#endif
            }
        }
    }
}

// MARK: - RestartRequiredView (post-restore enforcement, non-macOS)

#if !os(macOS)
/// Blocking, non-dismissable screen shown after a successful restore on platforms where the
/// app can't be force-quit programmatically. Continuing to use the app after a restore would
/// keep writing into the old (already-open) store file instead of the freshly restored one,
/// so this steers the user toward an actual relaunch instead of silently losing further edits.
struct RestartRequiredView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Restart Required")
                .font(.title2.bold())
            Text("Your data has been restored. To finish loading it safely, please close \(AppInfo.displayName) completely — swipe it up from the App Switcher — then reopen it.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}
#endif
