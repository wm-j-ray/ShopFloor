import SwiftUI

/// Lists the notebooks (subdirectories) and captures (.md files) inside a given URL.
/// Handles iCloud download-on-demand: shows a cloud indicator for files not yet local.
struct NotebookBrowserView: View {
    @EnvironmentObject var store: CaptureStore

    let url: URL
    let title: String

    @State private var items: [BrowserItem] = []
    @State private var showCreateCapture = false
    @State private var showCreateNotebook = false
    @State private var isLoading = false

    var body: some View {
        List {
            if items.isEmpty && !isLoading {
                ContentUnavailableView(
                    "Empty",
                    systemImage: "tray",
                    description: Text("Tap + to add a capture or notebook.")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(items) { item in
                    row(for: item)
                }
                .onDelete { indexSet in
                    let captures = indexSet.compactMap { index -> URL? in
                        if case .capture(let fileURL, _, _) = items[index] { return fileURL }
                        return nil
                    }
                    let notebooks = indexSet.compactMap { index -> URL? in
                        if case .notebook(let folderURL) = items[index] { return folderURL }
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
        .navigationTitle(title)
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
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for item: BrowserItem) -> some View {
        switch item {
        case .notebook(let notebookURL):
            NavigationLink {
                NotebookBrowserView(url: notebookURL, title: notebookURL.lastPathComponent)
            } label: {
                Label(notebookURL.lastPathComponent, systemImage: "folder")
            }

        case .capture(let fileURL, let isDownloaded, let contentType):
            if isDownloaded {
                NavigationLink {
                    CaptureDetailView(url: fileURL)
                } label: {
                    captureLabel(title: displayTitle(for: fileURL), contentType: contentType)
                }
            } else {
                Label {
                    VStack(alignment: .leading) {
                        Text(displayTitle(for: fileURL))
                        Text("Syncing from iCloud...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "icloud.and.arrow.down")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func captureLabel(title: String, contentType: String) -> some View {
        HStack {
            Label(title, systemImage: "doc.text")
            Spacer()
            if let label = contentTypeDisplayLabel(contentType) {
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Maps internal contentType strings to user-facing badge labels.
    /// Returns nil for "other" — no badge shown for unclassified files.
    private func contentTypeDisplayLabel(_ type: String) -> String? {
        switch type {
        case "text":  return "Text"
        case "image": return "Image"
        case "pdf":   return "PDF"
        case "link":  return "Link"
        default:      return nil
        }
    }

    // MARK: - Data

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let urls = try store.contents(of: url)
            items = urls.compactMap { fileURL -> BrowserItem? in
                let contentType = store.contentType(forFilename: fileURL.lastPathComponent)
                return BrowserItem(url: fileURL, contentType: contentType)
            }.sorted()
        } catch {
            store.error = error
        }
    }
}

// MARK: - BrowserItem

enum BrowserItem: Identifiable, Comparable {
    case notebook(URL)
    case capture(URL, isDownloaded: Bool, contentType: String)

    var id: String {
        switch self {
        case .notebook(let u):       return "nb-\(u.path)"
        case .capture(let u, _, _): return "cap-\(u.path)"
        }
    }

    var sortKey: String {
        switch self {
        case .notebook(let u):       return "0-\(u.lastPathComponent)"
        case .capture(let u, _, _): return "1-\(u.lastPathComponent)"
        }
    }

    static func < (lhs: BrowserItem, rhs: BrowserItem) -> Bool {
        lhs.sortKey < rhs.sortKey
    }

    init?(url: URL, contentType: String? = nil) {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .ubiquitousItemDownloadingStatusKey])
        guard let isDir = values?.isDirectory else { return nil }

        if isDir {
            self = .notebook(url)
        } else if url.pathExtension == "md" {
            let status = values?.ubiquitousItemDownloadingStatus
            let isDownloaded = (status == .current || status == nil)
            // Use stored contentType from .shopfloor JSON when available; fall back to
            // filename extension for files captured before this fix.
            let resolvedType = contentType ?? ContentType.from(filename: url.lastPathComponent)
            self = .capture(url, isDownloaded: isDownloaded, contentType: resolvedType)
        } else {
            return nil
        }
    }
}
