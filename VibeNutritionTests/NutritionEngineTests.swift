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
        let (kcal, _) = NutritionEngine.goalAdjustedKcal(tdee: 3000, goal: .loseWeight)
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
}
