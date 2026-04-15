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
/// If the app crashes between the two, the file is an orphan — recoverable
/// by the Foreman's rebuild skill (see Design Documents/ShopFloor Platform Spec.md).
// Module-level constants — accessible from isolated and nonisolated contexts.
let kContainerIdentifier = "iCloud.com.shopfloor.capture"
let kInboxName = "Inbox"

@MainActor
final class CaptureStore: ObservableObject {

    private let fileStore: any FileStoring

    @Published var rootURL: URL?
    @Published var error: Error?

    init(fileStore: any FileStoring = FileManager.default) {
        self.fileStore = fileStore
        self.rootURL = nil // resolved async — see resolveContainer()
    }

    /// Call once on app launch. Resolves the iCloud container URL on a background
    /// thread as Apple requires — calling url(forUbiquityContainerIdentifier:) on
    /// the main thread always returns nil.
    func resolveContainer() async {
        let url: URL? = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default

            // Diagnostic: is iCloud available at all?
            let token = fm.ubiquityIdentityToken
            print("[Capture] ubiquityIdentityToken: \(token != nil ? "present" : "nil — iCloud not signed in or not entitled")")

            // Try the named container first.
            let named = fm.url(forUbiquityContainerIdentifier: kContainerIdentifier)
            print("[Capture] url(forUbiquityContainerIdentifier: \(kContainerIdentifier)): \(named?.path ?? "nil")")

            // Fall back to the default container (nil = first container in entitlements).
            let defaultContainer = fm.url(forUbiquityContainerIdentifier: nil)
            print("[Capture] url(forUbiquityContainerIdentifier: nil): \(defaultContainer?.path ?? "nil")")

            let resolved = (named ?? defaultContainer)?
                .appendingPathComponent("Documents", isDirectory: true)
            print("[Capture] resolved rootURL: \(resolved?.path ?? "nil")")
            return resolved
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
    func contents(of notebookURL: URL) throws -> [URL] {
        try fileStore.contentsOfDirectory(
            at: notebookURL,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey, .ubiquitousItemDownloadingStatusKey],
            options: [.skipsHiddenFiles]
        )
    }

    // MARK: - Captures

    /// Creates a capture as a Markdown file and writes its .shopfloor metadata.
    /// - Parameters:
    ///   - title: Display title. Used as the filename slug.
    ///   - body: Markdown body content.
    ///   - notebook: Destination notebook URL. Defaults to Inbox.
    func createCapture(title: String, body: String, notebook: URL? = nil) throws {
        let base = try requireRoot()
        let destination = notebook ?? base.appendingPathComponent(kInboxName, isDirectory: true)

        // Ensure destination exists (Inbox may not yet exist on first launch).
        try fileStore.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)

        let filename = makeFilename(from: title)
        let fileURL = destination.appendingPathComponent(filename)
        let notebookPath = destination.path

        let markdown = "# \(title)\n\n\(body)"
        guard let data = markdown.data(using: .utf8) else {
            throw CaptureError.encodingFailed
        }

        // Write the .md file.
        guard fileStore.createFile(atPath: fileURL.path, contents: data, attributes: nil) else {
            throw CaptureError.writeFailed(fileURL)
        }

        // Write the .shopfloor metadata immediately after.
        // If the app crashes here, rebuild recovers the orphan.
        let metadata = CaptureMetadata.make(filename: filename, notebookPath: notebookPath)
        try writeMetadata(metadata)
    }

    // MARK: - Inbox

    /// Ensures the Inbox notebook exists at the root. Called on first launch.
    /// File I/O dispatched to a background thread — createDirectory on an iCloud
    /// path blocks the caller while iCloud sets up the container on first access.
    func ensureInbox() async throws {
        let base = try requireRoot()
        let inboxURL = base.appendingPathComponent(kInboxName, isDirectory: true)
        try await Task.detached(priority: .utility) {
            guard !FileManager.default.fileExists(atPath: inboxURL.path) else { return }
            try FileManager.default.createDirectory(
                at: inboxURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }.value
    }

    // MARK: - Private

    private func requireRoot() throws -> URL {
        guard let root = rootURL else { throw CaptureError.noContainer }
        return root
    }

    private func writeMetadata(_ metadata: CaptureMetadata) throws {
        let base = try requireRoot()
        let shopfloorURL = base
            .deletingLastPathComponent() // up from Documents/
            .appendingPathComponent(".shopfloor/files", isDirectory: true)

        try fileStore.createDirectory(at: shopfloorURL, withIntermediateDirectories: true, attributes: nil)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(metadata)
        let metaURL = shopfloorURL.appendingPathComponent("\(metadata.uuid).json")

        guard fileStore.createFile(atPath: metaURL.path, contents: jsonData, attributes: nil) else {
            throw CaptureError.writeFailed(metaURL)
        }
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

    var errorDescription: String? {
        switch self {
        case .noContainer:
            return "iCloud Drive is not available. Sign in to iCloud in Settings to use Capture."
        case .writeFailed(let url):
            return "Could not write to \(url.lastPathComponent). Check available storage."
        case .encodingFailed:
            return "Could not encode capture content."
        }
    }
}
