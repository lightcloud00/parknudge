import Foundation
import StoreKit

@MainActor
final class StoreKitPurchaseService: PurchaseProviding {
    static let productIdentifier = "com.gusdigitalsolutions.parknudge.pro.lifetime"

    private var product: Product?

    func loadProduct() async -> PurchaseProduct? {
        do {
            guard let product = try await Product.products(for: [Self.productIdentifier]).first else {
                return nil
            }
            self.product = product
            return PurchaseProduct(
                identifier: product.id,
                displayName: product.displayName,
                displayPrice: product.displayPrice
            )
        } catch {
            return nil
        }
    }

    func currentEntitlement() async -> EntitlementState {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productIdentifier,
                  transaction.revocationDate == nil else { continue }
            return .pro
        }
        return .free
    }

    func purchase() async throws -> PurchaseOutcome {
        let product: Product
        if let loaded = self.product {
            product = loaded
        } else {
            guard let loaded = try await Product.products(for: [Self.productIdentifier]).first else {
                throw PurchaseServiceError.productUnavailable
            }
            self.product = loaded
            product = loaded
        }

        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else {
                    throw PurchaseServiceError.verificationFailed
                }
                guard transaction.productID == Self.productIdentifier,
                      transaction.revocationDate == nil else {
                    throw PurchaseServiceError.verificationFailed
                }
                await transaction.finish()
                return .purchased
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                throw PurchaseServiceError.storeUnavailable
            }
        } catch let error as PurchaseServiceError {
            throw error
        } catch {
            throw PurchaseServiceError.storeUnavailable
        }
    }

    func restore() async throws -> EntitlementState {
        do {
            try await AppStore.sync()
            return await currentEntitlement()
        } catch {
            throw PurchaseServiceError.storeUnavailable
        }
    }

    func entitlementUpdates() -> AsyncStream<EntitlementState> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result,
                       transaction.productID == Self.productIdentifier,
                       transaction.revocationDate == nil {
                        continuation.yield(.pro)
                        await transaction.finish()
                    } else {
                        continuation.yield(await self.currentEntitlement())
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
