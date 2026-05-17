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

    private var readTypes: Set<HKObjectType> {
        var set = Set<HKObjectType>()
        for id in [
            HKQuantityTypeIdentifier.stepCount,
            .activeEnergyBurned,
            .bodyMass,
            .dietaryEnergyConsumed,
        ] {
            if let type = HKObjectType.quantityType(forIdentifier: id) {
                set.insert(type)
            }
        }
        return set
    }

    private var writeTypes: Set<HKSampleType> {
        var set = Set<HKSampleType>()
        for id in [
            HKQuantityTypeIdentifier.bodyMass,
            .dietaryEnergyConsumed,
        ] {
            if let type = HKObjectType.quantityType(forIdentifier: id) {
                set.insert(type)
            }
        }
        return set
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
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

    // MARK: - Weight (read + write)

    /// Most recent body-mass sample in kilograms. Nil if no sample or no permission.
    func latestWeightKg() async -> Double? {
        guard
            isAvailable,
            let type = HKQuantityType.quantityType(forIdentifier: .bodyMass)
        else { return nil }

        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)))
            }
            self.store.execute(query)
        }
    }

    /// Write a body-mass sample to HealthKit. Throws if writing isn't authorized.
    @discardableResult
    func writeWeight(kg: Double, at date: Date = Date()) async throws -> Bool {
        guard
            isAvailable,
            let type = HKQuantityType.quantityType(forIdentifier: .bodyMass)
        else { throw HealthKitError.notAvailable }

        let qty = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(type: type, quantity: qty, start: date, end: date)
        try await store.save(sample)
        return true
    }

    // MARK: - Dietary energy (write)

    /// Write a consumed-calories sample (e.g. when a food log is saved).
    @discardableResult
    func writeDietaryEnergy(kcal: Double, at date: Date = Date()) async throws -> Bool {
        guard
            isAvailable,
            let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        else { throw HealthKitError.notAvailable }

        let qty = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
        let sample = HKQuantitySample(type: type, quantity: qty, start: date, end: date)
        try await store.save(sample)
        return true
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
}
