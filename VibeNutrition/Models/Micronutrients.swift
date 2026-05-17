import Foundation

/// Per-food-item or per-log micronutrient totals.
/// All fields are optional — older scans (pre-micronutrient pipeline) decode with nils.
///
/// Units:
///   - vitaminDMcg:  micrograms (μg)
///   - vitaminB12Mcg: micrograms (μg)
///   - vitaminCMg:   milligrams (mg)
///   - magnesiumMg:  milligrams (mg)
///   - ironMg:       milligrams (mg)
///   - zincMg:       milligrams (mg)
struct Micronutrients: Codable, Hashable {
    var vitaminDMcg: Double?
    var vitaminB12Mcg: Double?
    var vitaminCMg: Double?
    var magnesiumMg: Double?
    var ironMg: Double?
    var zincMg: Double?

    enum CodingKeys: String, CodingKey {
        case vitaminDMcg   = "vitamin_d_mcg"
        case vitaminB12Mcg = "vitamin_b12_mcg"
        case vitaminCMg    = "vitamin_c_mg"
        case magnesiumMg   = "magnesium_mg"
        case ironMg        = "iron_mg"
        case zincMg        = "zinc_mg"
    }

    static let zero = Micronutrients(
        vitaminDMcg: 0, vitaminB12Mcg: 0, vitaminCMg: 0,
        magnesiumMg: 0, ironMg: 0, zincMg: 0
    )

    static func sum(_ values: [Micronutrients?]) -> Micronutrients {
        values.reduce(.zero) { acc, m in
            guard let m else { return acc }
            return Micronutrients(
                vitaminDMcg:   (acc.vitaminDMcg   ?? 0) + (m.vitaminDMcg   ?? 0),
                vitaminB12Mcg: (acc.vitaminB12Mcg ?? 0) + (m.vitaminB12Mcg ?? 0),
                vitaminCMg:    (acc.vitaminCMg    ?? 0) + (m.vitaminCMg    ?? 0),
                magnesiumMg:   (acc.magnesiumMg   ?? 0) + (m.magnesiumMg   ?? 0),
                ironMg:        (acc.ironMg        ?? 0) + (m.ironMg        ?? 0),
                zincMg:        (acc.zincMg        ?? 0) + (m.zincMg        ?? 0)
            )
        }
    }

    /// Linearly scale all present values (used when grams are adjusted in scan review).
    func scaled(by factor: Double) -> Micronutrients {
        Micronutrients(
            vitaminDMcg:   vitaminDMcg.map { $0 * factor },
            vitaminB12Mcg: vitaminB12Mcg.map { $0 * factor },
            vitaminCMg:    vitaminCMg.map { $0 * factor },
            magnesiumMg:   magnesiumMg.map { $0 * factor },
            ironMg:        ironMg.map { $0 * factor },
            zincMg:        zincMg.map { $0 * factor }
        )
    }
}

/// Recommended Daily Intake values for healthy adults (19+).
/// Source: U.S. NIH ODS Recommended Dietary Allowances. Same numbers as FDA Daily Values.
/// We picked one consistent standard (NIH ODS / FDA) per the spec and stick with it.
enum DailyIntake {
    static func recommended(sex: SexType?) -> Micronutrients {
        switch sex {
        case .male:
            return Micronutrients(
                vitaminDMcg:   15,   // 600 IU
                vitaminB12Mcg: 2.4,
                vitaminCMg:    90,
                magnesiumMg:   420,
                ironMg:        8,
                zincMg:        11
            )
        case .female:
            return Micronutrients(
                vitaminDMcg:   15,
                vitaminB12Mcg: 2.4,
                vitaminCMg:    75,
                magnesiumMg:   320,
                ironMg:        18,  // premenopausal default; conservative for women 19-50
                zincMg:        8
            )
        case .other, .none:
            // Average of male/female where they differ.
            return Micronutrients(
                vitaminDMcg:   15,
                vitaminB12Mcg: 2.4,
                vitaminCMg:    82,
                magnesiumMg:   370,
                ironMg:        13,
                zincMg:        9
            )
        }
    }
}
