import UIKit
import UniformTypeIdentifiers

// NSObject/UIViewController subclass — Share extensions use ObjC messaging for
// NSExtensionRequestHandling, which UIViewController already implements.
final class ShareViewController: UIViewController {

    private let label: UILabel = {
        let l = UILabel()
        l.text = "Saving to Capture..."
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        Task { await processShare() }
    }

    // MARK: - Share processing

    private func processShare() async {
        defer {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }

        guard
            let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let provider = item.attachments?.first(where: {
                $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
            })
        else { return }

        do {
            let rawItem = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
            guard let url = rawItem as? URL else { return }
            // Resolve iCloud container off main thread (Apple requirement).
            try await Task.detached(priority: .userInitiated) {
                try ShareViewController.writeCapture(sourceURL: url)
            }.value
        } catch {
            // Silent — best-effort capture; NSMetadataQuery will sync when available.
        }
    }

    // MARK: - File writing
    // nonisolated: UIViewController is @MainActor, but these static methods do only
    // file I/O — no UI access. nonisolated lets Task.detached call them without a hop.

    private nonisolated static func writeCapture(sourceURL: URL) throws {
        let fm = FileManager.default
        guard let container = fm.url(forUbiquityContainerIdentifier: "iCloud.com.shopfloor.capture") else {
            throw URLError(.unsupportedURL)
        }

        let docsURL      = container.appendingPathComponent("Documents", isDirectory: true)
        let inboxURL     = docsURL.appendingPathComponent("Inbox", isDirectory: true)
        let shopfloorURL = container.appendingPathComponent(".shopfloor/files", isDirectory: true)

        try fm.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: shopfloorURL, withIntermediateDirectories: true)

        let title    = sourceURL.host ?? sourceURL.absoluteString
        let filename = uniqueFilename(from: title, in: inboxURL)
        let fileURL  = inboxURL.appendingPathComponent(filename)

        try "# \(title)\n\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let metadata = CaptureMetadata.make(
            filename: filename,
            notebookPath: inboxURL.path,
            captureMethod: "share_sheet",
            sourceURL: sourceURL.absoluteString
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(metadata)
        try jsonData.write(
            to: shopfloorURL.appendingPathComponent("\(metadata.uuid).json"),
            options: .atomic
        )
    }

    // MARK: - Filename helpers
    // Mirrors CaptureStore — extension runs in a separate process and cannot share the class.

    private nonisolated static func uniqueFilename(from title: String, in directory: URL) -> String {
        let base = makeFilename(from: title)
        guard FileManager.default.fileExists(atPath: directory.appendingPathComponent(base).path) else {
            return base
        }
        let stem = String(base.dropLast(3))
        var counter = 2
        while true {
            let candidate = "\(stem)-\(counter).md"
            if !FileManager.default.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
                return candidate
            }
            counter += 1
        }
    }

    private nonisolated static func makeFilename(from title: String) -> String {
        let slug = title
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return "\(slug.isEmpty ? "capture" : slug).md"
    }
}
