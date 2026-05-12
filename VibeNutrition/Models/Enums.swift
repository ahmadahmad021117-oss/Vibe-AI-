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
    var label: String { rawValue.capitalized }
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
