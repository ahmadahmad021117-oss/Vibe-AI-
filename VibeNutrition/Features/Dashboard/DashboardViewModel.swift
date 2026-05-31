import Foundation
import Observation
import WidgetKit

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
    private(set) var waterConsumedMl: Int = 0
    var pace: Pace = .medium

    /// Daily hydration goal (ml), from the profile. Falls back to 2000.
    var waterGoalMl: Int { profile?.waterGoalMl ?? 2000 }
    var waterProgress: Double {
        guard waterGoalMl > 0 else { return 0 }
        return min(1, Double(waterConsumedMl) / Double(waterGoalMl))
    }
    /// Last 7 days of bucketed kcal totals (oldest → newest). Powers the
    /// calorie-history chart on the Progress tab.
    private(set) var weeklyKcalHistory: [FoodLogService.DailyKcal] = []

    var kcalConsumed: Int { todayLogs.reduce(0) { $0 + $1.kcal } }
    var proteinConsumed: Double { todayLogs.reduce(0) { $0 + $1.proteinG } }
    var carbsConsumed: Double { todayLogs.reduce(0) { $0 + $1.carbsG } }
    var fatConsumed: Double { todayLogs.reduce(0) { $0 + $1.fatG } }

    var kcalRemaining: Int { max(0, (target?.kcal ?? 0) - kcalConsumed) }
    var proteinRemaining: Double { max(0, Double(target?.proteinG ?? 0) - proteinConsumed) }
    var carbsRemaining: Double { max(0, Double(target?.carbsG ?? 0) - carbsConsumed) }
    var fatRemaining: Double { max(0, Double(target?.fatG ?? 0) - fatConsumed) }

    /// Kilocalories above the daily target. Zero when the user is still under.
    /// Used to drive the "over" state on the home ring instead of silently clamping
    /// `kcalRemaining` to 0 (which left users staring at "0 kcal left" with no way
    /// to tell whether they had hit the target exactly or blown past it).
    var kcalOver: Int { max(0, kcalConsumed - (target?.kcal ?? 0)) }
    var isOverTarget: Bool { kcalOver > 0 }

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
        // Persist any water the user logged straight from the widget before we
        // read today's total, so the dashboard reflects those taps.
        await drainPendingWidgetWater()
        do {
            async let targetTask = withRetry { try await TargetService.shared.fetchLatest() }
            async let logsTask = withRetry { try await FoodLogService.shared.fetchToday() }
            async let weeklyTask = withRetry { try await FoodLogService.shared.fetchDailyKcal(days: 7) }
            async let streakTask = withRetry { try await StreakService.shared.currentStreak() }
            async let profileTask = withRetry { try await ProfileService.shared.fetchCurrent() }
            async let goalTask = withRetry { try await GoalService.shared.fetchLatest() }
            async let weightTask = withRetry { try await WeightLogService.shared.fetchLatest() }
            async let waterTask = withRetry { try await WaterLogService.shared.todayTotalMl() }
            self.target = try await targetTask
            self.todayLogs = try await logsTask
            self.weeklyKcalHistory = try await weeklyTask
            self.streak = try await streakTask
            let profile = try await profileTask
            self.profile = profile
            self.latestGoal = try await goalTask
            self.latestWeight = try await weightTask
            self.waterConsumedMl = try await waterTask
            self.pace = profile?.pace ?? .medium
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.friendlyMessage
        }
        publishWidgetSnapshot()
    }

    /// Logs a quantity of water (ml) and refreshes the total + widget.
    func addWater(ml: Int) async {
        // Optimistic so the ring fills instantly; reconciled from the server total.
        waterConsumedMl += ml
        publishWidgetSnapshot()
        do {
            try await WaterLogService.shared.write(amountMl: ml)
            waterConsumedMl = try await WaterLogService.shared.todayTotalMl()
        } catch {
            errorMessage = error.friendlyMessage
        }
        publishWidgetSnapshot()
    }

    /// Updates the daily hydration goal on the profile and refreshes the widget.
    func setWaterGoal(ml: Int) async {
        do {
            try await ProfileService.shared.upsert(ProfilePatch(waterGoalMl: ml))
            profile?.waterGoalMl = ml
            publishWidgetSnapshot()
        } catch {
            errorMessage = error.friendlyMessage
        }
    }

    /// Flushes water amounts queued by the widget's interactive button into
    /// Supabase. Best-effort: a failed write is dropped rather than retried,
    /// since the optimistic widget total already reflected it.
    private func drainPendingWidgetWater() async {
        let pending = SharedStore.drainPendingWater()
        guard !pending.isEmpty else { return }
        for ml in pending {
            try? await WaterLogService.shared.write(amountMl: ml)
        }
    }

    func delete(log: FoodLog) async {
        do {
            try await FoodLogService.shared.delete(id: log.id)
            todayLogs.removeAll { $0.id == log.id }
            publishWidgetSnapshot()
        } catch {
            errorMessage = error.friendlyMessage
        }
    }

    /// Push today's calorie state to the App Group so the home/lock-screen
    /// widgets can render it, then ask WidgetKit to refresh.
    private func publishWidgetSnapshot() {
        let snapshot = CalorieSnapshot(
            kcalConsumed: kcalConsumed,
            kcalTarget: target?.kcal ?? 0,
            waterMl: waterConsumedMl,
            waterGoalMl: waterGoalMl,
            day: Calendar.current.startOfDay(for: Date())
        )
        SharedStore.writeSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
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
