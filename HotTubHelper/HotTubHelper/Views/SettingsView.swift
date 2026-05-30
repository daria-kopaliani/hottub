import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var config: HotTubConfig
    @State private var volumeText: String = ""
    @State private var suppressNextSave: Bool = false
    @FocusState private var volumeFocused: Bool

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Volume")
                    Spacer()
                    NumericTextField(text: $volumeText, allowDecimal: false)
                        .focused($volumeFocused)
                        .foregroundStyle(volumeFocused ? Color.primary : Color.accentColor)
                        .frame(width: 80)
                        .onAppear { syncVolumeText() }
                        .onChange(of: volumeText) { _, newValue in
                            if suppressNextSave {
                                suppressNextSave = false
                                return
                            }
                            if let gallons = VolumeUnit.parseGallons(newValue, metric: config.useMetric),
                               VolumeUnit.isValidGallons(gallons) {
                                config.gallons = gallons
                            }
                        }
                        .onChange(of: config.useMetric) { _, _ in
                            if !volumeFocused { syncVolumeText() }
                        }
                    Text(VolumeUnit.unitLabel(metric: config.useMetric))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .leading)
                }
                Picker("Sanitizer", selection: $config.sanitizer) {
                    ForEach(Sanitizer.allCases) { Text($0.displayName).tag($0) }
                }
            } header: {
                SectionHeaderLabel("Hot tub")
            }

            Section {
                if config.sanitizer == .chlorine {
                    Picker("Chlorine product", selection: $config.preferredChlorineProduct) {
                        ForEach(ChlorineProduct.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                Picker("pH lowerer", selection: $config.preferredPHLowerer) {
                    ForEach(PHLowerer.allCases) { Text($0.displayName).tag($0) }
                }
            } header: {
                SectionHeaderLabel("Preferred chemicals")
            }

            Section {
                Picker("Units", selection: $config.useMetric) {
                    Text("Metric").tag(true)
                    Text("Imperial").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } header: {
                SectionHeaderLabel("Units")
            } footer: {
                Text("Metric: grams, milliliters, liters. Imperial: ounces, fluid ounces, gallons.")
                    .font(.footnote)
            }

            Section {
                LabeledContent("Version", value: appVersion)
                ExternalLinkRow(
                    title: "Privacy policy",
                    url: URL(string: "https://daria-kopaliani.github.io/moondog/hottub/privacy.html")!)
                ExternalLinkRow(
                    title: "Support",
                    url: URL(string: "https://daria-kopaliani.github.io/moondog/hottub/support.html")!)
            } header: {
                SectionHeaderLabel("About")
            }
        }
        .headerProminence(.increased)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func syncVolumeText() {
        let newText = VolumeUnit.displayValue(gallons: config.gallons, metric: config.useMetric)
        if newText != volumeText {
            suppressNextSave = true
            volumeText = newText
        }
    }
}

private struct ExternalLinkRow: View {
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environmentObject(HotTubConfig())
}
