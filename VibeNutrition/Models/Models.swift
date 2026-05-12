import Foundation

struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    var age: Int?
    var sex: SexType?
    var heightCm: Double?
    var dietaryPref: DietaryPref
    var unitsPref: UnitsPref
    var mealsPerDay: Int?
    var trainingDaysPerWeek: Int?
    var mainFocus: MainFocus?
    var mealSuggestionsEnabled: Bool
    var notificationPref: NotificationPref
    var healthSyncEnabled: Bool
    var onboardingCompletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, age, sex
        case heightCm = "height_cm"
        case dietaryPref = "dietary_pref"
        case unitsPref = "units_pref"
        case mealsPerDay = "meals_per_day"
        case trainingDaysPerWeek = "training_days_per_week"
        case mainFocus = "main_focus"
        case mealSuggestionsEnabled = "meal_suggestions_enabled"
        case notificationPref = "notification_pref"
        case healthSyncEnabled = "health_sync_enabled"
        case onboardingCompletedAt = "onboarding_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Goal: Codable, Identifiable, Hashable {
    var id: UUID
    var userId: UUID
    var type: GoalType
    var startWeightKg: Double
    var goalWeightKg: Double
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case startWeightKg = "start_weight_kg"
        case goalWeightKg = "goal_weight_kg"
        case createdAt = "created_at"
    }
}

struct WeightLog: Codable, Identifiable, Hashable {
    var id: UUID
    var userId: UUID
    var weightKg: Double
    var loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case weightKg = "weight_kg"
        case loggedAt = "logged_at"
    }
}

struct NutritionTarget: Codable, Identifiable, Hashable {
    var id: UUID
    var userId: UUID
    var kcal: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int
    var inputsJson: [String: AnyCodable]
    var computedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case kcal
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case inputsJson = "inputs_json"
        case computedAt = "computed_at"
    }
}

struct FoodItem: Codable, Hashable {
    var name: String
    var grams: Double
    var kcal: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var confidence: Double?

    enum CodingKeys: String, CodingKey {
        case name, grams, kcal, confidence
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
    }
}

struct FoodLog: Codable, Identifiable, Hashable {
    var id: UUID
    var userId: UUID
    var imagePath: String?
    var items: [FoodItem]
    var kcal: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var source: LogSource
    var loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case imagePath = "image_path"
        case items = "items_json"
        case kcal
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case source
        case loggedAt = "logged_at"
    }
}

struct ActivitySync: Codable, Identifiable, Hashable {
    var id: UUID
    var userId: UUID
    var source: ActivitySource
    var steps: Int?
    var activeKcal: Int?
    var date: Date
    var syncedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case source, steps, date
        case activeKcal = "active_kcal"
        case syncedAt = "synced_at"
    }
}

struct Entitlement: Codable, Hashable {
    var userId: UUID
    var tier: EntitlementTier
    var expiresAt: Date?
    var productId: String?
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case tier
        case expiresAt = "expires_at"
        case productId = "product_id"
        case updatedAt = "updated_at"
    }
}
