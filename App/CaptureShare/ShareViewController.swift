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
            let attachments = item.attachments, !attachments.isEmpty
        else { return }

        do {
            // Priority: URL > text > image > PDF > movie > generic file.
            // URL is checked first so web-page shares capture the link, not embedded images.
            if let provider = attachments.first(where: {
                $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
            }) {
                let raw = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
                guard let url = raw as? URL else { return }
                try await Task.detached(priority: .userInitiated) {
                    try ShareViewController.writeLinkCapture(sourceURL: url)
                }.value

            } else if let provider = attachments.first(where: {
                $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
            }) {
                let raw = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
                guard let text = raw as? String else { return }
                try await Task.detached(priority: .userInitiated) {
                    try ShareViewController.writeTextCapture(text: text)
                }.value

            } else if let provider = attachments.first(where: {
                $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
            }) {
                let raw = try await provider.loadItem(forTypeIdentifier: UTType.image.identifier)
                if let fileURL = raw as? URL {
                    try await Task.detached(priority: .userInitiated) {
                        try ShareViewController.writeImageCapture(fileURL: fileURL)
                    }.value
                } else if let image = raw as? UIImage,
                          let data = image.jpegData(compressionQuality: 0.9) {
                    // UIImage is not Sendable — convert to Data on @MainActor before
                    // crossing to the detached task.
                    try await Task.detached(priority: .userInitiated) {
                        try ShareViewController.writeImageCapture(data: data, fileExtension: "jpg")
                    }.value
                }

            } else if let provider = attachments.first(where: {
                $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier)
            }) {
                let raw = try await provider.loadItem(forTypeIdentifier: UTType.pdf.identifier)
                guard let fileURL = raw as? URL else { return }
                try await Task.detached(priority: .userInitiated) {
                    try ShareViewController.writeFileCapture(fileURL: fileURL, contentType: "pdf")
                }.value

            } else if let provider = attachments.first(where: {
                $0.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
            }) {
                // Videos not copied — file sizes are impractical for iCloud sync.
                // Capture a reference note instead.
                let raw = try await provider.loadItem(forTypeIdentifier: UTType.movie.identifier)
                let title = (raw as? URL).map { $0.deletingPathExtension().lastPathComponent } ?? "video"
                try await Task.detached(priority: .userInitiated) {
                    try ShareViewController.writeReferenceNote(title: title, label: "Video")
                }.value

            } else if let provider = attachments.first {
                // Generic file fallback.
                let raw = try await provider.loadItem(forTypeIdentifier: UTType.data.identifier)
                guard let fileURL = raw as? URL else { return }
                try await Task.detached(priority: .userInitiated) {
                    try ShareViewController.writeFileCapture(fileURL: fileURL, contentType: "other")
                }.value
            }
        } catch {
            // Silent — best-effort capture.
        }
    }

    // MARK: - Container resolution
    // nonisolated: UIViewController is @MainActor, but these static methods do only
    // file I/O — no UI access. nonisolated lets Task.detached call them safely.

    private nonisolated static func resolveContainer() throws -> (inbox: URL, shopfloor: URL) {
        let fm = FileManager.default
        guard let container = fm.url(forUbiquityContainerIdentifier: "iCloud.com.shopfloor.capture") else {
            throw URLError(.unsupportedURL)
        }
        let inbox     = container.appendingPathComponent("Documents/Inbox", isDirectory: true)
        let shopfloor = container.appendingPathComponent(".shopfloor/files", isDirectory: true)
        try fm.createDirectory(at: inbox,     withIntermediateDirectories: true)
        try fm.createDirectory(at: shopfloor, withIntermediateDirectories: true)
        return (inbox, shopfloor)
    }

    // MARK: - Write helpers

    private nonisolated static func writeLinkCapture(sourceURL: URL) throws {
        let (inbox, shopfloor) = try resolveContainer()
        let title    = sourceURL.host ?? sourceURL.absoluteString
        let filename = uniqueFilename(from: title, in: inbox)
        try "# \(title)\n\n".write(to: inbox.appendingPathComponent(filename),
                                   atomically: true, encoding: .utf8)
        try flushMetadata(
            CaptureMetadata.make(
                filename: filename,
                notebookPath: inbox.path,
                captureMethod: "share_sheet",
                sourceURL: sourceURL.absoluteString
            ),
            to: shopfloor
        )
    }

    private nonisolated static func writeTextCapture(text: String) throws {
        let (inbox, shopfloor) = try resolveContainer()
        let firstLine = String(text.split(separator: "\n", maxSplits: 1).first ?? "capture")
        let title    = String(firstLine.prefix(60)).trimmingCharacters(in: .whitespaces)
        let filename = uniqueFilename(from: title.isEmpty ? "capture" : title, in: inbox)
        try "# \(title)\n\n\(text)".write(to: inbox.appendingPathComponent(filename),
                                          atomically: true, encoding: .utf8)
        try flushMetadata(
            CaptureMetadata.make(
                filename: filename,
                notebookPath: inbox.path,
                captureMethod: "share_sheet"
            ),
            to: shopfloor
        )
    }

    private nonisolated static func writeImageCapture(fileURL: URL) throws {
        let (inbox, shopfloor) = try resolveContainer()
        let stem      = fileURL.deletingPathExtension().lastPathComponent
        let ext       = fileURL.pathExtension.isEmpty ? "jpg" : fileURL.pathExtension.lowercased()
        let mdName    = uniqueFilename(from: stem, in: inbox)
        let imgName   = mdName.replacingOccurrences(of: ".md", with: ".\(ext)")
        try FileManager.default.copyItem(at: fileURL, to: inbox.appendingPathComponent(imgName))
        try "# \(stem)\n\n".write(to: inbox.appendingPathComponent(mdName),
                                  atomically: true, encoding: .utf8)
        try flushMetadata(
            CaptureMetadata.make(
                filename: mdName,
                notebookPath: inbox.path,
                captureMethod: "share_sheet",
                contentType: "image",
                companionFilename: imgName
            ),
            to: shopfloor
        )
    }

    private nonisolated static func writeImageCapture(data: Data, fileExtension: String) throws {
        let (inbox, shopfloor) = try resolveContainer()
        let mdName  = uniqueFilename(from: "image", in: inbox)
        let imgName = mdName.replacingOccurrences(of: ".md", with: ".\(fileExtension)")
        try data.write(to: inbox.appendingPathComponent(imgName), options: .atomic)
        try "# Image\n\n".write(to: inbox.appendingPathComponent(mdName),
                                atomically: true, encoding: .utf8)
        try flushMetadata(
            CaptureMetadata.make(
                filename: mdName,
                notebookPath: inbox.path,
                captureMethod: "share_sheet",
                contentType: "image",
                companionFilename: imgName
            ),
            to: shopfloor
        )
    }

    private nonisolated static func writeFileCapture(fileURL: URL, contentType: String) throws {
        let (inbox, shopfloor) = try resolveContainer()
        let stem     = fileURL.deletingPathExtension().lastPathComponent
        let ext      = fileURL.pathExtension.lowercased()
        let mdName   = uniqueFilename(from: stem, in: inbox)
        let fileName = mdName.replacingOccurrences(of: ".md", with: ext.isEmpty ? "" : ".\(ext)")
        try FileManager.default.copyItem(at: fileURL, to: inbox.appendingPathComponent(fileName))
        try "# \(stem)\n\n".write(to: inbox.appendingPathComponent(mdName),
                                  atomically: true, encoding: .utf8)
        try flushMetadata(
            CaptureMetadata.make(
                filename: mdName,
                notebookPath: inbox.path,
                captureMethod: "share_sheet",
                contentType: contentType,
                companionFilename: fileName
            ),
            to: shopfloor
        )
    }

    private nonisolated static func writeReferenceNote(title: String, label: String) throws {
        let (inbox, shopfloor) = try resolveContainer()
        let filename = uniqueFilename(from: title.isEmpty ? label.lowercased() : title, in: inbox)
        try "# \(title.isEmpty ? label : title)\n\nShared \(label.lowercased()) via Capture.\n"
            .write(to: inbox.appendingPathComponent(filename), atomically: true, encoding: .utf8)
        try flushMetadata(
            CaptureMetadata.make(
                filename: filename,
                notebookPath: inbox.path,
                captureMethod: "share_sheet"
            ),
            to: shopfloor
        )
    }

    private nonisolated static func flushMetadata(_ metadata: CaptureMetadata, to shopfloorURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(metadata)
        try data.write(
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
