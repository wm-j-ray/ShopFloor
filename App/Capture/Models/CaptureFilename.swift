import Foundation

/// Derives a display title purely from the filename slug.
/// Use `CaptureStore.displayTitle(for:)` in views — it checks stored titles first.
///
/// Current format: `[slug].md` — e.g., `this-is-the-title.md` → `This Is The Title`
/// Legacy format: `[slug]-[unix-timestamp].md` — timestamp stripped for backward compat.
func derivedTitle(for url: URL) -> String {
    var name = url.deletingPathExtension().lastPathComponent

    // Strip legacy trailing -[timestamp] (9–11 digit Unix timestamp).
    if let range = name.range(of: #"-\d{9,11}$"#, options: .regularExpression) {
        name = String(name[name.startIndex..<range.lowerBound])
    }

    // De-slugify: hyphens → spaces, capitalize each word.
    return name
        .replacingOccurrences(of: "-", with: " ")
        .capitalized
}

/// Legacy free-function shim — routes to `derivedTitle(for:)`.
/// Prefer `CaptureStore.displayTitle(for:)` in views so stored titles are respected.
func displayTitle(for url: URL) -> String { derivedTitle(for: url) }
