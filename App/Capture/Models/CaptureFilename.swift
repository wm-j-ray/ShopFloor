import Foundation

/// Converts a capture filename slug back to a human-readable display title.
///
/// Current format: `[slug].md` — e.g., `this-is-the-title.md` → `This Is The Title`
/// Legacy format: `[slug]-[unix-timestamp].md` — timestamp stripped for backward compat.
func displayTitle(for url: URL) -> String {
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
