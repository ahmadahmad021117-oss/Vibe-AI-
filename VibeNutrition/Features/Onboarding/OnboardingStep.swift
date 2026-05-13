import Foundation

enum OnboardingStep: Int, CaseIterable, Identifiable, Codable {
    case goal = 0
    case currentWeight
    case goalWeight
    case age
    case sex
    case height
    case healthSync
    case trainingDays
    case mainFocus
    case mealsPerDay
    case dietaryPref
    case mealSuggestions
    case notifications
    case done

    var id: Int { rawValue }

    /// Steps that count toward the progress bar (exclude `.done`).
    static var visibleSteps: [OnboardingStep] {
        allCases.filter { $0 != .done }
    }
}
