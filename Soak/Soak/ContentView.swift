import SwiftUI

struct ContentView: View {
    @EnvironmentObject var config: HotTubConfig

    private var initialScreen: String? {
        for arg in CommandLine.arguments where arg.hasPrefix("-UITestStartScreen=") {
            return String(arg.dropFirst("-UITestStartScreen=".count))
        }
        return nil
    }

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !config.hasCompletedOnboarding && !CommandLine.arguments.contains("-UITestShowPaywall") },
            set: { newValue in
                if !newValue { config.hasCompletedOnboarding = true }
            }
        )
    }

    @State private var showPaywallForScreenshot =
        CommandLine.arguments.contains("-UITestShowPaywall")

    var body: some View {
        rootView
            .fullScreenCover(isPresented: showOnboarding) {
                OnboardingView()
                    .environmentObject(config)
            }
            .sheet(isPresented: $showPaywallForScreenshot) {
                PaywallSheet()
            }
    }

    @ViewBuilder
    private var rootView: some View {
        switch initialScreen {
        case "testAdjust":
            NavigationStack { TestAdjustView() }
        case "afterUse":
            NavigationStack { AfterUseView() }
        case "shock":
            NavigationStack { ShockView() }
        default:
            MainView()
        }
    }
}

#Preview("Onboarding showing") {
    ContentView()
        .environmentObject(HotTubConfig())
}

#Preview("Main") {
    ContentView()
        .environmentObject({
            let c = HotTubConfig()
            c.hasCompletedOnboarding = true
            return c
        }())
}
