import Foundation
import Observation

/// All onboarding answers + the current step. Persisted locally so a kill resumes mid-flow.
/// Onboarding runs before sign-in, so `commit()` only reaches Supabase once a user exists
/// (the services guard on `userId`); RootCoordinator drives the authoritative write after
/// Apple sign-in.
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
    // Default is true: matches the "Recommended" badge on HealthSyncScreen so
    // the row labeled Recommended is the row that's actually pre-selected.
    // The system permission sheet still gates real data access.
    var healthSyncEnabled: Bool = true
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
        // Decode into locals first — `Decoder` is non-isolated, but the property
        // assignments below cross into MainActor territory.
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let goal = try c.decodeIfPresent(GoalType.self, forKey: .goal)
        let unitsPref = try c.decodeIfPresent(UnitsPref.self, forKey: .unitsPref) ?? .metric
        let currentWeightKg = try c.decodeIfPresent(Double.self, forKey: .currentWeightKg)
        let goalWeightKg = try c.decodeIfPresent(Double.self, forKey: .goalWeightKg)
        let pace = try c.decodeIfPresent(Pace.self, forKey: .pace) ?? .medium
        let age = try c.decodeIfPresent(Int.self, forKey: .age)
        let sex = try c.decodeIfPresent(SexType.self, forKey: .sex)
        let heightCm = try c.decodeIfPresent(Double.self, forKey: .heightCm)
        let healthSyncEnabled = try c.decodeIfPresent(Bool.self, forKey: .healthSyncEnabled) ?? true
        let trainingDaysPerWeek = try c.decodeIfPresent(Int.self, forKey: .trainingDaysPerWeek)
        let mainFocus = try c.decodeIfPresent(MainFocus.self, forKey: .mainFocus)
        let mealsPerDay = try c.decodeIfPresent(Int.self, forKey: .mealsPerDay)
        let dietaryPref = try c.decodeIfPresent(DietaryPref.self, forKey: .dietaryPref) ?? .normal
        let mealSuggestionsEnabled = try c.decodeIfPresent(Bool.self, forKey: .mealSuggestionsEnabled) ?? true
        let notificationPref = try c.decodeIfPresent(NotificationPref.self, forKey: .notificationPref) ?? .important
        let step = try c.decodeIfPresent(OnboardingStep.self, forKey: .step) ?? .goal
        // Decoding is only ever invoked from `restore()`, which is MainActor-isolated.
        MainActor.assumeIsolated {
            self.goal = goal
            self.unitsPref = unitsPref
            self.currentWeightKg = currentWeightKg
            self.goalWeightKg = goalWeightKg
            self.pace = pace
            self.age = age
            self.sex = sex
            self.heightCm = heightCm
            self.healthSyncEnabled = healthSyncEnabled
            self.trainingDaysPerWeek = trainingDaysPerWeek
            self.mainFocus = mainFocus
            self.mealsPerDay = mealsPerDay
            self.dietaryPref = dietaryPref
            self.mealSuggestionsEnabled = mealSuggestionsEnabled
            self.notificationPref = notificationPref
            self.step = step
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        // Encoding is only ever invoked from `persist()`, which is MainActor-isolated.
        try MainActor.assumeIsolated {
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
        case .goalWeight: return isGoalWeightConsistent
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

    /// True when the goal weight makes sense for the chosen goal direction.
    /// "Gain weight" with goal == current produced a 0-kg/week projection and
    /// the misleading "Maintain · Balanced" pace card; we now block Continue
    /// until the user actually picks a target in the right direction.
    var isGoalWeightConsistent: Bool {
        guard let goal, let cur = currentWeightKg, let target = goalWeightKg else {
            return goalWeightKg != nil
        }
        switch goal.direction {
        case .up:   return target > cur + 0.4   // 0.4kg slack to absorb slider step
        case .down: return target < cur - 0.4
        case .flat: return true
        }
    }

    /// Inline copy shown on the goal-weight screen when the slider is in a
    /// direction that contradicts the chosen goal.
    var goalWeightHint: String? {
        guard let goal, let cur = currentWeightKg, let target = goalWeightKg else { return nil }
        switch goal.direction {
        case .up where target <= cur + 0.4:
            return "Pick a target above your current weight."
        case .down where target >= cur - 0.4:
            return "Pick a target below your current weight."
        default:
            return nil
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
        // Defensive guard: if persisted state somehow lands on `.done`
        // (the terminal step), the coordinator would render EmptyView with
        // no signal to re-fire onComplete — a black screen with no escape.
        // Start the next session fresh instead.
        if restored.step == .done { return OnboardingState() }
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
}
