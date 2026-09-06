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
import CoreData
import CloudKit

// MARK: - AppSchema (single source of truth for the model list)

/// Every @Model type in the app. LandShipApp builds its SwiftData Schema from this same
/// list, and the restore re-import walks it entity by entity — sharing one list keeps the
/// two from ever drifting apart.
enum AppSchema {
	static let modelTypes: [any PersistentModel.Type] = [
		MxItems3.self,
		MxParts1.self,
		ServiceRecords1.self,
		Vehicle8.self,
		VehicleSystems1.self,
		Vendors1.self,
		Settings1.self,
		FuelLog1.self,
		TripLog2.self,
		Additions.self,
		Subscriptions.self,
		ProjectList.self,
		CheckList.self,
		CheckListItem.self,
		VehicleWarranty.self,
		VehicleSerialItem.self,
		VehicleScaleTicket.self
	]
}

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

	/// Describes what a staged restore should do when applied at the next launch.
	struct PendingRestoreManifest: Codable {
		enum SupportAction: String, Codable {
			/// Exact snapshot: rebuild the store by copying every record out of the backup's
			/// database into a brand-new store. The records get fresh identities and no
			/// CloudKit sync metadata, so when CloudKit mirroring next runs it uploads them
			/// as new — instead of reconciling the backup's stale sync state against the
			/// server and deleting the restored records again (which is what a raw file
			/// swap of a CloudKit-mirrored store leads to).
			case reimport
			/// Clear the local store so CloudKit re-imports fresh on this launch.
			case clearForCloudRepopulation
			/// Leave Application Support untouched (Documents-only restore).
			case none
		}
		var restoreDocuments: Bool
		var supportAction: SupportAction
	}

	private static let pendingManifestFilename = "manifest.json"

	/// App-private folder (outside both Documents and Application Support, so it's never
	/// part of a backup) holding a staged restore waiting to be applied at next launch.
	private static func pendingRestoreFolder() throws -> URL {
		guard let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
			throw NSError(domain: "Restore", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to resolve the Library directory."])
		}
		return library.appendingPathComponent("PendingRestore", isDirectory: true)
	}

	/// Stages a restore from the given backup folder and returns a success message.
	///
	/// This deliberately does NOT touch the live Documents or Application Support
	/// directories. The app's SwiftData store is still open (and CloudKit mirroring still
	/// running) while this executes — swapping the database files underneath them is what
	/// used to silently lose restored data: on quit, SQLite's clean close deletes the
	/// `-wal`/`-shm` sidecar files at the store path, destroying the freshly restored
	/// copies and with them most of the restored records. Instead, the backup is copied
	/// into Library/PendingRestore together with a manifest, and
	/// `applyPendingRestoreIfNeeded()` applies it at the next launch, before the
	/// ModelContainer opens the store.
	///
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

		// Decide what applying this restore should do to Application Support.
		//
		// The local SwiftData store carries its own CloudKit mirroring metadata (change tokens,
		// per-record sync state). Overwriting it with an old snapshot restores that stale belief
		// about what's already synced too — on relaunch the mirroring engine can reconcile against
		// it and push old/deleted records back out to every other device on the account.
		//
		// So by default, when iCloud sync is active, don't restore the local store from the
		// backup at all. Instead, clear it so SwiftData does a full, fresh import from CloudKit
		// on relaunch — CloudKit's current state is treated as authoritative. `forceExactSnapshot`
		// opts out of that and restores the raw snapshot anyway (see the doc comment above).
		let supportAction: PendingRestoreManifest.SupportAction
		if isCloudKitActive() && !forceExactSnapshot {
			supportAction = .clearForCloudRepopulation
		} else if hasSupport {
			supportAction = .reimport
		} else {
			supportAction = .none
		}

		// Stage into a fresh Library/PendingRestore folder.
		let pending = try pendingRestoreFolder()
		if fm.fileExists(atPath: pending.path) {
			try fm.removeItem(at: pending)
		}
		try fm.createDirectory(at: pending, withIntermediateDirectories: true, attributes: nil)

		do {
			if hasDocs {
				try fm.copyItem(at: backupDocs, to: pending.appendingPathComponent("Documents", isDirectory: true))
			}
			if supportAction == .reimport {
				let stagedSupport = pending.appendingPathComponent("Application Support", isDirectory: true)
				try fm.copyItem(at: backupSupport, to: stagedSupport)
				// Catch cloud-storage placeholder files (Dropbox/iCloud Drive folders that were
				// never downloaded copy "successfully" as stubs) before reporting success —
				// otherwise the next launch would quietly start with an empty database.
				try validateStagedStore(in: stagedSupport)
			}

			let manifest = PendingRestoreManifest(restoreDocuments: hasDocs, supportAction: supportAction)
			let manifestData = try JSONEncoder().encode(manifest)
			try manifestData.write(to: pending.appendingPathComponent(pendingManifestFilename), options: [.atomic])
		} catch {
			// Leave no half-staged restore behind for the next launch to trip over.
			try? fm.removeItem(at: pending)
			throw error
		}

		let baseMessage: String
		switch supportAction {
			case .clearForCloudRepopulation:
				baseMessage = "Your restore is ready. When \(AppInfo.displayName) restarts, your Documents will be restored from the backup, and because iCloud sync is active your vehicle and service data will re-download fresh from iCloud instead of the backup snapshot. \(AppInfo.displayName) must restart now to begin."
			case .reimport:
				if isCloudKitActive() {
					baseMessage = "Your restore is ready. When \(AppInfo.displayName) restarts, your data will be rebuilt from the backup and uploaded to iCloud, replacing what iCloud has now. Other devices signed into the same iCloud account will update to match once they sync. \(AppInfo.displayName) must restart now to finish."
				} else {
					baseMessage = "Your restore is ready. Your data will be rebuilt from the backup when \(AppInfo.displayName) restarts. \(AppInfo.displayName) must restart now to finish."
				}
			case .none:
				baseMessage = "Your restore is ready. Your Documents will be restored from the backup when \(AppInfo.displayName) restarts. \(AppInfo.displayName) must restart now to finish."
		}
		return baseMessage + "\n\n" + stagedRestoreSummary(pending: pending, restoreDocuments: hasDocs, supportAction: supportAction)
	}

	/// Human-readable list of what a staged restore will bring back, appended to the
	/// restart dialog — the restore-side counterpart of the post-backup summary sheet.
	private static func stagedRestoreSummary(pending: URL, restoreDocuments: Bool, supportAction: PendingRestoreManifest.SupportAction) -> String {
		var lines: [String] = ["What will be restored:"]
		if restoreDocuments {
			lines.append("")
			lines.append("Documents:")
			let docLines = describeFolder(url: pending.appendingPathComponent("Documents", isDirectory: true), depth: 0, maxDepth: 2, maxItems: 50)
			lines.append(contentsOf: docLines.isEmpty ? ["  (empty)"] : docLines)
		}
		switch supportAction {
			case .reimport:
				lines.append("")
				lines.append("Database (vehicles, records, photos, settings):")
				let supportLines = describeFolder(url: pending.appendingPathComponent("Application Support", isDirectory: true), depth: 0, maxDepth: 2, maxItems: 50)
				lines.append(contentsOf: supportLines.isEmpty ? ["  (empty)"] : supportLines)
			case .clearForCloudRepopulation:
				lines.append("")
				lines.append("Database (vehicles, records, photos, settings): will re-download fresh from iCloud.")
			case .none:
				break
		}
		return lines.joined(separator: "\n")
	}

	/// Verifies the staged Application Support copy actually contains a usable SwiftData
	/// database (a non-empty `*.store` file). Cloud-synced source folders (Dropbox,
	/// iCloud Drive) can hand over undownloaded placeholder stubs that copy without error;
	/// this turns that into a visible failure instead of a silent empty restore.
	private static func validateStagedStore(in stagedSupport: URL) throws {
		let fm = FileManager.default
		let items = (try? fm.contentsOfDirectory(at: stagedSupport, includingPropertiesForKeys: [.fileSizeKey], options: [])) ?? []
		let hasUsableStore = items.contains { url in
			guard url.lastPathComponent.hasSuffix(".store") else { return false }
			let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
			return size > 0
		}
		guard hasUsableStore else {
			throw NSError(domain: "Restore", code: 4, userInfo: [
				NSLocalizedDescriptionKey: "The backup's database file is missing or empty. If the backup folder is stored in Dropbox or iCloud Drive, make sure its contents are fully downloaded to this device (not online-only), then try again. Nothing was changed."
			])
		}
	}

	/// Applies a restore staged by `restoreFromBackupFolder`, if one is waiting.
	///
	/// Must be called at app launch BEFORE the ModelContainer is created, so the store
	/// files are swapped while nothing has them open. Attempted exactly once — the staged
	/// folder is removed whether or not applying succeeds, so a bad restore can't put the
	/// app into a failure loop. Returns true if a staged restore was applied.
	@discardableResult
	static func applyPendingRestoreIfNeeded() -> Bool {
		let fm = FileManager.default
		guard let pending = try? pendingRestoreFolder(), fm.fileExists(atPath: pending.path) else {
			return false
		}
		// If the process died mid-apply on a previous launch, the marker file is still here —
		// allow exactly one retry (the import is idempotent), then give up rather than
		// crash-looping the app on a bad backup.
		let attemptMarker = pending.appendingPathComponent("attempted")
		let isRetry = fm.fileExists(atPath: attemptMarker.path)
		if isRetry {
			print("[LandShip] PendingRestore: retrying once after an interrupted apply")
		}
		defer { try? fm.removeItem(at: pending) }

		guard let manifestData = try? Data(contentsOf: pending.appendingPathComponent(pendingManifestFilename)),
		      let manifest = try? JSONDecoder().decode(PendingRestoreManifest.self, from: manifestData) else {
			print("[LandShip] PendingRestore folder found but its manifest is unreadable — skipping restore")
			return false
		}

		guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first,
		      let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
			print("[LandShip] PendingRestore: unable to resolve app directories — skipping restore")
			return false
		}

		do {
			if !isRetry {
				fm.createFile(atPath: attemptMarker.path, contents: nil)
			}
			switch manifest.supportAction {
				case .reimport:
					let stagedSupport = pending.appendingPathComponent("Application Support", isDirectory: true)
					try importBackupIntoLiveStore(stagedSupport: stagedSupport, appSupport: appSupport)
				case .clearForCloudRepopulation:
					try resetLocalStoreForCloudKitRepopulation(appSupportDir: appSupport)
				case .none:
					break
			}
			if manifest.restoreDocuments {
				try replaceContents(of: docs, with: pending.appendingPathComponent("Documents", isDirectory: true))
			}
			print("[LandShip] Applied pending restore (documents: \(manifest.restoreDocuments), support: \(manifest.supportAction.rawValue))")
			return true
		} catch {
			// replaceContents rolls itself back on failure, so the previous data is intact.
			print("[LandShip] Failed to apply pending restore: \(error.localizedDescription)")
			return false
		}
	}

	/// Applies an exact-snapshot restore by rewriting the contents of the LIVE store through
	/// ordinary Core Data operations: delete every existing record, then insert a copy of
	/// every record from the backup's database.
	///
	/// Why not swap store files or purge the CloudKit zone? Both fight the sync engine and
	/// lose. A swapped-in store file carries stale CloudKit metadata, and the reconcile
	/// silently deletes the restored records again. Purging the zone is worse: other devices
	/// on the account discover their zone is gone and re-upload their entire local database
	/// as new records, duplicating every record fleet-wide. Deleting and re-inserting through
	/// the store's persistent history is the one path the sync engine understands: when
	/// CloudKit mirroring next runs it sends per-record deletions and insertions to the
	/// server, and every other device applies those same changes and converges — no
	/// duplicates, no re-upload storm. It also works across CloudKit environments (a
	/// production backup restored into a development build).
	///
	/// Runs before the ModelContainer is created, so nothing else has the store open. If the
	/// process dies mid-way, the whole operation is retried once on the next launch —
	/// delete-all-then-reinsert is idempotent.
	private static func importBackupIntoLiveStore(stagedSupport: URL, appSupport: URL) throws {
		let fm = FileManager.default
		let sourceStoreURL = try locateStoreFile(in: stagedSupport)

		guard let model = NSManagedObjectModel.makeManagedObjectModel(for: AppSchema.modelTypes) else {
			throw NSError(domain: "Restore", code: 5, userInfo: [
				NSLocalizedDescriptionKey: "Unable to build the data model needed to read the backup."
			])
		}

		try fm.createDirectory(at: appSupport, withIntermediateDirectories: true, attributes: nil)
		let liveStoreURL = appSupport.appendingPathComponent("default.store")

		let source = try loadPlainContainer(model: model, storeURL: sourceStoreURL)
		let live = try loadPlainContainer(model: model, storeURL: liveStoreURL)
		defer {
			closeStores(of: source)
			closeStores(of: live)
		}

		let sourceContext = source.viewContext
		let liveContext = live.viewContext
		liveContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

		// Phase 1: delete every existing record (as faults — no need to load photo blobs).
		// These deletions land in persistent history, so CloudKit mirroring propagates them
		// to the server and to every other device.
		var totalDeleted = 0
		for entity in model.entities {
			guard let entityName = entity.name else { continue }
			let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
			request.includesPropertyValues = false
			let existing = try liveContext.fetch(request)
			for object in existing {
				liveContext.delete(object)
			}
			totalDeleted += existing.count
			if liveContext.hasChanges {
				try liveContext.save()
			}
			liveContext.reset()
		}

		// Phase 2: insert a copy of every record from the backup.
		var totalCopied = 0
		for entity in model.entities {
			guard let entityName = entity.name else { continue }
			let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
			request.returnsObjectsAsFaults = false
			let rows = try sourceContext.fetch(request)
			for row in rows {
				let clone = NSEntityDescription.insertNewObject(forEntityName: entityName, into: liveContext)
				for attributeName in entity.attributesByName.keys {
					clone.setValue(row.value(forKey: attributeName), forKey: attributeName)
				}
			}
			totalCopied += rows.count
			if liveContext.hasChanges {
				try liveContext.save()
			}
			// Release fetched objects (image blobs can be large) before the next entity.
			liveContext.reset()
			sourceContext.reset()
		}

		print("[LandShip] Restore replaced \(totalDeleted) records with \(totalCopied) from the backup")
	}

	/// Finds the SwiftData database file inside a backup's Application Support copy.
	private static func locateStoreFile(in folder: URL) throws -> URL {
		let fm = FileManager.default
		let preferred = folder.appendingPathComponent("default.store")
		if fm.fileExists(atPath: preferred.path) { return preferred }
		let items = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [])) ?? []
		if let store = items.first(where: { $0.lastPathComponent.hasSuffix(".store") }) {
			return store
		}
		throw NSError(domain: "Restore", code: 6, userInfo: [
			NSLocalizedDescriptionKey: "The backup doesn't contain a database file to restore."
		])
	}

	/// Opens a store with a plain Core Data container (no CloudKit mirroring). History
	/// tracking is enabled to match what SwiftData requires of the live store — and recording
	/// the restore's inserts in persistent history is what lets the CloudKit engine discover
	/// and upload them on the next sync-enabled launch. Automatic lightweight migration is on
	/// so a backup made by an older app version can still be read.
	private static func loadPlainContainer(model: NSManagedObjectModel, storeURL: URL) throws -> NSPersistentContainer {
		let description = NSPersistentStoreDescription(url: storeURL)
		description.shouldMigrateStoreAutomatically = true
		description.shouldInferMappingModelAutomatically = true
		description.shouldAddStoreAsynchronously = false
		description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

		let container = NSPersistentContainer(name: "LandShipRestore", managedObjectModel: model)
		container.persistentStoreDescriptions = [description]
		var loadError: Error?
		container.loadPersistentStores { _, error in loadError = error }
		if let loadError { throw loadError }
		return container
	}

	/// Detaches all stores from the container's coordinator (idempotent), so SQLite closes
	/// and checkpoints the files before they're moved or reopened by SwiftData.
	private static func closeStores(of container: NSPersistentContainer) {
		let coordinator = container.persistentStoreCoordinator
		for store in coordinator.persistentStores {
			try? coordinator.remove(store)
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

// MARK: - RestoreReadySheet (pre-restart dialog listing what will be restored)

/// Scrollable presentation of the staged-restore summary, shown after staging succeeds.
/// The only way forward is the restart button — a restore in this state must not be
/// casually dismissed and forgotten.
struct RestoreReadySheet: View {
	var message: String
	var onRestart: () -> Void

	var body: some View {
		NavigationStack {
			ScrollView {
				Text(message)
					.font(.callout)
					.textSelection(.enabled)
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding()
			}
			.navigationTitle("Restart to Finish Restore")
			// Pinned to the bottom rather than placed in the toolbar — toolbar items in this
			// sheet don't reliably render on macOS, and this button must never be missing.
			.safeAreaInset(edge: .bottom) {
				Button {
					onRestart()
				} label: {
#if os(macOS)
					Text("Quit \(AppInfo.displayName) Now")
						.frame(maxWidth: .infinity)
#else
					Text("OK")
						.frame(maxWidth: .infinity)
#endif
				}
				.buttonStyle(.borderedProminent)
				.controlSize(.large)
				.keyboardShortcut(.defaultAction)
				.padding()
				.background(.regularMaterial)
			}
		}
	}
}

// MARK: - BackupRestoreProgressOverlay (in-progress dialog)

/// Blocking overlay shown while a manual backup is being prepared or a restore is running,
/// so the user isn't left staring at a frozen-looking screen wondering what's happening
/// (a restore can take 30 seconds or more). Covers the whole window and swallows taps
/// so nothing else can be triggered mid-operation.
struct BackupRestoreProgressOverlay: View {
	var title: String
	var message: String

	var body: some View {
		ZStack {
			Color.black.opacity(0.35)
				.ignoresSafeArea()
			VStack(spacing: 16) {
				ProgressView()
					.controlSize(.large)
				Text(title)
					.font(.headline)
				Text(message)
					.font(.callout)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}
			.padding(24)
			.frame(maxWidth: 360)
			.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
			.padding(40)
		}
		.transition(.opacity)
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(.updatesFrequently)
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
            Text("Your restore is ready. To finish restoring your data safely, please close \(AppInfo.displayName) completely — swipe it up from the App Switcher — then reopen it.")
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
