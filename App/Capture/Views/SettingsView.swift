import SwiftUI

/// App settings. Exposes the Rebuild Library recovery operation.
///
/// NSMetadataQuery keeps the filenameToUUID index live — Karen should never need
/// this button. It remains as a recovery escape hatch for orphaned metadata records
/// (e.g., a crash left a .shopfloor/.json with no matching .md).
struct SettingsView: View {
    @EnvironmentObject var store: CaptureStore

    @AppStorage("sort_order") private var sortOrder: String = "alpha"
    @AppStorage("notebook_position") private var notebookPosition: String = "notebooks_first"

    @State private var isRebuilding = false
    @State private var rebuildSummary: String = ""

    var body: some View {
        Form {
            Section("Sorting") {
                Picker("Sort order", selection: $sortOrder) {
                    Text("Alphabetical").tag("alpha")
                    Text("Newest first").tag("date_newest")
                }
                Picker("Show notebooks", selection: $notebookPosition) {
                    Text("Before documents").tag("notebooks_first")
                    Text("After documents").tag("documents_first")
                }
            }

            Section {
                Button {
                    runRebuild()
                } label: {
                    HStack {
                        Label("Rebuild Library", systemImage: "arrow.clockwise")
                        if isRebuilding {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRebuilding)

                if !rebuildSummary.isEmpty {
                    Text(rebuildSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Scans your library for orphaned metadata records and cleans them up. Run this if something looks out of sync.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func runRebuild() {
        isRebuilding = true
        rebuildSummary = ""
        // Task(priority:) inherits @MainActor context from the Button action — safe to
        // capture @State vars. Do NOT use Task.detached (non-Sendable @State capture fails).
        Task(priority: .utility) {
            await store.rebuild()
            if let result = store.lastRebuildResult {
                var parts: [String] = []
                let orphanNoun = result.orphansRemoved == 1 ? "orphan" : "orphans"
                parts.append("\(result.orphansRemoved) \(orphanNoun) removed")
                if result.filesImported > 0 {
                    let fileNoun = result.filesImported == 1 ? "file" : "files"
                    parts.append("\(result.filesImported) \(fileNoun) imported")
                }
                rebuildSummary = parts.joined(separator: " · ")
            }
            isRebuilding = false
        }
    }
}
