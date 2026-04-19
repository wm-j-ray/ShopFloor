import SwiftUI

/// Bottom sheet for moving a capture to a different notebook.
/// Navigates the notebook tree level-by-level. "Move Here" is available at every
/// level so Karen can choose any folder without drilling all the way to a leaf.
struct NotebookPickerView: View {
    @EnvironmentObject var store: CaptureStore
    @Environment(\.dismiss) private var dismiss

    let captureURL: URL
    var onMoved: () -> Void = {}

    private var captureTitle: String { store.displayTitle(for: captureURL) }

    var body: some View {
        NavigationStack {
            NotebookLevelView(
                folderURL: store.rootURL ?? captureURL.deletingLastPathComponent(),
                captureURL: captureURL,
                isRoot: true,
                onMoved: {
                    onMoved()
                    dismiss()
                }
            )
            .navigationTitle("Move to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - NotebookLevelView

/// One level of the notebook tree. Shown as a List of subfolders in folderURL.
/// "Move Here" commits the move to this level. Tapping a row with children pushes deeper.
private struct NotebookLevelView: View {
    @EnvironmentObject var store: CaptureStore

    let folderURL: URL
    let captureURL: URL
    let isRoot: Bool
    let onMoved: () -> Void

    @State private var subfolders: [URL] = []
    @State private var isMoving = false
    @State private var moveError: Error?

    private var currentNotebook: URL { captureURL.deletingLastPathComponent() }
    private var isCurrent: Bool { folderURL.path == currentNotebook.path }

    var body: some View {
        VStack(spacing: 0) {
            // Context header — shows what's being moved
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle")
                    .foregroundStyle(.secondary)
                Text(store.displayTitle(for: captureURL))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            List {
                ForEach(subfolders, id: \.path) { folder in
                    row(for: folder)
                }
            }
            .listStyle(.plain)

            Divider()

            // Move Here button — available at every level
            Button {
                commitMove(to: folderURL)
            } label: {
                if isMoving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label(
                        "Move Here" + (isCurrent ? " (Current)" : ""),
                        systemImage: "folder.badge.plus"
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCurrent || isMoving)
            .padding()
        }
        .task { loadSubfolders() }
        .alert("Could Not Move", isPresented: Binding(
            get: { moveError != nil },
            set: { if !$0 { moveError = nil } }
        )) {
            Button("OK") { moveError = nil }
        } message: {
            Text(moveError?.localizedDescription ?? "")
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for folder: URL) -> some View {
        let children = subfolderURLs(of: folder)
        if children.isEmpty {
            // Leaf — tapping commits move here
            Button {
                commitMove(to: folder)
            } label: {
                folderLabel(for: folder, hasChildren: false)
            }
        } else {
            // Has children — navigate deeper
            NavigationLink {
                NotebookLevelView(
                    folderURL: folder,
                    captureURL: captureURL,
                    isRoot: false,
                    onMoved: onMoved
                )
                .navigationTitle(folder.lastPathComponent)
            } label: {
                folderLabel(for: folder, hasChildren: true)
            }
        }
    }

    private func folderLabel(for folder: URL, hasChildren: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: hasChildren ? "folder.fill" : "folder")
                .font(.system(size: 15))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(Color(UIColor.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 7))

            Text(folder.lastPathComponent)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            if folder.path == currentNotebook.path {
                Text("Current")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Data

    private func loadSubfolders() {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        subfolders = entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func subfolderURLs(of dir: URL) -> [URL] {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return entries.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }

    // MARK: - Move

    private func commitMove(to target: URL) {
        isMoving = true
        Task {
            do {
                try await store.moveCapture(from: captureURL, to: target)
                onMoved()
            } catch {
                moveError = error
                isMoving = false
            }
        }
    }
}
