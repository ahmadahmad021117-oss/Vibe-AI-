import Foundation
import Supabase

@MainActor
final class ProfileService {
    static let shared = ProfileService()
    private init() {}

    private var table: PostgrestQueryBuilder {
        SupabaseService.shared.from("profiles")
    }

    func fetchCurrent() async throws -> Profile? {
        guard let userId = AuthService.shared.userId else { return nil }
        let row: Profile? = try await table
            .select()
            .eq("id", value: userId.uuidString)
            .limit(1)
            .single()
            .execute()
            .value
        return row
    }

    func upsert(_ patch: ProfilePatch) async throws {
        guard let userId = AuthService.shared.userId else { return }
        var payload = patch.dictionary
        payload["id"] = AnyJSON.string(userId.uuidString)
        try await table.upsert(payload).execute()
    }

    func markOnboardingComplete() async throws {
        guard let userId = AuthService.shared.userId else { return }
        try await table
            .update(["onboarding_completed_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))])
            .eq("id", value: userId.uuidString)
            .execute()
    }
}

/// Loose patch payload — only set keys are sent.
struct ProfilePatch {
    var age: Int?
    var sex: SexType?
    var heightCm: Double?
    var dietaryPref: DietaryPref?
    var unitsPref: UnitsPref?
    var mealsPerDay: Int?
    var trainingDaysPerWeek: Int?
    var mainFocus: MainFocus?
    var mealSuggestionsEnabled: Bool?
    var notificationPref: NotificationPref?
    var healthSyncEnabled: Bool?

    var dictionary: [String: AnyJSON] {
        var out: [String: AnyJSON] = [:]
        if let age { out["age"] = .integer(age) }
        if let sex { out["sex"] = .string(sex.rawValue) }
        if let heightCm { out["height_cm"] = .double(heightCm) }
        if let dietaryPref { out["dietary_pref"] = .string(dietaryPref.rawValue) }
        if let unitsPref { out["units_pref"] = .string(unitsPref.rawValue) }
        if let mealsPerDay { out["meals_per_day"] = .integer(mealsPerDay) }
        if let trainingDaysPerWeek { out["training_days_per_week"] = .integer(trainingDaysPerWeek) }
        if let mainFocus { out["main_focus"] = .string(mainFocus.rawValue) }
        if let mealSuggestionsEnabled { out["meal_suggestions_enabled"] = .bool(mealSuggestionsEnabled) }
        if let notificationPref { out["notification_pref"] = .string(notificationPref.rawValue) }
        if let healthSyncEnabled { out["health_sync_enabled"] = .bool(healthSyncEnabled) }
        return out
    }
}
