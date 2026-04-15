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
}

extension FileManager: FileStoring {}
