import Foundation

#if canImport(RevenueCat)
import RevenueCat
#endif

#if SKIP
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.CustomerInfo
#endif

// MARK: - Platform-Agnostic Data Models

public struct PurchasePackageData: Codable, Sendable {
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
}

public struct CustomerInfoData: Codable, Sendable {
    public let userId: String
    public let activeEntitlements: [String]
    public let allPurchasedProductIds: [String]

    public init(userId: String, activeEntitlements: [String], allPurchasedProductIds: [String]) {
        self.userId = userId
        self.activeEntitlements = activeEntitlements
        self.allPurchasedProductIds = allPurchasedProductIds
    }
}

public struct OfferingsData: Codable, Sendable {
    public let currentOffering: String?
    public let allOfferings: [String]

    public init(currentOffering: String?, allOfferings: [String]) {
        self.currentOffering = currentOffering
        self.allOfferings = allOfferings
    }
}

// MARK: - RevenueCat Service

/// RevenueCat service for purchases and subscriptions
public class RevenueCatService {
    public static let shared = RevenueCatService()

    private init() {}

    public func configure(apiKey: String) {
        logger.info("🔧 [RevenueCat] configure called")
        #if !SKIP && canImport(RevenueCat)
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)
        logger.info("✅ [RevenueCat] Configuration complete (iOS)")
        #elseif SKIP
        logger.info("🔧 [RevenueCat] Starting configuration for Android...")
        let activity = ProcessInfo.processInfo.androidActivity
        let builder = PurchasesConfiguration.Builder(activity, apiKey)
        let config = builder.build()
        Purchases.configure(config)
        Purchases.logLevel = LogLevel.DEBUG
        logger.info("✅ [RevenueCat] Configuration complete (Android)")
        #endif
    }

    public func loginUser(userId: String) async throws {
        logger.info("✅ [RevenueCat] Logging into RevenueCat with user ID: \(userId)")
        #if !SKIP && canImport(RevenueCat)
        let _ = try await Purchases.shared.logIn(userId)
        #elseif SKIP
        return try await withCheckedThrowingContinuation { continuation in
            let purchases = Purchases.sharedInstance
            purchases.logIn(
                userId,
                onError: { error in
                    logger.info("❌ [RevenueCat] Login error: \(error.message)")
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
        #if !SKIP && canImport(RevenueCat)
        let _ = try await Purchases.shared.logOut()
        #elseif SKIP
        return try await withCheckedThrowingContinuation { continuation in
            let purchases = Purchases.sharedInstance
            purchases.logOut(
                onError: { error in
                    logger.info("❌ [RevenueCat] Logout error: \(error.message)")
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
        #if !SKIP && canImport(RevenueCat)
        let offerings = try await Purchases.shared.offerings()

        return OfferingsData(
            currentOffering: offerings.current?.identifier,
            allOfferings: Array(offerings.all.keys)
        )
        #elseif SKIP
        return try await withCheckedThrowingContinuation { continuation in
            let purchases = Purchases.sharedInstance

            purchases.getOfferings(
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
        #else
        throw StoreError.unknown
        #endif
    }

    public func loadProducts() async throws -> [PurchasePackageData] {
        #if !SKIP && canImport(RevenueCat)
        let offerings = try await Purchases.shared.offerings()
        var packages: [PurchasePackageData] = []

        // Get current offering packages
        if let currentOffering = offerings.current {
            packages.append(contentsOf: currentOffering.availablePackages.map { convertPackage($0) })
        }

        // Get subscription offering packages
        if let subscriptionOffering = offerings.offering(identifier: "Subscription") {
            packages.append(contentsOf: subscriptionOffering.availablePackages.map { convertPackage($0) })
        }

        guard !packages.isEmpty else {
            throw StoreError.noProductsAvailable
        }

        return packages
        #elseif SKIP
        logger.info("🔍 [RevenueCat] loadProducts() called")

        return try await withCheckedThrowingContinuation { continuation in
            let purchases = Purchases.sharedInstance
            logger.info("📦 [RevenueCat] Got Purchases instance")

            purchases.getOfferings(
                onError: { error in
                    logger.info("❌ [RevenueCat] Error loading products: \(error.message)")
                    continuation.resume(throwing: StoreError.noProductsAvailable)
                },
                onSuccess: { offerings in
                    logger.info("✅ [RevenueCat] Got offerings")
                    logger.info("📊 [RevenueCat] Current offering: \(offerings.current?.identifier ?? "none")")
                    logger.info("📊 [RevenueCat] Total offerings: \(offerings.all.count)")

                    var packages: [PurchasePackageData] = []

                    // Get current offering packages
                    if let current = offerings.current {
                        logger.info("📦 [RevenueCat] Processing current offering: \(current.identifier)")
                        logger.info("📦 [RevenueCat] Available packages: \(current.availablePackages.count)")

                        for pkg in current.availablePackages {
                            logger.info("  💰 [RevenueCat] Package: \(pkg.identifier)")
                            logger.info("     [RevenueCat] Product ID: \(pkg.product.id)")
                            logger.info("     [RevenueCat] Price: \(pkg.product.price.formatted)")

                            packages.append(PurchasePackageData(
                                identifier: pkg.identifier,
                                productId: pkg.product.id,
                                priceString: pkg.product.price.formatted,
                                price: Double(pkg.product.price.amountMicros) / 1_000_000.0
                            ))
                        }
                    }

                    // Get subscription offering packages
                    if let subscription = offerings.all["Subscription"] {
                        logger.info("📦 [RevenueCat] Processing Subscription offering")
                        logger.info("📦 [RevenueCat] Available packages: \(subscription.availablePackages.count)")

                        for pkg in subscription.availablePackages {
                            logger.info("  💰 [RevenueCat] Package: \(pkg.identifier)")
                            logger.info("     [RevenueCat] Product ID: \(pkg.product.id)")
                            logger.info("     [RevenueCat] Price: \(pkg.product.price.formatted)")

                            packages.append(PurchasePackageData(
                                identifier: pkg.identifier,
                                productId: pkg.product.id,
                                priceString: pkg.product.price.formatted,
                                price: Double(pkg.product.price.amountMicros) / 1_000_000.0
                            ))
                        }
                    }

                    logger.info("✅ [RevenueCat] Total packages loaded: \(packages.count)")

                    guard !packages.isEmpty else {
                        logger.info("⚠️ [RevenueCat] No packages found!")
                        continuation.resume(throwing: StoreError.noProductsAvailable)
                        return
                    }

                    continuation.resume(returning: packages)
                }
            )
        }
        #else
        throw StoreError.unknown
        #endif
    }

    public func purchase(packageData: PurchasePackageData) async throws -> CustomerInfoData {
        #if !SKIP && canImport(RevenueCat)
        // First get the actual RevenueCat package
        let offerings = try await Purchases.shared.offerings()
        var foundPackage: Package? = nil

        // Search in current offering
        if let current = offerings.current {
            foundPackage = current.availablePackages.first {
                $0.storeProduct.productIdentifier == packageData.productId
            }
        }

        // Search in subscription offering
        if foundPackage == nil, let subscription = offerings.offering(identifier: "Subscription") {
            foundPackage = subscription.availablePackages.first {
                $0.storeProduct.productIdentifier == packageData.productId
            }
        }

        guard let package = foundPackage else {
            throw StoreError.packageNotFound
        }

        let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)

        if userCancelled {
            throw StoreError.userCancelled
        }

        return convertCustomerInfo(customerInfo)
        #elseif SKIP
        return try await withCheckedThrowingContinuation { continuation in
            let purchases = Purchases.sharedInstance
            let activity = ProcessInfo.processInfo.androidActivity

            // First get offerings to find the package
            purchases.getOfferings(
                onError: { error in
                    continuation.resume(throwing: StoreError.packageNotFound)
                },
                onSuccess: { offerings in
                    var foundPackage: Package? = nil

                    // Search in current offering
                    if let current = offerings.current {
                        foundPackage = current.availablePackages.first {
                            $0.product.id == packageData.productId
                        }
                    }

                    // Search in subscription offering if not found
                    if foundPackage == nil, let subscription = offerings.all["Subscription"] {
                        foundPackage = subscription.availablePackages.first {
                            $0.product.id == packageData.productId
                        }
                    }

                    guard let pkg = foundPackage else {
                        continuation.resume(throwing: StoreError.packageNotFound)
                        return
                    }

                    // Now purchase
                    let params = PurchaseParams.Builder(activity, pkg).build()
                    purchases.purchase(
                        params,
                        onError: { error, userCancelled in
                            if userCancelled {
                                continuation.resume(throwing: StoreError.userCancelled)
                            } else {
                                logger.info("❌ [RevenueCat] Purchase error: \(error.message)")
                                continuation.resume(throwing: StoreError.unknown)
                            }
                        },
                        onSuccess: { _, customerInfo in
                            let data = self.convertCustomerInfo(customerInfo)
                            continuation.resume(returning: data)
                        }
                    )
                }
            )
        }
        #else
        throw StoreError.unknown
        #endif
    }

    public func restorePurchases() async throws -> CustomerInfoData {
        #if !SKIP && canImport(RevenueCat)
        let customerInfo = try await Purchases.shared.restorePurchases()
        return convertCustomerInfo(customerInfo)
        #elseif SKIP
        return try await withCheckedThrowingContinuation { continuation in
            let purchases = Purchases.sharedInstance

            purchases.restorePurchases(
                onError: { error in
                    logger.info("❌ [RevenueCat] Restore error: \(error.message)")
                    continuation.resume(throwing: StoreError.noPurchasesFound)
                },
                onSuccess: { customerInfo in
                    let data = self.convertCustomerInfo(customerInfo)
                    continuation.resume(returning: data)
                }
            )
        }
        #else
        throw StoreError.unknown
        #endif
    }

    public func getCustomerInfo() async throws -> CustomerInfoData {
        #if !SKIP && canImport(RevenueCat)
        let customerInfo = try await Purchases.shared.customerInfo()
        return convertCustomerInfo(customerInfo)
        #elseif SKIP
        return try await withCheckedThrowingContinuation { continuation in
            let purchases = Purchases.sharedInstance

            purchases.getCustomerInfo(
                onError: { error in
                    logger.info("❌ [RevenueCat] Get customer info error: \(error.message)")
                    continuation.resume(throwing: StoreError.unknown)
                },
                onSuccess: { customerInfo in
                    let data = self.convertCustomerInfo(customerInfo)
                    continuation.resume(returning: data)
                }
            )
        }
        #else
        throw StoreError.unknown
        #endif
    }

    // MARK: - Conversion Helpers

    #if !SKIP && canImport(RevenueCat)
    private func convertPackage(_ package: Package) -> PurchasePackageData {
        PurchasePackageData(
            identifier: package.identifier,
            productId: package.storeProduct.productIdentifier,
            priceString: package.storeProduct.localizedPriceString,
            price: Double(truncating: package.storeProduct.price as NSNumber)
        )
    }
    #endif

    #if !SKIP && canImport(RevenueCat)
    private func convertCustomerInfo(_ info: CustomerInfo) -> CustomerInfoData {
        let activeEntitlements = info.entitlements.all.values
            .filter { $0.isActive }
            .map { $0.identifier }

        let purchasedProductIds = Array(info.allPurchasedProductIdentifiers)

        return CustomerInfoData(
            userId: info.originalAppUserId,
            activeEntitlements: activeEntitlements,
            allPurchasedProductIds: purchasedProductIds
        )
    }
    #endif

    #if SKIP
    private func convertCustomerInfo(_ info: CustomerInfo) -> CustomerInfoData {
        let activeEntitlements = Array(info.entitlements.active.keys)
        let purchasedProductIds = Array(info.allPurchasedProductIdentifiers)

        return CustomerInfoData(
            userId: info.originalAppUserId,
            activeEntitlements: activeEntitlements,
            allPurchasedProductIds: purchasedProductIds
        )
    }
    #endif
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
