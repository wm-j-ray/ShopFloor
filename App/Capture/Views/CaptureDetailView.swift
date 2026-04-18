import SwiftUI

/// Displays a single capture. Branches by contentType:
///   image   → ImageCaptureView + note section (in ScrollView)
///   pdf     → PDFCaptureView + note section (no ScrollView — PDFView scrolls itself)
///   default → Markdown text + note section (in ScrollView)
struct CaptureDetailView: View {
    @EnvironmentObject var store: CaptureStore
    let url: URL

    @State private var content: String?
    @State private var contentType: String = "text"
    @State private var companionURL: URL?
    @State private var isDownloading = false
    @State private var captureNote: String?
    @State private var isEditingNote = false
    @State private var noteEditDraft = ""
    @State private var isSavingNote = false
    @State private var error: Error?

    var title: String { displayTitle(for: url) }

    var body: some View {
        Group {
            if isDownloading {
                ProgressView("Syncing from iCloud...")

            } else if contentType == "pdf", let companion = companionURL {
                // PDF scrolls itself — no outer ScrollView.
                VStack(spacing: 0) {
                    PDFCaptureView(url: companion)
                    Divider()
                    noteSection
                        .padding()
                }

            } else if content != nil || companionURL != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        contentBody
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

    // MARK: - Content body

    @ViewBuilder
    private var contentBody: some View {
        if contentType == "image", let companion = companionURL {
            ImageCaptureView(url: companion)
                .padding(.horizontal)
        } else if let content {
            Text(content)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                    Button("Save") { saveNote() }
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
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let refreshed = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                if refreshed?.ubiquitousItemDownloadingStatus == .current { break }
            }
            isDownloading = false
        }

        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            self.error = error
        }

        captureNote = store.captureNote(forFilename: url.lastPathComponent)
        noteEditDraft = captureNote ?? ""

        // Content type drives which composite is shown.
        // Fall back to filename extension if index not yet warmed.
        contentType = store.contentType(forFilename: url.lastPathComponent)
            ?? ContentType.from(filename: url.lastPathComponent)
        companionURL = findCompanion()
    }

    /// Finds the companion image or PDF file in the same folder.
    /// The share extension writes e.g. photo.jpg alongside photo.md — same stem, different ext.
    private func findCompanion() -> URL? {
        let dir  = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
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
