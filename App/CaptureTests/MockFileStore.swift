import Foundation
@testable import Capture

/// In-memory FileStore for unit testing CaptureStore without iCloud.
final class MockFileStore: FileStoring, @unchecked Sendable {
    /// Files written: path → data
    var files: [String: Data] = [:]

    /// Directories created
    var directories: [String] = []

    /// Stubbed iCloud download statuses, keyed by absolute path.
    /// Used by tests that simulate iCloud stub files (not-yet-synced placeholders).
    var stubbedDownloadStatus: [String: URLUbiquitousItemDownloadingStatus] = [:]

    /// Controls what url(forUbiquityContainerIdentifier:) returns.
    /// Default: a temp directory so paths resolve without iCloud.
    var containerRoot: URL? = {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MockCapture-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp.appendingPathComponent("Documents", isDirectory: true)
    }()

    func url(forUbiquityContainerIdentifier containerIdentifier: String?) -> URL? {
        // Return one level up so CaptureStore can append "Documents"
        containerRoot?.deletingLastPathComponent()
    }

    func createDirectory(at url: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey: Any]?) throws {
        directories.append(url.path)
    }

    func createFile(atPath path: String, contents data: Data?, attributes: [FileAttributeKey: Any]?) -> Bool {
        files[path] = data ?? Data()
        return true
    }

    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        // Return files whose parent path matches the requested directory.
        let prefix = url.path + "/"
        return files.keys
            .filter { $0.hasPrefix(prefix) && !$0.dropFirst(prefix.count).contains("/") }
            .map { URL(fileURLWithPath: $0) }
    }

    func moveItem(at srcURL: URL, to dstURL: URL) throws {
        if let data = files[srcURL.path] {
            files[dstURL.path] = data
            files.removeValue(forKey: srcURL.path)
        }
    }

    func fileExists(atPath path: String) -> Bool {
        files[path] != nil || directories.contains(path)
    }

    func removeItem(at url: URL) throws {
        files.removeValue(forKey: url.path)
        directories.removeAll { $0 == url.path }
    }

    func contents(atPath path: String) -> Data? {
        files[path]
    }

    func downloadingStatus(for url: URL) -> URLUbiquitousItemDownloadingStatus? {
        stubbedDownloadStatus[url.path]
    }
}
