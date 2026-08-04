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

        do {
            let heartRateVariability = try await healthStore.dailyAverages(
                of: .heartRateVariability,
                from: windowStart,
                to: windowEnd
            )
            let restingHeartRate = try await healthStore.dailyAverages(
                of: .restingHeartRate,
                from: windowStart,
                to: windowEnd
            )
            let sleep = try await healthStore.sleepIntervals(from: windowStart, to: windowEnd)

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

private enum ReadinessProviderKey: DependencyKey {
    static let liveValue: any ReadinessProvider = LiveReadinessProvider()
}

extension DependencyValues {
    var readinessProvider: any ReadinessProvider {
        get { self[ReadinessProviderKey.self] }
        set { self[ReadinessProviderKey.self] = newValue }
    }
}
