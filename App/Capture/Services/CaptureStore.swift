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
}

// MARK: - CaptureStore

@MainActor
final class CaptureStore: ObservableObject {

    private let fileStore: any FileStoring
    private let shopfloorActor: ShopfloorFileActor

    @Published var rootURL: URL?
    @Published var error: Error?

    // MARK: - filename → UUID index
    // Warm-once per session. createCapture() adds eagerly; deleteCapture() removes;
    // rebuild() cleans orphans. Never re-scanned on pull-to-refresh.
    // TODO Sprint 3: Replace warm-once with NSMetadataQuery incremental updates.
    private(set) var filenameToUUID: [String: String] = [:]
    private(set) var indexIsWarmed = false
    private(set) var lastRebuildResult: RebuildResult?

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

        let filename = makeFilename(from: title)
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
            captureNote: captureNote
        )
        try writeMetadata(metadata)

        // Eagerly update index so updateNote / deleteCapture work immediately.
        filenameToUUID[filename] = metadata.uuid
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

        // Capture UUID BEFORE removing from index.
        // If we removed first, the lookup on the next line would return nil.
        let uuid = filenameToUUID[filename]
        filenameToUUID.removeValue(forKey: filename)

        // Delete .json first — crash here leaves .md intact (content preserved).
        if let uuid = uuid {
            // try? — missing .json is graceful; rebuild() already handles this case.
            try? await shopfloorActor.deleteMetadata(uuid: uuid, shopfloorURL: shopfloorURL)
        }

        // Delete .md last — crash here leaves a .md with no .json, which is invisible to Karen.
        try await shopfloorActor.deleteFile(at: url)
    }

    /// Scans .shopfloor/files/ for orphaned .json records (no matching .md on disk).
    /// Removes orphaned records and updates the filenameToUUID index.
    /// Silent — no throws. Designed to run at app launch (Task priority: utility).
    func rebuild() async {
        guard let base = try? requireRoot() else { return }
        let shopfloorURL = shopfloorFilesURL(relativeTo: base)

        let orphanedFilenames: [String]
        do {
            orphanedFilenames = try await shopfloorActor.scanForOrphans(in: shopfloorURL)
        } catch {
            return // Best-effort; any I/O error is non-fatal
        }

        for filename in orphanedFilenames {
            filenameToUUID.removeValue(forKey: filename)
        }
        lastRebuildResult = RebuildResult(orphansRemoved: orphanedFilenames.count)
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

    /// Warms the filenameToUUID index from existing .shopfloor/files/*.json records.
    /// Called once per session from contents(of:). Subsequent calls are no-ops.
    ///
    /// Synchronous scan is acceptable for warm-once. NSMetadataQuery (Sprint 3)
    /// will replace this with incremental real-time updates.
    private func warmIndex() {
        guard !indexIsWarmed else { return }
        guard let base = try? requireRoot() else { return }
        let shopfloorURL = shopfloorFilesURL(relativeTo: base)

        let jsonURLs = (try? fileStore.contentsOfDirectory(
            at: shopfloorURL,
            includingPropertiesForKeys: nil,
            options: []
        )) ?? []

        for jsonURL in jsonURLs where jsonURL.pathExtension == "json" {
            guard let data = fileStore.contents(atPath: jsonURL.path),
                  let meta = try? JSONDecoder().decode(CaptureMetadata.self, from: data) else {
                continue
            }
            filenameToUUID[meta.filename] = meta.uuid
        }

        indexIsWarmed = true
    }

    private func makeFilename(from title: String) -> String {
        let slug = title
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(slug.isEmpty ? "capture" : slug)-\(timestamp).md"
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
