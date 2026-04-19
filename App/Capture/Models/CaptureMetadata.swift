import Foundation

/// Per-file metadata record written to .shopfloor/files/[UUID].json alongside every capture.
/// This is the platform-layer UUID tracking described in the ShopFloor Platform Spec.
///
/// Canonical rules:
///   - captureNote and sourceURL are omitted from JSON entirely when nil (not written as null).
///   - Empty string captureNote is treated as nil at write time.
///   - contentType is always present; derived at capture time, never at display time.
struct CaptureMetadata: Codable, Sendable {
    /// Platform UUID for this file. Stable across renames and moves.
    let uuid: String

    /// Filename on disk (e.g., "my-capture.md"). Mutable — updated when file is moved.
    var filename: String

    /// Notebook path on disk at last known location. Mutable — updated on move.
    var notebookPath: String

    /// Karen's chosen display title. When present, shown instead of deriving from filename.
    /// Allows raw input (spaces, capitals, punctuation) while the filename stays a slug.
    var displayTitle: String?

    /// How this capture entered the system. "direct" = typed/pasted in-app.
    let captureMethod: String

    /// ISO 8601 creation timestamp.
    let createdAt: String

    /// Optional free-text note Karen can add at capture time or anytime afterward.
    /// Omitted from JSON when nil. Never written as null.
    var captureNote: String?

    /// What kind of content is inside the file. Set at capture time.
    /// Values: "text", "image", "pdf", "link", "other".
    /// See ContentType.from(filename:) — but "link" must be resolved BEFORE filename check.
    let contentType: String

    /// Source URL for share-sheet captures. Omitted when nil.
    var sourceURL: String?

    /// Filename of the companion binary file stored alongside the .md (e.g. "photo.jpg").
    /// Present for image, pdf, and other binary captures. Omitted when nil.
    var companionFilename: String?

    /// ISO 8601 timestamp when OG enrichment was last attempted for a link capture.
    /// Nil means enrichment has not been attempted yet.
    var ogFetchedAt: String?

    // ISO8601DateFormatter is non-Sendable (mutable NSObject subclass), so we cannot
    // share a static instance across actors under Swift 6 strict concurrency.
    // Create per-call — acceptable cost for the one-per-capture write path.
    static func make(
        filename: String,
        notebookPath: String,
        captureMethod: String = "direct",
        sourceURL: String? = nil,
        captureNote: String? = nil,
        contentType: String? = nil,
        displayTitle: String? = nil,
        companionFilename: String? = nil
    ) -> CaptureMetadata {
        // Explicit override wins. Then "link" for share_sheet+URL. Then filename extension.
        let resolvedType: String
        if let explicit = contentType {
            resolvedType = explicit
        } else if captureMethod == "share_sheet" && sourceURL?.isEmpty == false {
            resolvedType = "link"
        } else {
            resolvedType = ContentType.from(filename: filename)
        }
        // Treat empty captureNote as nil.
        let note = captureNote.flatMap { $0.isEmpty ? nil : $0 }
        let storedTitle = displayTitle.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0.trimmingCharacters(in: .whitespaces) }
        return CaptureMetadata(
            uuid: UUID().uuidString,
            filename: filename,
            notebookPath: notebookPath,
            displayTitle: storedTitle,
            captureMethod: captureMethod,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            captureNote: note,
            contentType: resolvedType,
            sourceURL: sourceURL,
            companionFilename: companionFilename,
            ogFetchedAt: nil
        )
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case uuid, filename, notebookPath, captureMethod, createdAt
        case captureNote, contentType, sourceURL, displayTitle, companionFilename, ogFetchedAt
    }

    /// Custom encode: omit captureNote and sourceURL keys entirely when nil.
    /// The default synthesized encoder writes `null` for optional nils — we don't want that.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(uuid, forKey: .uuid)
        try c.encode(filename, forKey: .filename)
        try c.encode(notebookPath, forKey: .notebookPath)
        try c.encode(captureMethod, forKey: .captureMethod)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(contentType, forKey: .contentType)
        try c.encodeIfPresent(captureNote, forKey: .captureNote)
        try c.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try c.encodeIfPresent(displayTitle, forKey: .displayTitle)
        try c.encodeIfPresent(companionFilename, forKey: .companionFilename)
        try c.encodeIfPresent(ogFetchedAt, forKey: .ogFetchedAt)
    }
}

// MARK: - ContentType

/// Derives contentType from file extension.
///
/// Does NOT handle "link" — callers must check captureMethod + sourceURL before calling this.
/// See CaptureMetadata.make() for the canonical resolution order.
enum ContentType {
    static func from(filename: String) -> String {
        switch URL(fileURLWithPath: filename).pathExtension.lowercased() {
        case "md", "txt":                          return "text"
        case "jpg", "jpeg", "png", "heic", "gif", "webp": return "image"
        case "pdf":                                return "pdf"
        default:                                   return "other"
        }
    }
}
