import Foundation

/// Dependency-injectable abstraction over FileManager.
/// Keeping this protocol makes CaptureStore fully testable without iCloud.
protocol FileStoring: Sendable {
    func url(forUbiquityContainerIdentifier containerIdentifier: String?) -> URL?
    func createDirectory(at url: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey: Any]?) throws
    func createFile(atPath path: String, contents data: Data?, attributes: [FileAttributeKey: Any]?) -> Bool
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions) throws -> [URL]
    func moveItem(at srcURL: URL, to dstURL: URL) throws
    func fileExists(atPath path: String) -> Bool
    func removeItem(at url: URL) throws

    /// Reads the raw bytes of a file. Returns nil if the file does not exist.
    func contents(atPath path: String) -> Data?

    /// Returns the iCloud downloading status for a URL, or nil if not an iCloud file.
    /// Used by rebuild() to distinguish absent files from not-yet-synced stubs.
    func downloadingStatus(for url: URL) -> URLUbiquitousItemDownloadingStatus?
}

// MARK: - FileManager conformance

extension FileManager: FileStoring {
    func downloadingStatus(for url: URL) -> URLUbiquitousItemDownloadingStatus? {
        let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        return values?.ubiquitousItemDownloadingStatus
    }
    // FileManager already satisfies contents(atPath:) — it is part of the class API.
}
