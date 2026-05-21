import XCTest
@testable import VibeNutrition

final class NutritionEngineTests: XCTestCase {

    // MARK: - BMR

    func testBMRMaleKnownReference() {
        // 25y male, 180cm, 80kg → 10·80 + 6.25·180 − 5·25 + 5 = 800 + 1125 − 125 + 5 = 1805
        let bmr = NutritionEngine.bmrMifflinStJeor(sex: .male, age: 25, heightCm: 180, weightKg: 80)
        XCTAssertEqual(bmr, 1805, accuracy: 0.5)
    }

    func testBMRFemaleKnownReference() {
        // 30y female, 165cm, 60kg → 600 + 1031.25 − 150 − 161 = 1320.25
        let bmr = NutritionEngine.bmrMifflinStJeor(sex: .female, age: 30, heightCm: 165, weightKg: 60)
        XCTAssertEqual(bmr, 1320.25, accuracy: 0.5)
    }

    func testBMROtherIsBetweenMaleAndFemale() {
        let m = NutritionEngine.bmrMifflinStJeor(sex: .male, age: 25, heightCm: 175, weightKg: 70)
        let f = NutritionEngine.bmrMifflinStJeor(sex: .female, age: 25, heightCm: 175, weightKg: 70)
        let o = NutritionEngine.bmrMifflinStJeor(sex: .other, age: 25, heightCm: 175, weightKg: 70)
        XCTAssertTrue(o < m && o > f)
    }

    // MARK: - Activity

    func testActivityMultiplierBaseline() {
        XCTAssertEqual(NutritionEngine.activityMultiplier(trainingDaysPerWeek: 0, avgSteps: nil), 1.30, accuracy: 0.001)
        XCTAssertEqual(NutritionEngine.activityMultiplier(trainingDaysPerWeek: 2, avgSteps: nil), 1.40, accuracy: 0.001)
        XCTAssertEqual(NutritionEngine.activityMultiplier(trainingDaysPerWeek: 4, avgSteps: nil), 1.55, accuracy: 0.001)
        XCTAssertEqual(NutritionEngine.activityMultiplier(trainingDaysPerWeek: 6, avgSteps: nil), 1.70, accuracy: 0.001)
        XCTAssertEqual(NutritionEngine.activityMultiplier(trainingDaysPerWeek: 7, avgSteps: nil), 1.80, accuracy: 0.001)
    }

    func testActivityStepBumpCapped() {
        // 5000 steps → 0 bump
        XCTAssertEqual(NutritionEngine.activityMultiplier(trainingDaysPerWeek: 3, avgSteps: 5000), 1.55, accuracy: 0.001)
        // 15000 steps over 5000 → (10000/2500)·0.025 = 0.10, capped.
        XCTAssertEqual(NutritionEngine.activityMultiplier(trainingDaysPerWeek: 3, avgSteps: 15000), 1.65, accuracy: 0.001)
        // 30000 steps → still +0.10
        XCTAssertEqual(NutritionEngine.activityMultiplier(trainingDaysPerWeek: 3, avgSteps: 30000), 1.65, accuracy: 0.001)
    }

    // MARK: - Goal adjustment cap

    func testGoalDeficitCappedAt20Percent() {
        // Fast pace + small-ish TDEE: deficit (~825 kcal/day from 0.75 kg/wk) blows past
        // the ±20% cap, so the cap must clamp the result to 80% of TDEE.
        let (kcal, _) = NutritionEngine.goalAdjustedKcal(tdee: 3000, goal: .loseWeight, pace: .fast)
        XCTAssertEqual(kcal, Int((3000 * 0.80).rounded()))
    }

    func testMaintainEqualsTDEE() {
        let (kcal, weekly) = NutritionEngine.goalAdjustedKcal(tdee: 2400, goal: .maintain)
        XCTAssertEqual(kcal, 2400)
        XCTAssertEqual(weekly, 0, accuracy: 0.0001)
    }

    func testRecompIsMildDeficit() {
        let (kcal, weekly) = NutritionEngine.goalAdjustedKcal(tdee: 2500, goal: .recomp)
        XCTAssertEqual(kcal, Int((2500 * 0.95).rounded()))
        XCTAssertLessThan(weekly, 0)
    }

    // MARK: - Macros

    func testMacrosProteinFloor() {
        // 80kg, build muscle → 2.2 g/kg = 176g protein.
        let m = NutritionEngine.macros(kcalTarget: 3000, weightKg: 80, goal: .buildMuscle)
        XCTAssertEqual(m.proteinG, 176, accuracy: 1)
    }

    func testMacrosFatFloor() {
        // 80kg → fat floor 64g. Ensure result honors floor when room exists.
        let m = NutritionEngine.macros(kcalTarget: 3000, weightKg: 80, goal: .buildMuscle)
        XCTAssertGreaterThanOrEqual(m.fatG, 64)
    }

    func testMacrosSumToKcalApprox() {
        let weight: Double = 70
        let kcal = 2200
        let m = NutritionEngine.macros(kcalTarget: kcal, weightKg: weight, goal: .loseWeight)
        let sum = m.proteinG * 4 + m.carbsG * 4 + m.fatG * 9
        // Allow ±50 kcal tolerance for integer rounding.
        XCTAssertEqual(sum, kcal, accuracy: 50)
    }

    func testMacrosNonNegativeAtLowKcal() {
        // Very low target where protein alone would exceed — verify nothing goes negative.
        let m = NutritionEngine.macros(kcalTarget: 1000, weightKg: 100, goal: .buildMuscle)
        XCTAssertGreaterThanOrEqual(m.proteinG, 0)
        XCTAssertGreaterThanOrEqual(m.carbsG, 0)
        XCTAssertGreaterThanOrEqual(m.fatG, 0)
    }

    // MARK: - End-to-end

    func testComputeReasonableTargetForAverageUser() {
        let inputs = NutritionEngine.Inputs(
            sex: .male, age: 25, heightCm: 178, weightKg: 78,
            trainingDaysPerWeek: 4, avgSteps: 8000, goal: .recomp, mainFocus: .recomp
        )
        let r = NutritionEngine.compute(inputs)
        XCTAssertGreaterThan(r.bmr, 1500)
        XCTAssertLessThan(r.bmr, 2200)
        XCTAssertGreaterThan(r.tdee, r.bmr)
        XCTAssertGreaterThan(r.kcalTarget, 1500)
        XCTAssertLessThan(r.kcalTarget, 4000)
        XCTAssertGreaterThan(r.proteinG, 100)
    }

    func testRecompSmallWeeklyDelta() {
        let inputs = NutritionEngine.Inputs(
            sex: .male, age: 25, heightCm: 178, weightKg: 78,
            trainingDaysPerWeek: 4, avgSteps: 8000, goal: .recomp, mainFocus: .recomp
        )
        let r = NutritionEngine.compute(inputs)
        XCTAssertLessThan(abs(r.weeklyDeltaKg), 0.4)
    }

    // MARK: - Pace

    func testPaceChangesKcalForLoseGoal() {
        // TDEE 3500 → 20% cap is 700 kcal/day, which exceeds the maximum daily delta the
        // fastest pace asks for (~825). Slow / medium / fast all stay distinct.
        let slow = NutritionEngine.goalAdjustedKcal(tdee: 3500, goal: .loseWeight, pace: .slow)
        let med  = NutritionEngine.goalAdjustedKcal(tdee: 3500, goal: .loseWeight, pace: .medium)
        let fast = NutritionEngine.goalAdjustedKcal(tdee: 3500, goal: .loseWeight, pace: .fast)
        // Faster pace = larger deficit = lower kcal.
        XCTAssertGreaterThan(slow.kcal, med.kcal)
        XCTAssertGreaterThanOrEqual(med.kcal, fast.kcal) // may tie at the cap for very small TDEEs
        // All deltas are negative for loseWeight.
        XCTAssertLessThan(slow.weeklyDeltaKg, 0)
        XCTAssertLessThan(med.weeklyDeltaKg, 0)
        XCTAssertLessThan(fast.weeklyDeltaKg, 0)
    }

    func testPaceChangesKcalForGainGoal() {
        let slow = NutritionEngine.goalAdjustedKcal(tdee: 3500, goal: .gainWeight, pace: .slow)
        let fast = NutritionEngine.goalAdjustedKcal(tdee: 3500, goal: .gainWeight, pace: .fast)
        XCTAssertLessThan(slow.kcal, fast.kcal)
        XCTAssertGreaterThan(slow.weeklyDeltaKg, 0)
        XCTAssertGreaterThan(fast.weeklyDeltaKg, 0)
    }

    func testMaintainIgnoresPace() {
        let slow = NutritionEngine.goalAdjustedKcal(tdee: 2400, goal: .maintain, pace: .slow)
        let fast = NutritionEngine.goalAdjustedKcal(tdee: 2400, goal: .maintain, pace: .fast)
        XCTAssertEqual(slow.kcal, 2400)
        XCTAssertEqual(fast.kcal, 2400)
        XCTAssertEqual(slow.weeklyDeltaKg, 0, accuracy: 0.001)
    }

    func testFastPaceStillCappedAt20Percent() {
        // Tiny TDEE — even fast pace must clamp to ±20 %.
        let r = NutritionEngine.goalAdjustedKcal(tdee: 1500, goal: .loseWeight, pace: .fast)
        XCTAssertGreaterThanOrEqual(r.kcal, Int((1500 * 0.80).rounded()))
    }

    // MARK: - Projection

    func testProjectionForLossEndsAtGoal() {
        let pts = NutritionEngine.projectWeeks(currentKg: 80, goalKg: 75, pace: .medium)
        XCTAssertEqual(pts.first?.weightKg ?? 0, 80, accuracy: 0.001)
        XCTAssertEqual(pts.last?.weightKg ?? 0, 75, accuracy: 0.001)
        // 5 kg / 0.5 = 10 weeks (plus index 0 → 11 points).
        XCTAssertEqual(pts.count, 11)
    }

    func testProjectionForGainEndsAtGoal() {
        let pts = NutritionEngine.projectWeeks(currentKg: 70, goalKg: 75, pace: .slow)
        XCTAssertEqual(pts.first?.weightKg ?? 0, 70, accuracy: 0.001)
        XCTAssertEqual(pts.last?.weightKg ?? 0, 75, accuracy: 0.001)
    }

    func testProjectionForMaintainIsSinglePoint() {
        let pts = NutritionEngine.projectWeeks(currentKg: 70, goalKg: 70, pace: .medium)
        XCTAssertEqual(pts.count, 1)
    }

    func testWeeksToReachIsCeilOfWeeks() {
        XCTAssertEqual(NutritionEngine.weeksToReach(currentKg: 80, goalKg: 75, pace: .medium), 10)
        // 5 kg / 0.25 = 20 weeks.
        XCTAssertEqual(NutritionEngine.weeksToReach(currentKg: 80, goalKg: 75, pace: .slow), 20)
    }

    // MARK: - Goal realism

    func testRealismFlagsUnderweightGoal() {
        // 1.80 m, 55 kg goal → BMI ~17 (underweight)
        let warning = NutritionEngine.goalRealismWarning(
            heightCm: 180, goalKg: 55, currentKg: 80
        )
        XCTAssertNotNil(warning)
    }

    func testRealismSilentForSensibleGoal() {
        // 1.80 m, 75 kg goal → BMI ~23 (healthy)
        let warning = NutritionEngine.goalRealismWarning(
            heightCm: 180, goalKg: 75, currentKg: 78
        )
        XCTAssertNil(warning)
    }

    func testRealismFlagsExtremeGain() {
        let warning = NutritionEngine.goalRealismWarning(
            heightCm: 175, goalKg: 130, currentKg: 70
        )
        XCTAssertNotNil(warning)
    }

    // MARK: - Effective-direction (weight-delta) override

    func testEffectiveDirectionFollowsWeightDelta() {
        // Stored type is .loseWeight but the user has set a HIGHER goal weight (their stored
        // type is stale because GoalService didn't migrate). Without the fix the engine would
        // produce a deficit; with the fix it must report .gain.
        let dir = NutritionEngine.effectiveDirection(
            goal: .loseWeight, currentWeightKg: 73, goalWeightKg: 104
        )
        XCTAssertEqual(dir, .gain)
    }

    func testEffectiveDirectionMaintainsWhenWeightsClose() {
        let dir = NutritionEngine.effectiveDirection(
            goal: .gainWeight, currentWeightKg: 80, goalWeightKg: 80.3
        )
        XCTAssertEqual(dir, .maintain)
    }

    func testEffectiveDirectionFallsBackToEnumWhenWeightsAbsent() {
        // No weights → fall back to the stored type so legacy callers keep working.
        let dir = NutritionEngine.effectiveDirection(goal: .loseWeight)
        XCTAssertEqual(dir, .loss)
    }

    func testFasterPaceMeansMoreKcalForRealGainGoal() {
        // The exact user-reported bug: stored type is .loseWeight, but the actual delta says
        // gain. After the fix, Faster pace MUST produce more kcal than Slow.
        let slow = NutritionEngine.goalAdjustedKcal(
            tdee: 2400, goal: .loseWeight, pace: .slow,
            currentWeightKg: 73, goalWeightKg: 104
        )
        let fast = NutritionEngine.goalAdjustedKcal(
            tdee: 2400, goal: .loseWeight, pace: .fast,
            currentWeightKg: 73, goalWeightKg: 104
        )
        XCTAssertGreaterThan(fast.kcal, slow.kcal)
        XCTAssertGreaterThan(slow.weeklyDeltaKg, 0) // both gain
        XCTAssertGreaterThan(fast.weeklyDeltaKg, 0)
    }

    func testFasterPaceMeansFewerKcalForRealLossGoal() {
        // Stored type is .gainWeight but real delta says lose → must produce a deficit.
        let slow = NutritionEngine.goalAdjustedKcal(
            tdee: 2400, goal: .gainWeight, pace: .slow,
            currentWeightKg: 90, goalWeightKg: 78
        )
        let fast = NutritionEngine.goalAdjustedKcal(
            tdee: 2400, goal: .gainWeight, pace: .fast,
            currentWeightKg: 90, goalWeightKg: 78
        )
        XCTAssertGreaterThan(slow.kcal, fast.kcal)
        XCTAssertLessThan(slow.weeklyDeltaKg, 0)
        XCTAssertLessThan(fast.weeklyDeltaKg, 0)
    }

    func testMaintainWhenWeightsMatchEvenIfTypeSaysLose() {
        let (kcal, weekly) = NutritionEngine.goalAdjustedKcal(
            tdee: 2400, goal: .loseWeight, pace: .fast,
            currentWeightKg: 78, goalWeightKg: 78.2
        )
        XCTAssertEqual(kcal, 2400)
        XCTAssertEqual(weekly, 0, accuracy: 0.001)
    }

    func testProteinFollowsRealDirectionNotEnum() {
        // Stored type = loseWeight (would say 2.0 g/kg cut). Real delta = gain.
        // Lean-bulk protein should be 1.8 g/kg.
        let perKg = NutritionEngine.proteinTargetGramsPerKg(
            goal: .loseWeight, currentWeightKg: 70, goalWeightKg: 80
        )
        XCTAssertEqual(perKg, 1.8, accuracy: 0.0001)
    }

    func testComputeUsesGoalWeightForDirection() {
        // Simulate the bug scenario end-to-end: stale .loseWeight type, real gain target.
        let inputs = NutritionEngine.Inputs(
            sex: .male, age: 28, heightCm: 178, weightKg: 73,
            trainingDaysPerWeek: 4, avgSteps: 8000,
            goal: .loseWeight, mainFocus: .muscleGain, pace: .fast,
            goalWeightKg: 104
        )
        let r = NutritionEngine.compute(inputs)
        // Surplus, not deficit.
        XCTAssertGreaterThan(r.kcalTarget, r.tdee)
        XCTAssertGreaterThan(r.weeklyDeltaKg, 0)
    }

    // MARK: - GoalService type resolution

    func testResolveGoalTypeFlipsToGainOnRaise() {
        let resolved = GoalService.resolveGoalType(
            existing: .loseWeight, currentKg: 73, goalKg: 104
        )
        XCTAssertEqual(resolved, .gainWeight)
    }

    func testResolveGoalTypeFlipsToLoseOnLower() {
        let resolved = GoalService.resolveGoalType(
            existing: .gainWeight, currentKg: 90, goalKg: 75
        )
        XCTAssertEqual(resolved, .loseWeight)
    }

    func testResolveGoalTypeKeepsRecompWhenDirectionStillMakesSense() {
        let resolved = GoalService.resolveGoalType(
            existing: .recomp, currentKg: 80, goalKg: 79
        )
        // Small loss, recomp preserved.
        XCTAssertEqual(resolved, .recomp)
    }

    func testResolveGoalTypeMaintainOnTinyDelta() {
        let resolved = GoalService.resolveGoalType(
            existing: .loseWeight, currentKg: 80, goalKg: 80.3
        )
        XCTAssertEqual(resolved, .maintain)
    }

    func testResolveGoalTypeKeepsBuildMuscleOnGain() {
        let resolved = GoalService.resolveGoalType(
            existing: .buildMuscle, currentKg: 75, goalKg: 82
        )
        XCTAssertEqual(resolved, .buildMuscle)
    }
}

// MARK: - Micronutrients

final class MicronutrientsTests: XCTestCase {
    func testRDIDiffersBetweenSexes() {
        let male = DailyIntake.recommended(sex: .male)
        let female = DailyIntake.recommended(sex: .female)
        XCTAssertGreaterThan(male.vitaminCMg ?? 0, female.vitaminCMg ?? 0)
        XCTAssertGreaterThan(female.ironMg ?? 0, male.ironMg ?? 0)
    }

    func testSumHandlesNils() {
        let a = Micronutrients(vitaminCMg: 30, ironMg: nil)
        let b = Micronutrients(vitaminCMg: 40, ironMg: 4)
        let sum = Micronutrients.sum([a, b, nil])
        XCTAssertEqual(sum.vitaminCMg, 70)
        XCTAssertEqual(sum.ironMg, 4)
    }

    func testScaleAppliesToAllPresentValues() {
        let m = Micronutrients(vitaminDMcg: 10, ironMg: 5, zincMg: nil)
        let s = m.scaled(by: 0.5)
        XCTAssertEqual(s.vitaminDMcg, 5)
        XCTAssertEqual(s.ironMg, 2.5)
        XCTAssertNil(s.zincMg)
    }
}
