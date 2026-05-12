import XCTest
@testable import VibeNutrition

final class WeeklyProgressDecodingTests: XCTestCase {
    func testDecodesEdgeFunctionPayload() throws {
        let json = """
        {
            "days": 7,
            "log_count": 21,
            "avg_kcal": 2240,
            "avg_protein_g": 160,
            "target_kcal": 2200,
            "adherence_pct": 102,
            "weight_start_kg": 78.4,
            "weight_end_kg": 77.9,
            "actual_delta_kg": -0.5,
            "expected_delta_kg": -0.4,
            "adaptive_nudge": false
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WeeklyProgressService.Summary.self, from: json)
        XCTAssertEqual(decoded.days, 7)
        XCTAssertEqual(decoded.logCount, 21)
        XCTAssertEqual(decoded.avgKcal, 2240)
        XCTAssertEqual(decoded.avgProteinG, 160)
        XCTAssertEqual(decoded.targetKcal, 2200)
        XCTAssertEqual(decoded.adherencePct, 102)
        XCTAssertEqual(decoded.weightStartKg, 78.4)
        XCTAssertEqual(decoded.weightEndKg, 77.9)
        XCTAssertEqual(decoded.actualDeltaKg, -0.5)
        XCTAssertEqual(decoded.expectedDeltaKg, -0.4)
        XCTAssertFalse(decoded.adaptiveNudge)
    }

    func testDecodesNullWeights() throws {
        let json = """
        {
            "days": 7,
            "log_count": 3,
            "avg_kcal": 1900,
            "avg_protein_g": 120,
            "target_kcal": 2200,
            "adherence_pct": 86,
            "weight_start_kg": null,
            "weight_end_kg": null,
            "actual_delta_kg": null,
            "expected_delta_kg": -0.4,
            "adaptive_nudge": false
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WeeklyProgressService.Summary.self, from: json)
        XCTAssertNil(decoded.weightStartKg)
        XCTAssertNil(decoded.weightEndKg)
        XCTAssertNil(decoded.actualDeltaKg)
        XCTAssertEqual(decoded.expectedDeltaKg, -0.4)
    }

    func testAdaptiveNudgeTrue() throws {
        let json = """
        {"days":7,"log_count":7,"avg_kcal":2400,"avg_protein_g":150,"target_kcal":2000,
         "adherence_pct":120,"weight_start_kg":80,"weight_end_kg":80.5,
         "actual_delta_kg":0.5,"expected_delta_kg":-0.3,"adaptive_nudge":true}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(WeeklyProgressService.Summary.self, from: json)
        XCTAssertTrue(decoded.adaptiveNudge)
    }
}
