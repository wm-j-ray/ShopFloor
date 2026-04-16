import Foundation

/// Converts a capture filename slug back to a human-readable display title.
///
/// Filename format: `[slug]-[unix-timestamp].md`
/// Example: `this-is-the-title-1776284785.md` → `This Is The Title`
func displayTitle(for url: URL) -> String {
    var name = url.deletingPathExtension().lastPathComponent

    // Strip trailing -[timestamp] (9–11 digit Unix timestamp).
    if let range = name.range(of: #"-\d{9,11}$"#, options: .regularExpression) {
        name = String(name[name.startIndex..<range.lowerBound])
    }

    // De-slugify: hyphens → spaces, capitalize each word.
    return name
        .replacingOccurrences(of: "-", with: " ")
        .capitalized
}
