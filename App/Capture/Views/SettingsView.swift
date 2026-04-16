import SwiftUI

/// App settings. Currently exposes the Rebuild Library emergency operation.
///
/// "Rebuild Library" is an escape hatch — Karen should never need it. The index
/// warms automatically on launch and rebuild() runs in the background. This button
/// exists for the case where Karen's library got into an inconsistent state (e.g.,
/// files deleted externally while the app was closed).
///
/// Note: This view will be simplified in Sprint 3 when NSMetadataQuery keeps the
/// index live — the manual rebuild button can be removed once real-time updates land.
struct SettingsView: View {
    @EnvironmentObject var store: CaptureStore

    @State private var isRebuilding = false
    @State private var rebuildSummary: String = ""

    var body: some View {
        Form {
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
                let noun = result.orphansRemoved == 1 ? "orphan" : "orphans"
                rebuildSummary = "\(result.orphansRemoved) \(noun) removed"
            }
            isRebuilding = false
        }
    }
}
