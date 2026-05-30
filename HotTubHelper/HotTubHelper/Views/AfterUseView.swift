import SwiftUI

struct AfterUseView: View {
    @EnvironmentObject var config: HotTubConfig

    @State private var people: Int = 2
    @State private var hours: Double = 1.0

    var dose: Dose {
        Formulas.afterUseDose(
            people: people,
            hours: hours,
            sanitizer: config.sanitizer,
            gallons: config.gallons,
            chlorineProduct: config.preferredChlorineProduct
        )
    }

    var product: String {
        switch config.sanitizer {
        case .chlorine: return config.preferredChlorineProduct.displayName
        case .bromine: return "Sodium bromide"
        }
    }

    var personHours: Double { Double(people) * hours }

    var body: some View {
        Form {
            Section {
                Stepper(value: $people, in: 1...10) {
                    HStack {
                        Text("People")
                        Spacer()
                        Text("\(people)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Hours")
                        Spacer()
                        Text(String(format: "%.1f", hours))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $hours, in: 0.25...4.0, step: 0.25)
                }
            } header: {
                SectionHeaderLabel("How did you use the tub?")
            }

            Section {
                DoseHero(product: product,
                         dose: dose,
                         metric: config.useMetric)
            } header: {
                SectionHeaderLabel("Chemicals to add")
            } footer: {
                Text("Run the jets while adding. Re-test sanitizer level after 30–60 minutes.")
                    .font(.footnote)
            }

            if personHours >= 5 {
                Section {
                    AdvisoryRow(advisory: Advisory(
                        title: "Heavy use",
                        body: "Consider a shock cycle if you haven't run one in the last few days.",
                        kind: .shock))
                }
            }
        }
        .headerProminence(.increased)
        .navigationTitle("After-Use Dose")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack { AfterUseView() }
        .environmentObject({
            let c = HotTubConfig()
            c.gallons = 400
            return c
        }())
}
