import Foundation
import Observation

/// All onboarding answers + the current step. Persisted locally so a kill resumes mid-flow,
/// then synced to Supabase via `commit()` when each answer settles.
@MainActor
@Observable
final class OnboardingState: Codable {
    // MARK: - Answers
    var goal: GoalType?
    var unitsPref: UnitsPref = .metric
    var currentWeightKg: Double?
    var goalWeightKg: Double?
    var pace: Pace = .medium
    var age: Int?
    var sex: SexType?
    var heightCm: Double?
    var healthSyncEnabled: Bool = false
    var trainingDaysPerWeek: Int?
    var mainFocus: MainFocus?
    var mealsPerDay: Int?
    var dietaryPref: DietaryPref = .normal
    var mealSuggestionsEnabled: Bool = true
    var notificationPref: NotificationPref = .important

    // MARK: - Navigation
    var step: OnboardingStep = .goal

    // MARK: - Codable (manual, because Observation property wrappers don't auto-synthesize)
    enum CodingKeys: String, CodingKey {
        case goal, unitsPref, currentWeightKg, goalWeightKg, pace, age, sex, heightCm,
             healthSyncEnabled, trainingDaysPerWeek, mainFocus, mealsPerDay,
             dietaryPref, mealSuggestionsEnabled, notificationPref, step
    }

    init() {}

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goal = try c.decodeIfPresent(GoalType.self, forKey: .goal)
        unitsPref = try c.decodeIfPresent(UnitsPref.self, forKey: .unitsPref) ?? .metric
        currentWeightKg = try c.decodeIfPresent(Double.self, forKey: .currentWeightKg)
        goalWeightKg = try c.decodeIfPresent(Double.self, forKey: .goalWeightKg)
        pace = try c.decodeIfPresent(Pace.self, forKey: .pace) ?? .medium
        age = try c.decodeIfPresent(Int.self, forKey: .age)
        sex = try c.decodeIfPresent(SexType.self, forKey: .sex)
        heightCm = try c.decodeIfPresent(Double.self, forKey: .heightCm)
        healthSyncEnabled = try c.decodeIfPresent(Bool.self, forKey: .healthSyncEnabled) ?? false
        trainingDaysPerWeek = try c.decodeIfPresent(Int.self, forKey: .trainingDaysPerWeek)
        mainFocus = try c.decodeIfPresent(MainFocus.self, forKey: .mainFocus)
        mealsPerDay = try c.decodeIfPresent(Int.self, forKey: .mealsPerDay)
        dietaryPref = try c.decodeIfPresent(DietaryPref.self, forKey: .dietaryPref) ?? .normal
        mealSuggestionsEnabled = try c.decodeIfPresent(Bool.self, forKey: .mealSuggestionsEnabled) ?? true
        notificationPref = try c.decodeIfPresent(NotificationPref.self, forKey: .notificationPref) ?? .important
        step = try c.decodeIfPresent(OnboardingStep.self, forKey: .step) ?? .goal
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(goal, forKey: .goal)
        try c.encode(unitsPref, forKey: .unitsPref)
        try c.encodeIfPresent(currentWeightKg, forKey: .currentWeightKg)
        try c.encodeIfPresent(goalWeightKg, forKey: .goalWeightKg)
        try c.encode(pace, forKey: .pace)
        try c.encodeIfPresent(age, forKey: .age)
        try c.encodeIfPresent(sex, forKey: .sex)
        try c.encodeIfPresent(heightCm, forKey: .heightCm)
        try c.encode(healthSyncEnabled, forKey: .healthSyncEnabled)
        try c.encodeIfPresent(trainingDaysPerWeek, forKey: .trainingDaysPerWeek)
        try c.encodeIfPresent(mainFocus, forKey: .mainFocus)
        try c.encodeIfPresent(mealsPerDay, forKey: .mealsPerDay)
        try c.encode(dietaryPref, forKey: .dietaryPref)
        try c.encode(mealSuggestionsEnabled, forKey: .mealSuggestionsEnabled)
        try c.encode(notificationPref, forKey: .notificationPref)
        try c.encode(step, forKey: .step)
    }

    // MARK: - Progress
    var progress: Double {
        let total = Double(OnboardingStep.visibleSteps.count)
        let current = Double(step.rawValue)
        return min(1, current / total)
    }

    var canAdvance: Bool {
        switch step {
        case .goal: return goal != nil
        case .currentWeight: return currentWeightKg != nil
        case .goalWeight: return goalWeightKg != nil
        case .pace: return true  // pace defaults to .medium so always valid
        case .age: return age != nil
        case .sex: return sex != nil
        case .height: return heightCm != nil
        case .healthSync: return true
        case .trainingDays: return trainingDaysPerWeek != nil
        case .mainFocus: return mainFocus != nil
        case .mealsPerDay: return mealsPerDay != nil
        case .dietaryPref: return true
        case .mealSuggestions: return true
        case .notifications: return true
        case .done: return true
        }
    }

    // MARK: - Navigation helpers
    func advance() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        step = next
        persist()
    }

    func goBack() {
        guard step.rawValue > 0,
              let prev = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        step = prev
        persist()
    }

    // MARK: - Persistence
    private static let storeKey = "vibe.onboarding.v1"

    func persist() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: Self.storeKey)
        } catch {
            // best-effort; resume just starts from beginning
        }
    }

    static func restore() -> OnboardingState {
        guard
            let data = UserDefaults.standard.data(forKey: storeKey),
            let restored = try? JSONDecoder().decode(OnboardingState.self, from: data)
        else { return OnboardingState() }
        return restored
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storeKey)
    }

    // MARK: - Sync to Supabase
    func commit() async {
        let patch = ProfilePatch(
            age: age,
            sex: sex,
            heightCm: heightCm,
            dietaryPref: dietaryPref,
            unitsPref: unitsPref,
            mealsPerDay: mealsPerDay,
            trainingDaysPerWeek: trainingDaysPerWeek,
            mainFocus: mainFocus,
            mealSuggestionsEnabled: mealSuggestionsEnabled,
            notificationPref: notificationPref,
            healthSyncEnabled: healthSyncEnabled,
            pace: pace
        )
        do {
            try await ProfileService.shared.upsert(patch)
            if let goal, let currentWeightKg, let goalWeightKg {
                try await GoalService.shared.upsertActiveGoal(
                    type: goal,
                    startWeightKg: currentWeightKg,
                    goalWeightKg: goalWeightKg
                )
            }
        } catch {
            // Surface in UI later; persistence keeps the answers locally.
        }
    }

    func finish() async {
        await commit()
        try? await ProfileService.shared.markOnboardingComplete()
        Self.clear()
    }
}
