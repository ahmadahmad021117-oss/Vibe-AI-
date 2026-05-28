import Foundation
import Supabase

@MainActor
final class FoodLogService {
    static let shared = FoodLogService()
    private init() {}

    @discardableResult
    func write(items: [FoodItem], imagePath: String?, source: LogSource) async throws -> UUID {
        guard let userId = AuthService.shared.userId else {
            throw NSError(
                domain: "FoodLogService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: String(
                    localized: "food_log.error.not_signed_in",
                    defaultValue: "Not signed in.",
                    comment: "Shown when attempting to write a food log without an authenticated user"
                )]
            )
        }

        let kcal = items.reduce(0) { $0 + $1.kcal }
        let protein = items.reduce(0.0) { $0 + $1.proteinG }
        let carbs = items.reduce(0.0) { $0 + $1.carbsG }
        let fat = items.reduce(0.0) { $0 + $1.fatG }
        let micros = Micronutrients.sum(items.map { $0.micros })

        let itemsJSON: [AnyJSON] = items.map { item in
            var d: [String: AnyJSON] = [
                "name": .string(item.name),
                "grams": .double(item.grams),
                "kcal": .integer(item.kcal),
                "protein_g": .double(item.proteinG),
                "carbs_g": .double(item.carbsG),
                "fat_g": .double(item.fatG),
            ]
            if let c = item.confidence { d["confidence"] = .double(c) }
            if let v = item.vitaminDMcg   { d["vitamin_d_mcg"]   = .double(v) }
            if let v = item.vitaminB12Mcg { d["vitamin_b12_mcg"] = .double(v) }
            if let v = item.vitaminCMg    { d["vitamin_c_mg"]    = .double(v) }
            if let v = item.magnesiumMg   { d["magnesium_mg"]    = .double(v) }
            if let v = item.ironMg        { d["iron_mg"]         = .double(v) }
            if let v = item.zincMg        { d["zinc_mg"]         = .double(v) }
            return .object(d)
        }

        // Client-generated id + timestamp so we can mirror the same identity into
        // HealthKit (HKMetadataKeyExternalUUID) for later deletes.
        let logId = UUID()
        let loggedAt = Date()

        var payload: [String: AnyJSON] = [
            "id": .string(logId.uuidString),
            "user_id": .string(userId.uuidString),
            "image_path": imagePath.map { AnyJSON.string($0) } ?? .null,
            "items_json": .array(itemsJSON),
            "kcal": .integer(kcal),
            "protein_g": .double(protein),
            "carbs_g": .double(carbs),
            "fat_g": .double(fat),
            "source": .string(source.rawValue),
            "logged_at": .string(ISO8601DateFormatter().string(from: loggedAt)),
        ]
        if let v = micros.vitaminDMcg   { payload["vitamin_d_mcg"]   = .double(v) }
        if let v = micros.vitaminB12Mcg { payload["vitamin_b12_mcg"] = .double(v) }
        if let v = micros.vitaminCMg    { payload["vitamin_c_mg"]    = .double(v) }
        if let v = micros.magnesiumMg   { payload["magnesium_mg"]    = .double(v) }
        if let v = micros.ironMg        { payload["iron_mg"]         = .double(v) }
        if let v = micros.zincMg        { payload["zinc_mg"]         = .double(v) }

        try await SupabaseService.shared.from("food_logs").insert(payload).execute()

        // Mirror to Apple Health if the user opted in. Fire-and-forget — Supabase
        // is the source of truth; HK write must never gate the user-visible flow.
        Task { [logId, loggedAt] in
            await HealthKitService.shared.writeFoodLog(
                logId: logId,
                kcal: kcal,
                proteinG: protein,
                carbsG: carbs,
                fatG: fat,
                loggedAt: loggedAt
            )
        }

        return logId
    }

    func fetchToday() async throws -> [FoodLog] {
        guard let userId = AuthService.shared.userId else { return [] }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let iso = ISO8601DateFormatter().string(from: startOfDay)
        let rows: [FoodLog] = try await SupabaseService.shared
            .from("food_logs")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("logged_at", value: iso)
            .order("logged_at", ascending: false)
            .execute()
            .value
        return rows
    }

    /// One day's kcal total, used by the Progress-tab history chart.
    struct DailyKcal: Hashable, Identifiable {
        /// Local-calendar start-of-day, so chart bars line up cleanly per day.
        let date: Date
        let kcal: Int
        var id: Date { date }
    }

    /// Returns `days` entries oldest-to-newest, including days with zero logs.
    /// We bucket on the *local* calendar day rather than UTC so a meal logged
    /// at 11pm doesn't slide into the next bar.
    func fetchDailyKcal(days: Int) async throws -> [DailyKcal] {
        guard days > 0, let userId = AuthService.shared.userId else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let earliest = cal.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        struct Row: Decodable { let kcal: Int; let loggedAt: Date
            enum CodingKeys: String, CodingKey { case kcal; case loggedAt = "logged_at" }
        }

        let iso = ISO8601DateFormatter().string(from: earliest)
        let rows: [Row] = try await SupabaseService.shared
            .from("food_logs")
            .select("kcal, logged_at")
            .eq("user_id", value: userId.uuidString)
            .gte("logged_at", value: iso)
            .execute()
            .value

        // Pre-seed every day with 0 so empty days still render a bar slot.
        var buckets: [Date: Int] = [:]
        for offset in 0..<days {
            if let d = cal.date(byAdding: .day, value: offset, to: earliest) {
                buckets[cal.startOfDay(for: d)] = 0
            }
        }
        for r in rows {
            let key = cal.startOfDay(for: r.loggedAt)
            buckets[key, default: 0] += r.kcal
        }
        return buckets.keys.sorted().map { DailyKcal(date: $0, kcal: buckets[$0] ?? 0) }
    }

    func delete(id: UUID) async throws {
        try await SupabaseService.shared.from("food_logs")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()

        // Mirror the delete to HealthKit if applicable. Best-effort.
        Task { await HealthKitService.shared.deleteFoodLog(logId: id) }
    }
}
