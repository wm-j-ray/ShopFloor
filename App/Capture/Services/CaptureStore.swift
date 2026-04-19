import Foundation
import Combine

/// Core write path for the Capture app.
///
/// Architecture:
///   iCloud Drive container (local-first, background sync)
///     Documents/
///       Inbox/              ← first-class inbox notebook
///       [Notebook]/         ← Karen-created notebooks
///     .shopfloor/
///       files/
///         [UUID].json       ← per-file metadata (platform UUID layer)
///
/// Every file write is accompanied by a .shopfloor/files/[UUID].json write.
/// If the app crashes between the two, rebuild() recovers the orphan.
// Module-level constants — accessible from isolated and nonisolated contexts.
let kContainerIdentifier = "iCloud.com.shopfloor.capture"
let kInboxName = "Inbox"

// MARK: - RebuildResult

/// Summary of a rebuild() pass. Published so SettingsView can show feedback.
struct RebuildResult: Sendable {
    let orphansRemoved: Int
    let filesImported: Int
}

// MARK: - ShopfloorFileActor

/// Serializes all .shopfloor/ file I/O off the @MainActor.
///
/// INVARIANT: every method MUST use self.fileStore for all file I/O.
/// No FileManager.default calls anywhere in this actor.
private actor ShopfloorFileActor {
    private let fileStore: any FileStoring

    init(fileStore: any FileStoring) {
        self.fileStore = fileStore
    }

    /// Scans the shopfloor directory for orphaned .json records (no matching .md on disk).
    /// Returns the filenames of orphaned records (which have been deleted from disk).
    ///
    /// Skips iCloud stub files — a file with `.notDownloaded` status is not an orphan;
    /// iCloud will sync it. Also skips files present on disk regardless of download status.
    func scanForOrphans(in shopfloorURL: URL) throws -> [String] {
        let jsonURLs = (try? fileStore.contentsOfDirectory(
            at: shopfloorURL,
            includingPropertiesForKeys: nil,
            options: []
        )) ?? []

        var orphanedFilenames: [String] = []

        for jsonURL in jsonURLs where jsonURL.pathExtension == "json" {
            guard let data = fileStore.contents(atPath: jsonURL.path),
                  let meta = try? JSONDecoder().decode(CaptureMetadata.self, from: data) else {
                continue
            }

            let mdPath = (meta.notebookPath as NSString).appendingPathComponent(meta.filename)
            let mdURL  = URL(fileURLWithPath: mdPath)

            if fileStore.fileExists(atPath: mdPath) {
                continue // Present (downloaded or iCloud stub on disk) — not an orphan.
            }

            // File absent locally. Check iCloud: if it's queued to sync, skip.
            if fileStore.downloadingStatus(for: mdURL) == .notDownloaded {
                continue // iCloud will deliver it — not an orphan.
            }

            // True orphan: file is gone and iCloud has no record of a pending sync.
            try fileStore.removeItem(at: jsonURL)
            orphanedFilenames.append(meta.filename)
        }

        return orphanedFilenames
    }

    /// Reads a .json record, applies the modify closure, writes it back.
    /// All encode/decode/write errors propagate to the caller.
    func readModifyWrite(
        uuid: String,
        shopfloorURL: URL,
        modify: @Sendable (inout CaptureMetadata) -> Void
    ) throws {
        let metaURL = shopfloorURL.appendingPathComponent("\(uuid).json")
        guard let data = fileStore.contents(atPath: metaURL.path) else {
            throw CaptureError.metadataNotFound(uuid)
        }
        var metadata = try JSONDecoder().decode(CaptureMetadata.self, from: data)
        modify(&metadata)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let newData = try encoder.encode(metadata)
        guard fileStore.createFile(atPath: metaURL.path, contents: newData, attributes: nil) else {
            throw CaptureError.writeFailed(metaURL)
        }
    }

    /// Removes the .json record for a given UUID.
    /// Propagates I/O errors to the caller; callers use `try?` for graceful handling.
    func deleteMetadata(uuid: String, shopfloorURL: URL) throws {
        let metaURL = shopfloorURL.appendingPathComponent("\(uuid).json")
        try fileStore.removeItem(at: metaURL)
    }

    /// Removes the .md file. Propagates any I/O error to the caller.
    func deleteFile(at url: URL) throws {
        try fileStore.removeItem(at: url)
    }

    /// Moves (or renames) a file. Propagates any I/O error to the caller.
    func moveFile(from src: URL, to dst: URL) throws {
        try fileStore.moveItem(at: src, to: dst)
    }
}

// MARK: - CaptureStore

@MainActor
final class CaptureStore: ObservableObject {

    private let fileStore: any FileStoring
    private let shopfloorActor: ShopfloorFileActor

    @Published var rootURL: URL?
    @Published var error: Error?
    /// Incremented by rebuildIndex() so views can observe and refresh their lists.
    @Published var lastIndexUpdate: Date = Date()

    // MARK: - filename → UUID index
    // Warmed synchronously on first contents(of:) call, then kept live by NSMetadataQuery.
    // createCapture() adds eagerly; deleteCapture() removes; rebuild() cleans orphans.
    private(set) var filenameToUUID: [String: String] = [:]
    /// Maps filename → Karen's raw display title (from CaptureMetadata.displayTitle).
    /// Falls back to deriving from filename when no entry exists.
    private(set) var titleIndex: [String: String] = [:]
    private(set) var indexIsWarmed = false
    private(set) var lastRebuildResult: RebuildResult?

    // MARK: - NSMetadataQuery (live iCloud index updates)
    private var metadataQuery: NSMetadataQuery?
    private var queryCancellables = Set<AnyCancellable>()

    init(fileStore: any FileStoring = FileManager.default) {
        self.fileStore = fileStore
        self.shopfloorActor = ShopfloorFileActor(fileStore: fileStore)
        self.rootURL = nil // resolved async — see resolveContainer()
    }

    /// Call once on app launch. Resolves the iCloud container URL on a background
    /// thread as Apple requires — calling url(forUbiquityContainerIdentifier:) on
    /// the main thread always returns nil.
    ///
    /// Uses the injected fileStore (not FileManager.default) so tests work without iCloud.
    func resolveContainer() async {
        // Capture fileStore before crossing into the detached task — actor-isolated
        // properties cannot be read from nonisolated contexts in Swift 6.
        let fs = fileStore
        let url: URL? = await Task.detached(priority: .userInitiated) {
            // Try the named container first; fall back to the default (first entitlement).
            let named = fs.url(forUbiquityContainerIdentifier: kContainerIdentifier)
            let defaultContainer = fs.url(forUbiquityContainerIdentifier: nil)
            return (named ?? defaultContainer)?
                .appendingPathComponent("Documents", isDirectory: true)
        }.value
        self.rootURL = url
    }

    // MARK: - Notebooks

    /// Creates a notebook (directory) at the given parent, or at the root if parent is nil.
    func createNotebook(name: String, parent: URL? = nil) throws {
        let base = try requireRoot()
        let container = parent ?? base
        let notebookURL = container.appendingPathComponent(name, isDirectory: true)
        try fileStore.createDirectory(at: notebookURL, withIntermediateDirectories: true, attributes: nil)
    }

    /// Lists the contents of a notebook URL, filtering hidden platform directories.
    /// Returns directories (notebooks) and .md files (captures).
    /// Warms the filenameToUUID index on the first call (warm-once per session).
    func contents(of notebookURL: URL) throws -> [URL] {
        let urls = try fileStore.contentsOfDirectory(
            at: notebookURL,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey, .ubiquitousItemDownloadingStatusKey],
            options: [.skipsHiddenFiles]
        )
        if !indexIsWarmed {
            warmIndex()
        }
        return urls
    }

    // MARK: - Captures

    /// Creates a capture as a Markdown file and writes its .shopfloor metadata.
    /// Also eagerly adds filename → UUID to the in-memory index.
    func createCapture(
        title: String,
        body: String,
        notebook: URL? = nil,
        captureNote: String? = nil,
        sourceURL: String? = nil,
        captureMethod: String = "direct"
    ) throws {
        let base = try requireRoot()
        let destination = notebook ?? base.appendingPathComponent(kInboxName, isDirectory: true)

        try fileStore.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)

        let filename = uniqueFilename(from: title, in: destination)
        let fileURL  = destination.appendingPathComponent(filename)
        let notebookPath = destination.path

        let markdown = "# \(title)\n\n\(body)"
        guard let data = markdown.data(using: .utf8) else {
            throw CaptureError.encodingFailed
        }

        guard fileStore.createFile(atPath: fileURL.path, contents: data, attributes: nil) else {
            throw CaptureError.writeFailed(fileURL)
        }

        let metadata = CaptureMetadata.make(
            filename: filename,
            notebookPath: notebookPath,
            captureMethod: captureMethod,
            sourceURL: sourceURL,
            captureNote: captureNote,
            displayTitle: title
        )
        try writeMetadata(metadata)

        // Eagerly update indexes so title/note/delete work immediately.
        filenameToUUID[filename] = metadata.uuid
        titleIndex[filename] = title
    }

    /// Deletes the capture at the given URL and its .shopfloor metadata record.
    ///
    /// Async because deleting from iCloud Drive should not block @MainActor.
    ///
    /// Delete order: .json first, .md second.
    /// If the app crashes between the two, the .md survives (Karen keeps her content).
    /// A .md with no .json is an invisible orphan — no UX impact, rebuild cleans the index.
    /// The reverse order (.md first) would silently destroy content on crash.
    func deleteCapture(at url: URL) async throws {
        let base = try requireRoot()
        let shopfloorURL = shopfloorFilesURL(relativeTo: base)
        let filename = url.lastPathComponent

        // Read companion filename BEFORE removing from index.
        let uuid = filenameToUUID[filename]
        let companionFilename: String? = uuid.flatMap { u in
            let path = shopfloorURL.appendingPathComponent("\(u).json").path
            guard let data = fileStore.contents(atPath: path),
                  let meta = try? JSONDecoder().decode(CaptureMetadata.self, from: data)
            else { return nil }
            return meta.companionFilename
        }

        filenameToUUID.removeValue(forKey: filename)

        // Delete .json first — crash here leaves .md intact (content preserved).
        if let uuid = uuid {
            try? await shopfloorActor.deleteMetadata(uuid: uuid, shopfloorURL: shopfloorURL)
        }

        // Delete companion binary (image/pdf/etc) before the .md.
        if let companion = companionFilename {
            let companionURL = url.deletingLastPathComponent().appendingPathComponent(companion)
            try? await shopfloorActor.deleteFile(at: companionURL)
        }

        // Delete .md last — crash here leaves a .md with no .json, which is invisible to Karen.
        try await shopfloorActor.deleteFile(at: url)
    }

    /// Full library repair:
    ///   1. Removes orphaned .shopfloor records (no matching .md on disk).
    ///   2. Imports external .md files (added via Files.app or another app) by
    ///      creating .shopfloor sidecar records for any .md without one.
    /// Silent — no throws. Designed for the Rebuild Library button and app launch.
    func rebuild() async {
        guard let base = try? requireRoot() else { return }
        let shopfloorURL = shopfloorFilesURL(relativeTo: base)

        // Step 1: Remove orphaned .json records
        let orphanedFilenames: [String]
        do {
            orphanedFilenames = try await shopfloorActor.scanForOrphans(in: shopfloorURL)
        } catch {
            return // Best-effort; any I/O error is non-fatal
        }
        for filename in orphanedFilenames {
            filenameToUUID.removeValue(forKey: filename)
        }

        // Step 2: Import external .md files that have no .shopfloor sidecar
        let imported = (try? importExternalFiles(from: base)) ?? 0

        lastRebuildResult = RebuildResult(orphansRemoved: orphanedFilenames.count, filesImported: imported)
    }

    /// Scans the Documents root recursively for .md files not yet in filenameToUUID.
    /// Creates a .shopfloor sidecar for each, using captureMethod "import".
    /// Returns the number of files newly imported.
    @discardableResult
    private func importExternalFiles(from root: URL) throws -> Int {
        let mdURLs = collectMdFiles(in: root)
        var count = 0
        for mdURL in mdURLs {
            let filename = mdURL.lastPathComponent
            guard filenameToUUID[filename] == nil else { continue }
            let metadata = CaptureMetadata.make(
                filename: filename,
                notebookPath: mdURL.deletingLastPathComponent().path,
                captureMethod: "import"
            )
            try writeMetadata(metadata)
            filenameToUUID[filename] = metadata.uuid
            count += 1
        }
        return count
    }

    /// Returns the stored contentType for the given filename, or nil if not found.
    /// Reads from the .shopfloor JSON record — not derived from the filename extension.
    func contentType(forFilename filename: String) -> String? {
        guard let base = try? requireRoot() else { return nil }
        let shopfloorURL = shopfloorFilesURL(relativeTo: base)
        guard let uuid = filenameToUUID[filename] else { return nil }
        let path = shopfloorURL.appendingPathComponent("\(uuid).json").path
        guard let data = fileStore.contents(atPath: path),
              let meta = try? JSONDecoder().decode(CaptureMetadata.self, from: data) else {
            return nil
        }
        return meta.contentType
    }

    /// Returns the full metadata record for the given filename, or nil if not found.
    /// Prefer this over contentType/captureNote when multiple fields are needed.
    func metadata(forFilename filename: String) -> CaptureMetadata? {
        guard let base = try? requireRoot() else { return nil }
        let shopfloorURL = shopfloorFilesURL(relativeTo: base)
        guard let uuid = filenameToUUID[filename] else { return nil }
        let path = shopfloorURL.appendingPathComponent("\(uuid).json").path
        guard let data = fileStore.contents(atPath: path),
              let meta = try? JSONDecoder().decode(CaptureMetadata.self, from: data) else {
            return nil
        }
        return meta
    }

    /// Returns the captureNote for the given filename, or nil if not found.
    /// Uses the injected fileStore — testable and DI-consistent.
    func captureNote(forFilename filename: String) -> String? {
        guard let base = try? requireRoot() else { return nil }
        let shopfloorURL = shopfloorFilesURL(relativeTo: base)
        guard let uuid = filenameToUUID[filename] else { return nil }
        let path = shopfloorURL.appendingPathComponent("\(uuid).json").path
        guard let data = fileStore.contents(atPath: path),
              let meta = try? JSONDecoder().decode(CaptureMetadata.self, from: data) else {
            return nil
        }
        return meta.captureNote
    }

    /// Updates the captureNote for the file identified by filename.
    /// Empty string is treated as nil (removes the captureNote key from JSON).
    /// UUID resolution goes through the filenameToUUID index — call createCapture
    /// (or warm the index via contents(of:)) before calling this.
    func updateNote(_ note: String?, forFilename filename: String) async throws {
        let base = try requireRoot()
        let shopfloorURL = shopfloorFilesURL(relativeTo: base)

        guard let uuid = filenameToUUID[filename] else {
            throw CaptureError.uuidNotFound(filename)
        }

        let finalNote: String? = note.flatMap { $0.isEmpty ? nil : $0 }

        try await shopfloorActor.readModifyWrite(uuid: uuid, shopfloorURL: shopfloorURL) { meta in
            meta.captureNote = finalNote
        }
    }

    // MARK: - OG enrichment

    /// Fetches OpenGraph metadata for a link capture and persists it to the sidecar JSON.
    /// No-ops if enrichment was already attempted (ogFetchedAt is set).
    /// Updates: displayTitle (if still a bare domain), captureNote (if empty), companionFilename (og image).
    func enrichLinkCapture(filename: String) async {
        guard let base = try? requireRoot() else { return }
        let shopfloorURL = shopfloorFilesURL(relativeTo: base)
        guard let uuid = filenameToUUID[filename] else { return }
        let metaPath = shopfloorURL.appendingPathComponent("\(uuid).json").path
        guard let data = fileStore.contents(atPath: metaPath),
              let meta = try? JSONDecoder().decode(CaptureMetadata.self, from: data),
              meta.contentType == "link",
              meta.ogFetchedAt == nil,
              let rawURL = meta.sourceURL,
              let sourceURL = URL(string: rawURL)
        else { return }

        let og = await fetchOGMetadata(from: sourceURL)
        let fetchedAt = ISO8601DateFormatter().string(from: Date())

        // Download OG image and save alongside the .md
        var newCompanionFilename: String? = meta.companionFilename
        if let imageURL = og.imageURL, meta.companionFilename == nil {
            let ext = imageURL.pathExtension.split(separator: "?").first.map(String.init) ?? "jpg"
            let safeExt = ext.isEmpty ? "jpg" : ext.lowercased()
            let stem = String(filename.dropLast(3))
            let imgFilename = "\(stem)-og.\(safeExt)"
            let notebookURL = URL(fileURLWithPath: meta.notebookPath, isDirectory: true)
            let imgDestURL = notebookURL.appendingPathComponent(imgFilename)
            if let (imgData, _) = try? await URLSession.shared.data(from: imageURL),
               (try? imgData.write(to: imgDestURL, options: .atomic)) != nil {
                newCompanionFilename = imgFilename
            }
        }

        let finalCompanionFilename = newCompanionFilename
        let ogTitle = og.title
        let ogDesc  = og.description
        try? await shopfloorActor.readModifyWrite(uuid: uuid, shopfloorURL: shopfloorURL) { m in
            m.ogFetchedAt = fetchedAt
            if let title = ogTitle, !title.isEmpty, m.displayTitle == nil {
                m.displayTitle = title
            }
            if let desc = ogDesc, !desc.isEmpty, m.captureNote == nil {
                m.captureNote = desc
            }
            if let companion = finalCompanionFilename {
                m.companionFilename = companion
            }
        }

        titleIndex[filename] = metadata(forFilename: filename)?.displayTitle
        lastIndexUpdate = Date()
    }

    // MARK: - Display title

    /// Returns Karen's display title for a capture. Checks the in-memory title index first;
    /// falls back to deriving from the filename slug.
    func displayTitle(for url: URL) -> String {
        let filename = url.lastPathComponent
        if let stored = titleIndex[filename], !stored.isEmpty { return stored }
        return derivedTitle(for: url)
    }

    // MARK: - Rename

    /// Updates the display title for a capture. The slug filename stays unchanged.
    func renameCapture(at url: URL, newTitle: String) async throws {
        let base = try requireRoot()
        let shopfloorURL = shopfloorFilesURL(relativeTo: base)
        let filename = url.lastPathComponent
        guard let uuid = filenameToUUID[filename] else {
            throw CaptureError.uuidNotFound(filename)
        }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        try await shopfloorActor.readModifyWrite(uuid: uuid, shopfloorURL: shopfloorURL) { meta in
            meta.displayTitle = trimmed.isEmpty ? nil : trimmed
        }
        if trimmed.isEmpty {
            titleIndex.removeValue(forKey: filename)
        } else {
            titleIndex[filename] = trimmed
        }
        lastIndexUpdate = Date()
    }

    /// Renames a notebook directory on disk.
    func renameNotebook(at url: URL, newName: String) async throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newURL = url.deletingLastPathComponent().appendingPathComponent(trimmed, isDirectory: true)
        try await shopfloorActor.moveFile(from: url, to: newURL)
        lastIndexUpdate = Date()
    }

    // MARK: - Move

    /// Moves a capture .md file to a different notebook directory.
    /// Updates the metadata's notebookPath. The slug filename is preserved unless there is a collision.
    func moveCapture(from url: URL, to targetNotebook: URL) async throws {
        let base = try requireRoot()
        let shopfloorURL = shopfloorFilesURL(relativeTo: base)
        let oldFilename = url.lastPathComponent
        let uuid = filenameToUUID[oldFilename]

        // Read current companion filename before moving anything.
        let oldCompanionFilename: String? = uuid.flatMap { u in
            let path = shopfloorURL.appendingPathComponent("\(u).json").path
            guard let data = fileStore.contents(atPath: path),
                  let meta = try? JSONDecoder().decode(CaptureMetadata.self, from: data)
            else { return nil }
            return meta.companionFilename
        }

        // Resolve destination filename for .md (handle collision).
        let destFilename: String
        let destURL: URL
        let candidate = targetNotebook.appendingPathComponent(oldFilename)
        if fileStore.fileExists(atPath: candidate.path) {
            let stem = String(oldFilename.dropLast(3)) // strip ".md"
            destFilename = uniqueFilename(from: stem, in: targetNotebook)
            destURL = targetNotebook.appendingPathComponent(destFilename)
        } else {
            destFilename = oldFilename
            destURL = candidate
        }

        // Move .md first.
        try await shopfloorActor.moveFile(from: url, to: destURL)

        // Move companion binary and compute its new filename.
        // If .md was renamed due to collision, mirror the new stem into the companion name.
        var newCompanionFilename = oldCompanionFilename
        if let oldCompanion = oldCompanionFilename {
            let companionSrc = url.deletingLastPathComponent().appendingPathComponent(oldCompanion)
            let companionExt = URL(fileURLWithPath: oldCompanion).pathExtension
            let newStem = String(destFilename.dropLast(3)) // strip ".md"
            let newCompanion = companionExt.isEmpty ? newStem : "\(newStem).\(companionExt)"
            let companionDst = targetNotebook.appendingPathComponent(newCompanion)
            if fileStore.fileExists(atPath: companionSrc.path) {
                try? await shopfloorActor.moveFile(from: companionSrc, to: companionDst)
                newCompanionFilename = newCompanion
            }
        }

        // Update metadata.
        if let uuid = uuid {
            let newPath = targetNotebook.path
            let companion = newCompanionFilename
            try await shopfloorActor.readModifyWrite(uuid: uuid, shopfloorURL: shopfloorURL) { meta in
                meta.notebookPath = newPath
                meta.filename = destFilename
                meta.companionFilename = companion
            }
            filenameToUUID.removeValue(forKey: oldFilename)
            filenameToUUID[destFilename] = uuid
            if let title = titleIndex[oldFilename] {
                titleIndex.removeValue(forKey: oldFilename)
                titleIndex[destFilename] = title
            }
        }
        lastIndexUpdate = Date()
    }

    /// Deletes a notebook directory and all its captures, cleaning up .shopfloor metadata.
    ///
    /// Delete order: metadata first, directory last.
    /// FileManager.removeItem on a directory removes all contents recursively.
    func deleteNotebook(at url: URL) async throws {
        let base = try requireRoot()
        let shopfloorURL = shopfloorFilesURL(relativeTo: base)

        // Collect captures before the directory is gone.
        let mdURLs = collectMdFiles(in: url)
        for mdURL in mdURLs {
            let filename = mdURL.lastPathComponent
            if let uuid = filenameToUUID[filename] {
                try? await shopfloorActor.deleteMetadata(uuid: uuid, shopfloorURL: shopfloorURL)
                filenameToUUID.removeValue(forKey: filename)
            }
        }

        try await shopfloorActor.deleteFile(at: url)
    }

    private func collectMdFiles(in directory: URL) -> [URL] {
        var result: [URL] = []
        let entries = (try? fileStore.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for url in entries {
            if fileStore.isDirectory(at: url) {
                result += collectMdFiles(in: url)
            } else if url.pathExtension == "md" {
                result.append(url)
            }
        }
        return result
    }

    // MARK: - Inbox

    /// Ensures the Inbox notebook exists at the root.
    /// Uses the injected fileStore (not FileManager.default — see ensureInbox DI fix).
    func ensureInbox() async throws {
        let base = try requireRoot()
        let inboxURL = base.appendingPathComponent(kInboxName, isDirectory: true)
        guard !fileStore.fileExists(atPath: inboxURL.path) else { return }
        try fileStore.createDirectory(at: inboxURL, withIntermediateDirectories: true, attributes: nil)
    }

    // MARK: - Private

    private func requireRoot() throws -> URL {
        guard let root = rootURL else { throw CaptureError.noContainer }
        return root
    }

    /// Returns the .shopfloor/files/ URL for the given iCloud Documents root.
    private func shopfloorFilesURL(relativeTo base: URL) -> URL {
        base
            .deletingLastPathComponent() // up from Documents/
            .appendingPathComponent(".shopfloor/files", isDirectory: true)
    }

    private func writeMetadata(_ metadata: CaptureMetadata) throws {
        let base = try requireRoot()
        let shopfloorURL = shopfloorFilesURL(relativeTo: base)

        try fileStore.createDirectory(at: shopfloorURL, withIntermediateDirectories: true, attributes: nil)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(metadata)
        let metaURL = shopfloorURL.appendingPathComponent("\(metadata.uuid).json")

        guard fileStore.createFile(atPath: metaURL.path, contents: jsonData, attributes: nil) else {
            throw CaptureError.writeFailed(metaURL)
        }
    }

    /// Sync fallback: warms the index on the first contents(of:) call if NSMetadataQuery
    /// hasn't fired yet (e.g., app just launched, query still initialising).
    private func warmIndex() {
        guard !indexIsWarmed else { return }
        rebuildIndex()
    }

    // MARK: - NSMetadataQuery

    /// Starts live iCloud index tracking. Call once from the app layer after resolveContainer().
    /// Not called in tests — NSMetadataQuery requires real iCloud and would interfere with mocks.
    func startMetadataQuery() {
        guard metadataQuery == nil, rootURL != nil else { return }

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*.md'", NSMetadataItemFSNameKey)
        query.operationQueue = .main

        NotificationCenter.default
            .publisher(for: .NSMetadataQueryDidFinishGathering, object: query)
            .sink { [weak self, weak query] _ in
                query?.disableUpdates()
                self?.rebuildIndex()
                query?.enableUpdates()
            }
            .store(in: &queryCancellables)

        NotificationCenter.default
            .publisher(for: .NSMetadataQueryDidUpdate, object: query)
            .sink { [weak self, weak query] _ in
                query?.disableUpdates()
                self?.rebuildIndex()
                query?.enableUpdates()
            }
            .store(in: &queryCancellables)

        query.start()
        metadataQuery = query
    }

    /// Full scan of .shopfloor/files/*.json — rebuilds filenameToUUID from disk.
    /// Called by startMetadataQuery() notifications and by warmIndex() on first contents(of:).
    private func rebuildIndex() {
        guard let base = try? requireRoot() else { return }
        let shopfloorURL = shopfloorFilesURL(relativeTo: base)

        let jsonURLs = (try? fileStore.contentsOfDirectory(
            at: shopfloorURL,
            includingPropertiesForKeys: nil,
            options: []
        )) ?? []

        var newIndex: [String: String] = [:]
        var newTitleIndex: [String: String] = [:]
        for jsonURL in jsonURLs where jsonURL.pathExtension == "json" {
            guard let data = fileStore.contents(atPath: jsonURL.path),
                  let meta = try? JSONDecoder().decode(CaptureMetadata.self, from: data) else {
                continue
            }
            newIndex[meta.filename] = meta.uuid
            if let title = meta.displayTitle {
                newTitleIndex[meta.filename] = title
            }
        }
        filenameToUUID = newIndex
        titleIndex = newTitleIndex
        indexIsWarmed = true
        lastIndexUpdate = Date()
    }

    private func uniqueFilename(from title: String, in directory: URL) -> String {
        let base = makeFilename(from: title)
        guard fileStore.fileExists(atPath: directory.appendingPathComponent(base).path) else {
            return base
        }
        let stem = String(base.dropLast(3)) // strip ".md"
        var counter = 2
        while true {
            let candidate = "\(stem)-\(counter).md"
            if !fileStore.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
                return candidate
            }
            counter += 1
        }
    }

    private func makeFilename(from title: String) -> String {
        let slug = title
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return "\(slug.isEmpty ? "capture" : slug).md"
    }
}

// MARK: - Errors

enum CaptureError: LocalizedError {
    case noContainer
    case writeFailed(URL)
    case encodingFailed
    case uuidNotFound(String)
    case metadataNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noContainer:
            return "iCloud Drive is not available. Sign in to iCloud in Settings to use Capture."
        case .writeFailed(let url):
            return "Could not write to \(url.lastPathComponent). Check available storage."
        case .encodingFailed:
            return "Could not encode capture content."
        case .uuidNotFound(let filename):
            return "Could not find metadata record for \(filename)."
        case .metadataNotFound(let uuid):
            return "Could not find metadata for UUID \(uuid)."
        }
    }
}
