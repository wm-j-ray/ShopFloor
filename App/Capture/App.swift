import SwiftUI

@main
struct CaptureApp: App {
    @StateObject private var store = CaptureStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
