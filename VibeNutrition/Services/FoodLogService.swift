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

    func delete(id: UUID) async throws {
        try await SupabaseService.shared.from("food_logs")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()

        // Mirror the delete to HealthKit if applicable. Best-effort.
        Task { await HealthKitService.shared.deleteFoodLog(logId: id) }
    }
}
