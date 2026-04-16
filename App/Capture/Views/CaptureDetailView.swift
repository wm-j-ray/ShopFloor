import SwiftUI

/// Displays a single capture's Markdown content.
/// Handles iCloud download-on-demand gracefully.
struct CaptureDetailView: View {
    @EnvironmentObject var store: CaptureStore
    let url: URL

    @State private var content: String?
    @State private var isDownloading = false
    @State private var captureNote: String?
    @State private var isEditingNote = false
    @State private var noteEditDraft = ""
    @State private var isSavingNote = false
    @State private var error: Error?

    var title: String {
        displayTitle(for: url)
    }

    var body: some View {
        Group {
            if isDownloading {
                ProgressView("Syncing from iCloud...")
            } else if let content {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(content)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()
                            .padding(.horizontal)

                        noteSection
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            } else if error != nil {
                ContentUnavailableView(
                    "Could Not Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error?.localizedDescription ?? "")
                )
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
    }

    // MARK: - Note section

    @ViewBuilder
    private var noteSection: some View {
        if isEditingNote {
            VStack(alignment: .leading, spacing: 8) {
                Text("Note")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $noteEditDraft)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                HStack {
                    Button("Cancel") {
                        isEditingNote = false
                        noteEditDraft = captureNote ?? ""
                    }
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button("Save") {
                        saveNote()
                    }
                    .disabled(isSavingNote)
                    .bold()
                }
            }
        } else {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Note")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let note = captureNote, !note.isEmpty {
                        Text(note)
                    } else {
                        Text("Add a note...")
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                }
                Spacer()
                Button {
                    noteEditDraft = captureNote ?? ""
                    isEditingNote = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Load

    private func load() async {
        let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        let status = values?.ubiquitousItemDownloadingStatus

        if status == .notDownloaded {
            isDownloading = true
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            // Poll until downloaded (production: use NSMetadataQuery instead).
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let refreshed = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                if refreshed?.ubiquitousItemDownloadingStatus == .current {
                    break
                }
            }
            isDownloading = false
        }

        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            self.error = error
        }

        // Load captureNote via the store (uses injected fileStore, not FileManager.default).
        captureNote = store.captureNote(forFilename: url.lastPathComponent)
        noteEditDraft = captureNote ?? ""
    }

    private func saveNote() {
        isSavingNote = true
        Task {
            do {
                try await store.updateNote(noteEditDraft, forFilename: url.lastPathComponent)
                captureNote = noteEditDraft.isEmpty ? nil : noteEditDraft
                isEditingNote = false
            } catch {
                self.error = error
            }
            isSavingNote = false
        }
    }
}
