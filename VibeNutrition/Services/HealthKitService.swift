import Foundation
import HealthKit

enum HealthKitError: Error {
    case notAvailable
    case denied
}

@MainActor
final class HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private static let nutritionWriteIdentifiers: [HKQuantityTypeIdentifier] = [
        .dietaryEnergyConsumed,
        .dietaryProtein,
        .dietaryCarbohydrates,
        .dietaryFatTotal,
    ]

    private var readTypes: Set<HKObjectType> {
        var set = Set<HKObjectType>()
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            set.insert(steps)
        }
        if let activeKcal = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            set.insert(activeKcal)
        }
        return set
    }

    private var nutritionWriteTypes: Set<HKSampleType> {
        var set = Set<HKSampleType>()
        for id in Self.nutritionWriteIdentifiers {
            if let t = HKQuantityType.quantityType(forIdentifier: id) {
                set.insert(t)
            }
        }
        return set
    }

    /// Asks for both nutrition write and activity read in one prompt.
    /// Already gated upstream on `profile.healthSyncEnabled` (see PlanGenerator).
    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        try await store.requestAuthorization(toShare: nutritionWriteTypes, read: readTypes)
    }

    /// True once the user has granted share permission for dietary energy.
    /// Used as a single proxy for the full nutrition-write set — Apple grants the
    /// types together in one sheet.
    var canWriteNutrition: Bool {
        guard isAvailable,
              let kcalType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        else { return false }
        return store.authorizationStatus(for: kcalType) == .sharingAuthorized
    }

    /// 14-day average daily steps. Returns nil on permission denial or no data.
    func averageDailySteps(days: Int = 14) async -> Int? {
        guard
            isAvailable,
            let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)
        else { return nil }

        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date()).addingTimeInterval(86400)
        guard let start = calendar.date(byAdding: .day, value: -days, to: end) else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                guard let sum = stats?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                let total = sum.doubleValue(for: .count())
                let avg = Int((total / Double(days)).rounded())
                continuation.resume(returning: avg)
            }
            self.store.execute(query)
        }
    }

    /// 14-day average daily active energy in kcal.
    func averageDailyActiveKcal(days: Int = 14) async -> Int? {
        guard
            isAvailable,
            let kcalType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        else { return nil }

        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date()).addingTimeInterval(86400)
        guard let start = calendar.date(byAdding: .day, value: -days, to: end) else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: kcalType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                guard let sum = stats?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                let total = sum.doubleValue(for: .kilocalorie())
                let avg = Int((total / Double(days)).rounded())
                continuation.resume(returning: avg)
            }
            self.store.execute(query)
        }
    }

    // MARK: - Nutrition write-back

    /// Best-effort: writes the meal to Apple Health as four dietary samples tagged
    /// with our food-log id (HKMetadataKeyExternalUUID). Silent no-op if the user
    /// has not granted share permission. Errors are swallowed — Supabase remains
    /// the source of truth for food logs.
    func writeFoodLog(
        logId: UUID,
        kcal: Int,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        loggedAt: Date
    ) async {
        guard canWriteNutrition else { return }
        guard
            let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein),
            let carbsType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates),
            let fatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal)
        else { return }

        let metadata: [String: Any] = [HKMetadataKeyExternalUUID: logId.uuidString]
        let samples: [HKQuantitySample] = [
            .init(type: energyType,
                  quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(kcal)),
                  start: loggedAt, end: loggedAt, metadata: metadata),
            .init(type: proteinType,
                  quantity: HKQuantity(unit: .gram(), doubleValue: max(0, proteinG)),
                  start: loggedAt, end: loggedAt, metadata: metadata),
            .init(type: carbsType,
                  quantity: HKQuantity(unit: .gram(), doubleValue: max(0, carbsG)),
                  start: loggedAt, end: loggedAt, metadata: metadata),
            .init(type: fatType,
                  quantity: HKQuantity(unit: .gram(), doubleValue: max(0, fatG)),
                  start: loggedAt, end: loggedAt, metadata: metadata),
        ]
        do { try await store.save(samples) } catch { /* best-effort */ }
    }

    /// Best-effort: removes any dietary samples we previously wrote for this log id.
    func deleteFoodLog(logId: UUID) async {
        guard canWriteNutrition else { return }
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyExternalUUID,
            allowedValues: [logId.uuidString]
        )
        for id in Self.nutritionWriteIdentifiers {
            guard let type = HKObjectType.quantityType(forIdentifier: id) else { continue }
            do { try await store.deleteObjects(of: type, predicate: predicate) } catch {}
        }
    }
}
