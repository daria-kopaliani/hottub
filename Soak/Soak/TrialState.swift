import Foundation
import Combine

// 48-hour full-feature trial. Persists the first-launch instant in
// UserDefaults the moment the app boots for the first time. Everything is
// unlocked during the trial window; after 48h the app re-locks behind the
// paywall until com.kopaliani.HotTubHelper.pro is purchased.
//
// Launch-arg overrides for sim verification + screenshots:
//   -UITestTrialActive   → treat trial as just-started (~47h left)
//   -UITestTrialExpired  → treat trial as expired 1h ago

@MainActor
final class TrialState: ObservableObject {
    static let trialDurationHours: Double = 48

    private let userDefaults: UserDefaults
    private let firstLaunchKey = "soak.trial.firstLaunchAt"

    @Published private(set) var firstLaunchAt: Date?
    @Published private(set) var now: Date = .now

    private var tickTimer: Timer?

    init(userDefaults: UserDefaults = .standard, clock: Date = .now) {
        self.userDefaults = userDefaults
        self.now = clock
        self.firstLaunchAt = Self.loadFirstLaunch(userDefaults: userDefaults, key: firstLaunchKey)
        applyOverrides()
        scheduleTick()
    }

    deinit { tickTimer?.invalidate() }

    private static func loadFirstLaunch(userDefaults: UserDefaults, key: String) -> Date? {
        let raw = userDefaults.double(forKey: key)
        guard raw > 0 else { return nil }
        return Date(timeIntervalSince1970: raw)
    }

    /// Start the 48h clock if it hasn't started yet. Call at app launch so
    /// the trial begins when the user first opens Soak.
    func startIfNeeded() {
        guard firstLaunchAt == nil else { return }
        guard !isUITestOverride else { return }
        let stamp = Date()
        userDefaults.set(stamp.timeIntervalSince1970, forKey: firstLaunchKey)
        firstLaunchAt = stamp
    }

    func resetForTesting() {
        userDefaults.removeObject(forKey: firstLaunchKey)
        firstLaunchAt = nil
    }

    var elapsedSeconds: TimeInterval {
        guard let start = firstLaunchAt else { return 0 }
        return max(0, now.timeIntervalSince(start))
    }

    var remainingSeconds: TimeInterval {
        let total = TrialState.trialDurationHours * 3600
        return max(0, total - elapsedSeconds)
    }

    var isActive: Bool { firstLaunchAt != nil && remainingSeconds > 0 }
    var isExpired: Bool { firstLaunchAt != nil && remainingSeconds == 0 }
    var hasStarted: Bool { firstLaunchAt != nil }

    var expiryDate: Date? {
        guard let start = firstLaunchAt else { return nil }
        return start.addingTimeInterval(TrialState.trialDurationHours * 3600)
    }

    var remainingShortLabel: String {
        let secs = Int(remainingSeconds)
        let hours = secs / 3_600
        let mins = (secs % 3_600) / 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(max(1, mins))m"
    }

    /// True in the final 6 hours of the trial — triggers the gentle banner.
    var isInWarningWindow: Bool {
        isActive && remainingSeconds <= 6 * 3600
    }

    private func scheduleTick() {
        tickTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = Date()
            }
        }
    }

    private var isUITestOverride: Bool {
        CommandLine.arguments.contains("-UITestTrialActive")
            || CommandLine.arguments.contains("-UITestTrialExpired")
    }

    private func applyOverrides() {
        let args = CommandLine.arguments
        if args.contains("-UITestTrialActive") {
            firstLaunchAt = Date().addingTimeInterval(-1 * 3600)
        } else if args.contains("-UITestTrialExpired") {
            firstLaunchAt = Date().addingTimeInterval(-49 * 3600)
        }
    }
}
