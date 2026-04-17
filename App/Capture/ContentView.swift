import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: CaptureStore
    @State private var isResolving = true
    @State private var showSettings = false

    var body: some View {
        Group {
            if isResolving {
                ProgressView("Loading...")
            } else if let root = store.rootURL {
                NavigationStack {
                    NotebookBrowserView(url: root, title: "Capture")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    showSettings = true
                                } label: {
                                    Image(systemName: "gear")
                                }
                                .accessibilityLabel("Settings")
                            }
                        }
                }
                .sheet(isPresented: $showSettings) {
                    NavigationStack {
                        SettingsView()
                    }
                }
            } else {
                iCloudUnavailableView()
            }
        }
        .task {
            await store.resolveContainer()
            // Start live iCloud index tracking. Must be called after rootURL is set.
            store.startMetadataQuery()
            isResolving = false
            // Clean orphaned .shopfloor records. Background so it doesn't delay first render.
            Task(priority: .utility) {
                await store.rebuild()
            }
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
