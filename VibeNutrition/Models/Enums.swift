import Foundation

enum GoalType: String, Codable, CaseIterable, Identifiable {
    case loseWeight = "lose_weight"
    case gainWeight = "gain_weight"
    case buildMuscle = "build_muscle"
    case maintain
    case recomp
    case improveHealth = "improve_health"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .loseWeight: return "Lose weight"
        case .gainWeight: return "Gain weight"
        case .buildMuscle: return "Build muscle"
        case .maintain: return "Maintain weight"
        case .recomp: return "Body recomposition"
        case .improveHealth: return "Improve health"
        }
    }

    /// Direction the goal weight should move relative to the current weight.
    /// Drives both the goal-weight slider default and the validation that
    /// blocks Continue when the user picks a target inconsistent with the goal.
    enum Direction { case up, down, flat }
    var direction: Direction {
        switch self {
        case .gainWeight, .buildMuscle: return .up
        case .loseWeight: return .down
        // Maintain / recomp / improve health all sit around the current weight.
        // Recomp can drift either way but we don't enforce a delta — the user
        // can land exactly on their current weight without seeing a warning.
        case .maintain, .recomp, .improveHealth: return .flat
        }
    }

    /// Reasonable default delta in kg to seed the goal-weight slider with after
    /// the user picks a goal. Avoids the bug where the slider sat at the same
    /// value as the current weight and produced a 0-kg projection.
    var defaultDeltaKg: Double {
        switch direction {
        case .up:   return 5
        case .down: return -5
        case .flat: return 0
        }
    }
}

enum MainFocus: String, Codable, CaseIterable, Identifiable {
    case fatLoss = "fat_loss"
    case muscleGain = "muscle_gain"
    case recomp
    case generalHealth = "general_health"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .fatLoss: return "Fat loss"
        case .muscleGain: return "Muscle gain"
        case .recomp: return "Recomposition"
        case .generalHealth: return "General health"
        }
    }
}

enum DietaryPref: String, Codable, CaseIterable, Identifiable {
    case normal
    case highProtein = "high_protein"
    case vegetarian
    case vegan
    case halal
    case keto

    var id: String { rawValue }
    var label: String {
        switch self {
        case .normal: return "Normal"
        case .highProtein: return "High protein"
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .halal: return "Halal"
        case .keto: return "Keto / low carb"
        }
    }
}

enum UnitsPref: String, Codable, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }
    var label: String {
        switch self {
        case .metric: return "kg / cm"
        case .imperial: return "lb / ft·in"
        }
    }
}

enum SexType: String, Codable, CaseIterable, Identifiable {
    case male, female, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Prefer not to say"
        }
    }
}

enum NotificationPref: String, Codable, CaseIterable, Identifiable {
    case full
    case important
    case off

    var id: String { rawValue }
    var label: String {
        switch self {
        case .full: return "Full updates"
        case .important: return "Important only"
        case .off: return "Off"
        }
    }
}

enum LogSource: String, Codable { case scan, manual }
enum ActivitySource: String, Codable {
    case appleHealth = "apple_health"
    case googleFit = "google_fit"
    case manual
}
enum EntitlementTier: String, Codable { case free, premium }

/// How aggressively the user wants to move toward their goal.
/// Used to size the daily calorie surplus/deficit (cap-limited by NutritionEngine).
enum Pace: String, Codable, CaseIterable, Identifiable {
    case slow
    case medium
    case fast

    var id: String { rawValue }

    var label: String {
        switch self {
        case .slow: return "Slow & steady"
        case .medium: return "Balanced"
        case .fast: return "Faster"
        }
    }

    var subtitle: String {
        switch self {
        case .slow: return "About 0.25 kg / week"
        case .medium: return "About 0.5 kg / week"
        case .fast: return "About 0.75 kg / week"
        }
    }

    /// Target absolute weight delta per week, in kg.
    /// Applies as a deficit for loss goals and a surplus for gain goals.
    var weeklyKg: Double {
        switch self {
        case .slow:   return 0.25
        case .medium: return 0.50
        case .fast:   return 0.75
        }
    }
}
