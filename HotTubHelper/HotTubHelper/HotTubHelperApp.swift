import SwiftUI

@main
struct HotTubHelperApp: App {
    @StateObject private var config = HotTubConfig()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(config)
        }
    }
}
