import SwiftUI

@main
struct SoakApp: App {
    @StateObject private var config = HotTubConfig()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .reviewPrompter()
                .environmentObject(config)
        }
    }
}
