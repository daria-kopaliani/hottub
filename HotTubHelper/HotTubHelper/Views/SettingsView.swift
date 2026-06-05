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
                Picker("Units", selection: $config.useMetric) {
                    Text("Metric").tag(true)
                    Text("Imperial").tag(false)
                }
            }

            Section {
                HStack {
                    Text("Volume")
                    Spacer()
                    NumericTextField(text: $volumeText, allowDecimal: false)
                        .focused($volumeFocused)
                        .foregroundStyle(volumeFocused ? Color.primary : Color.accentColor)
                        .multilineTextAlignment(.trailing)
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
                    Text(LocalizedStringKey(config.useMetric ? "liters" : "gallons"))
                        .foregroundStyle(.secondary)
                }
                Picker("Sanitizer", selection: $config.sanitizer) {
                    ForEach(Sanitizer.allCases) { Text($0.displayName).tag($0) }
                }
            } header: {
                SectionHeaderLabel(String(localized: "Your hot tub"))
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
                SectionHeaderLabel(String(localized: "Preferred chemicals"))
            }

            Section {
                LinkRow(title: String(localized: "Privacy policy"),
                        url: URL(string: "https://daria-kopaliani.github.io/moondog/hottub/privacy.html")!)
                LinkRow(title: String(localized: "Support"),
                        url: URL(string: "https://daria-kopaliani.github.io/moondog/hottub/support.html")!)
            } footer: {
                Text("v\(appVersion)")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.footnote)
                    .padding(.top, 8)
            }
        }
        .headerProminence(.increased)
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }

    private func syncVolumeText() {
        let newText = VolumeUnit.displayValue(gallons: config.gallons, metric: config.useMetric)
        if newText != volumeText {
            suppressNextSave = true
            volumeText = newText
        }
    }
}

private struct LinkRow: View {
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
