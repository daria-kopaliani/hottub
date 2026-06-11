import Foundation
import Combine
import StoreKit

@MainActor
final class PurchaseStore: ObservableObject {
    static let proProductID = "com.kopaliani.HotTubHelper.pro"

    @Published private(set) var product: Product?
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var isPurchasing: Bool = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        if CommandLine.arguments.contains("-UITestForcePro") {
            isPro = true
        }
    }

    func start() async {
        await refreshProducts()
        await refreshEntitlement()
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    guard let self else { return }
                    if case .verified(let tx) = update {
                        await tx.finish()
                        await self.refreshEntitlement()
                    }
                }
            }
        }
    }

    func refreshProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: [PurchaseStore.proProductID])
            self.product = products.first
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    func refreshEntitlement() async {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let tx) = entitlement,
               tx.productID == PurchaseStore.proProductID {
                self.isPro = true
                return
            }
        }
        if !CommandLine.arguments.contains("-UITestForcePro") {
            self.isPro = false
        }
    }

    enum PurchaseResultLite {
        case success
        case userCancelled
        case pending
        case failed(String)
    }

    func purchase() async -> PurchaseResultLite {
        guard let product else { return .failed("Product not loaded yet.") }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    await refreshEntitlement()
                    return .success
                }
                return .failed("Could not verify the receipt.")
            case .userCancelled:
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Unknown purchase state.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    var priceText: String? {
        for arg in CommandLine.arguments where arg.hasPrefix("-UITestPriceOverride=") {
            return String(arg.dropFirst("-UITestPriceOverride=".count))
        }
        return product?.displayPrice
    }
}
