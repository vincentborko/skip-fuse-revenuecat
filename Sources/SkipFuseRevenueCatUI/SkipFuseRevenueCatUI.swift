#if !SKIP_BRIDGE
import Foundation
import SwiftUI
import SkipFuseRevenueCat
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
    let offering: RCFuseOffering?
    let onPurchaseCompleted: ((String) -> Void)?  // Returns customer user ID
    let onRestoreCompleted: ((String) -> Void)?   // Returns customer user ID

    public init(
        offering: RCFuseOffering? = nil,
        onPurchaseCompleted: ((String) -> Void)? = nil,
        onRestoreCompleted: ((String) -> Void)? = nil
    ) {
        self.offering = offering
        self.onPurchaseCompleted = onPurchaseCompleted
        self.onRestoreCompleted = onRestoreCompleted
    }

    #if !SKIP
    public var body: some View {
        #if os(iOS)
        PaywallViewWrapper(
            offering: offering,
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
        // Build options with offering if available
        var builder = PaywallDialogOptions.Builder()

        // Set offering if provided - use the native offering from RCFuseOffering
        if let offering {
            builder = builder.setOffering(offering.offering)
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
    let offering: RCFuseOffering?
    let onPurchaseCompleted: ((RevenueCat.CustomerInfo) -> Void)?
    let onRestoreCompleted: ((RevenueCat.CustomerInfo) -> Void)?

    var body: some View {
        Group {
            if let offering {
                PaywallView(offering: offering.offering)
                    .onPurchaseCompleted { customerInfo in
                        onPurchaseCompleted?(customerInfo)
                    }
                    .onRestoreCompleted { customerInfo in
                        onRestoreCompleted?(customerInfo)
                    }
            } else {
                EmptyView()
            }
        }
    }
}
#endif

#endif // !SKIP_BRIDGE
