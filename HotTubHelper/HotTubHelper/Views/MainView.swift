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
            }
            .headerProminence(.increased)
            .contentMargins(.top, 24, for: .scrollContent)
            .navigationTitle("Hot Tub Helper")
            .settingsToolbar()
        }
    }
}

private struct ActionRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 38, height: 38)
                .foregroundStyle(tint)
                .background(tint.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
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
