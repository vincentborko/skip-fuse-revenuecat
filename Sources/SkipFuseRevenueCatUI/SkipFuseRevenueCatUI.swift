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
    let onDismiss: (() -> Void)?  // Called when dialog is manually dismissed (X button or outside tap)

    public init(
        offering: RCFuseOffering? = nil,
        onPurchaseCompleted: ((String) -> Void)? = nil,
        onRestoreCompleted: ((String) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.offering = offering
        self.onPurchaseCompleted = onPurchaseCompleted
        self.onRestoreCompleted = onRestoreCompleted
        self.onDismiss = onDismiss
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

        // Set dismiss request callback - called when user manually closes dialog (X button or outside tap)
        if let onDismiss {
            builder = builder.setDismissRequest { onDismiss() }
        }

        // Set listener for purchase/restore events
        if onPurchaseCompleted != nil || onRestoreCompleted != nil {
            // SKIP INSERT: val listener = object : PaywallListener {
            // SKIP INSERT:     override fun onPurchaseCompleted(customerInfo: CustomerInfo, storeTransaction: StoreTransaction) {
            if let onPurchaseCompleted {
                // SKIP INSERT:         onPurchaseCompleted(customerInfo.originalAppUserId)
                onPurchaseCompleted("") // Placeholder for Swift compilation
            }
            // SKIP INSERT:     }
            // SKIP INSERT:     override fun onRestoreCompleted(customerInfo: CustomerInfo) {
            if let onRestoreCompleted {
                // SKIP INSERT:         onRestoreCompleted(customerInfo.originalAppUserId)
                onRestoreCompleted("") // Placeholder for Swift compilation
            }
            // SKIP INSERT:     }
            // SKIP INSERT: }
            // SKIP INSERT: builder = builder.setListener(listener)
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
