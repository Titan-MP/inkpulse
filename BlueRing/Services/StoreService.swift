import Foundation
import StoreKit

// MARK: - Product IDs (must match App Store Connect + BlueRing.storekit)

enum StoreIDs {
    static let removeAds = "com.rhymaun.bluering.removeads"
    static let skinPackKelp = "com.rhymaun.bluering.skinpack.kelp"
    static let skinPackCoral = "com.rhymaun.bluering.skinpack.coral"
    static let shellsSmall = "com.rhymaun.bluering.shells.small"   // 600 shells
    static let shellsMedium = "com.rhymaun.bluering.shells.medium" // 1,600 shells
    static let shellsLarge = "com.rhymaun.bluering.shells.large"   // 4,000 shells

    static let all: [String] = [removeAds, skinPackKelp, skinPackCoral, shellsSmall, shellsMedium, shellsLarge]

    static let shellAmounts: [String: Int] = [
        shellsSmall: 600, shellsMedium: 1600, shellsLarge: 4000,
    ]

    static let skinForProduct: [String: String] = [
        skinPackKelp: "kelp", skinPackCoral: "coral",
    ]
}

// MARK: - StoreKit 2 service

@MainActor
final class StoreService: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedIDs: Set<String> = []
    @Published var isLoading = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    var removeAds: Bool { purchasedIDs.contains(StoreIDs.removeAds) }

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: StoreIDs.all)
            await refreshPurchased()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification)
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshPurchased()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Private

    private func handle(_ verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification else { return }
        purchasedIDs.insert(transaction.productID)
        await transaction.finish()
    }

    private func refreshPurchased() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result else { continue }
            ids.insert(t.productID)
        }
        purchasedIDs = ids
    }
}
