import SwiftUI

struct MainView: View {
    @EnvironmentObject var config: HotTubConfig
    @EnvironmentObject var entitlement: Entitlement
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                if !entitlement.isPro {
                    Section {
                        Button { showPaywall = true } label: { trialBannerRow }
                            .buttonStyle(.plain)
                    }
                }
                Section {
                    gatedLink(symbol: "eyedropper.halffull", tint: .blue,
                              title: String(localized: "Test & Adjust"),
                              subtitle: String(localized: "Enter test readings, get exact doses")) {
                        TestAdjustView()
                    }
                    gatedLink(symbol: "person.2.fill", tint: .orange,
                              title: String(localized: "After-Use Dose"),
                              subtitle: String(localized: "Top up sanitizer after each use")) {
                        AfterUseView()
                    }
                    gatedLink(symbol: "bolt.fill", tint: .pink,
                              title: String(localized: "Shock"),
                              subtitle: String(localized: "Once-a-week treatment")) {
                        ShockView()
                    }
                }
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        ActionRow(symbol: "gearshape.fill",
                                  tint: .gray,
                                  title: String(localized: "Settings"),
                                  subtitle: String(localized: "Volume, sanitizer, products"))
                    }
                }
            }
            .headerProminence(.increased)
            .contentMargins(.top, 24, for: .scrollContent)
            .navigationTitle("Hot Tub Assistant")
            .sheet(isPresented: $showPaywall) { PaywallSheet() }
        }
    }

    @ViewBuilder
    private var trialBannerRow: some View {
        if entitlement.requiresPurchase {
            ActionRow(symbol: "lock.fill", tint: .accentColor,
                      title: String(localized: "Free trial ended"),
                      subtitle: String(localized: "Unlock Soak to keep dosing — one-time purchase."))
        } else {
            ActionRow(symbol: "clock.fill", tint: .accentColor,
                      title: String(localized: "Free trial — \(entitlement.trial.remainingShortLabel) left"),
                      subtitle: String(localized: "Everything’s unlocked. Tap to unlock for good."))
        }
    }

    @ViewBuilder
    private func gatedLink<Destination: View>(
        symbol: String, tint: Color, title: String, subtitle: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        if entitlement.requiresPurchase {
            Button { showPaywall = true } label: {
                ActionRow(symbol: symbol, tint: tint, title: title, subtitle: subtitle)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                destination()
            } label: {
                ActionRow(symbol: symbol, tint: tint, title: title, subtitle: subtitle)
            }
        }
    }
}

private struct ActionRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 48, height: 48)
                .foregroundStyle(tint)
                .background(tint.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    MainView()
        .environmentObject({
            let c = HotTubConfig()
            c.hasCompletedOnboarding = true
            return c
        }())
}
