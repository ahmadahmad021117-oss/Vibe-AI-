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
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            set.insert(steps)
        }
        if let activeKcal = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            set.insert(activeKcal)
        }
        return set
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
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
}
