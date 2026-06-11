import StoreKit
import SwiftUI

// Moon Dog shared pattern. Canonical copy: /moondog/patterns/ReviewPrompter.swift
// Drop this file into the app's source folder and attach `.reviewPrompter()`
// to the root view in <App>App.swift.
//
// Asks for an App Store rating on the 3rd foreground session, at most once
// per app version. The system additionally caps prompts at 3 per year, so
// this can never spam. Skipped entirely under UI tests / screenshot capture
// (any launch argument containing "UITest" or "screenshot").
struct ReviewPrompterModifier: ViewModifier {
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("review.sessionCount") private var sessionCount = 0
    @AppStorage("review.lastPromptedVersion") private var lastPromptedVersion = ""

    private static let sessionThreshold = 3

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            sessionCount += 1
            promptIfEarned()
        }
    }

    @MainActor
    private func promptIfEarned() {
        let isTestRun = CommandLine.arguments.contains {
            $0.localizedCaseInsensitiveContains("uitest") || $0.localizedCaseInsensitiveContains("screenshot")
        }
        guard !isTestRun else { return }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        guard sessionCount >= Self.sessionThreshold, lastPromptedVersion != version else { return }
        lastPromptedVersion = version
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            requestReview()
        }
    }
}

extension View {
    func reviewPrompter() -> some View {
        modifier(ReviewPrompterModifier())
    }
}
