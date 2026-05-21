import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var target: NutritionTarget?
    private(set) var todayLogs: [FoodLog] = []
    private(set) var streak: Int = 0
    private(set) var isLoading: Bool = true
    var errorMessage: String?
    private(set) var profile: Profile?
    private(set) var latestGoal: Goal?
    private(set) var latestWeight: WeightLog?
    var pace: Pace = .medium

    var kcalConsumed: Int { todayLogs.reduce(0) { $0 + $1.kcal } }
    var proteinConsumed: Double { todayLogs.reduce(0) { $0 + $1.proteinG } }
    var carbsConsumed: Double { todayLogs.reduce(0) { $0 + $1.carbsG } }
    var fatConsumed: Double { todayLogs.reduce(0) { $0 + $1.fatG } }

    var kcalRemaining: Int { max(0, (target?.kcal ?? 0) - kcalConsumed) }
    var proteinRemaining: Double { max(0, Double(target?.proteinG ?? 0) - proteinConsumed) }
    var carbsRemaining: Double { max(0, Double(target?.carbsG ?? 0) - carbsConsumed) }
    var fatRemaining: Double { max(0, Double(target?.fatG ?? 0) - fatConsumed) }

    var kcalProgress: Double {
        guard let t = target, t.kcal > 0 else { return 0 }
        return min(1.5, Double(kcalConsumed) / Double(t.kcal))
    }

    /// Summed micronutrients across today's logs.
    var microsConsumed: Micronutrients {
        Micronutrients.sum(todayLogs.map { $0.micros })
    }

    /// Daily target micronutrients, derived from profile sex.
    var microsTarget: Micronutrients {
        DailyIntake.recommended(sex: profile?.sex)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let targetTask = withRetry { try await TargetService.shared.fetchLatest() }
            async let logsTask = withRetry { try await FoodLogService.shared.fetchToday() }
            async let streakTask = withRetry { try await StreakService.shared.currentStreak() }
            async let profileTask = withRetry { try await ProfileService.shared.fetchCurrent() }
            async let goalTask = withRetry { try await GoalService.shared.fetchLatest() }
            async let weightTask = withRetry { try await WeightLogService.shared.fetchLatest() }
            self.target = try await targetTask
            self.todayLogs = try await logsTask
            self.streak = try await streakTask
            let profile = try await profileTask
            self.profile = profile
            self.latestGoal = try await goalTask
            self.latestWeight = try await weightTask
            self.pace = profile?.pace ?? .medium
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.friendlyMessage
        }
    }

    func delete(log: FoodLog) async {
        do {
            try await FoodLogService.shared.delete(id: log.id)
            todayLogs.removeAll { $0.id == log.id }
        } catch {
            errorMessage = error.friendlyMessage
        }
    }

    func saveCurrentWeight(_ kg: Double) async {
        do {
            try await WeightLogService.shared.write(weightKg: kg)
            latestWeight = try await WeightLogService.shared.fetchLatest()
            await recomputePlan()
        } catch {
            errorMessage = error.friendlyMessage
        }
    }

    func saveGoalWeight(_ kg: Double) async {
        do {
            try await GoalService.shared.updateGoalWeight(kg)
            latestGoal = try await GoalService.shared.fetchLatest()
            await recomputePlan()
        } catch {
            errorMessage = error.friendlyMessage
        }
    }

    func savePace(_ newPace: Pace) async {
        pace = newPace
        do {
            try await ProfileService.shared.upsert(ProfilePatch(pace: newPace))
            profile?.pace = newPace
            await recomputePlan()
        } catch {
            errorMessage = error.friendlyMessage
        }
    }

    private func recomputePlan() async {
        let gen = PlanGenerator()
        await gen.run(using: nil)
        self.target = try? await TargetService.shared.fetchLatest()
    }
}
