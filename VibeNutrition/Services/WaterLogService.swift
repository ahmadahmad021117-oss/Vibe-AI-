import Foundation
import Supabase

/// Backs hydration tracking. A "log" is one drink event in millilitres; the
/// dashboard and widget show the running daily total against the profile goal.
@MainActor
final class WaterLogService {
    static let shared = WaterLogService()
    private init() {}

    func write(amountMl: Int, loggedAt: Date = Date()) async throws {
        guard let userId = AuthService.shared.userId else { return }
        let payload: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "amount_ml": .integer(amountMl),
            "logged_at": .string(ISO8601DateFormatter().string(from: loggedAt)),
        ]
        try await SupabaseService.shared.from("water_logs").insert(payload).execute()
    }

    /// Total millilitres logged since local start-of-day.
    func todayTotalMl() async throws -> Int {
        guard let userId = AuthService.shared.userId else { return 0 }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let iso = ISO8601DateFormatter().string(from: startOfDay)

        struct Row: Decodable { let amountMl: Int
            enum CodingKeys: String, CodingKey { case amountMl = "amount_ml" }
        }
        let rows: [Row] = try await SupabaseService.shared
            .from("water_logs")
            .select("amount_ml")
            .eq("user_id", value: userId.uuidString)
            .gte("logged_at", value: iso)
            .execute()
            .value
        return rows.reduce(0) { $0 + $1.amountMl }
    }
}
