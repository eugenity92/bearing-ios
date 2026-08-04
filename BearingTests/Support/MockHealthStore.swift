import Foundation
import ReadinessCore
@testable import Bearing

actor MockHealthStore: HealthStore {
    struct RequestedRange: Equatable {
        let metric: String
        let from: Date
        let to: Date
    }

    private let dailyValues: [HealthMetric: [DailyMetric]]
    private let sleep: [SleepInterval]
    private let error: (any Error)?

    private(set) var requestedRanges: [RequestedRange] = []
    private(set) var authorizedMetrics: Set<HealthMetric> = []

    nonisolated let isAvailable = true

    init(
        dailyValues: [HealthMetric: [DailyMetric]] = [:],
        sleep: [SleepInterval] = [],
        error: (any Error)? = nil
    ) {
        self.dailyValues = dailyValues
        self.sleep = sleep
        self.error = error
    }

    func requestAuthorization(for metrics: Set<HealthMetric>) async throws {
        if let error { throw error }
        authorizedMetrics = metrics
    }

    func dailyAverages(of metric: HealthMetric, from: Date, to: Date) async throws -> [DailyMetric] {
        requestedRanges.append(RequestedRange(metric: metric.rawValue, from: from, to: to))
        if let error { throw error }
        return dailyValues[metric] ?? []
    }

    func sleepIntervals(from: Date, to: Date) async throws -> [SleepInterval] {
        requestedRanges.append(RequestedRange(metric: "sleep", from: from, to: to))
        if let error { throw error }
        return sleep
    }
}
