import SwiftUI

/// Displays a single capture. Branches by contentType:
///   text    → MarkdownTextEditor (always editable; auto-saves on disappear)
///   image   → ImageCaptureView + note section (in ScrollView)
///   pdf     → PDFCaptureView + note section (no ScrollView — PDFView scrolls itself)
///   default → plain text + note section
struct CaptureDetailView: View {
    @EnvironmentObject var store: CaptureStore
    let url: URL

    // Content
    @State private var content: String = ""
    @State private var bodyDraft: String = ""
    @State private var contentType: String = "text"
    @State private var companionURL: URL?
    @State private var isDownloading = false

    // Note
    @State private var captureNote: String?
    @State private var isEditingNote = false
    @State private var noteEditDraft = ""
    @State private var isSavingNote = false

    // Editor focus
    @State private var isEditingBody = false

    // Rename
    @State private var showRenameAlert = false
    @State private var renameText: String = ""

    // Move
    @State private var showMovePicker = false

    // Link insertion
    @State private var pendingLink: PendingLink? = nil
    @State private var pendingURL: String = ""
    @State private var markdownCoordinator: MarkdownTextEditor.Coordinator? = nil

    @State private var error: Error?

    struct PendingLink {
        let label: String
        let range: NSRange
    }

    var title: String { store.displayTitle(for: url) }

    var body: some View {
        Group {
            if isDownloading {
                ProgressView("Syncing from iCloud...")

            } else if contentType == "pdf", let companion = companionURL {
                VStack(spacing: 0) {
                    PDFCaptureView(url: companion)
                    Divider()
                    noteSection
                        .padding()
                }

            } else if contentType == "text" {
                textEditorBody

            } else if content != "" || companionURL != nil {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Rename") {
                        renameText = store.displayTitle(for: url)
                        showRenameAlert = true
                    }
                    Button("Move to...") {
                        showMovePicker = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task { await load() }
        .onDisappear { saveBodyIfChanged() }
        // Rename alert
        .alert("Rename", isPresented: $showRenameAlert) {
            TextField("Name", text: $renameText)
                .autocorrectionDisabled()
            Button("Rename") {
                let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                Task { try? await store.renameCapture(at: url, newTitle: name) }
            }
            Button("Cancel", role: .cancel) {}
        }
        // Move sheet
        .sheet(isPresented: $showMovePicker) {
            NotebookPickerView(captureURL: url)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Add Link", isPresented: Binding(
            get: { pendingLink != nil },
            set: { if !$0 { pendingLink = nil; pendingURL = "" } }
        )) {
            TextField("URL", text: $pendingURL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Add") { commitLink() }
            Button("Cancel", role: .cancel) { pendingLink = nil; pendingURL = "" }
        } message: {
            if let p = pendingLink, !p.label.isEmpty {
                Text("Link text: \"\(p.label)\"")
            }
        }
    }

    // MARK: - Text editor body

    private var textEditorBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            MarkdownTextEditor(
                text: $bodyDraft,
                onLinkRequest: { selected, range in
                    pendingLink = PendingLink(label: selected, range: range)
                },
                onCoordinatorReady: { coordinator in
                    markdownCoordinator = coordinator
                },
                onEditingChanged: { editing in
                    isEditingBody = editing
                }
            )
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Hide note section while editing — give Karen the full screen
            if !isEditingBody {
                Divider()
                    .padding(.horizontal)

                noteSection
                    .padding()
            }
        }
    }

    // MARK: - Content body (image / other)

    @ViewBuilder
    private var contentBody: some View {
        if contentType == "image", let companion = companionURL {
            ImageCaptureView(url: companion)
                .padding(.horizontal)
        } else if !content.isEmpty {
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
            bodyDraft = content
        } catch {
            self.error = error
        }

        captureNote = store.captureNote(forFilename: url.lastPathComponent)
        noteEditDraft = captureNote ?? ""

        contentType = store.contentType(forFilename: url.lastPathComponent)
            ?? ContentType.from(filename: url.lastPathComponent)
        companionURL = findCompanion()
    }

    // MARK: - Save body

    private func saveBodyIfChanged() {
        guard contentType == "text", bodyDraft != content else { return }
        let draft = bodyDraft
        let fileURL = url
        content = draft
        Task.detached(priority: .utility) {
            try? draft.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Link

    private func commitLink() {
        guard let p = pendingLink, !pendingURL.isEmpty else {
            pendingLink = nil
            pendingURL = ""
            return
        }
        let label = p.label.isEmpty ? pendingURL : p.label
        markdownCoordinator?.applyLink(label: label, url: pendingURL, range: p.range)
        pendingLink = nil
        pendingURL = ""
    }

    // MARK: - Note

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

    // MARK: - Companion

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
}
