import Foundation

public struct DailyMetric: Hashable, Sendable {
    public let day: Date
    public let value: Double?

    public init(day: Date, value: Double?) {
        self.day = day
        self.value = value
    }
}

public struct DayMetrics: Hashable, Sendable {
    public let day: Date
    public let heartRateVariability: Double?
    public let restingHeartRate: Double?
    public let sleepHours: Double?

    public init(
        day: Date,
        heartRateVariability: Double? = nil,
        restingHeartRate: Double? = nil,
        sleepHours: Double? = nil
    ) {
        self.day = day
        self.heartRateVariability = heartRateVariability
        self.restingHeartRate = restingHeartRate
        self.sleepHours = sleepHours
    }
}

public enum ReadinessMetric: String, CaseIterable, Sendable {
    case heartRateVariability
    case restingHeartRate
    case sleep

    public var weight: Double {
        switch self {
        case .heartRateVariability: 0.5
        case .restingHeartRate: 0.3
        case .sleep: 0.2
        }
    }
}
