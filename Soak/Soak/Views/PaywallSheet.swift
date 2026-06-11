import SwiftUI

struct PaywallSheet: View {
    @EnvironmentObject var purchases: PurchaseStore
    @EnvironmentObject var entitlement: Entitlement
    @Environment(\.dismiss) private var dismiss

    private var trialEndedNote: String? {
        guard entitlement.requiresPurchase,
              let expiry = entitlement.trial.expiryDate else { return nil }
        let formatted = expiry.formatted(date: .abbreviated, time: .omitted)
        return String(localized: "Your free trial ended on \(formatted).")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "lock.open.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .foregroundStyle(.tint)
                        .padding(.top, 32)

                    VStack(spacing: 8) {
                        Text(String(localized: "Unlock Soak"))
                            .font(.largeTitle.bold())
                        Text(String(localized: "Keep your hot tub balanced — one-time purchase, no subscription."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if let trialEndedNote {
                            Text(trialEndedNote)
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 12) {
                        featureRow(String(localized: "Exact dosing for chlorine and bromine tubs"))
                        featureRow(String(localized: "After-use top-up doses sized to your soak"))
                        featureRow(String(localized: "Weekly shock treatment amounts"))
                        featureRow(String(localized: "Plain-English \u{201C}re-test\u{201D} and \u{201C}don’t add more\u{201D} warnings"))
                        featureRow(String(localized: "No ads, no subscription, fully offline"))
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        if entitlement.isPro {
                            Label(String(localized: "Already unlocked"), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .padding()
                        } else if let price = purchases.priceText {
                            Button {
                                Task {
                                    let result = await purchases.purchase()
                                    if case .success = result {
                                        dismiss()
                                    }
                                }
                            } label: {
                                Text(String(localized: "Unlock for \(price)"))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(purchases.isPurchasing)

                            Button(String(localized: "Restore Purchases")) {
                                Task { await purchases.restore() }
                            }
                            .font(.subheadline)
                        } else {
                            ProgressView()
                                .padding()
                        }

                        Text(String(localized: "One-time purchase. No subscription. Family Sharing not enabled."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func featureRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.tint)
                .font(.subheadline)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}
