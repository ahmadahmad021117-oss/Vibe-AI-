import Foundation
import Supabase

/// Backs tape-measure body check-ins (waist, hips, chest, arm, thigh, body-fat).
/// Weight lives in `weight_logs`; this is for the other circumference metrics.
@MainActor
final class BodyMeasurementService {
    static let shared = BodyMeasurementService()
    private init() {}

    func list(limit: Int = 60) async throws -> [BodyMeasurement] {
        guard let userId = AuthService.shared.userId else { return [] }
        return try await SupabaseService.shared
            .from("body_measurements")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("measured_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func fetchLatest() async throws -> BodyMeasurement? {
        try await list(limit: 1).first
    }

    @discardableResult
    func save(waistCm: Double?, hipCm: Double?, chestCm: Double?,
              armCm: Double?, thighCm: Double?, bodyFatPct: Double?,
              notes: String?) async throws -> UUID {
        guard let userId = AuthService.shared.userId else {
            throw NSError(domain: "BodyMeasurementService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }
        let id = UUID()
        var payload: [String: AnyJSON] = [
            "id": .string(id.uuidString),
            "user_id": .string(userId.uuidString),
        ]
        if let waistCm { payload["waist_cm"] = .double(waistCm) }
        if let hipCm { payload["hip_cm"] = .double(hipCm) }
        if let chestCm { payload["chest_cm"] = .double(chestCm) }
        if let armCm { payload["arm_cm"] = .double(armCm) }
        if let thighCm { payload["thigh_cm"] = .double(thighCm) }
        if let bodyFatPct { payload["body_fat_pct"] = .double(bodyFatPct) }
        if let notes, !notes.isEmpty { payload["notes"] = .string(notes) }

        try await SupabaseService.shared.from("body_measurements").insert(payload).execute()
        return id
    }

    func delete(id: UUID) async throws {
        try await SupabaseService.shared.from("body_measurements")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
