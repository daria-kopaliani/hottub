import Foundation
import Combine
import SwiftUI

/// Single source of truth for "can the user use the app's features." Folds the
/// 48-hour full-unlock trial together with the StoreKit purchase status so
/// views don't have to reason about both.
///
///     @EnvironmentObject private var entitlement: Entitlement
///     if entitlement.requiresPurchase { showPaywall() }
@MainActor
final class Entitlement: ObservableObject {
    let purchases: PurchaseStore
    let trial: TrialState

    private var cancellables: Set<AnyCancellable> = []

    init(purchases: PurchaseStore, trial: TrialState) {
        self.purchases = purchases
        self.trial = trial

        purchases.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        trial.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// True if the user can use every feature right now — either because they
    /// paid (StoreKit) or because the 48-hour trial is active.
    var isUnlocked: Bool { purchases.isPro || trial.isActive }

    /// True only when the trial has expired and the user has not paid.
    /// Gates the paywall on the calculator surface.
    var requiresPurchase: Bool {
        !purchases.isPro && trial.isExpired
    }

    /// True only when the user is paid for life.
    var isPro: Bool { purchases.isPro }
}
