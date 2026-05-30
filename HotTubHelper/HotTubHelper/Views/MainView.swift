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
                        ActionRow(symbol: "drop.triangle.fill",
                                  tint: .blue,
                                  title: "Test & Adjust",
                                  subtitle: "Enter test readings, get exact doses")
                    }
                    NavigationLink {
                        AfterUseView()
                    } label: {
                        ActionRow(symbol: "person.2.fill",
                                  tint: .teal,
                                  title: "After-Use Dose",
                                  subtitle: "Sanitizer to add after a soak")
                    }
                    NavigationLink {
                        ShockView()
                    } label: {
                        ActionRow(symbol: "bolt.fill",
                                  tint: .orange,
                                  title: "Shock",
                                  subtitle: "Weekly shock dose")
                    }
                }
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        ActionRow(symbol: "gearshape.fill",
                                  tint: .gray,
                                  title: "Settings",
                                  subtitle: "Volume, sanitizer, products")
                    }
                }
            }
            .headerProminence(.increased)
            .contentMargins(.top, 24, for: .scrollContent)
            .navigationTitle("Hot Tub Helper")
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
