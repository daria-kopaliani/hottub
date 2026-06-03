import SwiftUI

struct TestAdjustView: View {
    @EnvironmentObject var config: HotTubConfig

    @State private var sanitizerText: String = ""
    @State private var phText: String = ""
    @State private var taText: String = ""
    @State private var chText: String = ""

    private enum Field: Hashable { case sanitizer, ph, ta, ch }
    @FocusState private var focusedField: Field?

    private var sanitizerValue: Double? { NumericInput.parse(sanitizerText) }
    private var phValue: Double? { NumericInput.parse(phText) }
    private var taValue: Double? { NumericInput.parse(taText) }
    private var chValue: Double? { NumericInput.parse(chText) }

    private var hasAnyReading: Bool {
        sanitizerValue != nil || phValue != nil || taValue != nil || chValue != nil
    }

    private var recommendations: [Recommendation] {
        computeRecommendations()
    }

    private var advisories: [Advisory] {
        computeAdvisories()
    }

    var body: some View {
        Form {
            Section {
                readingRow(label: sanitizerLabel,
                           unit: "ppm",
                           text: $sanitizerText,
                           parsedValue: sanitizerValue,
                           target: config.sanitizer.targetRange,
                           practical: config.sanitizer.practicalRange,
                           rangeText: DisplayFormat.rangeOneDecimal(config.sanitizer.targetRange),
                           field: .sanitizer)
                    .task {
                        if CommandLine.arguments.contains("-UITestSampleReadings") {
                            let sep = Locale.current.decimalSeparator ?? "."
                            sanitizerText = "1\(sep)5"
                            phText = "7\(sep)9"
                            taText = "60"
                            chText = "120"
                        }
                    }
                readingRow(label: "pH",
                           unit: nil,
                           text: $phText,
                           parsedValue: phValue,
                           target: Formulas.TargetRange.pH,
                           practical: Formulas.PracticalRange.pH,
                           rangeText: DisplayFormat.rangeOneDecimal(Formulas.TargetRange.pH),
                           field: .ph)
                readingRow(label: "Alkalinity",
                           unit: "ppm",
                           text: $taText,
                           parsedValue: taValue,
                           target: Formulas.TargetRange.totalAlkalinity,
                           practical: Formulas.PracticalRange.totalAlkalinity,
                           rangeText: DisplayFormat.rangeInteger(Formulas.TargetRange.totalAlkalinity),
                           field: .ta)
                readingRow(label: "Calcium",
                           unit: "ppm",
                           text: $chText,
                           parsedValue: chValue,
                           target: Formulas.TargetRange.calciumHardness,
                           practical: Formulas.PracticalRange.calciumHardness,
                           rangeText: DisplayFormat.rangeInteger(Formulas.TargetRange.calciumHardness),
                           field: .ch)
            } header: {
                Text("Your readings")
                    .textCase(.none)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            resultsSection
        }
        .headerProminence(.increased)
        .navigationTitle("Test & Adjust")
        .navigationBarTitleDisplayMode(.large)
        .onTapGesture { focusedField = nil }
    }

    private var sanitizerLabel: String {
        switch config.sanitizer {
        case .chlorine: return "Free Chlorine"
        case .bromine: return "Bromine"
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if !hasAnyReading {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "eyedropper.halffull")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Enter at least one reading above to see adjustments.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        } else {
            if !advisories.isEmpty {
                Section {
                    ForEach(advisories) { advisory in
                        AdvisoryRow(advisory: advisory)
                    }
                } header: {
                    Text("Heads up")
                        .textCase(.none)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
            }

            if recommendations.isEmpty && advisories.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("Looking good.")
                            .font(.headline)
                        Text("Nothing to add right now.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            } else if !recommendations.isEmpty {
                Section {
                    ForEach(recommendations) { rec in
                        RecommendationRow(rec: rec, metric: config.useMetric)
                    }
                } header: {
                    Text("Chemicals to add")
                        .textCase(.none)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                } footer: {
                    Text("Add in the order shown. Wait at least 4 hours between major adjustments and re-test.")
                        .font(.footnote)
                }
            }
        }
    }

    @ViewBuilder
    private func readingRow(label: String,
                            unit: String?,
                            text: Binding<String>,
                            parsedValue: Double?,
                            target: ClosedRange<Double>,
                            practical: ClosedRange<Double>,
                            rangeText: String,
                            field: Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor(for: parsedValue, target: target, practical: practical))
                    .frame(width: 10, height: 10)
                Text(label)
                Spacer()
                NumericTextField(text: text)
                    .focused($focusedField, equals: field)
                    .frame(width: 70)
                if let unit {
                    Text(unit)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .frame(width: 40, alignment: .leading)
                } else {
                    Spacer().frame(width: 40)
                }
            }
            HStack(spacing: 4) {
                Text("Target")
                Text(rangeText).monospacedDigit()
                if let unit { Text(unit) }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.leading, 20)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = field }
    }

    private func statusColor(for value: Double?,
                             target: ClosedRange<Double>,
                             practical: ClosedRange<Double>) -> Color {
        guard let v = value else { return Color.gray.opacity(0.25) }
        if !practical.contains(v) { return .red }
        if target.contains(v) { return .green }
        return .orange
    }

    private func computeRecommendations() -> [Recommendation] {
        var out: [Recommendation] = []

        if let v = taValue, Formulas.PracticalRange.totalAlkalinity.contains(v) {
            if v < Formulas.TargetRange.totalAlkalinity.lowerBound {
                let target = Formulas.TargetRange.totalAlkalinity.lowerBound + 10
                let dose = Formulas.alkalinityRaiseDose(currentTA: v,
                                                       targetTA: target,
                                                       gallons: config.gallons)
                if !dose.isNegligible {
                    out.append(.init(
                        title: "Raises Alkalinity to \(Int(target)) ppm",
                        product: "Sodium bicarbonate (baking soda)",
                        dose: dose,
                        detail: nil))
                }
            } else if v > Formulas.TargetRange.totalAlkalinity.upperBound {
                let target = Formulas.TargetRange.totalAlkalinity.upperBound - 10
                let dose = Formulas.alkalinityLowerDose(currentTA: v,
                                                       targetTA: target,
                                                       gallons: config.gallons)
                if !dose.isNegligible {
                    out.append(.init(
                        title: "Lowers Alkalinity to \(Int(target)) ppm",
                        product: "Muriatic acid (31.45%)",
                        dose: dose,
                        detail: "Aerate the water for several hours after adding."))
                }
            }
        }

        if let v = phValue, Formulas.PracticalRange.pH.contains(v) {
            if v < Formulas.TargetRange.pHIdeal.lowerBound {
                let dose = Formulas.pHRaiseDose(currentPH: v, targetPH: 7.5,
                                               gallons: config.gallons)
                if !dose.isNegligible {
                    out.append(.init(
                        title: "Raises pH to 7.5",
                        product: PHRaiser.sodaAsh.displayName,
                        dose: dose,
                        detail: nil))
                }
            } else if v > Formulas.TargetRange.pHIdeal.upperBound {
                let dose = Formulas.pHLowerDose(currentPH: v, targetPH: 7.5,
                                               gallons: config.gallons,
                                               product: config.preferredPHLowerer)
                if !dose.isNegligible {
                    out.append(.init(
                        title: "Lowers pH to 7.5",
                        product: config.preferredPHLowerer.displayName,
                        dose: dose,
                        detail: nil))
                }
            }
        }

        if let v = chValue,
           Formulas.PracticalRange.calciumHardness.contains(v),
           v < Formulas.TargetRange.calciumHardness.lowerBound {
            let target = Formulas.TargetRange.calciumHardness.lowerBound + 25
            let dose = Formulas.calciumRaiseDose(currentCH: v, targetCH: target,
                                                gallons: config.gallons)
            if !dose.isNegligible {
                out.append(.init(
                    title: "Raises Calcium to \(Int(target)) ppm",
                    product: "Calcium chloride",
                    dose: dose,
                    detail: nil))
            }
        }

        if let v = sanitizerValue,
           config.sanitizer.practicalRange.contains(v),
           v < config.sanitizer.targetRange.lowerBound {
            let mid = (config.sanitizer.targetRange.lowerBound
                       + config.sanitizer.targetRange.upperBound) / 2
            let dose: Dose
            let product: String
            switch config.sanitizer {
            case .chlorine:
                dose = Formulas.chlorineDose(currentFC: v, targetFC: mid,
                                             gallons: config.gallons,
                                             product: config.preferredChlorineProduct)
                product = config.preferredChlorineProduct.displayName
            case .bromine:
                dose = Formulas.bromineDose(currentBr: v, targetBr: mid,
                                            gallons: config.gallons)
                product = "Sodium bromide"
            }
            if !dose.isNegligible {
                out.append(.init(
                    title: "Raises \(config.sanitizer.displayName) to \(DisplayFormat.oneDecimal(mid)) ppm",
                    product: product,
                    dose: dose,
                    detail: nil))
            }
        }

        return out
    }

    private func computeAdvisories() -> [Advisory] {
        var out: [Advisory] = []

        var outOfRange: [String] = []
        if let v = sanitizerValue, !config.sanitizer.practicalRange.contains(v) {
            outOfRange.append(sanitizerLabel)
        }
        if let v = phValue, !Formulas.PracticalRange.pH.contains(v) {
            outOfRange.append("pH")
        }
        if let v = taValue, !Formulas.PracticalRange.totalAlkalinity.contains(v) {
            outOfRange.append("Alkalinity")
        }
        if let v = chValue, !Formulas.PracticalRange.calciumHardness.contains(v) {
            outOfRange.append("Calcium")
        }

        if !outOfRange.isEmpty {
            let names = outOfRange.joined(separator: ", ")
            let isPlural = outOfRange.count > 1
            out.append(.init(
                title: "Re-test \(names)",
                body: "\(isPlural ? "They're" : "It's") outside the usual range — worth checking your test kit.",
                kind: .warning))
        }

        if let v = sanitizerValue,
           config.sanitizer.practicalRange.contains(v),
           v > config.sanitizer.targetRange.upperBound {
            out.append(.init(
                title: "\(config.sanitizer.displayName) is high",
                body: "Don't add more sanitizer. Let it dissipate — re-test in a few hours.",
                kind: .warning))
        }

        return out
    }
}

struct AdvisoryRow: View {
    let advisory: Advisory

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(advisory.title)
                    .font(.headline)
                Text(advisory.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }

    private var iconName: String {
        switch advisory.kind {
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .shock: return "bolt.fill"
        }
    }

    private var iconColor: Color {
        switch advisory.kind {
        case .warning: return .orange
        case .info: return .blue
        case .shock: return .pink
        }
    }
}

struct RecommendationRow: View {
    let rec: Recommendation
    let metric: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rec.product)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(rec.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(rec.dose.formattedAmount(metric: metric))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                    Text(rec.dose.unitLabel(metric: metric))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.accentColor.opacity(0.5))
                }
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            }
            if let detail = rec.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview("Bromine — empty") {
    NavigationStack { TestAdjustView() }
        .environmentObject({
            let c = HotTubConfig()
            c.gallons = 400
            c.sanitizer = .bromine
            c.hasCompletedOnboarding = true
            return c
        }())
}
