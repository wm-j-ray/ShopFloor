import SwiftUI

/// Lists the notebooks (subdirectories) and captures (.md files) inside a given URL.
/// Handles iCloud download-on-demand: shows a cloud indicator for files not yet local.
struct NotebookBrowserView: View {
    @EnvironmentObject var store: CaptureStore

    let url: URL
    let title: String

    @AppStorage("sort_order") private var sortOrder: String = "alpha"
    @AppStorage("notebook_position") private var notebookPosition: String = "notebooks_first"

    @State private var items: [BrowserItem] = []
    @State private var showCreateCapture = false
    @State private var showCreateNotebook = false
    @State private var isLoading = false

    // Rename
    @State private var renamingItem: BrowserItem? = nil
    @State private var renameText: String = ""

    // Move
    @State private var movingCaptureURL: URL? = nil

    private var captureCount: Int {
        items.filter { if case .capture = $0 { true } else { false } }.count
    }

    private var sortedItems: [BrowserItem] {
        let nbFirst = notebookPosition != "documents_first"
        let byDate  = sortOrder == "date_newest"
        return items.sorted { a, b in
            let aIsNb: Bool
            let bIsNb: Bool
            if case .notebook = a { aIsNb = true } else { aIsNb = false }
            if case .notebook = b { bIsNb = true } else { bIsNb = false }
            if aIsNb != bIsNb { return nbFirst ? aIsNb : !aIsNb }
            if byDate {
                let aDate = BrowserItem.createdAt(of: a)
                let bDate = BrowserItem.createdAt(of: b)
                if aDate != bDate { return aDate > bDate }
            }
            return BrowserItem.name(of: a).localizedCaseInsensitiveCompare(BrowserItem.name(of: b)) == .orderedAscending
        }
    }

    var body: some View {
        List {
            if items.isEmpty && !isLoading {
                ContentUnavailableView(
                    "Empty",
                    systemImage: "tray",
                    description: Text("Tap + to add a capture or notebook.")
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
            } else {
                if captureCount > 0 {
                    Text("\(captureCount) \(captureCount == 1 ? "Document" : "Documents")")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 2, trailing: 12))
                        .listRowSeparator(.hidden)
                }

                ForEach(sortedItems) { item in
                    row(for: item)
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                        .listRowSeparator(.hidden)
                }
                .onDelete { indexSet in
                    let captures = indexSet.compactMap { index -> URL? in
                        if case .capture(let fileURL, _, _, _, _, _, _) = sortedItems[index] { return fileURL }
                        return nil
                    }
                    let notebooks = indexSet.compactMap { index -> URL? in
                        if case .notebook(let folderURL, _, _) = sortedItems[index] { return folderURL }
                        return nil
                    }
                    Task {
                        for fileURL in captures {
                            try? await store.deleteCapture(at: fileURL)
                        }
                        for folderURL in notebooks {
                            try? await store.deleteNotebook(at: folderURL)
                        }
                        await refresh()
                    }
                }
            }
        }
        .listStyle(.plain)
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("New Capture", systemImage: "doc.text") {
                        showCreateCapture = true
                    }
                    Button("New Notebook", systemImage: "folder") {
                        showCreateNotebook = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateCapture, onDismiss: { Task { await refresh() } }) {
            CreateCaptureView(destinationURL: url)
        }
        .sheet(isPresented: $showCreateNotebook, onDismiss: { Task { await refresh() } }) {
            CreateNotebookView(parentURL: url)
        }
        .task { await refresh() }
        .refreshable { await refresh() }
        .onChange(of: store.lastIndexUpdate) { _, _ in Task { await refresh() } }
        .alert("Rename", isPresented: Binding(
            get: { renamingItem != nil },
            set: { if !$0 { renamingItem = nil } }
        )) {
            TextField("Name", text: $renameText)
                .autocorrectionDisabled()
            Button("Rename") { commitRename() }
            Button("Cancel", role: .cancel) { renamingItem = nil }
        }
        .sheet(isPresented: Binding(
            get: { movingCaptureURL != nil },
            set: { if !$0 { movingCaptureURL = nil } }
        )) {
            if let captureURL = movingCaptureURL {
                NotebookPickerView(captureURL: captureURL) {
                    Task { await refresh() }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Rename

    private func commitRename() {
        guard let item = renamingItem else { return }
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { renamingItem = nil; return }

        Task {
            switch item {
            case .notebook(let url, _, _):
                try? await store.renameNotebook(at: url, newName: name)
            case .capture(let url, _, _, _, _, _, _):
                try? await store.renameCapture(at: url, newTitle: name)
            }
            renamingItem = nil
            await refresh()
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for item: BrowserItem) -> some View {
        switch item {
        case .notebook(let notebookURL, let captureCount, let subNotebookCount):
            NavigationLink(value: notebookURL) {
                NotebookRowLabel(
                    name: notebookURL.lastPathComponent,
                    captureCount: captureCount,
                    subNotebookCount: subNotebookCount
                )
            }
            .contextMenu {
                Button("Rename") {
                    renameText = notebookURL.lastPathComponent
                    renamingItem = item
                }
            }

        case .capture(let fileURL, let isDownloaded, let contentType, let note, let createdAt, let sourceURL, let companionURL):
            if isDownloaded {
                NavigationLink(value: fileURL) {
                    CaptureCardRow(
                        title: store.displayTitle(for: fileURL),
                        contentType: contentType,
                        note: note,
                        createdAt: createdAt,
                        sourceURL: sourceURL,
                        companionURL: companionURL
                    )
                }
                .contextMenu {
                    Button("Rename") {
                        renameText = store.displayTitle(for: fileURL)
                        renamingItem = item
                    }
                    Button("Move to...") {
                        movingCaptureURL = fileURL
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        Task {
                            try? await store.deleteCapture(at: fileURL)
                            await refresh()
                        }
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(width: 64, height: 64)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.displayTitle(for: fileURL))
                            .font(.system(size: 15, weight: .semibold))
                        Text("Syncing from iCloud...")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Data

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let urls = try store.contents(of: url)
            items = urls.compactMap { buildItem(from: $0) }
        } catch {
            store.error = error
        }
    }

    private func buildItem(from fileURL: URL) -> BrowserItem? {
        let values = try? fileURL.resourceValues(
            forKeys: [.isDirectoryKey, .ubiquitousItemDownloadingStatusKey]
        )
        guard let isDir = values?.isDirectory else { return nil }

        if isDir {
            let subURLs = (try? store.contents(of: fileURL)) ?? []
            var captures = 0, notebooks = 0
            for u in subURLs {
                let v = try? u.resourceValues(forKeys: [.isDirectoryKey])
                if v?.isDirectory == true { notebooks += 1 }
                else if u.pathExtension == "md" { captures += 1 }
            }
            return .notebook(fileURL, captureCount: captures, subNotebookCount: notebooks)
        } else if fileURL.pathExtension == "md" {
            let status = values?.ubiquitousItemDownloadingStatus
            let isDownloaded = (status == .current || status == nil)
            let filename = fileURL.lastPathComponent
            let meta = store.metadata(forFilename: filename)
            let contentType = meta?.contentType ?? ContentType.from(filename: filename)
            let companionURL = isDownloaded ? findCompanion(for: fileURL, contentType: contentType, meta: meta) : nil
            return .capture(
                fileURL,
                isDownloaded: isDownloaded,
                contentType: contentType,
                note: meta?.captureNote,
                createdAt: meta?.createdAt,
                sourceURL: meta?.sourceURL,
                companionURL: companionURL
            )
        }
        return nil
    }

    private func findCompanion(for mdURL: URL, contentType: String, meta: CaptureMetadata? = nil) -> URL? {
        let dir = mdURL.deletingLastPathComponent()

        if let name = meta?.companionFilename {
            let candidate = dir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }

        let stem = mdURL.deletingPathExtension().lastPathComponent
        let exts: [String]
        switch contentType {
        case "image": exts = ["jpg", "jpeg", "png", "heic", "gif", "webp"]
        case "pdf":   exts = ["pdf"]
        default:      return nil
        }
        return exts
            .map { dir.appendingPathComponent("\(stem).\($0)") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

// MARK: - CaptureCardRow

private struct CaptureCardRow: View {
    let title: String
    let contentType: String
    let note: String?
    let createdAt: String?
    let sourceURL: String?
    let companionURL: URL?

    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                thumbnailView
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                typeBadge.padding(4)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                if let dateText {
                    Text(dateText)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 2)
        }
        .padding(.vertical, 6)
        .task(id: companionURL) {
            guard let url = companionURL, contentType == "image" else { return }
            thumbnail = await Task.detached(priority: .utility) {
                UIImage(contentsOfFile: url.path)
            }.value
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if contentType == "image", let img = thumbnail {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            iconBackground
        }
    }

    private var iconBackground: some View {
        let (symbol, color) = typeAppearance
        return ZStack {
            color.opacity(0.12)
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(color.opacity(0.9))
        }
    }

    private var typeBadge: some View {
        let (symbol, label, color) = badgeAppearance
        return HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color, in: Capsule())
    }

    private var typeAppearance: (String, Color) {
        switch contentType {
        case "link":  return ("link", .blue)
        case "pdf":   return ("doc.richtext", .orange)
        case "image": return ("photo", .teal)
        default:      return ("doc.text", Color(.systemPurple))
        }
    }

    private var badgeAppearance: (String, String, Color) {
        switch contentType {
        case "link":  return ("link", "Link", .blue)
        case "pdf":   return ("doc.richtext", "PDF", .orange)
        case "image": return ("photo", "Image", .teal)
        default:      return ("doc.text", "Text", Color(.systemPurple))
        }
    }

    private var domain: String? {
        guard let raw = sourceURL,
              let host = URL(string: raw)?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private var dateText: String? {
        var parts: [String] = []
        if let d = domain { parts.append(d) }
        if let iso = createdAt, let date = ISO8601DateFormatter().date(from: iso) {
            let now = Date()
            if now.timeIntervalSince(date) < 86400 {
                let f = RelativeDateTimeFormatter()
                f.unitsStyle = .abbreviated
                parts.append(f.localizedString(for: date, relativeTo: now))
            } else {
                let f = DateFormatter()
                f.dateFormat = "MMM d"
                parts.append(f.string(from: date))
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - NotebookRowLabel

private struct NotebookRowLabel: View {
    let name: String
    let captureCount: Int
    let subNotebookCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.blue)
                .frame(width: 64, height: 64)
                .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(countDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var countDescription: String {
        if captureCount == 0 && subNotebookCount == 0 { return "Empty" }
        var parts: [String] = []
        if captureCount > 0 {
            parts.append("\(captureCount) \(captureCount == 1 ? "item" : "items")")
        }
        if subNotebookCount > 0 {
            parts.append("\(subNotebookCount) \(subNotebookCount == 1 ? "notebook" : "notebooks")")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - BrowserItem

enum BrowserItem: Identifiable, Comparable {
    case notebook(URL, captureCount: Int, subNotebookCount: Int)
    case capture(URL, isDownloaded: Bool, contentType: String, note: String?, createdAt: String?, sourceURL: String?, companionURL: URL?)

    var id: String {
        switch self {
        case .notebook(let u, _, _):          return "nb-\(u.path)"
        case .capture(let u, _, _, _, _, _, _): return "cap-\(u.path)"
        }
    }

    var sortKey: String {
        switch self {
        case .notebook(let u, _, _):          return "0-\(u.lastPathComponent.lowercased())"
        case .capture(let u, _, _, _, _, _, _): return "1-\(u.lastPathComponent.lowercased())"
        }
    }

    static func < (lhs: BrowserItem, rhs: BrowserItem) -> Bool {
        lhs.sortKey < rhs.sortKey
    }

    static func name(of item: BrowserItem) -> String {
        switch item {
        case .notebook(let u, _, _):          return u.lastPathComponent
        case .capture(let u, _, _, _, _, _, _): return u.lastPathComponent
        }
    }

    static func createdAt(of item: BrowserItem) -> String {
        if case .capture(_, _, _, _, let date, _, _) = item { return date ?? "" }
        return ""
    }
}
