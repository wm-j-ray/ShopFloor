import Foundation

struct OGMetadata: Sendable {
    var title: String?
    var description: String?
    var imageURL: URL?
}

/// Fetches OpenGraph metadata from a URL by downloading the page HTML and parsing og: meta tags.
/// Returns whatever it finds; all fields are optional. Fails silently (returns empty struct).
func fetchOGMetadata(from url: URL) async -> OGMetadata {
    var request = URLRequest(url: url, timeoutInterval: 8)
    request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
    request.setValue("text/html", forHTTPHeaderField: "Accept")

    guard let (data, _) = try? await URLSession.shared.data(for: request) else {
        return OGMetadata()
    }
    let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
    return parseOGTags(from: html)
}

private func parseOGTags(from html: String) -> OGMetadata {
    var result = OGMetadata()

    // Scan only the <head> section for speed — OG tags are always there.
    let searchScope: String
    if let headEnd = html.range(of: "</head>", options: .caseInsensitive) {
        searchScope = String(html[..<headEnd.upperBound])
    } else {
        searchScope = html
    }

    result.title       = extractOGTag("og:title", from: searchScope)
                      ?? extractMetaName("title", from: searchScope)
    result.description = extractOGTag("og:description", from: searchScope)
                      ?? extractMetaName("description", from: searchScope)

    if let rawImage = extractOGTag("og:image", from: searchScope),
       let imageURL = URL(string: rawImage) {
        result.imageURL = imageURL
    }

    return result
}

private func extractOGTag(_ property: String, from html: String) -> String? {
    // <meta property="og:title" content="..."> or reversed attribute order
    let patterns = [
        "property=[\"']\(property)[\"'][^>]*content=[\"']([^\"']+)[\"']",
        "content=[\"']([^\"']+)[\"'][^>]*property=[\"']\(property)[\"']",
    ]
    for pattern in patterns {
        if let value = firstCapture(pattern: pattern, in: html) {
            return htmlEntityDecode(value)
        }
    }
    return nil
}

private func extractMetaName(_ name: String, from html: String) -> String? {
    let patterns = [
        "name=[\"']\(name)[\"'][^>]*content=[\"']([^\"']+)[\"']",
        "content=[\"']([^\"']+)[\"'][^>]*name=[\"']\(name)[\"']",
    ]
    for pattern in patterns {
        if let value = firstCapture(pattern: pattern, in: html) {
            return htmlEntityDecode(value)
        }
    }
    return nil
}

private func firstCapture(pattern: String, in text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: range),
          match.numberOfRanges > 1,
          let captureRange = Range(match.range(at: 1), in: text)
    else { return nil }
    let value = String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
}

private func htmlEntityDecode(_ s: String) -> String {
    var r = s
    r = r.replacingOccurrences(of: "&amp;",  with: "&")
    r = r.replacingOccurrences(of: "&lt;",   with: "<")
    r = r.replacingOccurrences(of: "&gt;",   with: ">")
    r = r.replacingOccurrences(of: "&quot;", with: "\"")
    r = r.replacingOccurrences(of: "&#39;",  with: "'")
    r = r.replacingOccurrences(of: "&apos;", with: "'")
    return r
}
