import SwiftUI

@main
struct SoakApp: App {
    @StateObject private var config = HotTubConfig()
    @StateObject private var purchases: PurchaseStore
    @StateObject private var trial: TrialState
    @StateObject private var entitlement: Entitlement

    init() {
        let p = PurchaseStore()
        let t = TrialState()
        _purchases = StateObject(wrappedValue: p)
        _trial = StateObject(wrappedValue: t)
        _entitlement = StateObject(wrappedValue: Entitlement(purchases: p, trial: t))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .reviewPrompter()
                .environmentObject(config)
                .environmentObject(purchases)
                .environmentObject(trial)
                .environmentObject(entitlement)
                .task {
                    trial.startIfNeeded()
                    await purchases.start()
                }
        }
    }
}
