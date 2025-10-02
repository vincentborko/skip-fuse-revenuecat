#if !SKIP_BRIDGE
import Foundation
#if !SKIP
import RevenueCat
#else
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.CustomerInfo
#endif

// MARK: - Platform-Agnostic Data Models

public struct PurchasePackageData: Sendable {
    public let identifier: String
    public let productId: String
    public let priceString: String
    public let price: Double

    public init(identifier: String, productId: String, priceString: String, price: Double) {
        self.identifier = identifier
        self.productId = productId
        self.priceString = priceString
        self.price = price
    }

    #if !SKIP
    init(package: Package) {
        self.identifier = package.identifier
        self.productId = package.storeProduct.productIdentifier
        self.priceString = package.storeProduct.localizedPriceString
        self.price = Double(truncating: package.storeProduct.price as NSNumber)
    }
    #else
    init(package: Package) {
        self.identifier = package.identifier
        self.productId = package.product.id
        self.priceString = package.product.price.formatted
        self.price = Double(package.product.price.amountMicros) / 1_000_000.0
    }
    #endif
}

public struct CustomerInfoData: Sendable {
    public let userId: String
    public let activeEntitlements: [String]
    public let allPurchasedProductIds: [String]

    public init(userId: String, activeEntitlements: [String], allPurchasedProductIds: [String]) {
        self.userId = userId
        self.activeEntitlements = activeEntitlements
        self.allPurchasedProductIds = allPurchasedProductIds
    }

    #if !SKIP
    init(info: CustomerInfo) {
        self.userId = info.originalAppUserId
        self.activeEntitlements = info.entitlements.all.values
            .filter { $0.isActive }
            .map { $0.identifier }
        self.allPurchasedProductIds = Array(info.allPurchasedProductIdentifiers)
    }
    #else
    init(info: CustomerInfo) {
        self.userId = info.originalAppUserId
        self.activeEntitlements = Array(info.entitlements.active.keys)
        self.allPurchasedProductIds = Array(info.allPurchasedProductIdentifiers)
    }
    #endif
}

public struct OfferingsData: Sendable {
    public let currentOffering: String?
    public let allOfferings: [String]

    public init(currentOffering: String?, allOfferings: [String]) {
        self.currentOffering = currentOffering
        self.allOfferings = allOfferings
    }
}

// MARK: - RevenueCat Service

/// RevenueCat service for purchases and subscriptions
public struct RevenueCat: Sendable {
    public static let shared = RevenueCat()

    private init() {}

    public func configure(apiKey: String) {
        #if !SKIP
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)
        #else
        let activity = ProcessInfo.processInfo.androidActivity
        let builder = PurchasesConfiguration.Builder(activity, apiKey)
        let config = builder.build()
        Purchases.configure(config)
        Purchases.logLevel = LogLevel.DEBUG
        #endif
    }

    public func loginUser(userId: String) async throws {
        #if !SKIP
        let _ = try await Purchases.shared.logIn(userId)
        #else
        return try await withCheckedThrowingContinuation { continuation in
            Purchases.sharedInstance.logIn(
                userId,
                onError: { error in
                    continuation.resume(throwing: StoreError.unknown)
                },
                onSuccess: { _, _ in
                    continuation.resume(returning: ())
                }
            )
        }
        #endif
    }

    public func logoutUser() async throws {
        #if !SKIP
        let _ = try await Purchases.shared.logOut()
        #else
        return try await withCheckedThrowingContinuation { continuation in
            Purchases.sharedInstance.logOut(
                onError: { error in
                    continuation.resume(throwing: StoreError.unknown)
                },
                onSuccess: { _ in
                    continuation.resume(returning: ())
                }
            )
        }
        #endif
    }

    public func loadOfferings() async throws -> OfferingsData {
        #if !SKIP
        let offerings = try await Purchases.shared.offerings()
        return OfferingsData(
            currentOffering: offerings.current?.identifier,
            allOfferings: Array(offerings.all.keys)
        )
        #else
        return try await withCheckedThrowingContinuation { continuation in
            Purchases.sharedInstance.getOfferings(
                onError: { error in
                    continuation.resume(throwing: StoreError.noProductsAvailable)
                },
                onSuccess: { offerings in
                    let data = OfferingsData(
                        currentOffering: offerings.current?.identifier,
                        allOfferings: Array(offerings.all.keys)
                    )
                    continuation.resume(returning: data)
                }
            )
        }
        #endif
    }

    public func loadProducts(offeringIdentifier: String? = nil) async throws -> [PurchasePackageData] {
        #if !SKIP
        let offerings = try await Purchases.shared.offerings()
        guard let packages = try extractPackages(from: offerings, offeringIdentifier: offeringIdentifier) else {
            throw StoreError.noProductsAvailable
        }
        return packages
        #else
        return try await withCheckedThrowingContinuation { continuation in
            Purchases.sharedInstance.getOfferings(
                onError: { error in
                    continuation.resume(throwing: StoreError.noProductsAvailable)
                },
                onSuccess: { offerings in
                    do {
                        guard let packages = try self.extractPackages(from: offerings, offeringIdentifier: offeringIdentifier) else {
                            continuation.resume(throwing: StoreError.noProductsAvailable)
                            return
                        }
                        continuation.resume(returning: packages)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            )
        }
        #endif
    }

    public func purchase(packageData: PurchasePackageData) async throws -> CustomerInfoData {
        #if !SKIP
        let offerings = try await Purchases.shared.offerings()
        guard let package = findPackage(in: offerings, productId: packageData.productId) else {
            throw StoreError.packageNotFound
        }

        let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)

        if userCancelled {
            throw StoreError.userCancelled
        }

        return CustomerInfoData(info: customerInfo)
        #else
        return try await withCheckedThrowingContinuation { continuation in
            let activity = ProcessInfo.processInfo.androidActivity

            Purchases.sharedInstance.getOfferings(
                onError: { error in
                    continuation.resume(throwing: StoreError.packageNotFound)
                },
                onSuccess: { offerings in
                    guard let pkg = self.findPackage(in: offerings, productId: packageData.productId) else {
                        continuation.resume(throwing: StoreError.packageNotFound)
                        return
                    }

                    let params = PurchaseParams.Builder(activity, pkg).build()
                    Purchases.sharedInstance.purchase(
                        params,
                        onError: { error, userCancelled in
                            if userCancelled {
                                continuation.resume(throwing: StoreError.userCancelled)
                            } else {
                                continuation.resume(throwing: StoreError.unknown)
                            }
                        },
                        onSuccess: { _, customerInfo in
                            continuation.resume(returning: CustomerInfoData(info: customerInfo))
                        }
                    )
                }
            )
        }
        #endif
    }

    public func restorePurchases() async throws -> CustomerInfoData {
        #if !SKIP
        let customerInfo = try await Purchases.shared.restorePurchases()
        return CustomerInfoData(info: customerInfo)
        #else
        return try await withCheckedThrowingContinuation { continuation in
            Purchases.sharedInstance.restorePurchases(
                onError: { error in
                    continuation.resume(throwing: StoreError.noPurchasesFound)
                },
                onSuccess: { customerInfo in
                    continuation.resume(returning: CustomerInfoData(info: customerInfo))
                }
            )
        }
        #endif
    }

    public func getCustomerInfo() async throws -> CustomerInfoData {
        #if !SKIP
        let customerInfo = try await Purchases.shared.customerInfo()
        return CustomerInfoData(info: customerInfo)
        #else
        return try await withCheckedThrowingContinuation { continuation in
            Purchases.sharedInstance.getCustomerInfo(
                onError: { error in
                    continuation.resume(throwing: StoreError.unknown)
                },
                onSuccess: { customerInfo in
                    continuation.resume(returning: CustomerInfoData(info: customerInfo))
                }
            )
        }
        #endif
    }

    // MARK: - Helper Methods

    private func extractPackages(from offerings: Offerings, offeringIdentifier: String?) throws -> [PurchasePackageData]? {
        #if !SKIP
        let offering = offeringIdentifier != nil ? offerings.offering(identifier: offeringIdentifier!) : offerings.current
        #else
        let offering = offeringIdentifier != nil ? offerings.all[offeringIdentifier!] : offerings.current
        #endif

        guard let packages = offering?.availablePackages, !packages.isEmpty else {
            return nil
        }
        return packages.map { PurchasePackageData(package: $0) }
    }

    private func findPackage(in offerings: Offerings, productId: String) -> Package? {
        #if !SKIP
        // Search all offerings
        for offering in offerings.all.values {
            if let found = offering.availablePackages.first(where: { $0.storeProduct.productIdentifier == productId }) {
                return found
            }
        }
        return nil
        #else
        // Search all offerings
        for offering in offerings.all.values {
            if let found = offering.availablePackages.first(where: { $0.product.id == productId }) {
                return found
            }
        }
        return nil
        #endif
    }
}

// MARK: - Errors

public enum StoreError: Error {
    case userCancelled
    case unknown
    case noPurchasesFound
    case noProductsAvailable
    case packageNotFound
}

extension StoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .userCancelled: return "User cancelled"
        case .unknown: return "Unknown error"
        case .noPurchasesFound: return "No purchases found"
        case .noProductsAvailable: return "No products available"
        case .packageNotFound: return "Package not found"
        }
    }
}

#endif // !SKIP_BRIDGE
