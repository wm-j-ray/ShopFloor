import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: CaptureStore
    @State private var isResolving = true
    @State private var showSettings = false
    @State private var navigationPath: [URL] = []

    var body: some View {
        Group {
            if isResolving {
                ProgressView("Loading...")
            } else if let root = store.rootURL {
                NavigationStack(path: $navigationPath) {
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
                        .navigationDestination(for: URL.self) { url in
                            if url.pathExtension == "md" {
                                CaptureDetailView(url: url)
                            } else {
                                NotebookBrowserView(url: url, title: url.lastPathComponent)
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
            store.startMetadataQuery()
            isResolving = false
            navigationPath = loadValidatedNavPath()
            Task(priority: .utility) {
                await store.rebuild()
            }
        }
        .onChange(of: navigationPath) { _, newPath in
            saveNavPath(newPath)
        }
        .onReceive(NotificationCenter.default.publisher(for: .rapidFireCreateCapture)) { notif in
            if let newURL = notif.object as? URL {
                navigationPath.append(newURL)
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

    // MARK: - Nav path persistence

    private let navPathKey = "nav_path_urls"

    private func saveNavPath(_ urls: [URL]) {
        UserDefaults.standard.set(urls.map(\.path), forKey: navPathKey)
    }

    private func loadValidatedNavPath() -> [URL] {
        guard let paths = UserDefaults.standard.stringArray(forKey: navPathKey) else { return [] }
        return paths.compactMap { path -> URL? in
            let url = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: path) ? url : nil
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
