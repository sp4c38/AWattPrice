//
//  ProSupporterStore.swift
//  AWattPrice
//
//  Created by Codex on 14.05.26.
//

import Foundation
import StoreKit

enum ProSupporterPlan: String, CaseIterable, Identifiable {
    case monthly = "awattprice.pro.supporter.monthly"
    case yearly = "awattprice.pro.supporter.yearly"
    case lifetime = "awattprice.pro.supporter.lifetime"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        case .lifetime:
            return "Lifetime"
        }
    }

    var subtitle: String {
        switch self {
        case .monthly:
            return "About the price of a donut."
        case .yearly:
            return "The price of a book."
        case .lifetime:
            return "Less than a dinner out."
        }
    }

    var badge: String? {
        switch self {
        case .monthly:
            return nil
        case .yearly:
            return "Most popular"
        case .lifetime:
            return "One-time"
        }
    }

    static var productIdentifiers: [String] {
        allCases.map(\.rawValue)
    }
}

enum ProSupporterStoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "The purchase could not be verified."
        }
    }
}

@MainActor
final class ProSupporterStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIdentifiers: Set<String> = [] {
        didSet {
            ProSupporterEntitlementStore.setHasPro(hasPro)
        }
    }
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isRestoringPurchases = false
    @Published var purchaseInProgressProductIdentifier: String?
    @Published var message: String?
    @Published var messageIsError = false

    private var transactionUpdatesTask: Task<Void, Never>?

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var hasPro: Bool {
        purchasedProductIdentifiers.isDisjoint(with: Set(ProSupporterPlan.productIdentifiers)) == false
    }

    var isBusy: Bool {
        purchaseInProgressProductIdentifier != nil || isRestoringPurchases
    }

    var availablePlans: [ProSupporterPlan] {
        ProSupporterPlan.allCases.filter { product(for: $0) != nil }
    }

    func start() {
        print("[Pro Supporter Store] Starting Pro Supporter store.")

        if transactionUpdatesTask == nil {
            print("[Pro Supporter Store] Starting transaction update observer.")
            transactionUpdatesTask = observeTransactionUpdates()
        } else {
            print("[Pro Supporter Store] Transaction update observer is already running.")
        }

        Task {
            await refreshPurchasedProducts()
            await loadProducts()
        }
    }

    func product(for plan: ProSupporterPlan) -> Product? {
        products.first { $0.id == plan.rawValue }
    }

    func loadProducts() async {
        guard isLoadingProducts == false else { return }

        print("[Pro Supporter Store] Loading products: \(ProSupporterPlan.productIdentifiers.joined(separator: ", ")).")
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let loadedProducts = try await Product.products(for: ProSupporterPlan.productIdentifiers)
            products = loadedProducts.sorted { lhs, rhs in
                productSortIndex(lhs.id) < productSortIndex(rhs.id)
            }
            print("[Pro Supporter Store] Loaded \(products.count) product(s): \(products.map(\.id).joined(separator: ", ")).")
            message = nil
            messageIsError = false
        } catch {
            products = []
            print("[Pro Supporter Store] Failed to load products: \(error.localizedDescription).")
            if hasPro == false {
                message = "Pro products could not be loaded. Please try again in a moment.".localized()
                messageIsError = true
            }
        }
    }

    func purchase(_ plan: ProSupporterPlan) async {
        guard purchaseInProgressProductIdentifier == nil else { return }
        guard let product = product(for: plan) else {
            print("[Pro Supporter Store] Purchase requested for unavailable plan: \(plan.rawValue).")
            message = "Pro options unavailable".localized()
            messageIsError = true
            return
        }

        print("[Pro Supporter Store] Starting purchase for \(product.id) at \(product.displayPrice).")
        purchaseInProgressProductIdentifier = product.id
        message = nil
        messageIsError = false

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                let transaction = try verifiedTransaction(from: verificationResult)
                print("[Pro Supporter Store] Purchase succeeded and was verified for \(transaction.productID).")
                await transaction.finish()
                await refreshPurchasedProducts()
                message = "Pro is active. Thank you for your support.".localized()
                messageIsError = false
            case .pending:
                print("[Pro Supporter Store] Purchase is pending for \(product.id).")
                message = "Your purchase is pending approval.".localized()
                messageIsError = false
            case .userCancelled:
                print("[Pro Supporter Store] Purchase was cancelled by the user for \(product.id).")
                break
            @unknown default:
                print("[Pro Supporter Store] Purchase returned an unknown result for \(product.id).")
                break
            }
        } catch {
            print("[Pro Supporter Store] Purchase failed for \(product.id): \(error.localizedDescription).")
            message = "The purchase could not be completed. Please try again.".localized()
            messageIsError = true
        }

        purchaseInProgressProductIdentifier = nil
    }

    func restorePurchases() async {
        guard isRestoringPurchases == false else { return }

        print("[Pro Supporter Store] Restoring purchases.")
        isRestoringPurchases = true
        message = nil
        messageIsError = false

        do {
            try await AppStore.sync()
            print("[Pro Supporter Store] AppStore.sync completed.")
            await refreshPurchasedProducts()

            if hasPro {
                message = "Pro is active. Thank you for your support.".localized()
                messageIsError = false
            } else {
                print("[Pro Supporter Store] Restore completed without active Pro entitlements.")
                message = "No active Pro purchase was found.".localized()
                messageIsError = true
            }
        } catch {
            print("[Pro Supporter Store] Restore failed: \(error.localizedDescription).")
            message = "Purchases could not be restored. Please try again.".localized()
            messageIsError = true
        }

        isRestoringPurchases = false
    }

    func refreshPurchasedProducts() async {
        print("[Pro Supporter Store] Refreshing current entitlements.")
        var purchasedIdentifiers = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verifiedTransaction(from: result) else {
                print("[Pro Supporter Store] Ignored unverified entitlement.")
                continue
            }
            guard ProSupporterPlan.productIdentifiers.contains(transaction.productID) else {
                print("[Pro Supporter Store] Ignored unrelated entitlement: \(transaction.productID).")
                continue
            }
            guard transaction.revocationDate == nil else {
                print("[Pro Supporter Store] Ignored revoked entitlement: \(transaction.productID).")
                continue
            }

            if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
                print("[Pro Supporter Store] Ignored expired entitlement: \(transaction.productID).")
                continue
            }

            print("[Pro Supporter Store] Found active entitlement: \(transaction.productID).")
            purchasedIdentifiers.insert(transaction.productID)
        }

        purchasedProductIdentifiers = purchasedIdentifiers
        print("[Pro Supporter Store] Active Pro entitlement count: \(purchasedProductIdentifiers.count).")
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionUpdate: result)
            }
        }
    }

    private func handle(transactionUpdate result: VerificationResult<Transaction>) async {
        guard let transaction = try? verifiedTransaction(from: result) else {
            print("[Pro Supporter Store] Ignored unverified transaction update.")
            return
        }
        print("[Pro Supporter Store] Handling transaction update for \(transaction.productID).")
        await transaction.finish()
        await refreshPurchasedProducts()
    }

    private func verifiedTransaction(from result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw ProSupporterStoreError.failedVerification
        }
    }

    private func productSortIndex(_ productIdentifier: String) -> Int {
        ProSupporterPlan.allCases.firstIndex { $0.rawValue == productIdentifier } ?? Int.max
    }

}

extension ProSupporterStore {
    static func preview(hasPro: Bool) -> ProSupporterStore {
        let store = ProSupporterStore()
        store.purchasedProductIdentifiers = hasPro ? [ProSupporterPlan.yearly.rawValue] : []
        return store
    }
}
