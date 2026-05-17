import XCTest
@testable import VibeNutrition

@MainActor
final class OnboardingStateTests: XCTestCase {
    func testInitialStepIsGoal() {
        let s = OnboardingState()
        XCTAssertEqual(s.step, .goal)
    }

    func testCannotAdvanceWithoutGoal() {
        let s = OnboardingState()
        XCTAssertFalse(s.canAdvance)
        s.goal = .buildMuscle
        XCTAssertTrue(s.canAdvance)
    }

    func testAdvanceMovesToNextStep() {
        let s = OnboardingState()
        s.goal = .buildMuscle
        s.advance()
        XCTAssertEqual(s.step, .currentWeight)
    }

    func testGoBackDoesNotUnderflow() {
        let s = OnboardingState()
        s.goBack()
        XCTAssertEqual(s.step, .goal)
    }

    func testPersistRoundtrip() throws {
        let s = OnboardingState()
        s.goal = .recomp
        s.currentWeightKg = 75
        s.sex = .female
        s.pace = .fast
        s.advance()
        s.persist()

        let restored = OnboardingState.restore()
        XCTAssertEqual(restored.goal, .recomp)
        XCTAssertEqual(restored.currentWeightKg, 75)
        XCTAssertEqual(restored.sex, .female)
        XCTAssertEqual(restored.pace, .fast)
        XCTAssertEqual(restored.step, .currentWeight)

        OnboardingState.clear()
    }

    func testPaceStepAlwaysAdvances() {
        let s = OnboardingState()
        s.step = .pace
        // Pace defaults to .medium so we can always continue.
        XCTAssertTrue(s.canAdvance)
    }

    func testSexIsRequiredToAdvanceFromSexStep() {
        let s = OnboardingState()
        s.step = .sex
        XCTAssertFalse(s.canAdvance)
        s.sex = .female
        XCTAssertTrue(s.canAdvance)
    }

    func testProgressIsMonotonic() {
        let s = OnboardingState()
        var last = -1.0
        for step in OnboardingStep.visibleSteps {
            s.step = step
            XCTAssertGreaterThanOrEqual(s.progress, last)
            last = s.progress
        }
    }
}
