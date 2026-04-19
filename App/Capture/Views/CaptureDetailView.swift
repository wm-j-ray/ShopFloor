import SwiftUI

extension Notification.Name {
    static let rapidFireCreateCapture = Notification.Name("rapidFireCreateCapture")
}

/// Displays a single capture. Branches by contentType:
///   text    → MarkdownTextEditor (always editable; auto-saves on disappear)
///   link    → hero + title + domain + metadata bar + notes
///   image   → ImageCaptureView + note section (in ScrollView)
///   pdf     → PDFCaptureView + note section (no ScrollView — PDFView scrolls itself)
///   default → plain text + note section
struct CaptureDetailView: View {
    @EnvironmentObject var store: CaptureStore
    @Environment(\.openURL) private var openURL
    let url: URL

    // Content
    @State private var content: String = ""
    @State private var bodyDraft: String = ""
    @State private var contentType: String = "text"
    @State private var companionURL: URL?
    @State private var isDownloading = false

    // Link metadata
    @State private var sourceURL: String? = nil
    @State private var createdAt: String? = nil

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

            } else if contentType == "link" {
                linkBody

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
                HStack(spacing: 4) {
                    Button {
                        rapidFireCreate()
                    } label: {
                        Image(systemName: "plus")
                    }
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
            if contentType == "link" {
                ToolbarItem(placement: .principal) {
                    Button {
                        renameText = title
                        showRenameAlert = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(Color(red: 0.88, green: 0.42, blue: 0.32))
                                .font(.system(size: 14))
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task { await load() }
        .onChange(of: store.lastIndexUpdate) { _, _ in
            guard contentType == "link" else { return }
            Task { await load() }
        }
        .onDisappear {
            saveBodyIfChanged()
            saveNoteIfEditing()
        }
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
        VStack(alignment: .leading, spacing: 10) {
            // Header — pencil icon signals this section is editable
            HStack(spacing: 6) {
                Text("Notes")
                    .font(.headline)
                Image(systemName: "square.and.pencil")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if isEditingNote {
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
            } else if let note = captureNote, !note.isEmpty {
                Text(note)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        noteEditDraft = note
                        isEditingNote = true
                    }
            } else {
                Text("Tap to add a note...")
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        noteEditDraft = ""
                        isEditingNote = true
                    }
            }
        }
    }

    // MARK: - Load

    private func load() async {
        await ensureDownloaded(url)

        do {
            content = try String(contentsOf: url, encoding: .utf8)
            bodyDraft = content
        } catch {
            self.error = error
        }

        let meta = store.metadata(forFilename: url.lastPathComponent)
        captureNote = meta?.captureNote
        sourceURL   = meta?.sourceURL
        createdAt   = meta?.createdAt
        noteEditDraft = captureNote ?? ""

        contentType = meta?.contentType
            ?? ContentType.from(filename: url.lastPathComponent)

        if let candidate = findCompanion(meta: meta) {
            await ensureDownloaded(candidate)
            companionURL = candidate
        }

        // Kick off OG enrichment in background for un-enriched link captures.
        if contentType == "link", meta?.ogFetchedAt == nil {
            Task { await store.enrichLinkCapture(filename: url.lastPathComponent) }
        }
    }

    /// Triggers iCloud download of a file and waits up to 10 seconds for it to arrive.
    /// Sets isDownloading so the view shows a "Syncing from iCloud…" overlay.
    private func ensureDownloaded(_ fileURL: URL) async {
        let values = try? fileURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        guard values?.ubiquitousItemDownloadingStatus == .notDownloaded else { return }
        isDownloading = true
        try? FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            let refreshed = try? fileURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if refreshed?.ubiquitousItemDownloadingStatus == .current { break }
        }
        isDownloading = false
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

    /// Auto-saves the note draft when navigating away mid-edit, matching text-body behavior.
    private func saveNoteIfEditing() {
        guard isEditingNote, noteEditDraft != (captureNote ?? "") else { return }
        let draft = noteEditDraft
        Task {
            try? await store.updateNote(draft, forFilename: url.lastPathComponent)
        }
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

    // MARK: - Rapid fire

    private func rapidFireCreate() {
        let notebook = url.deletingLastPathComponent()
        guard let newURL = try? store.createCapture(title: "capture", body: "", notebook: notebook) else { return }
        NotificationCenter.default.post(name: .rapidFireCreateCapture, object: newURL)
    }

    // MARK: - Link body

    private var linkBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                linkHero
                    .frame(maxWidth: .infinity)

                // Title — long press to rename
                Text(title)
                    .font(.title3.bold())
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onLongPressGesture {
                        renameText = title
                        showRenameAlert = true
                    }

                if let domain = extractedDomain {
                    Label(domain, systemImage: "globe")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }

                Divider().padding(.horizontal)

                linkMetadataBar
                    .padding()

                Divider().padding(.horizontal)

                noteSection
                    .padding()

                Spacer(minLength: 32)
            }
        }
    }

    private var linkHero: some View {
        Button {
            if let raw = sourceURL, let dest = URL(string: raw) {
                openURL(dest)
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                if let companion = companionURL,
                   let img = UIImage(contentsOfFile: companion.path) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [Color.blue.opacity(0.18), Color.blue.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 220)
                    .overlay {
                        Image(systemName: "link")
                            .font(.system(size: 60, weight: .ultraLight))
                            .foregroundStyle(.blue.opacity(0.20))
                    }
                }

                // Visual affordance only — whole hero is the tap target
                if sourceURL != nil {
                    Label("Open", systemImage: "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.88, green: 0.42, blue: 0.32), in: Capsule())
                        .padding(16)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var linkMetadataBar: some View {
        HStack(spacing: 16) {
            if let date = formattedDate {
                Label(date, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let domain = extractedDomain {
                Label(domain, systemImage: "globe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "link")
                    .font(.system(size: 9, weight: .semibold))
                Text("Link")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue, in: Capsule())
        }
    }

    private var extractedDomain: String? {
        guard let raw = sourceURL, let host = URL(string: raw)?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private var formattedDate: String? {
        guard let iso = createdAt, let date = ISO8601DateFormatter().date(from: iso) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    // MARK: - Companion

    /// Locates the companion binary file for this capture.
    /// Prefers the explicit filename stored in metadata (set at capture time).
    /// Falls back to a filesystem stem-scan for captures that predate this field.
    private func findCompanion(meta: CaptureMetadata? = nil) -> URL? {
        let dir = url.deletingLastPathComponent()

        if let name = meta?.companionFilename {
            let candidate = dir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }

        // Legacy fallback: scan for known extensions matching the .md stem.
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
