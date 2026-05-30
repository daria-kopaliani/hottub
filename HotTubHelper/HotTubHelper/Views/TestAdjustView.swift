import SwiftUI

struct TestAdjustView: View {
    @EnvironmentObject var config: HotTubConfig

    @State private var sanitizerText: String = ""
    @State private var phText: String = ""
    @State private var taText: String = ""
    @State private var chText: String = ""

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

    var body: some View {
        Form {
            Section {
                readingRow(label: sanitizerLabel,
                           unit: "ppm",
                           text: $sanitizerText,
                           parsedValue: sanitizerValue,
                           target: config.sanitizer.targetRange,
                           rangeText: DisplayFormat.rangeOneDecimal(config.sanitizer.targetRange))
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
                           rangeText: DisplayFormat.rangeOneDecimal(Formulas.TargetRange.pH))
                readingRow(label: "Alkalinity",
                           unit: "ppm",
                           text: $taText,
                           parsedValue: taValue,
                           target: Formulas.TargetRange.totalAlkalinity,
                           rangeText: DisplayFormat.rangeInteger(Formulas.TargetRange.totalAlkalinity))
                readingRow(label: "Calcium",
                           unit: "ppm",
                           text: $chText,
                           parsedValue: chValue,
                           target: Formulas.TargetRange.calciumHardness,
                           rangeText: DisplayFormat.rangeInteger(Formulas.TargetRange.calciumHardness))
            } header: {
                HStack {
                    Text("Your readings")
                    Spacer()
                    SanitizerPill(sanitizer: config.sanitizer)
                }
                .textCase(.none)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            }

            resultsSection
        }
        .headerProminence(.increased)
        .navigationTitle("Test & Adjust")
        .navigationBarTitleDisplayMode(.inline)
        .settingsToolbar()
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
                Text("Enter at least one reading above to see adjustments.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        } else if recommendations.isEmpty {
            Section {
                Label("Looking good. Nothing to add right now.",
                      systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .padding(.vertical, 4)
            }
        } else {
            Section {
                ForEach(recommendations) { rec in
                    RecommendationRow(rec: rec, metric: config.useMetric)
                }
                Text("Add in the order shown. Wait at least 4 hours between major adjustments and re-test.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Add in this order")
                    .textCase(.none)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
    }

    @ViewBuilder
    private func readingRow(label: String,
                            unit: String?,
                            text: Binding<String>,
                            parsedValue: Double?,
                            target: ClosedRange<Double>,
                            rangeText: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor(for: parsedValue, target: target))
                    .frame(width: 8, height: 8)
                Text(label)
                Spacer()
                NumericTextField(text: text)
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
            .padding(.leading, 18)
        }
        .padding(.vertical, 2)
    }

    private func statusColor(for value: Double?, target: ClosedRange<Double>) -> Color {
        guard let v = value else { return Color.gray.opacity(0.25) }
        if target.contains(v) { return .green }
        return .orange
    }

    private func computeRecommendations() -> [Recommendation] {
        var out: [Recommendation] = []

        if let v = taValue {
            if v < Formulas.TargetRange.totalAlkalinity.lowerBound {
                let target = Formulas.TargetRange.totalAlkalinity.lowerBound + 10
                let dose = Formulas.alkalinityRaiseDose(currentTA: v,
                                                       targetTA: target,
                                                       gallons: config.gallons)
                if !dose.isNegligible {
                    out.append(.init(
                        title: "Raise Alkalinity to \(Int(target)) ppm",
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
                        title: "Lower Alkalinity to \(Int(target)) ppm",
                        product: "Muriatic acid (31.45%)",
                        dose: dose,
                        detail: "Aerate the water for several hours after adding."))
                }
            }
        }

        if let v = phValue {
            if v < Formulas.TargetRange.pHIdeal.lowerBound {
                let dose = Formulas.pHRaiseDose(currentPH: v, targetPH: 7.5,
                                               gallons: config.gallons)
                if !dose.isNegligible {
                    out.append(.init(
                        title: "Raise pH to 7.5",
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
                        title: "Lower pH to 7.5",
                        product: config.preferredPHLowerer.displayName,
                        dose: dose,
                        detail: nil))
                }
            }
        }

        if let v = chValue, v < Formulas.TargetRange.calciumHardness.lowerBound {
            let target = Formulas.TargetRange.calciumHardness.lowerBound + 25
            let dose = Formulas.calciumRaiseDose(currentCH: v, targetCH: target,
                                                gallons: config.gallons)
            if !dose.isNegligible {
                out.append(.init(
                    title: "Raise Calcium to \(Int(target)) ppm",
                    product: "Calcium chloride",
                    dose: dose,
                    detail: nil))
            }
        }

        if let v = sanitizerValue, v < config.sanitizer.targetRange.lowerBound {
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
                    title: "Raise \(config.sanitizer.displayName) to \(DisplayFormat.oneDecimal(mid)) ppm",
                    product: product,
                    dose: dose,
                    detail: nil))
            }
        }

        return out
    }
}

struct RecommendationRow: View {
    let rec: Recommendation
    let metric: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(rec.title)
                .font(.subheadline.weight(.semibold))
            HStack(alignment: .firstTextBaseline) {
                Text(rec.product)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(rec.dose.formatted(metric: metric))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
            }
            .font(.subheadline)
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
