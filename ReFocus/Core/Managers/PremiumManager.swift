import Foundation
import StoreKit

/// Manages premium subscription and strict mode feature
@MainActor
final class PremiumManager: ObservableObject {
    static let shared = PremiumManager()

    // MARK: - Product IDs

    static let strictModeProductId = "com.refocus.premium.strictmode"
    static let monthlyProductId = "com.refocus.premium.monthly"
    static let yearlyProductId = "com.refocus.premium.yearly"

    // Consumable product for emergency exit (strict mode escape hatch)
    static let emergencyExitProductId = "com.refocus.emergency.exit"  // $1.99

    // Legacy aliases
    static let overrideSingleProductId = emergencyExitProductId
    static let overridePack5ProductId = "com.refocus.override.pack5"  // Deprecated

    // MARK: - Published State

    @Published private(set) var isPremium: Bool = false
    @Published private(set) var isStrictModeEnabled: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var overrideProducts: [Product] = []
    @Published private(set) var purchaseError: String?
    @Published private(set) var isLoading: Bool = false

    // MARK: - Private

    private var transactionListener: Task<Void, Never>?
    private static let strictModeKey = "strictModeEnabled"

    private init() {
        // Load local strict mode preference
        isStrictModeEnabled = UserDefaults.standard.bool(forKey: Self.strictModeKey)

        // Start listening for transactions
        transactionListener = listenForTransactions()

        // Load products and check entitlements
        Task {
            await loadProducts()
            await checkPremiumStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Products

    func loadProducts() async {
        isLoading = true

        do {
            // Load subscription products
            let subscriptionIds = [
                Self.strictModeProductId,
                Self.monthlyProductId,
                Self.yearlyProductId
            ]

            products = try await Product.products(for: subscriptionIds)
            products.sort { $0.price < $1.price }

            // Load override consumable products
            let overrideIds = [
                Self.overrideSingleProductId,
                Self.overridePack5ProductId
            ]

            overrideProducts = try await Product.products(for: overrideIds)
            overrideProducts.sort { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }

        isLoading = false
    }

    /// Get the emergency exit product ($1.99)
    var emergencyExitProduct: Product? {
        overrideProducts.first { $0.id == Self.emergencyExitProductId }
    }

    /// Legacy alias
    var singleOverrideProduct: Product? { emergencyExitProduct }

    /// Purchase emergency exit for strict mode session
    func purchaseEmergencyExit() async -> Bool {
        guard let product = emergencyExitProduct else {
            purchaseError = "Emergency exit not available"
            return false
        }

        return await purchase(product)
    }

    /// Legacy alias
    func purchaseOverride() async -> Bool {
        await purchaseEmergencyExit()
    }

    // MARK: - Purchases

    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await checkPremiumStatus()
                isLoading = false
                return true

            case .userCancelled:
                isLoading = false
                return false

            case .pending:
                purchaseError = "Purchase is pending approval"
                isLoading = false
                return false

            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func restorePurchases() async {
        isLoading = true

        do {
            try await AppStore.sync()
            await checkPremiumStatus()
        } catch {
            purchaseError = "Failed to restore purchases: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Entitlements

    func checkPremiumStatus() async {
        var hasPremium = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.strictModeProductId ||
                   transaction.productID == Self.monthlyProductId ||
                   transaction.productID == Self.yearlyProductId {
                    hasPremium = true
                    break
                }
            }
        }

        isPremium = hasPremium

        // If not premium, disable strict mode
        if !isPremium && isStrictModeEnabled {
            isStrictModeEnabled = false
            UserDefaults.standard.set(false, forKey: Self.strictModeKey)
        }
    }

    // MARK: - Strict Mode

    func toggleStrictMode() {
        guard isPremium else { return }

        isStrictModeEnabled.toggle()
        UserDefaults.standard.set(isStrictModeEnabled, forKey: Self.strictModeKey)
    }

    func setStrictMode(_ enabled: Bool) {
        guard isPremium || !enabled else { return }

        isStrictModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.strictModeKey)
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.checkPremiumStatus()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Errors

enum StoreError: LocalizedError {
    case verificationFailed
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Transaction verification failed"
        case .purchaseFailed:
            return "Purchase failed"
        }
    }
}
