import Dependencies
import Foundation
import os
import ReadinessCore

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Readiness")

protocol ReadinessProvider: Sendable {
    var snapshot: AsyncStream<Result<ReadinessSnapshot, any Error>?> { get async }
    func refresh() async
}

actor LiveReadinessProvider: ReadinessProvider {
    private let streamable = CurrentValueStreamable<Result<ReadinessSnapshot, any Error>?>(nil)

    @Dependency(\.healthStore) private var healthStore: any HealthStore
    @Dependency(\.date) private var date: DateGenerator
    @Dependency(\.calendar) private var calendar: Calendar

    var snapshot: AsyncStream<Result<ReadinessSnapshot, any Error>?> {
        get async { await streamable.updates }
    }

    func refresh() async {
        let today = calendar.startOfDay(for: date.now)

        guard let windowStart = calendar.date(
            byAdding: .day,
            value: -(ReadinessWindow.totalDays - 1),
            to: today
        ), let windowEnd = calendar.date(byAdding: .day, value: 1, to: today) else {
            await streamable.update { $0 = .failure(HealthStoreError.queryFailed) }
            return
        }

        // Each signal is fetched independently and a failure degrades that one metric
        // rather than the screen. A partial grant — HRV allowed, sleep denied — is the
        // normal case, not an edge case, and HealthKit reports a denied read type as
        // absent data rather than as a denial.
        let heartRateVariability = await dailyAverages(of: .heartRateVariability, from: windowStart, to: windowEnd)
        let restingHeartRate = await dailyAverages(of: .restingHeartRate, from: windowStart, to: windowEnd)
        let sleep = await sleepIntervals(from: windowStart, to: windowEnd)

        do {
            let days = (0..<ReadinessWindow.totalDays).compactMap {
                calendar.date(byAdding: .day, value: -$0, to: today)
            }.reversed()

            let metrics = ReadinessWindow.dayMetrics(
                days: Array(days),
                heartRateVariability: heartRateVariability,
                restingHeartRate: restingHeartRate,
                sleepIntervals: sleep,
                calendar: calendar
            )

            await streamable.update { $0 = .success(ReadinessWindow.snapshot(from: metrics)) }
        } catch {
            logger.error("Readiness refresh failed: \(error.localizedDescription, privacy: .private)")
            await streamable.update { $0 = .failure(error) }
        }
    }
}

private extension LiveReadinessProvider {
    func dailyAverages(of metric: HealthMetric, from start: Date, to end: Date) async -> [DailyMetric] {
        do {
            return try await healthStore.dailyAverages(of: metric, from: start, to: end)
        } catch {
            logger.notice("No \(metric.rawValue) available: \(error.localizedDescription)")
            return []
        }
    }

    func sleepIntervals(from start: Date, to end: Date) async -> [SleepInterval] {
        do {
            return try await healthStore.sleepIntervals(from: start, to: end)
        } catch {
            logger.notice("No sleep data available: \(error.localizedDescription)")
            return []
        }
    }
}

private enum ReadinessProviderKey: DependencyKey {
    static let liveValue: any ReadinessProvider = LiveReadinessProvider()
}

extension DependencyValues {
    var readinessProvider: any ReadinessProvider {
        get { self[ReadinessProviderKey.self] }
        set { self[ReadinessProviderKey.self] = newValue }
    }
}
