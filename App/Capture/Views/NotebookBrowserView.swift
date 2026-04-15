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

        case .capture(let fileURL, let isDownloaded):
            if isDownloaded {
                NavigationLink {
                    CaptureDetailView(url: fileURL)
                } label: {
                    Label(displayTitle(for: fileURL), systemImage: "doc.text")
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

    // MARK: - Data

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let urls = try store.contents(of: url)
            items = urls.compactMap { BrowserItem(url: $0) }.sorted()
        } catch {
            store.error = error
        }
    }
}

// MARK: - Browser Item

enum BrowserItem: Identifiable, Comparable {
    case notebook(URL)
    case capture(URL, isDownloaded: Bool)

    var id: String {
        switch self {
        case .notebook(let u): return "nb-\(u.path)"
        case .capture(let u, _): return "cap-\(u.path)"
        }
    }

    var sortKey: String {
        switch self {
        case .notebook(let u): return "0-\(u.lastPathComponent)"
        case .capture(let u, _): return "1-\(u.lastPathComponent)"
        }
    }

    static func < (lhs: BrowserItem, rhs: BrowserItem) -> Bool {
        lhs.sortKey < rhs.sortKey
    }

    init?(url: URL) {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .ubiquitousItemDownloadingStatusKey])
        guard let isDir = values?.isDirectory else { return nil }

        if isDir {
            self = .notebook(url)
        } else if url.pathExtension == "md" {
            let status = values?.ubiquitousItemDownloadingStatus
            let isDownloaded = (status == .current || status == nil)
            self = .capture(url, isDownloaded: isDownloaded)
        } else {
            return nil
        }
    }
}
