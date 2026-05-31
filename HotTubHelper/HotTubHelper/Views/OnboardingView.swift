import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var config: HotTubConfig
    @State private var step: Int? = 1
    @State private var isVolumeValid: Bool = true

    private let totalSteps = 3
    private var currentStep: Int { step ?? 1 }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 16) {
                topBar
                progressBar
                cardScroller
                VStack(spacing: 12) {
                    if currentStep == 1 {
                        Text("You can change all answers later in Settings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    primaryButton
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
    }

    private var topBar: some View {
        ZStack {
            HStack {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .opacity(currentStep > 1 ? 1 : 0)
                .disabled(currentStep <= 1)
                .accessibilityHidden(currentStep <= 1)
                .accessibilityLabel("Back")
                Spacer()
            }
            Text("Step \(currentStep) of \(totalSteps)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(Color.primary)
                    .frame(width: max(0, geo.size.width * CGFloat(currentStep) / CGFloat(totalSteps)))
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 24)
    }

    private var cardScroller: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                stepCard(1,
                         icon: "drop.fill",
                         title: "What's the volume of your hot tub?",
                         subtitle: "We use this to size your doses.") {
                    VolumeStep(isValid: $isVolumeValid)
                }
                stepCard(2,
                         icon: "sparkles",
                         title: "What sanitizer does your tub use?",
                         subtitle: "Sets the target range we'll aim for.") {
                    SanitizerStep()
                }
                stepCard(3,
                         icon: "testtube.2",
                         title: "Which chemicals do you use?",
                         subtitle: "So doses match the products you have.") {
                    ChemicalsStep()
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollDisabled(true)
        .scrollPosition(id: $step, anchor: .leading)
    }

    private func stepCard<Content: View>(_ id: Int,
                                         icon: String,
                                         title: String,
                                         subtitle: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            iconBadge(icon)
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
                .padding(.top, 56)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerRelativeFrame(.horizontal)
        .id(id)
    }

    private func iconBadge(_ name: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
            Image(systemName: name)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 56, height: 56)
    }

    private var primaryButton: some View {
        Button(action: goNext) {
            Text(currentStep == totalSteps ? "Get started" : "Next")
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(currentStep == 1 && !isVolumeValid)
    }

    private func goNext() {
        dismissKeyboard()
        if currentStep < totalSteps {
            withAnimation(.easeInOut(duration: 0.35)) {
                step = currentStep + 1
            }
        } else {
            config.hasCompletedOnboarding = true
        }
    }

    private func goBack() {
        guard currentStep > 1 else { return }
        dismissKeyboard()
        withAnimation(.easeInOut(duration: 0.35)) {
            step = currentStep - 1
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

private struct VolumeStep: View {
    @Binding var isValid: Bool
    @EnvironmentObject var config: HotTubConfig
    @State private var volumeText: String = ""
    @State private var suppressNextSave: Bool = false
    @State private var hasEdited: Bool = false
    @FocusState private var volumeFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                NumericTextField(text: $volumeText, allowDecimal: false)
                    .focused($volumeFocused)
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                    .onAppear { syncVolumeText() }
                    .onChange(of: volumeText) { _, newValue in
                        if suppressNextSave {
                            suppressNextSave = false
                            return
                        }
                        hasEdited = true
                        if let g = VolumeUnit.parseGallons(newValue, metric: config.useMetric),
                           VolumeUnit.isValidGallons(g) {
                            config.gallons = g
                            isValid = true
                        } else {
                            isValid = false
                        }
                    }
                    .onChange(of: config.useMetric) { _, _ in
                        if !volumeFocused { syncVolumeText() }
                    }

                Button(action: toggleUnit) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(config.useMetric ? "liters" : "gallons")
                            .font(.title2.weight(.medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change units")
            }
            .frame(maxWidth: .infinity)
            .sensoryFeedback(.selection, trigger: config.useMetric)

            Text(helpText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var helpText: String {
        config.useMetric
            ? "Typical home tubs hold 950–1900 liters. Check your manual or the cabinet label."
            : "Typical home tubs hold 250–500 gallons. Check your manual or the cabinet label."
    }

    private func syncVolumeText() {
        let newText = VolumeUnit.displayValue(gallons: config.gallons, metric: config.useMetric)
        if newText != volumeText {
            suppressNextSave = true
            volumeText = newText
        }
    }

    private func toggleUnit() {
        let newMetric = !config.useMetric
        if !hasEdited {
            config.gallons = VolumeUnit.niceDefaultGallons(metric: newMetric)
        }
        config.useMetric = newMetric
    }
}

private struct SanitizerStep: View {
    @EnvironmentObject var config: HotTubConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Sanitizer", selection: $config.sanitizer) {
                ForEach(Sanitizer.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.large)

            Text(helpText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var helpText: String {
        switch config.sanitizer {
        case .bromine: return "Most hot tubs use bromine. Target 2–4 ppm."
        case .chlorine: return "Chlorine target is 1–3 ppm."
        }
    }
}

private struct ChemicalsStep: View {
    @EnvironmentObject var config: HotTubConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 0) {
                if config.sanitizer == .chlorine {
                    pickerRow(label: "Chlorine product") {
                        Picker("", selection: $config.preferredChlorineProduct) {
                            ForEach(ChlorineProduct.allCases) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(.primary)
                    }
                    Divider().padding(.leading, 16)
                }
                pickerRow(label: "pH lowerer") {
                    Picker("", selection: $config.preferredPHLowerer) {
                        ForEach(PHLowerer.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("Pick what's on your shelf — we'll size doses to match.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func pickerRow<Content: View>(label: String,
                                          @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
            Spacer()
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(HotTubConfig())
}
