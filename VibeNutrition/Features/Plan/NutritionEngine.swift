import Foundation

/// Pure functions — no IO, fully unit-testable.
enum NutritionEngine {

    // MARK: - Inputs

    struct Inputs: Codable, Hashable {
        var sex: SexType
        var age: Int
        var heightCm: Double
        var weightKg: Double
        var trainingDaysPerWeek: Int
        var avgSteps: Int?        // optional from HealthKit
        var goal: GoalType
        var mainFocus: MainFocus?
        /// User-selected pace. Optional for backward compat — defaults to .medium when nil.
        var pace: Pace?
    }

    // MARK: - Outputs

    struct Result: Codable, Hashable {
        var bmr: Int
        var activityMultiplier: Double
        var tdee: Int
        var kcalTarget: Int
        var proteinG: Int
        var carbsG: Int
        var fatG: Int
        /// Estimated weight change per week in kg (negative = loss).
        var weeklyDeltaKg: Double
    }

    // MARK: - BMR (Mifflin–St Jeor)

    /// Returns BMR in kilocalories/day.
    /// male:   10·kg + 6.25·cm − 5·age + 5
    /// female: 10·kg + 6.25·cm − 5·age − 161
    /// other:  average of the two (no validated MSJ for nonbinary; this is a reasonable default).
    static func bmrMifflinStJeor(sex: SexType, age: Int, heightCm: Double, weightKg: Double) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        case .other: return base + (5 - 161) / 2.0   // = base − 78
        }
    }

    // MARK: - Activity multiplier

    /// Combines training frequency and optional step data.
    /// Training-day baseline:
    ///   0 days → 1.30 (sedentary-to-light, very lean default)
    ///   1–2  → 1.40
    ///   3–4  → 1.55
    ///   5–6  → 1.70
    ///   7    → 1.80
    /// Step adjustment: +0.025 per 2.5k steps over 5k, capped at +0.10.
    static func activityMultiplier(trainingDaysPerWeek: Int, avgSteps: Int?) -> Double {
        let base: Double
        switch trainingDaysPerWeek {
        case ...0:   base = 1.30
        case 1...2:  base = 1.40
        case 3...4:  base = 1.55
        case 5...6:  base = 1.70
        default:     base = 1.80
        }

        guard let steps = avgSteps, steps > 5000 else { return base }
        let over = Double(steps - 5000)
        let bump = (over / 2500.0) * 0.025
        return base + min(bump, 0.10)
    }

    // MARK: - TDEE

    static func tdee(bmr: Double, multiplier: Double) -> Double {
        bmr * multiplier
    }

    // MARK: - Macro targets

    /// Calorie deficit/surplus depending on goal, capped at ±20% TDEE.
    /// Returns (kcalTarget, weeklyDeltaKg).
    /// 7700 kcal ≈ 1 kg body mass (rough but standard).
    /// Kept for back-compat / tests; uses a fixed pace per goal.
    static func goalAdjustedKcal(tdee: Double, goal: GoalType) -> (kcal: Int, weeklyDeltaKg: Double) {
        let defaultPace: Pace? = {
            switch goal {
            case .loseWeight, .gainWeight, .buildMuscle: return .medium
            case .recomp:                                return .slow
            case .maintain, .improveHealth:              return nil
            }
        }()
        return goalAdjustedKcal(tdee: tdee, goal: goal, pace: defaultPace)
    }

    /// Calorie deficit/surplus driven by the user's selected pace.
    /// Falls back to a sensible default per goal when `pace` is nil.
    /// Cap at ±20 % TDEE so even "fast" stays sane for small users.
    /// Maintain / improveHealth / recomp ignore pace by design.
    static func goalAdjustedKcal(
        tdee: Double,
        goal: GoalType,
        pace: Pace?
    ) -> (kcal: Int, weeklyDeltaKg: Double) {
        let cap = 0.20

        // Goals that are pace-insensitive use a fixed percentage adjustment.
        // (Recomp is intentionally mild; maintain / improveHealth are zero.)
        if let fixedPct = fixedPercentageFor(goal: goal) {
            let target = tdee * (1 + fixedPct)
            let weeklyKg = ((target - tdee) * 7) / 7700.0
            return (Int(target.rounded()), weeklyKg)
        }

        let effectivePace = pace ?? .medium
        let direction: Double = (goal == .loseWeight) ? -1 : 1
        let weeklyKg = effectivePace.weeklyKg * direction
        let dailyDeltaKcal = (weeklyKg * 7700) / 7.0
        var target = tdee + dailyDeltaKcal
        // Clamp to ±20 % TDEE.
        let lo = tdee * (1 - cap)
        let hi = tdee * (1 + cap)
        target = min(hi, max(lo, target))
        // Recompute actual weekly delta after clamping.
        let actualDailyDelta = target - tdee
        let actualWeeklyKg = (actualDailyDelta * 7) / 7700.0
        return (Int(target.rounded()), actualWeeklyKg)
    }

    /// Returns the fixed percentage adjustment for goals that don't honor pace.
    /// Returns nil for goals (lose / gain / build) that scale with pace.
    private static func fixedPercentageFor(goal: GoalType) -> Double? {
        switch goal {
        case .maintain, .improveHealth: return  0.0
        case .recomp:                   return -0.05   // mild deficit, unchanged from v1
        case .loseWeight, .gainWeight, .buildMuscle: return nil
        }
    }

    /// Protein g/kg by goal — priority macro.
    /// build/recomp → 2.2, lose → 2.0, gain/maintain → 1.8, health → 1.6.
    static func proteinTargetGramsPerKg(goal: GoalType) -> Double {
        switch goal {
        case .buildMuscle, .recomp: return 2.2
        case .loseWeight:           return 2.0
        case .gainWeight, .maintain:return 1.8
        case .improveHealth:        return 1.6
        }
    }

    /// Compute macro split for the given kcal target.
    /// Protein first (priority), then fat floor ≥ 0.8 g/kg (9 kcal/g), remainder → carbs (4 kcal/g).
    /// If protein+fat alone exceed kcal target, trim fat to the floor and let carbs hit 0.
    static func macros(kcalTarget: Int, weightKg: Double, goal: GoalType)
        -> (proteinG: Int, carbsG: Int, fatG: Int)
    {
        let proteinG = max(0, weightKg * proteinTargetGramsPerKg(goal: goal))
        let proteinKcal = proteinG * 4

        let fatFloorG = max(0, weightKg * 0.8)
        let fatFloorKcal = fatFloorG * 9

        let kcal = Double(kcalTarget)
        let remainingAfterProtein = max(0, kcal - proteinKcal)

        // If protein already eats most of kcal, fat = floor, carbs = whatever remains.
        let fatKcal = min(remainingAfterProtein, max(fatFloorKcal, remainingAfterProtein * 0.30))
        let fatG = fatKcal / 9.0

        let remainingAfterFat = max(0, kcal - proteinKcal - fatKcal)
        let carbsG = remainingAfterFat / 4.0

        return (
            Int(proteinG.rounded()),
            Int(carbsG.rounded()),
            Int(fatG.rounded())
        )
    }

    // MARK: - One-shot compute

    static func compute(_ inputs: Inputs) -> Result {
        let bmr = bmrMifflinStJeor(
            sex: inputs.sex, age: inputs.age,
            heightCm: inputs.heightCm, weightKg: inputs.weightKg
        )
        let mult = activityMultiplier(
            trainingDaysPerWeek: inputs.trainingDaysPerWeek,
            avgSteps: inputs.avgSteps
        )
        let tdeeKcal = tdee(bmr: bmr, multiplier: mult)
        let (kcalTarget, weeklyDelta) = goalAdjustedKcal(
            tdee: tdeeKcal, goal: inputs.goal, pace: inputs.pace
        )
        let m = macros(kcalTarget: kcalTarget, weightKg: inputs.weightKg, goal: inputs.goal)

        return Result(
            bmr: Int(bmr.rounded()),
            activityMultiplier: mult,
            tdee: Int(tdeeKcal.rounded()),
            kcalTarget: kcalTarget,
            proteinG: m.proteinG,
            carbsG: m.carbsG,
            fatG: m.fatG,
            weeklyDeltaKg: weeklyDelta
        )
    }

    // MARK: - Weight projection

    /// One point on the projection chart.
    struct ProjectionPoint: Hashable {
        var weekIndex: Int
        var weightKg: Double
        var date: Date
    }

    /// Project a straight-line trajectory from `currentKg` toward `goalKg` at the given pace.
    /// - If the goal direction conflicts with the goal type (e.g. user picked "lose weight"
    ///   but goalKg > currentKg) the engine ignores the conflict and projects toward `goalKg`.
    /// - Returns at least the starting point. Empty pace / equal weights → just the start.
    /// - `maxWeeks` keeps the chart bounded for very small paces or unreachable goals.
    static func projectWeeks(
        currentKg: Double,
        goalKg: Double,
        pace: Pace,
        maxWeeks: Int = 104,
        startingFrom start: Date = Date()
    ) -> [ProjectionPoint] {
        let diff = goalKg - currentKg
        if abs(diff) < 0.05 {
            return [ProjectionPoint(weekIndex: 0, weightKg: currentKg, date: start)]
        }
        let direction: Double = diff > 0 ? 1 : -1
        let perWeek = pace.weeklyKg * direction
        let weeksToGoal = Int(ceil(abs(diff) / pace.weeklyKg))
        let weeks = min(maxWeeks, max(1, weeksToGoal))

        var points: [ProjectionPoint] = []
        for week in 0...weeks {
            let projected = currentKg + perWeek * Double(week)
            let clamped: Double
            if direction > 0 {
                clamped = min(goalKg, projected)
            } else {
                clamped = max(goalKg, projected)
            }
            let date = Calendar.current.date(byAdding: .weekOfYear, value: week, to: start) ?? start
            points.append(ProjectionPoint(weekIndex: week, weightKg: clamped, date: date))
        }
        return points
    }

    /// Weeks (rounded up) to reach `goalKg` from `currentKg` at the given pace.
    /// Returns 0 if the weights are essentially equal.
    static func weeksToReach(currentKg: Double, goalKg: Double, pace: Pace) -> Int {
        let diff = abs(goalKg - currentKg)
        if diff < 0.05 { return 0 }
        return max(1, Int(ceil(diff / pace.weeklyKg)))
    }

    /// Goal-realism check, called by the projection view.
    /// "Unhealthy" if the user is targeting an underweight BMI (<18.5) or an obese-class-II BMI (>35).
    /// Returns nil when the goal is sensible.
    static func goalRealismWarning(
        heightCm: Double?,
        goalKg: Double,
        currentKg: Double
    ) -> String? {
        guard let heightCm, heightCm > 0 else { return nil }
        let heightM = heightCm / 100
        let bmi = goalKg / (heightM * heightM)
        if bmi < 18.5 {
            return "This goal puts your BMI below 18.5 (underweight)."
        }
        if bmi > 35 {
            return "This goal puts your BMI above 35 (severe obesity range)."
        }
        // Also flag very large absolute swings, regardless of BMI.
        if abs(goalKg - currentKg) > 40 {
            return "That's a very large change — please consult a clinician."
        }
        return nil
    }
}
