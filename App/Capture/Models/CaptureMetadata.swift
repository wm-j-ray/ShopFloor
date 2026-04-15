import Foundation

/// Per-file metadata record written to .shopfloor/files/[UUID].json alongside every capture.
/// This is the platform-layer UUID tracking described in the ShopFloor Platform Spec.
struct CaptureMetadata: Codable, Sendable {
    /// Platform UUID for this file. Stable across renames and moves.
    let uuid: String

    /// Filename at time of capture (e.g., "my-capture.md"). May drift if Karen renames.
    let filename: String

    /// Notebook path relative to the iCloud Documents root at time of capture.
    let notebookPath: String

    /// How this capture entered the system. "direct" = typed/pasted in-app.
    let captureMethod: String

    /// ISO 8601 creation timestamp.
    let createdAt: String

    static func make(filename: String, notebookPath: String, captureMethod: String = "direct") -> CaptureMetadata {
        CaptureMetadata(
            uuid: UUID().uuidString,
            filename: filename,
            notebookPath: notebookPath,
            captureMethod: captureMethod,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}
