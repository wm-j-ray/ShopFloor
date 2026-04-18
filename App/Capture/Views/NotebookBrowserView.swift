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

    // Rename
    @State private var renamingItem: BrowserItem? = nil
    @State private var renameText: String = ""

    // Move
    @State private var movingCaptureURL: URL? = nil

    private var captureCount: Int {
        items.filter { if case .capture = $0 { true } else { false } }.count
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
                // Count header as a plain row — no Section wrapper (Section always adds top inset)
                if captureCount > 0 {
                    Text("\(captureCount) \(captureCount == 1 ? "Document" : "Documents")")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 2, trailing: 12))
                        .listRowSeparator(.hidden)
                }

                ForEach(items) { item in
                    row(for: item)
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
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
        .listStyle(.plain)
        // Zero out the List's built-in top scroll inset — this is what caused the gap
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
        // Rename alert
        .alert("Rename", isPresented: Binding(
            get: { renamingItem != nil },
            set: { if !$0 { renamingItem = nil } }
        )) {
            TextField("Name", text: $renameText)
                .autocorrectionDisabled()
            Button("Rename") { commitRename() }
            Button("Cancel", role: .cancel) { renamingItem = nil }
        }
        // Move sheet
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
            case .notebook(let url):
                try? await store.renameNotebook(at: url, newName: name)
            case .capture(let url, _, _):
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
        case .notebook(let notebookURL):
            NavigationLink {
                NotebookBrowserView(url: notebookURL, title: notebookURL.lastPathComponent)
            } label: {
                BrowserRowLabel(icon: "folder", title: notebookURL.lastPathComponent)
            }
            .contextMenu {
                Button("Rename") {
                    renameText = notebookURL.lastPathComponent
                    renamingItem = item
                }
            }

        case .capture(let fileURL, let isDownloaded, let contentType):
            if isDownloaded {
                NavigationLink {
                    CaptureDetailView(url: fileURL)
                } label: {
                    BrowserRowLabel(
                        icon: contentTypeIcon(contentType),
                        title: store.displayTitle(for: fileURL),
                        badge: contentTypeDisplayLabel(contentType)
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
                BrowserRowLabel(
                    icon: "icloud.and.arrow.down",
                    title: store.displayTitle(for: fileURL),
                    subtitle: "Syncing from iCloud..."
                )
            }
        }
    }

    /// Maps contentType to an SF symbol name.
    private func contentTypeIcon(_ type: String) -> String {
        switch type {
        case "image": return "photo"
        case "pdf":   return "doc.richtext"
        case "link":  return "link"
        default:      return "doc.text"
        }
    }

    /// Maps internal contentType strings to user-facing badge labels.
    /// Returns nil for plain text — no badge needed for the default type.
    private func contentTypeDisplayLabel(_ type: String) -> String? {
        switch type {
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

// MARK: - BrowserRowLabel

private struct BrowserRowLabel: View {
    let icon: String
    let title: String
    var badge: String? = nil
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Icon card — matches Notebooks App reference
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color(UIColor.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let badge {
                Text(badge)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
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
            let resolvedType = contentType ?? ContentType.from(filename: url.lastPathComponent)
            self = .capture(url, isDownloaded: isDownloaded, contentType: resolvedType)
        } else {
            return nil
        }
    }
}
