import SwiftUI

struct MainView: View {
    @EnvironmentObject var config: HotTubConfig

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        TestAdjustView()
                    } label: {
                        ActionRow(symbol: "eyedropper.halffull",
                                  tint: .blue,
                                  title: String(localized: "Test & Adjust"),
                                  subtitle: String(localized: "Enter test readings, get exact doses"))
                    }
                    NavigationLink {
                        AfterUseView()
                    } label: {
                        ActionRow(symbol: "person.2.fill",
                                  tint: .orange,
                                  title: String(localized: "After-Use Dose"),
                                  subtitle: String(localized: "Top up sanitizer after each use"))
                    }
                    NavigationLink {
                        ShockView()
                    } label: {
                        ActionRow(symbol: "bolt.fill",
                                  tint: .pink,
                                  title: String(localized: "Shock"),
                                  subtitle: String(localized: "Once-a-week treatment"))
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
