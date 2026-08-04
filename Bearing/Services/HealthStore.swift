import Dependencies
import Foundation
import HealthKit
import os
import ReadinessCore

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "HealthStore")

/// No HealthKit type crosses this boundary. Everything is mapped to plain value types
/// inside the live implementation, which is what lets the domain package stay free of
/// Apple frameworks and lets tests run without entitlements. Under simulator test
/// builds `CODE_SIGNING_ALLOWED=NO` strips entitlements, so a real `HKHealthStore`
/// authorization call throws — no test may construct `LiveHealthStore`.
protocol HealthStore: Sendable {
    var isAvailable: Bool { get }
    func requestAuthorization(for metrics: Set<HealthMetric>) async throws
    func dailyAverages(of metric: HealthMetric, from: Date, to: Date) async throws -> [DailyMetric]
    func sleepIntervals(from: Date, to: Date) async throws -> [SleepInterval]
}

/// An actor because `HKHealthStore` is not `Sendable` and neither are `HKSample`
/// subclasses. Confining the store and mapping samples to value types before returning
/// is what satisfies complete concurrency checking.
actor LiveHealthStore: HealthStore {
    private let store = HKHealthStore()

    nonisolated var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization(for metrics: Set<HealthMetric>) async throws {
        guard isAvailable else { throw HealthStoreError.unavailableOnThisDevice }

        do {
            try await store.requestAuthorization(toShare: [], read: Set(metrics.map(\.objectType)))
        } catch {
            logger.error("Health authorization failed: \(error.localizedDescription)")
            throw HealthStoreError.authorizationFailed
        }
    }

    func dailyAverages(of metric: HealthMetric, from start: Date, to end: Date) async throws -> [DailyMetric] {
        guard let quantityType = metric.quantityType, let unit = metric.unit else { return [] }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(
                type: quantityType,
                predicate: HKQuery.predicateForSamples(withStart: start, end: end)
            ),
            options: .discreteAverage,
            anchorDate: calendar.startOfDay(for: start),
            intervalComponents: DateComponents(day: 1)
        )

        do {
            let collection = try await descriptor.result(for: store)
            return collection.statistics().map { statistics in
                DailyMetric(
                    day: calendar.startOfDay(for: statistics.startDate),
                    value: statistics.averageQuantity()?.doubleValue(for: unit)
                )
            }
        } catch {
            logger.error("Query for \(metric.rawValue) failed: \(error.localizedDescription)")
            throw HealthStoreError.queryFailed
        }
    }

    func sleepIntervals(from start: Date, to end: Date) async throws -> [SleepInterval] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [
                .categorySample(
                    type: HKCategoryType(.sleepAnalysis),
                    predicate: HKQuery.predicateForSamples(withStart: start, end: end)
                )
            ],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        do {
            return try await descriptor.result(for: store).map {
                SleepInterval(start: $0.startDate, end: $0.endDate, stage: .init(categoryValue: $0.value))
            }
        } catch {
            logger.error("Sleep query failed: \(error.localizedDescription)")
            throw HealthStoreError.queryFailed
        }
    }
}

private extension HealthMetric {
    var objectType: HKObjectType {
        switch self {
        case .heartRateVariability: HKQuantityType(.heartRateVariabilitySDNN)
        case .restingHeartRate: HKQuantityType(.restingHeartRate)
        case .sleep: HKCategoryType(.sleepAnalysis)
        }
    }

    var quantityType: HKQuantityType? {
        switch self {
        case .heartRateVariability: HKQuantityType(.heartRateVariabilitySDNN)
        case .restingHeartRate: HKQuantityType(.restingHeartRate)
        case .sleep: nil
        }
    }

    var unit: HKUnit? {
        switch self {
        case .heartRateVariability: .secondUnit(with: .milli)
        case .restingHeartRate: .count().unitDivided(by: .minute())
        case .sleep: nil
        }
    }
}

private extension SleepStage {
    init(categoryValue: Int) {
        switch HKCategoryValueSleepAnalysis(rawValue: categoryValue) {
        case .inBed: self = .inBed
        case .awake: self = .awake
        case .asleepCore: self = .core
        case .asleepDeep: self = .deep
        case .asleepREM: self = .rem
        default: self = .unspecified
        }
    }
}

private enum HealthStoreKey: DependencyKey {
    static var liveValue: any HealthStore {
        #if DEBUG
        // Launch argument rather than a build flag so the same build can be run either
        // way — this is how screenshots are taken without a paired Apple Watch.
        if ProcessInfo.processInfo.arguments.contains("-useSampleHealthData") {
            return SampleHealthStore()
        }
        #endif
        return LiveHealthStore()
    }

    #if DEBUG
    static let previewValue: any HealthStore = SampleHealthStore()
    #endif
}

extension DependencyValues {
    var healthStore: any HealthStore {
        get { self[HealthStoreKey.self] }
        set { self[HealthStoreKey.self] = newValue }
    }
}
