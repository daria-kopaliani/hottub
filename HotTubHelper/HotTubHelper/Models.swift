import Foundation

enum Sanitizer: String, CaseIterable, Codable, Identifiable {
    case bromine
    case chlorine

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chlorine: return "Chlorine"
        case .bromine: return "Bromine"
        }
    }

    var unitLabel: String {
        switch self {
        case .chlorine: return "FC (ppm)"
        case .bromine: return "Bromine (ppm)"
        }
    }

    var targetRange: ClosedRange<Double> {
        switch self {
        case .chlorine: return 1.0...3.0
        case .bromine: return 2.0...4.0
        }
    }
}

enum ChlorineProduct: String, CaseIterable, Codable, Identifiable {
    case liquid125
    case calHypo68
    case dichlor56

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .liquid125: return "Liquid chlorine 12.5%"
        case .calHypo68: return "Cal-hypo 68%"
        case .dichlor56: return "Dichlor 56%"
        }
    }

    var isLiquid: Bool { self == .liquid125 }
}

enum PHRaiser: String, CaseIterable, Codable, Identifiable {
    case sodaAsh

    var id: String { rawValue }
    var displayName: String { "Soda ash" }
}

enum PHLowerer: String, CaseIterable, Codable, Identifiable {
    case dryAcid
    case muriatic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dryAcid: return "Dry acid"
        case .muriatic: return "Muriatic acid"
        }
    }

    var isLiquid: Bool { self == .muriatic }
}

struct Dose: Equatable {
    enum Unit { case grams, milliliters }

    let amount: Double
    let unit: Unit

    static let none = Dose(amount: 0, unit: .grams)

    var isNegligible: Bool { amount < 0.5 }

    func formatted(metric: Bool = true) -> String {
        if isNegligible { return "—" }
        if metric {
            switch unit {
            case .grams:
                return amount < 10
                    ? String(format: "%.1f g", amount)
                    : String(format: "%.0f g", amount)
            case .milliliters:
                return amount < 10
                    ? String(format: "%.1f ml", amount)
                    : String(format: "%.0f ml", amount)
            }
        } else {
            switch unit {
            case .grams:
                let oz = amount / 28.3495
                return String(format: "%.2f oz", oz)
            case .milliliters:
                let flOz = amount / 29.5735
                return String(format: "%.2f fl oz", flOz)
            }
        }
    }
}

struct Recommendation: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let product: String
    let dose: Dose
    let detail: String?

    static func == (lhs: Recommendation, rhs: Recommendation) -> Bool {
        lhs.title == rhs.title
            && lhs.product == rhs.product
            && lhs.dose == rhs.dose
            && lhs.detail == rhs.detail
    }
}
