import SwiftUI

struct ShockView: View {
    @EnvironmentObject var config: HotTubConfig

    var dose: Dose {
        Formulas.shockDose(sanitizer: config.sanitizer, gallons: config.gallons)
    }

    var product: String {
        switch config.sanitizer {
        case .chlorine: return String(localized: "Cal-hypo 68%")
        case .bromine: return String(localized: "Non-chlorine shock (MPS)")
        }
    }

    var body: some View {
        Form {
            Section {
                DoseHero(product: product,
                         dose: dose,
                         metric: config.useMetric)
            } header: {
                SectionHeaderLabel(String(localized: "Chemicals to add"))
            } footer: {
                Text("Once a week, or after heavy use.")
                    .font(.footnote)
            }

            Section {
                StepRow(number: 1, text: String(localized: "Remove the cover and run the jets."))
                StepRow(number: 2, text: String(localized: "Add the shock with the jets running for at least 15 minutes."))
                StepRow(number: 3, text: String(localized: "Leave the cover off for 20–30 minutes before closing."))
                StepRow(
                    number: 4,
                    text: config.sanitizer == .chlorine
                        ? String(localized: "Wait until free chlorine drops below 5 ppm before using the tub.")
                        : String(localized: "Wait at least 15 minutes before using the tub.")
                )
            } header: {
                SectionHeaderLabel(String(localized: "How to"))
            } footer: {
                Text("Shock breaks down body oils and bound sanitizer. The water may look cloudy briefly.")
                    .font(.footnote)
            }
        }
        .headerProminence(.increased)
        .navigationTitle("Shock")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct StepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 6 }
            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack { ShockView() }
        .environmentObject({
            let c = HotTubConfig()
            c.gallons = 400
            return c
        }())
}
