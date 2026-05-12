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
    static func goalAdjustedKcal(tdee: Double, goal: GoalType) -> (kcal: Int, weeklyDeltaKg: Double) {
        let cap = 0.20
        let pct: Double = {
            switch goal {
            case .loseWeight:    return -0.20
            case .gainWeight:    return  0.15
            case .buildMuscle:   return  0.10
            case .maintain:      return  0.0
            case .recomp:        return -0.05
            case .improveHealth: return  0.0
            }
        }()
        let clamped = max(-cap, min(cap, pct))
        let target = tdee * (1 + clamped)
        let dailyDelta = target - tdee
        let weeklyKcal = dailyDelta * 7
        let weeklyKg = weeklyKcal / 7700.0
        return (Int(target.rounded()), weeklyKg)
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
        let (kcalTarget, weeklyDelta) = goalAdjustedKcal(tdee: tdeeKcal, goal: inputs.goal)
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
}
