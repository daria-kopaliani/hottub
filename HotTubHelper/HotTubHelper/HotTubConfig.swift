import Foundation
import Combine

@MainActor
final class HotTubConfig: ObservableObject {

    @Published var gallons: Double {
        didSet { UserDefaults.standard.set(gallons, forKey: Keys.gallons) }
    }

    @Published var sanitizer: Sanitizer {
        didSet { UserDefaults.standard.set(sanitizer.rawValue, forKey: Keys.sanitizer) }
    }

    @Published var preferredChlorineProduct: ChlorineProduct {
        didSet {
            UserDefaults.standard.set(preferredChlorineProduct.rawValue,
                                      forKey: Keys.chlorineProduct)
        }
    }

    @Published var preferredPHLowerer: PHLowerer {
        didSet {
            UserDefaults.standard.set(preferredPHLowerer.rawValue,
                                      forKey: Keys.phLowerer)
        }
    }

    @Published var useMetric: Bool {
        didSet { UserDefaults.standard.set(useMetric, forKey: Keys.useMetric) }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.onboarded) }
    }

    init() {
        let d = UserDefaults.standard

        if CommandLine.arguments.contains("-UITestDemoState") {
            if let bundleID = Bundle.main.bundleIdentifier {
                d.removePersistentDomain(forName: bundleID)
            }
            useMetric = true
            gallons = VolumeUnit.niceDefaultGallons(metric: true)
            sanitizer = .bromine
            preferredChlorineProduct = .dichlor56
            preferredPHLowerer = .dryAcid
            hasCompletedOnboarding = true
            return
        }

        let resolvedMetric = (d.object(forKey: Keys.useMetric) as? Bool) ?? Self.defaultUseMetric()
        useMetric = resolvedMetric
        gallons = (d.object(forKey: Keys.gallons) as? Double)
            ?? VolumeUnit.niceDefaultGallons(metric: resolvedMetric)
        sanitizer = Sanitizer(rawValue: d.string(forKey: Keys.sanitizer) ?? "") ?? .bromine
        preferredChlorineProduct = ChlorineProduct(
            rawValue: d.string(forKey: Keys.chlorineProduct) ?? "") ?? .dichlor56
        preferredPHLowerer = PHLowerer(
            rawValue: d.string(forKey: Keys.phLowerer) ?? "") ?? .dryAcid
        hasCompletedOnboarding = d.bool(forKey: Keys.onboarded)
    }

    private static func defaultUseMetric() -> Bool {
        Locale.current.measurementSystem == .metric
    }

    private enum Keys {
        static let gallons = "config.gallons"
        static let sanitizer = "config.sanitizer"
        static let chlorineProduct = "config.chlorineProduct"
        static let phLowerer = "config.phLowerer"
        static let useMetric = "config.useMetric"
        static let onboarded = "config.onboarded"
    }
}
