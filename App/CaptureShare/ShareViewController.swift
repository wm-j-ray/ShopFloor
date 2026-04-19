import UIKit
import UniformTypeIdentifiers

// NSObject/UIViewController subclass — Share extensions use ObjC messaging for
// NSExtensionRequestHandling, which UIViewController already implements.
final class ShareViewController: UIViewController {

    // MARK: - Pending content

    /// Loaded from the extension context before the folder picker is shown.
    /// Holds everything needed to write the capture once a target folder is chosen.
    private struct PendingShare {
        enum Payload {
            case link(url: URL)
            case text(content: String)
            case imageFile(sourceURL: URL, ext: String)
            case imageData(data: Data, ext: String)
            case pdfFile(sourceURL: URL)
            case movie(title: String)
            case genericFile(sourceURL: URL, contentType: String)
        }
        let payload: Payload
    }

    private var pending: PendingShare?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        Task {
            await setup()
            spinner.removeFromSuperview()
        }
    }

    // MARK: - Setup

    private func setup() async {
        // Resolve the iCloud Documents root on a background thread (Apple requirement).
        let rootURL: URL? = await Task.detached(priority: .userInitiated) {
            FileManager.default
                .url(forUbiquityContainerIdentifier: "iCloud.com.shopfloor.capture")?
                .appendingPathComponent("Documents", isDirectory: true)
        }.value

        guard let rootURL else { complete(); return }

        // Load the share payload.
        guard
            let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let attachments = item.attachments, !attachments.isEmpty
        else { complete(); return }

        do {
            let payload = try await loadPayload(from: attachments)
            pending = PendingShare(payload: payload)
        } catch {
            complete()
            return
        }

        showFolderPicker(root: rootURL)
    }

    // MARK: - Payload loading

    private func loadPayload(from attachments: [NSItemProvider]) async throws -> PendingShare.Payload {
        if let provider = attachments.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }) {
            let raw = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
            guard let url = raw as? URL else { throw URLError(.unknown) }
            return .link(url: url)
        }

        if let provider = attachments.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        }) {
            let raw = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
            guard let text = raw as? String else { throw URLError(.unknown) }
            return .text(content: text)
        }

        if let provider = attachments.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }) {
            let raw = try await provider.loadItem(forTypeIdentifier: UTType.image.identifier)
            if let fileURL = raw as? URL {
                let ext = fileURL.pathExtension.isEmpty ? "jpg" : fileURL.pathExtension.lowercased()
                return .imageFile(sourceURL: fileURL, ext: ext)
            } else if let image = raw as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.9) {
                return .imageData(data: data, ext: "jpg")
            }
            throw URLError(.unknown)
        }

        if let provider = attachments.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier)
        }) {
            let raw = try await provider.loadItem(forTypeIdentifier: UTType.pdf.identifier)
            guard let fileURL = raw as? URL else { throw URLError(.unknown) }
            return .pdfFile(sourceURL: fileURL)
        }

        if let provider = attachments.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
        }) {
            let raw = try await provider.loadItem(forTypeIdentifier: UTType.movie.identifier)
            let title = (raw as? URL).map { $0.deletingPathExtension().lastPathComponent } ?? "video"
            return .movie(title: title)
        }

        if let provider = attachments.first {
            let raw = try await provider.loadItem(forTypeIdentifier: UTType.data.identifier)
            guard let fileURL = raw as? URL else { throw URLError(.unknown) }
            return .genericFile(sourceURL: fileURL, contentType: "other")
        }

        throw URLError(.unknown)
    }

    // MARK: - Folder picker

    private func showFolderPicker(root: URL) {
        guard let payload = pending?.payload else { complete(); return }

        // Seed the title from content; updated live as Karen types.
        var userTitle = ShareViewController.candidateTitle(for: payload)

        let pickerVC = FolderPickerViewController(
            folderURL: root,
            isRoot: true,
            candidateTitle: userTitle,
            onTitleChanged: { userTitle = $0 },
            onSave: { [weak self] targetFolder in
                self?.writeThenComplete(to: targetFolder, title: userTitle)
            },
            onCancel: { [weak self] in
                self?.complete()
            }
        )
        let nav = UINavigationController(rootViewController: pickerVC)
        nav.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(nav)
        view.addSubview(nav.view)
        NSLayoutConstraint.activate([
            nav.view.topAnchor.constraint(equalTo: view.topAnchor),
            nav.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nav.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nav.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        nav.didMove(toParent: self)
    }

    // MARK: - Write + complete

    private func writeThenComplete(to folder: URL, title: String) {
        guard let pending else { complete(); return }
        Task {
            try? await Task.detached(priority: .userInitiated) {
                try ShareViewController.write(pending.payload, title: title, to: folder)
            }.value
            complete()
        }
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    // MARK: - Candidate title

    /// Derives a default title from share content before Karen can edit it.
    private nonisolated static func candidateTitle(for payload: PendingShare.Payload) -> String {
        switch payload {
        case .link(let url):
            return url.host ?? url.absoluteString
        case .text(let content):
            let first = String(content.split(separator: "\n", maxSplits: 1).first ?? "capture")
            let trimmed = String(first.prefix(60)).trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? "capture" : trimmed
        case .imageFile(let url, _):
            return url.deletingPathExtension().lastPathComponent
        case .imageData:
            return "Image"
        case .pdfFile(let url):
            return url.deletingPathExtension().lastPathComponent
        case .movie(let title):
            return title.isEmpty ? "Video" : title
        case .genericFile(let url, _):
            return url.deletingPathExtension().lastPathComponent
        }
    }

    // MARK: - Write helpers
    // nonisolated: called from Task.detached — no UI access, only file I/O.

    private nonisolated static func write(_ payload: PendingShare.Payload, title: String, to folder: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let shopfloor = try resolveShopfloor()
        try fm.createDirectory(at: shopfloor, withIntermediateDirectories: true)
        let t = title.trimmingCharacters(in: .whitespaces)

        switch payload {
        case .link(let url):
            try writeLinkCapture(sourceURL: url, title: t, to: folder, shopfloor: shopfloor)
        case .text(let content):
            try writeTextCapture(text: content, title: t, to: folder, shopfloor: shopfloor)
        case .imageFile(let sourceURL, let ext):
            try writeImageCapture(fileURL: sourceURL, title: t, ext: ext, to: folder, shopfloor: shopfloor)
        case .imageData(let data, let ext):
            try writeImageCapture(data: data, title: t, fileExtension: ext, to: folder, shopfloor: shopfloor)
        case .pdfFile(let sourceURL):
            try writeFileCapture(fileURL: sourceURL, title: t, contentType: "pdf", to: folder, shopfloor: shopfloor)
        case .movie:
            try writeReferenceNote(title: t, label: "Video", to: folder, shopfloor: shopfloor)
        case .genericFile(let sourceURL, let contentType):
            try writeFileCapture(fileURL: sourceURL, title: t, contentType: contentType, to: folder, shopfloor: shopfloor)
        }
    }

    private nonisolated static func resolveShopfloor() throws -> URL {
        guard let container = FileManager.default
            .url(forUbiquityContainerIdentifier: "iCloud.com.shopfloor.capture") else {
            throw URLError(.unsupportedURL)
        }
        let shopfloor = container.appendingPathComponent(".shopfloor/files", isDirectory: true)
        return shopfloor
    }

    private nonisolated static func writeLinkCapture(sourceURL: URL, title: String, to folder: URL, shopfloor: URL) throws {
        let filename = uniqueFilename(from: title, in: folder)
        try "# \(title)\n\n".write(to: folder.appendingPathComponent(filename),
                                   atomically: true, encoding: .utf8)
        try flushMetadata(
            CaptureMetadata.make(
                filename: filename,
                notebookPath: folder.path,
                captureMethod: "share_sheet",
                sourceURL: sourceURL.absoluteString,
                displayTitle: title
            ),
            to: shopfloor
        )
    }

    private nonisolated static func writeTextCapture(text: String, title: String, to folder: URL, shopfloor: URL) throws {
        let filename = uniqueFilename(from: title, in: folder)
        try "# \(title)\n\n\(text)".write(to: folder.appendingPathComponent(filename),
                                          atomically: true, encoding: .utf8)
        try flushMetadata(
            CaptureMetadata.make(
                filename: filename,
                notebookPath: folder.path,
                captureMethod: "share_sheet",
                displayTitle: title
            ),
            to: shopfloor
        )
    }

    private nonisolated static func writeImageCapture(fileURL: URL, title: String, ext: String, to folder: URL, shopfloor: URL) throws {
        let mdName  = uniqueFilename(from: title, in: folder)
        let imgName = mdName.replacingOccurrences(of: ".md", with: ".\(ext)")
        try FileManager.default.copyItem(at: fileURL, to: folder.appendingPathComponent(imgName))
        try "# \(title)\n\n".write(to: folder.appendingPathComponent(mdName),
                                   atomically: true, encoding: .utf8)
        try flushMetadata(
            CaptureMetadata.make(
                filename: mdName,
                notebookPath: folder.path,
                captureMethod: "share_sheet",
                contentType: "image",
                displayTitle: title,
                companionFilename: imgName
            ),
            to: shopfloor
        )
    }

    private nonisolated static func writeImageCapture(data: Data, title: String, fileExtension: String, to folder: URL, shopfloor: URL) throws {
        let mdName  = uniqueFilename(from: title, in: folder)
        let imgName = mdName.replacingOccurrences(of: ".md", with: ".\(fileExtension)")
        try data.write(to: folder.appendingPathComponent(imgName), options: .atomic)
        try "# \(title)\n\n".write(to: folder.appendingPathComponent(mdName),
                                   atomically: true, encoding: .utf8)
        try flushMetadata(
            CaptureMetadata.make(
                filename: mdName,
                notebookPath: folder.path,
                captureMethod: "share_sheet",
                contentType: "image",
                displayTitle: title,
                companionFilename: imgName
            ),
            to: shopfloor
        )
    }

    private nonisolated static func writeFileCapture(fileURL: URL, title: String, contentType: String, to folder: URL, shopfloor: URL) throws {
        let ext      = fileURL.pathExtension.lowercased()
        let mdName   = uniqueFilename(from: title, in: folder)
        let fileName = mdName.replacingOccurrences(of: ".md", with: ext.isEmpty ? "" : ".\(ext)")
        try FileManager.default.copyItem(at: fileURL, to: folder.appendingPathComponent(fileName))
        try "# \(title)\n\n".write(to: folder.appendingPathComponent(mdName),
                                   atomically: true, encoding: .utf8)
        try flushMetadata(
            CaptureMetadata.make(
                filename: mdName,
                notebookPath: folder.path,
                captureMethod: "share_sheet",
                contentType: contentType,
                displayTitle: title,
                companionFilename: fileName
            ),
            to: shopfloor
        )
    }

    private nonisolated static func writeReferenceNote(title: String, label: String, to folder: URL, shopfloor: URL) throws {
        let filename = uniqueFilename(from: title.isEmpty ? label.lowercased() : title, in: folder)
        try "# \(title.isEmpty ? label : title)\n\nShared \(label.lowercased()) via Capture.\n"
            .write(to: folder.appendingPathComponent(filename), atomically: true, encoding: .utf8)
        try flushMetadata(
            CaptureMetadata.make(
                filename: filename,
                notebookPath: folder.path,
                captureMethod: "share_sheet",
                displayTitle: title.isEmpty ? nil : title
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
