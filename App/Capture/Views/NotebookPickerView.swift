import SwiftUI

/// Bottom sheet for moving a capture to a different notebook.
/// Shows a sticky context header ("Moving 'Title' to:"), a flat list of all
/// notebooks, and a commit button. Presented as a sheet.
struct NotebookPickerView: View {
    @EnvironmentObject var store: CaptureStore
    @Environment(\.dismiss) private var dismiss

    let captureURL: URL
    var onMoved: () -> Void = {}

    @State private var notebooks: [URL] = []
    @State private var selectedNotebook: URL? = nil
    @State private var isMoving = false
    @State private var moveError: Error?

    private var captureTitle: String { store.displayTitle(for: captureURL) }
    private var currentNotebook: URL { captureURL.deletingLastPathComponent() }

    var body: some View {
        VStack(spacing: 0) {
            // Sticky context header
            VStack(alignment: .leading, spacing: 4) {
                Text("Move to")
                    .font(.headline)
                Text(captureTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            List(notebooks, id: \.path) { notebook in
                Button {
                    selectedNotebook = notebook
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color(UIColor.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 7))

                        Text(notebook.lastPathComponent)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        if selectedNotebook?.path == notebook.path {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.blue)
                        } else if notebook.path == currentNotebook.path {
                            Text("Current")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 3)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
            .listStyle(.plain)

            Divider()

            Button {
                commitMove()
            } label: {
                if isMoving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Move Here")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedNotebook == nil || isMoving)
            .padding()
        }
        .task { loadNotebooks() }
        .alert("Could Not Move", isPresented: Binding(
            get: { moveError != nil },
            set: { if !$0 { moveError = nil } }
        )) {
            Button("OK") { moveError = nil }
        } message: {
            Text(moveError?.localizedDescription ?? "")
        }
    }

    // MARK: - Actions

    private func commitMove() {
        guard let target = selectedNotebook else { return }
        isMoving = true
        Task {
            do {
                try await store.moveCapture(from: captureURL, to: target)
                onMoved()
                dismiss()
            } catch {
                moveError = error
            }
            isMoving = false
        }
    }

    // MARK: - Data

    private func loadNotebooks() {
        guard let root = store.rootURL else { return }
        notebooks = collectNotebooks(from: root).sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func collectNotebooks(from dir: URL) -> [URL] {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        var result: [URL] = []
        for url in entries {
            let vals = try? url.resourceValues(forKeys: [.isDirectoryKey])
            guard vals?.isDirectory == true else { continue }
            result.append(url)
            result += collectNotebooks(from: url)
        }
        return result
    }
}
