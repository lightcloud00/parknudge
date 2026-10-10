import Foundation
import os
import StoreKit

/// Races a StoreKit call against a deadline.
///
/// StoreKit can wait indefinitely for App Store authentication, for example
/// after an interrupted sign-in. An expired deadline throws
/// `storeUnavailable`, so callers treat it exactly like a store failure and a
/// timeout can never grant access. A task group cannot be used here: its scope
/// waits for every child, and a StoreKit call may ignore cancellation.
func withStoreDeadline<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let settled = OSAllocatedUnfairLock(initialState: false)
    return try await withCheckedThrowingContinuation { continuation in
        let work = Task {
            let result: Result<T, Error>
            do {
                result = .success(try await operation())
            } catch {
                result = .failure(error)
            }
            let first = settled.withLock { done in
                defer { done = true }
                return !done
            }
            if first { continuation.resume(with: result) }
        }
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            let first = settled.withLock { done in
                defer { done = true }
                return !done
            }
            if first {
                work.cancel()
                continuation.resume(throwing: PurchaseServiceError.storeUnavailable)
            }
        }
    }
}

@MainActor
final class StoreKitPurchaseService: PurchaseProviding {
    static let productIdentifier = "com.gusdigitalsolutions.parknudge.pro.lifetime"

    /// The launch check never prompts, so a long wait means the store is stuck.
    static let silentStoreDeadline: Double = 15
    /// Restore may show an App Store sign-in sheet; leave time to type a password.
    static let interactiveStoreDeadline: Double = 120

    private var product: Product?
    /// Set when `AppStore.sync()` hit its deadline. A second interactive call
    /// would most likely hang the same way, so the following legacy check falls
    /// back to the cached app transaction instead.
    private var lastSyncTimedOut = false

    func loadProduct() async -> PurchaseProduct? {
        do {
            let products = try await withStoreDeadline(seconds: Self.silentStoreDeadline) {
                try await Product.products(for: [Self.productIdentifier])
            }
            guard let product = products.first else {
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

    func hasLegacyParkingAccess() async -> Bool {
        await legacyParkingAccessState(refresh: false) == .eligible
    }

    func legacyParkingAccessState(refresh: Bool) async -> LegacyParkingAccessState {
        let result: VerificationResult<AppTransaction>
        do {
            // Refresh is reserved for the user's Restore action because it
            // may ask them to authenticate with the App Store.
            if refresh && !lastSyncTimedOut {
                result = try await withStoreDeadline(seconds: Self.interactiveStoreDeadline) {
                    try await AppTransaction.refresh()
                }
            } else {
                result = try await withStoreDeadline(seconds: Self.silentStoreDeadline) {
                    try await AppTransaction.shared
                }
            }
        } catch {
            return .unknown
        }
        switch result {
        case .verified(let transaction):
            // A verified sandbox or Xcode transaction (App Review, TestFlight)
            // means "not an original customer", not "could not verify".
            return LegacyParkingAccessPolicy.state(
                isVerified: true,
                bundleID: transaction.bundleID,
                isProduction: transaction.environment == .production,
                originalAppVersion: transaction.originalAppVersion
            )
        case .unverified:
            return .unknown
        }
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
        lastSyncTimedOut = false
        let started = ContinuousClock.now
        do {
            try await withStoreDeadline(seconds: Self.interactiveStoreDeadline) {
                try await AppStore.sync()
            }
            return await currentEntitlement()
        } catch {
            lastSyncTimedOut = started.duration(to: .now) >= .seconds(Self.interactiveStoreDeadline)
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
