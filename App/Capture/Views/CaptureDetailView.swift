import SwiftUI

/// Displays a single capture's Markdown content.
/// Handles iCloud download-on-demand gracefully.
struct CaptureDetailView: View {
    let url: URL

    @State private var content: String?
    @State private var isDownloading = false
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
                    Text(content)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func load() async {
        let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        let status = values?.ubiquitousItemDownloadingStatus

        if status == .notDownloaded {
            // Trigger download and wait. Don't read an empty file.
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
    }
}
