//
//  ProSupporterStore.swift
//  AWattPrice
//
//  Created by Codex on 14.05.26.
//

import Foundation
import StoreKit

enum ProSupporterPlan: String, CaseIterable, Identifiable {
    case monthly = "awattprice.pro.monthly"
    case yearly = "awattprice.pro.yearly"
    case lifetime = "awattprice.pro.lifetime"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly:
            return "Monthly Pro Supporter"
        case .yearly:
            return "Yearly Pro Supporter"
        case .lifetime:
            return "Lifetime Pro Supporter"
        }
    }

    var subtitle: String {
        switch self {
        case .monthly:
            return "Support AWattPrice month by month."
        case .yearly:
            return "Support AWattPrice for a full year."
        case .lifetime:
            return "Unlock AWattPrice Pro Supporter forever with one purchase."
        }
    }

    var expectedPrice: String {
        switch self {
        case .monthly:
            return "€1.29"
        case .yearly:
            return "€9.99"
        case .lifetime:
            return "€24.44"
        }
    }

    var badge: String? {
        switch self {
        case .monthly:
            return nil
        case .yearly:
            return "Best value"
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
    @Published private(set) var purchasedProductIdentifiers: Set<String> = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isRestoringPurchases = false
    @Published var purchaseInProgressProductIdentifier: String?
    @Published var message: String?
    @Published var messageIsError = false

    private var transactionUpdatesTask: Task<Void, Never>?

    var hasPro: Bool {
        purchasedProductIdentifiers.isDisjoint(with: Set(ProSupporterPlan.productIdentifiers)) == false
    }

    var isBusy: Bool {
        purchaseInProgressProductIdentifier != nil || isRestoringPurchases
    }

    func start() {
        if transactionUpdatesTask == nil {
            transactionUpdatesTask = observeTransactionUpdates()
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

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let loadedProducts = try await Product.products(for: ProSupporterPlan.productIdentifiers)
            products = loadedProducts.sorted { lhs, rhs in
                productSortIndex(lhs.id) < productSortIndex(rhs.id)
            }
            message = nil
            messageIsError = false
        } catch {
            products = []
            if hasPro == false {
                message = "Pro products could not be loaded. Please try again in a moment.".localized()
                messageIsError = true
            }
        }
    }

    func purchase(_ product: Product) async {
        guard purchaseInProgressProductIdentifier == nil else { return }

        purchaseInProgressProductIdentifier = product.id
        message = nil
        messageIsError = false

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                let transaction = try verifiedTransaction(from: verificationResult)
                await transaction.finish()
                await refreshPurchasedProducts()
                message = "AWattPrice Pro Supporter is active. Thank you for your support.".localized()
                messageIsError = false
            case .pending:
                message = "Your purchase is pending approval.".localized()
                messageIsError = false
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase could not be completed. Please try again.".localized()
            messageIsError = true
        }

        purchaseInProgressProductIdentifier = nil
    }

    func restorePurchases() async {
        guard isRestoringPurchases == false else { return }

        isRestoringPurchases = true
        message = nil
        messageIsError = false

        do {
            try await AppStore.sync()
            await refreshPurchasedProducts()

            if hasPro {
                message = "AWattPrice Pro Supporter is active. Thank you for your support.".localized()
                messageIsError = false
            } else {
                message = "No active AWattPrice Pro Supporter purchase was found.".localized()
                messageIsError = true
            }
        } catch {
            message = "Purchases could not be restored. Please try again.".localized()
            messageIsError = true
        }

        isRestoringPurchases = false
    }

    func refreshPurchasedProducts() async {
        var purchasedIdentifiers = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verifiedTransaction(from: result) else { continue }
            guard ProSupporterPlan.productIdentifiers.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }

            if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
                continue
            }

            purchasedIdentifiers.insert(transaction.productID)
        }

        purchasedProductIdentifiers = purchasedIdentifiers
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
        guard let transaction = try? verifiedTransaction(from: result) else { return }
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
