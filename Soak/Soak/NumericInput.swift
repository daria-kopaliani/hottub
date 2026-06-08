import SwiftUI

enum NumericInput {
    /// Filter typed input down to digits + a single decimal separator. Accepts
    /// both "." and "," regardless of system locale so a comma-decimal user
    /// can still type "7.5" and a dot-decimal user can still type "7,5".
    static func filter(_ s: String, allowDecimal: Bool = true) -> String {
        var seenSeparator = false
        var result = ""
        for ch in s {
            if ch.isASCII && ch.isNumber {
                result.append(ch)
            } else if allowDecimal && (ch == "." || ch == ",") && !seenSeparator {
                result.append(ch)
                seenSeparator = true
            }
        }
        return result
    }

    /// Parse a numeric string. Accepts both "." and "," as the decimal
    /// separator so a user on a comma-decimal locale (en_UA, fr_FR, etc.)
    /// who types "7.5" still gets a valid Double back — the prior
    /// NumberFormatter+.current path silently returned nil.
    static func parse(_ s: String) -> Double? {
        guard !s.isEmpty else { return nil }
        let normalized = s.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}

struct NumericTextField: View {
    @Binding var text: String
    var placeholder: String = "—"
    var allowDecimal: Bool = true

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(allowDecimal ? .decimalPad : .numberPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .onChange(of: text) { _, newValue in
                let filtered = NumericInput.filter(newValue, allowDecimal: allowDecimal)
                if filtered != newValue {
                    text = filtered
                }
            }
    }
}

struct SanitizerPill: View {
    let sanitizer: Sanitizer

    var body: some View {
        Text(sanitizer.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.accentColor.opacity(0.18)))
            .foregroundStyle(Color.accentColor)
    }
}

struct DoseHero: View {
    let product: String
    let dose: Dose
    let metric: Bool
    var tint: Color = .accentColor

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(product)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(dose.formattedAmount(metric: metric))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                Text(dose.unitLabel(metric: metric))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint.opacity(0.5))
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 6)
    }
}

struct SectionHeaderLabel: View {
    let text: String
    var trailing: AnyView? = nil

    init(_ text: String, trailing: AnyView? = nil) {
        self.text = text
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(text)
            Spacer()
            if let trailing { trailing }
        }
        .textCase(.none)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.primary)
    }
}

enum DisplayFormat {
    static func oneDecimal(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(1)))
    }

    static func integer(_ v: Double) -> String {
        "\(Int(v.rounded()))"
    }

    static func rangeOneDecimal(_ r: ClosedRange<Double>) -> String {
        "\(oneDecimal(r.lowerBound))–\(oneDecimal(r.upperBound))"
    }

    static func rangeInteger(_ r: ClosedRange<Double>) -> String {
        "\(integer(r.lowerBound))–\(integer(r.upperBound))"
    }
}

enum VolumeUnit {
    static let litersPerGallon: Double = 3.78541

    static func displayValue(gallons: Double, metric: Bool) -> String {
        let v = metric ? gallons * litersPerGallon : gallons
        return "\(Int(v.rounded()))"
    }

    static func parseGallons(_ text: String, metric: Bool) -> Double? {
        guard let v = NumericInput.parse(text) else { return nil }
        return metric ? v / litersPerGallon : v
    }

    static func unitLabel(metric: Bool) -> String {
        metric ? "L" : "gal"
    }

    static let minGallons: Double = 50
    static let maxGallons: Double = 2000

    static func isValidGallons(_ g: Double) -> Bool {
        g >= minGallons && g <= maxGallons
    }

    // Nice round defaults per unit. Not exact conversions of each other —
    // each is the most common, cleanest number for a home hot tub in that unit.
    static let niceMetricLiters: Double = 1500
    static let niceImperialGallons: Double = 400

    static func niceDefaultGallons(metric: Bool) -> Double {
        metric ? niceMetricLiters / litersPerGallon : niceImperialGallons
    }
}
