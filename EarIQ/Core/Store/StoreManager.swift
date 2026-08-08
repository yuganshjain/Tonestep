import StoreKit
import Foundation
import Combine

enum EarIQProduct: String, CaseIterable {
    case monthly  = "com.yugansh.EarIQ.pro.monthly"
    case annual   = "com.yugansh.EarIQ.pro.annual"
    case lifetime = "com.yugansh.EarIQ.pro.lifetime"

    var displayName: String {
        switch self {
        case .monthly:  return "Monthly"
        case .annual:   return "Annual"
        case .lifetime: return "Lifetime"
        }
    }

    var badge: String? {
        switch self {
        case .annual: return "Save 48%"
        default: return nil
        }
    }
}

@MainActor
final class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var isPro: Bool = false
    @Published var isLoading = false

    private var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await refreshPurchaseStatus() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        do {
            products = try await Product.products(for: EarIQProduct.allCases.map(\.rawValue))
                .sorted { $0.price < $1.price }
        } catch {
            print("StoreKit product load error: \(error)")
        }
        isLoading = false
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshPurchaseStatus()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshPurchaseStatus()
        } catch {
            print("Restore error: \(error)")
        }
    }

    private func refreshPurchaseStatus() async {
        var hasPro = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if EarIQProduct(rawValue: transaction.productID) != nil {
                    hasPro = true
                }
            }
        }
        isPro = hasPro
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.refreshPurchaseStatus()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let value): return value
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
