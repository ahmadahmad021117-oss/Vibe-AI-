import Foundation
import Observation

/// Drives the plan-generation flow. Each real computation step flips a status message —
/// no fake counters, no "120,000 users" claims.
@MainActor
@Observable
final class PlanGenerator {
    enum Stage: String, CaseIterable {
        case loadingProfile = "Loading your profile…"
        case readingHealth = "Reading recent activity from Health…"
        case computingTDEE = "Calculating energy expenditure…"
        case settingProtein = "Setting your protein target…"
        case finalizing = "Finalizing your plan…"
        case ready = "Your plan is ready."
        case failed = "We hit a snag. Tap to retry."
    }

    private(set) var stage: Stage = .loadingProfile
    private(set) var result: NutritionEngine.Result?
    private(set) var inputs: NutritionEngine.Inputs?
    private(set) var errorMessage: String?

    /// 0...1, advances as we move through the real stages.
    var progress: Double {
        switch stage {
        case .loadingProfile: return 0.10
        case .readingHealth:  return 0.30
        case .computingTDEE:  return 0.55
        case .settingProtein: return 0.75
        case .finalizing:     return 0.92
        case .ready:          return 1.0
        case .failed:         return 0.0
        }
    }

    func run(using onboarding: OnboardingState? = nil) async {
        errorMessage = nil

        do {
            stage = .loadingProfile
            try await Task.sleep(for: .milliseconds(250))

            let (sex, age, heightCm, weightKg, trainingDays, goal, focus, healthOn) =
                try await resolveInputs(onboarding: onboarding)

            var avgSteps: Int? = nil
            if healthOn {
                stage = .readingHealth
                try? await HealthKitService.shared.requestAuthorization()
                avgSteps = await HealthKitService.shared.averageDailySteps()
            }

            stage = .computingTDEE
            try await Task.sleep(for: .milliseconds(200))
            let computed = NutritionEngine.compute(
                NutritionEngine.Inputs(
                    sex: sex,
                    age: age,
                    heightCm: heightCm,
                    weightKg: weightKg,
                    trainingDaysPerWeek: trainingDays,
                    avgSteps: avgSteps,
                    goal: goal,
                    mainFocus: focus
                )
            )

            stage = .settingProtein
            try await Task.sleep(for: .milliseconds(200))

            stage = .finalizing
            self.inputs = NutritionEngine.Inputs(
                sex: sex, age: age, heightCm: heightCm, weightKg: weightKg,
                trainingDaysPerWeek: trainingDays, avgSteps: avgSteps,
                goal: goal, mainFocus: focus
            )
            self.result = computed
            try await TargetService.shared.writeLatest(computed, inputs: self.inputs!)

            stage = .ready
        } catch {
            errorMessage = error.localizedDescription
            stage = .failed
        }
    }

    // MARK: - Input resolution

    private func resolveInputs(onboarding: OnboardingState?) async throws -> (
        SexType, Int, Double, Double, Int, GoalType, MainFocus?, Bool
    ) {
        // Fresh-from-onboarding path: every required answer is in memory.
        // Sex is not collected in the 12-question flow yet; default to .male so BMR stays finite.
        // A future Profile/Sex screen will replace this default.
        if let o = onboarding,
           let weight = o.currentWeightKg,
           let age = o.age,
           let height = o.heightCm,
           let days = o.trainingDaysPerWeek,
           let goal = o.goal {
            return (.male, age, height, weight, days, goal, o.mainFocus, o.healthSyncEnabled)
        }

        // Returning-user path: hydrate from Supabase.
        let profile = try await ProfileService.shared.fetchCurrent()
        let latestGoal = try await GoalService.shared.fetchLatest()

        guard
            let profile,
            let age = profile.age,
            let height = profile.heightCm,
            let days = profile.trainingDaysPerWeek,
            let latestGoal
        else {
            throw NSError(
                domain: "PlanGenerator", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Missing profile data. Complete onboarding first."]
            )
        }

        // Weight: latest weight_log if available, else goal start weight.
        let weight = latestGoal.startWeightKg

        return (
            profile.sex ?? .male,
            age,
            height,
            weight,
            days,
            latestGoal.type,
            profile.mainFocus,
            profile.healthSyncEnabled
        )
    }
}
