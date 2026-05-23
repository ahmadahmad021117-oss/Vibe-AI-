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

    /// Soft pre-check used by the UI to short-circuit before uploading an image.
    /// The authoritative gate is in the analyze-food edge function — a free
    /// user who somehow gets past this check will still be blocked server-side
    /// with HTTP 402, which `FoodScanService` surfaces as `.scanLimitReached`.
    func assertCanScan() async throws {
        if isPremium { return }
        let today = try await todayScanCount()
        if today >= Self.freeDailyScanLimit {
            throw FoodScanError.scanLimitReached
        }
    }

    /// Today's billable scan attempts (UTC day). Source of truth is
    /// `scan_attempts` — the same table the server gates against — so the
    /// client and server always agree on what's left.
    func todayScanCount() async throws -> Int {
        guard let userId = AuthService.shared.userId else { return 0 }
        // Server counts attempts >= start-of-UTC-day, so we must too.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let startOfDay = utc.startOfDay(for: Date())
        let iso = ISO8601DateFormatter().string(from: startOfDay)
        let rows: [ScanAttempt] = try await SupabaseService.shared
            .from("scan_attempts")
            .select()
            .eq("user_id", value: userId.uuidString)
            .in("status", values: ["pending", "success"])
            .gte("created_at", value: iso)
            .execute()
            .value
        return rows.count
    }
}

/// Mirrors the public columns of the `scan_attempts` table.
private struct ScanAttempt: Decodable {
    let id: UUID
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case createdAt = "created_at"
    }
}
