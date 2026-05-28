import Foundation
import Supabase

@MainActor
@Observable
final class EntitlementService {
    static let shared = EntitlementService()
    private init() {}

    private(set) var tier: EntitlementTier = .free
    private(set) var expiresAt: Date?

    var isPremium: Bool {
        Self.isPremium(tier: tier, expiresAt: expiresAt, now: Date())
    }

    /// Pure helper, exposed for testing.
    nonisolated static func isPremium(tier: EntitlementTier, expiresAt: Date?, now: Date) -> Bool {
        guard tier == .premium else { return false }
        guard let expiresAt else { return true }   // lifetime / non-expiring
        return expiresAt > now
    }

    func refresh() async {
        guard let userId = AuthService.shared.userId else {
            tier = .free; expiresAt = nil; return
        }
        do {
            let row: Entitlement? = try await SupabaseService.shared
                .from("entitlements")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .single()
                .execute()
                .value
            if let row {
                tier = row.tier
                expiresAt = row.expiresAt
            }
            // No row yet: keep whatever state we have. The RevenueCat webhook
            // populates this table asynchronously, so a just-purchased user
            // may have no row for a few seconds — downgrading them here would
            // bounce them straight back to the paywall.
        } catch {
            // Same reasoning: don't clobber an optimistic premium set from
            // RevenueCat's customerInfo just because the network blipped.
        }
    }

    /// Locally apply a premium entitlement learned from RevenueCat's customerInfo,
    /// without waiting for the Supabase `entitlements` row (which lags behind by
    /// however long the RC → Supabase webhook takes). The DB row is still the
    /// long-term source of truth — `refresh()` will reconcile once it appears.
    func applyLocalPremium(expiresAt: Date?) {
        tier = .premium
        self.expiresAt = expiresAt
    }

    /// Locally drop entitlement (e.g. on sign-out).
    func clearLocal() {
        tier = .free
        expiresAt = nil
    }

    /// Hard-paywall gate: scanning requires an active premium entitlement (which
    /// includes the 3-day intro-offer free trial — RevenueCat reports that as
    /// active premium until the trial expires). The server-side gate in
    /// analyze-food is the authoritative source of truth; this client check just
    /// avoids opening the camera / uploading an image when we already know the
    /// scan would be rejected.
    func assertCanScan() throws {
        if !isPremium {
            throw FoodScanError.premiumRequired
        }
    }
}
