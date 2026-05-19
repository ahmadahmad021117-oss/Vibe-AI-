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

            let resolved = try await resolveInputs(onboarding: onboarding)
            let sex = resolved.sex
            let age = resolved.age
            let heightCm = resolved.heightCm
            let weightKg = resolved.weightKg
            let trainingDays = resolved.trainingDaysPerWeek
            let goal = resolved.goal
            let focus = resolved.mainFocus
            let healthOn = resolved.healthSyncEnabled
            let pace = resolved.pace

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
                    mainFocus: focus,
                    pace: pace
                )
            )

            stage = .settingProtein
            try await Task.sleep(for: .milliseconds(200))

            stage = .finalizing
            self.inputs = NutritionEngine.Inputs(
                sex: sex, age: age, heightCm: heightCm, weightKg: weightKg,
                trainingDaysPerWeek: trainingDays, avgSteps: avgSteps,
                goal: goal, mainFocus: focus, pace: pace
            )
            self.result = computed
            try await TargetService.shared.writeLatest(computed, inputs: self.inputs!)

            stage = .ready
        } catch {
            errorMessage = error.friendlyMessage
            stage = .failed
        }
    }

    // MARK: - Input resolution

    private struct ResolvedInputs {
        var sex: SexType
        var age: Int
        var heightCm: Double
        var weightKg: Double
        var trainingDaysPerWeek: Int
        var goal: GoalType
        var mainFocus: MainFocus?
        var healthSyncEnabled: Bool
        var pace: Pace
    }

    private func resolveInputs(onboarding: OnboardingState?) async throws -> ResolvedInputs {
        // Fresh-from-onboarding path: every required answer is in memory.
        if let o = onboarding,
           let weight = o.currentWeightKg,
           let age = o.age,
           let sex = o.sex,
           let height = o.heightCm,
           let days = o.trainingDaysPerWeek,
           let goal = o.goal {
            return ResolvedInputs(
                sex: sex, age: age, heightCm: height, weightKg: weight,
                trainingDaysPerWeek: days, goal: goal, mainFocus: o.mainFocus,
                healthSyncEnabled: o.healthSyncEnabled, pace: o.pace
            )
        }

        // Returning-user path: hydrate from Supabase.
        let profile = try await ProfileService.shared.fetchCurrent()
        let latestGoal = try await GoalService.shared.fetchLatest()
        let latestWeight = try? await WeightLogService.shared.fetchLatest()

        guard
            let profile,
            let age = profile.age,
            let sex = profile.sex,
            let height = profile.heightCm,
            let days = profile.trainingDaysPerWeek,
            let latestGoal
        else {
            throw NSError(
                domain: "PlanGenerator", code: -1,
                userInfo: [NSLocalizedDescriptionKey: String(
                    localized: "plan.error.missing_profile",
                    defaultValue: "Missing profile data. Complete onboarding first.",
                    comment: "Shown when the plan generator can't find required onboarding answers"
                )]
            )
        }

        // Weight: latest weight_log if available, else goal start weight.
        let weight = latestWeight?.weightKg ?? latestGoal.startWeightKg

        return ResolvedInputs(
            sex: sex, age: age, heightCm: height, weightKg: weight,
            trainingDaysPerWeek: days, goal: latestGoal.type,
            mainFocus: profile.mainFocus,
            healthSyncEnabled: profile.healthSyncEnabled,
            pace: profile.pace ?? .medium
        )
    }
}
