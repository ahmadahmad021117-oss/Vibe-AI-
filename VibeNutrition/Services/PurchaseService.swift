import Foundation
import RevenueCat
import Observation

@MainActor
@Observable
final class PurchaseService {
    static let shared = PurchaseService()

    private(set) var offerings: Offerings?
    private(set) var customerInfo: CustomerInfo?
    private(set) var isLoadingOfferings = false
    private(set) var error: String?

    static let premiumEntitlementID = "premium"

    private init() {}

    func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
        Purchases.shared.delegate = PurchasesDelegateBridge.shared
    }

    /// Log in to RevenueCat with the Supabase user id so the webhook
    /// can later match entitlements -> user row.
    func loginIfNeeded() async {
        guard let userId = AuthService.shared.userId else { return }
        do {
            let result = try await Purchases.shared.logIn(userId.uuidString)
            self.customerInfo = result.customerInfo
        } catch {
            self.error = error.localizedDescription
        }
    }

    func logOut() async {
        do {
            _ = try await Purchases.shared.logOut()
            self.customerInfo = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadOfferings() async {
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        do {
            self.offerings = try await Purchases.shared.offerings()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func purchase(_ package: Package) async -> Bool {
        do {
            let result = try await Purchases.shared.purchase(package: package)
            self.customerInfo = result.customerInfo
            await EntitlementService.shared.refresh()
            return result.customerInfo.entitlements[Self.premiumEntitlementID]?.isActive == true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func restore() async -> Bool {
        do {
            let info = try await Purchases.shared.restorePurchases()
            self.customerInfo = info
            await EntitlementService.shared.refresh()
            return info.entitlements[Self.premiumEntitlementID]?.isActive == true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

/// Bridge for `PurchasesDelegate` (which requires NSObject conformance).
private final class PurchasesDelegateBridge: NSObject, PurchasesDelegate {
    static let shared = PurchasesDelegateBridge()

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            PurchaseService.shared.applyCustomerInfo(customerInfo)
        }
    }
}

extension PurchaseService {
    fileprivate func applyCustomerInfo(_ info: CustomerInfo) {
        self.customerInfo = info
        Task { await EntitlementService.shared.refresh() }
    }
}
