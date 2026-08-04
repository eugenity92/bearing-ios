import Foundation

public struct DatedScore: Hashable, Sendable {
    public let day: Date
    public let value: Int

    public init(day: Date, value: Int) {
        self.day = day
        self.value = value
    }
}

public struct ReadinessSnapshot: Hashable, Sendable {
    public let today: ReadinessResult
    public let trend: [DatedScore]

    public init(today: ReadinessResult, trend: [DatedScore]) {
        self.today = today
        self.trend = trend
    }
}

public enum ReadinessWindow {
    public static let baselineDays = 28
    public static let trendDays = 14
    public static let totalDays = baselineDays + trendDays

    /// Builds `DayMetrics` for every day in the window, pairing the per-day quantity
    /// averages with sleep totals aggregated over each night's 18:00–12:00 window.
    public static func dayMetrics(
        days: [Date],
        heartRateVariability: [DailyMetric],
        restingHeartRate: [DailyMetric],
        sleepIntervals: [SleepInterval],
        calendar: Calendar
    ) -> [DayMetrics] {
        let hrvByDay = Dictionary(
            heartRateVariability.map { (calendar.startOfDay(for: $0.day), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        let restingByDay = Dictionary(
            restingHeartRate.map { (calendar.startOfDay(for: $0.day), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )

        return days.map { day in
            let startOfDay = calendar.startOfDay(for: day)
            return DayMetrics(
                day: startOfDay,
                heartRateVariability: hrvByDay[startOfDay] ?? nil,
                restingHeartRate: restingByDay[startOfDay] ?? nil,
                sleepHours: SleepAggregator.hours(on: day, intervals: sleepIntervals, calendar: calendar)
            )
        }
    }

    /// Evaluates each of the most recent `trendDays`, giving every day its own
    /// preceding baseline so a trend point is never computed against future data.
    public static func snapshot(from metrics: [DayMetrics]) -> ReadinessSnapshot {
        let ordered = metrics.sorted { $0.day < $1.day }

        guard let today = ordered.last else {
            return ReadinessSnapshot(today: .insufficientData(.noDataToday), trend: [])
        }

        let trend = ordered.suffix(trendDays).compactMap { day -> DatedScore? in
            let baseline = ordered.filter { $0.day < day.day }.suffix(baselineDays)
            guard let score = ReadinessCalculator.evaluate(today: day, baseline: Array(baseline)).score else {
                return nil
            }
            return DatedScore(day: day.day, value: score.value)
        }

        let baseline = ordered.filter { $0.day < today.day }.suffix(baselineDays)

        return ReadinessSnapshot(
            today: ReadinessCalculator.evaluate(today: today, baseline: Array(baseline)),
            trend: trend
        )
    }
}
