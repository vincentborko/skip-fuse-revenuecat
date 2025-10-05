#if !SKIP_BRIDGE
import Foundation
import SwiftUI
#if !SKIP
import RevenueCat
import RevenueCatUI
#else
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.Offering
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.models.StoreTransaction
import com.revenuecat.purchases.ui.revenuecatui.PaywallDialog
import com.revenuecat.purchases.ui.revenuecatui.PaywallDialogOptions
import com.revenuecat.purchases.ui.revenuecatui.PaywallListener
#endif

// MARK: - Paywall View Wrapper

/// SwiftUI/Compose view wrapper for RevenueCat Paywall
///
/// This view presents a paywall UI using RevenueCat's native paywall components.
/// Callbacks provide the customer's user ID after purchase/restore completion.
public struct RCFusePaywallView: View {
    let offeringIdentifier: String?
    let onPurchaseCompleted: ((String) -> Void)?  // Returns customer user ID
    let onRestoreCompleted: ((String) -> Void)?   // Returns customer user ID

    public init(
        offeringIdentifier: String? = nil,
        onPurchaseCompleted: ((String) -> Void)? = nil,
        onRestoreCompleted: ((String) -> Void)? = nil
    ) {
        self.offeringIdentifier = offeringIdentifier
        self.onPurchaseCompleted = onPurchaseCompleted
        self.onRestoreCompleted = onRestoreCompleted
    }

    #if !SKIP
    public var body: some View {
        #if os(iOS)
        PaywallViewWrapper(
            offeringIdentifier: offeringIdentifier,
            onPurchaseCompleted: { customerInfo in
                onPurchaseCompleted?(customerInfo.originalAppUserId)
            },
            onRestoreCompleted: { customerInfo in
                onRestoreCompleted?(customerInfo.originalAppUserId)
            }
        )
        #else
        EmptyView()
        #endif
    }
    #else
    // SKIP @nobridge
    @Composable override func ComposeContent(context: ComposeContext) {
        var builder = PaywallDialogOptions.Builder()

        // Set offering identifier if provided
        if let offeringId = offeringIdentifier {
            builder = builder.setRequiredEntitlementIdentifier(offeringId)
        }

        let options = builder.build()
        PaywallDialog(paywallDialogOptions: options)
    }
    #endif
}

#if !SKIP && os(iOS)
// iOS-specific wrapper to handle offering loading
@available(iOS 15.0, *)
private struct PaywallViewWrapper: View {
    let offeringIdentifier: String?
    let onPurchaseCompleted: ((RevenueCat.CustomerInfo) -> Void)?
    let onRestoreCompleted: ((RevenueCat.CustomerInfo) -> Void)?

    @State private var offering: RevenueCat.Offering?

    var body: some View {
        Group {
            if let offering {
                PaywallView(offering: offering)
                    .onPurchaseCompleted { customerInfo in
                        onPurchaseCompleted?(customerInfo)
                    }
                    .onRestoreCompleted { customerInfo in
                        onRestoreCompleted?(customerInfo)
                    }
            } else {
                ProgressView()
                    .task {
                        await loadOffering()
                    }
            }
        }
    }

    private func loadOffering() async {
        do {
            let offerings = try await RevenueCat.Purchases.shared.offerings()
            if let offeringId = offeringIdentifier {
                offering = offerings.all[offeringId]
            } else {
                offering = offerings.current
            }
        } catch {
            // Handle error - for now just fail silently
            print("Failed to load offering: \(error)")
        }
    }
}
#endif

#endif // !SKIP_BRIDGE
