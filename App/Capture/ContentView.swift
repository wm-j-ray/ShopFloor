import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: CaptureStore
    @State private var isResolving = true

    var body: some View {
        Group {
            if isResolving {
                ProgressView("Loading...")
            } else if let root = store.rootURL {
                NavigationStack {
                    NotebookBrowserView(url: root, title: "Capture")
                }
            } else {
                iCloudUnavailableView()
            }
        }
        .task {
            await store.resolveContainer()
            isResolving = false
            // Yield so SwiftUI redraws before we do background file I/O.
            await Task.yield()
            try? await store.ensureInbox()
        }
        .alert("Error", isPresented: Binding(
            get: { store.error != nil },
            set: { if !$0 { store.error = nil } }
        )) {
            Button("OK") { store.error = nil }
        } message: {
            Text(store.error?.localizedDescription ?? "")
        }
    }
}

private struct iCloudUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            "iCloud Not Available",
            systemImage: "icloud.slash",
            description: Text("Sign in to iCloud in Settings to use Capture.")
        )
    }
}
