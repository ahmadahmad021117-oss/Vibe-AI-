import Foundation
import Supabase

@MainActor
@Observable
final class EntitlementService {
    static let shared = EntitlementService()
    private init() {}

    private(set) var tier: EntitlementTier = .free
    private(set) var expiresAt: Date?

    static let freeDailyScanLimit = 3

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
            tier = row?.tier ?? .free
            expiresAt = row?.expiresAt
        } catch {
            tier = .free
            expiresAt = nil
        }
    }

    func assertCanScan() async throws {
        if isPremium { return }
        let today = try await todayScanCount()
        if today >= Self.freeDailyScanLimit {
            throw FoodScanError.scanLimitReached
        }
    }

    func todayScanCount() async throws -> Int {
        guard let userId = AuthService.shared.userId else { return 0 }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let iso = ISO8601DateFormatter().string(from: startOfDay)
        let rows: [FoodLog] = try await SupabaseService.shared
            .from("food_logs")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("source", value: "scan")
            .gte("logged_at", value: iso)
            .execute()
            .value
        return rows.count
    }
}
