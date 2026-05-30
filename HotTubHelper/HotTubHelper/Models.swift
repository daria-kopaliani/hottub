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

    var practicalRange: ClosedRange<Double> { 0...20 }
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
        let amount = formattedAmount(metric: metric)
        let unit = unitLabel(metric: metric)
        return unit.isEmpty ? amount : "\(amount) \(unit)"
    }

    func formattedAmount(metric: Bool = true) -> String {
        if isNegligible { return "—" }
        if metric {
            return amount < 10
                ? String(format: "%.1f", amount)
                : String(format: "%.0f", amount)
        } else {
            switch unit {
            case .grams:
                let oz = amount / 28.3495
                return String(format: "%.2f", oz)
            case .milliliters:
                let flOz = amount / 29.5735
                return String(format: "%.2f", flOz)
            }
        }
    }

    func unitLabel(metric: Bool = true) -> String {
        if isNegligible { return "" }
        if metric {
            return unit == .grams ? "g" : "ml"
        } else {
            return unit == .grams ? "oz" : "fl oz"
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

struct Advisory: Identifiable, Equatable {
    enum Kind { case info, warning }

    let id = UUID()
    let title: String
    let body: String
    let kind: Kind

    static func == (lhs: Advisory, rhs: Advisory) -> Bool {
        lhs.title == rhs.title && lhs.body == rhs.body && lhs.kind == rhs.kind
    }
}
