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
    var pace: Pace?
    var marketingEmail: String?
    var marketingEmailOptIn: Bool?
    var marketingConsentAt: Date?
    var onboardingCompletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, age, sex, pace
        case heightCm = "height_cm"
        case dietaryPref = "dietary_pref"
        case unitsPref = "units_pref"
        case mealsPerDay = "meals_per_day"
        case trainingDaysPerWeek = "training_days_per_week"
        case mainFocus = "main_focus"
        case mealSuggestionsEnabled = "meal_suggestions_enabled"
        case notificationPref = "notification_pref"
        case healthSyncEnabled = "health_sync_enabled"
        case marketingEmail = "marketing_email"
        case marketingEmailOptIn = "marketing_email_opt_in"
        case marketingConsentAt = "marketing_consent_at"
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

    // Per-item micronutrients (optional — older scans decode with nils).
    var vitaminDMcg: Double?
    var vitaminB12Mcg: Double?
    var vitaminCMg: Double?
    var magnesiumMg: Double?
    var ironMg: Double?
    var zincMg: Double?

    enum CodingKeys: String, CodingKey {
        case name, grams, kcal, confidence
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case vitaminDMcg   = "vitamin_d_mcg"
        case vitaminB12Mcg = "vitamin_b12_mcg"
        case vitaminCMg    = "vitamin_c_mg"
        case magnesiumMg   = "magnesium_mg"
        case ironMg        = "iron_mg"
        case zincMg        = "zinc_mg"
    }

    /// Convenience view of all micronutrients in one struct.
    var micros: Micronutrients {
        Micronutrients(
            vitaminDMcg: vitaminDMcg,
            vitaminB12Mcg: vitaminB12Mcg,
            vitaminCMg: vitaminCMg,
            magnesiumMg: magnesiumMg,
            ironMg: ironMg,
            zincMg: zincMg
        )
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

    // Micronutrient totals stored on the row for fast aggregation.
    // Nil for legacy rows logged before the micronutrient pipeline.
    var vitaminDMcg: Double?
    var vitaminB12Mcg: Double?
    var vitaminCMg: Double?
    var magnesiumMg: Double?
    var ironMg: Double?
    var zincMg: Double?

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
        case vitaminDMcg   = "vitamin_d_mcg"
        case vitaminB12Mcg = "vitamin_b12_mcg"
        case vitaminCMg    = "vitamin_c_mg"
        case magnesiumMg   = "magnesium_mg"
        case ironMg        = "iron_mg"
        case zincMg        = "zinc_mg"
    }

    /// Convenience: micronutrient totals on this log.
    /// Prefers the row columns; falls back to summing items if they are nil.
    var micros: Micronutrients {
        if vitaminDMcg != nil || vitaminB12Mcg != nil || vitaminCMg != nil
            || magnesiumMg != nil || ironMg != nil || zincMg != nil {
            return Micronutrients(
                vitaminDMcg: vitaminDMcg,
                vitaminB12Mcg: vitaminB12Mcg,
                vitaminCMg: vitaminCMg,
                magnesiumMg: magnesiumMg,
                ironMg: ironMg,
                zincMg: zincMg
            )
        }
        return Micronutrients.sum(items.map { $0.micros })
    }
}

/// One ingredient of a meal idea, sized for a single serving. The portion
/// calculator scales `quantity` by the chosen number of servings.
struct MealIngredient: Codable, Hashable {
    var name: String
    var quantity: Double
    var unit: String
}

/// A meal the user kept in their personal registry, saved from a meal idea.
struct SavedMeal: Codable, Identifiable, Hashable {
    var id: UUID
    var userId: UUID
    var name: String
    var description: String
    var kcal: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var ingredients: [MealIngredient]
    var steps: [String]
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description, kcal
        case userId = "user_id"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case ingredients = "ingredients_json"
        case steps = "steps_json"
        case createdAt = "created_at"
    }

    // Custom decode so rows saved before the recipe columns existed (or any
    // null jsonb) fall back to empty lists instead of failing to decode.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decode(String.self, forKey: .description)
        kcal = try c.decode(Int.self, forKey: .kcal)
        proteinG = try c.decode(Double.self, forKey: .proteinG)
        carbsG = try c.decode(Double.self, forKey: .carbsG)
        fatG = try c.decode(Double.self, forKey: .fatG)
        ingredients = try c.decodeIfPresent([MealIngredient].self, forKey: .ingredients) ?? []
        steps = try c.decodeIfPresent([String].self, forKey: .steps) ?? []
        createdAt = try c.decode(Date.self, forKey: .createdAt)
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
