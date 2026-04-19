import SwiftUI

extension Notification.Name {
    static let navigateToURL = Notification.Name("navigateToURL")
}

/// Bottom sheet for jumping to any notebook or document in the tree.
/// "Go Here" navigates to that notebook; tapping a document navigates directly to it.
struct GoToPickerView: View {
    @EnvironmentObject var store: CaptureStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GoToLevelView(
                folderURL: store.rootURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
                isRoot: true,
                onNavigate: { url in
                    NotificationCenter.default.post(name: .navigateToURL, object: url)
                    dismiss()
                }
            )
            .navigationTitle("Go To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - GoToLevelView

private struct GoToLevelView: View {
    @EnvironmentObject var store: CaptureStore

    let folderURL: URL
    let isRoot: Bool
    let onNavigate: (URL) -> Void

    @State private var notebooks: [URL] = []
    @State private var documents: [URL] = []

    var body: some View {
        List {
            if !isRoot {
                Button {
                    onNavigate(folderURL)
                } label: {
                    Label("Go Here", systemImage: "arrow.right.circle.fill")
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                }
                .listRowBackground(Color.blue.opacity(0.06))
            }

            if !notebooks.isEmpty {
                Section("Notebooks") {
                    ForEach(notebooks, id: \.path) { folder in
                        NavigationLink {
                            GoToLevelView(
                                folderURL: folder,
                                isRoot: false,
                                onNavigate: onNavigate
                            )
                            .navigationTitle(folder.lastPathComponent)
                        } label: {
                            Label(folder.lastPathComponent, systemImage: "folder.fill")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

            if !documents.isEmpty {
                Section("Documents") {
                    ForEach(documents, id: \.path) { doc in
                        Button {
                            onNavigate(doc)
                        } label: {
                            Label(store.displayTitle(for: doc), systemImage: "doc.text")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

            if notebooks.isEmpty && documents.isEmpty {
                Text("Empty")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .task { loadContents() }
    }

    private func loadContents() {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var nbs: [URL] = []
        var docs: [URL] = []
        for entry in entries {
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            if isDir {
                nbs.append(entry)
            } else if entry.pathExtension == "md" {
                docs.append(entry)
            }
        }

        notebooks = nbs.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        documents = docs.sorted { store.displayTitle(for: $0).localizedCaseInsensitiveCompare(store.displayTitle(for: $1)) == .orderedAscending }
    }
}
