#if DEBUG
import Foundation
import ReadinessCore

/// HealthKit returns nothing in the simulator and seeding the Health app by hand is not
/// a path worth walking, so screenshots and previews run against this instead. Values are
/// derived from the day index rather than a random source, so a screenshot taken today
/// looks the same as one taken next week.
actor SampleHealthStore: HealthStore {
    private let calendar: Calendar
    private let referenceDate: Date

    nonisolated let isAvailable = true

    init(calendar: Calendar = .current, referenceDate: Date = Date()) {
        self.calendar = calendar
        self.referenceDate = referenceDate
    }

    func requestAuthorization(for metrics: Set<HealthMetric>) async throws {}

    func dailyAverages(of metric: HealthMetric, from start: Date, to end: Date) async throws -> [DailyMetric] {
        days(from: start, to: end).map { day in
            DailyMetric(day: day, value: value(of: metric, on: day))
        }
    }

    func sleepIntervals(from start: Date, to end: Date) async throws -> [SleepInterval] {
        days(from: start, to: end).compactMap { day -> SleepInterval? in
            let hours = 6.4 + wave(day, period: 5) * 1.6
            guard let bedtime = calendar.date(bySettingHour: 23, minute: 15, second: 0, of: day),
                  let previousNight = calendar.date(byAdding: .day, value: -1, to: bedtime),
                  let wake = calendar.date(byAdding: .second, value: Int(hours * 3600), to: previousNight)
            else { return nil }

            return SleepInterval(start: previousNight, end: wake, stage: .core)
        }
    }
}

private extension SampleHealthStore {
    func days(from start: Date, to end: Date) -> [Date] {
        var days: [Date] = []
        var cursor = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)

        while cursor < last {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    func value(of metric: HealthMetric, on day: Date) -> Double? {
        let index = calendar.dateComponents([.day], from: referenceDate, to: day).day ?? 0

        // One day in nine has no reading, so the empty-data paths stay visible.
        guard abs(index) % 9 != 4 else { return nil }

        switch metric {
        case .heartRateVariability:
            return 48 + wave(day, period: 7) * 14 + wave(day, period: 3) * 5
        case .restingHeartRate:
            return 57 - wave(day, period: 7) * 4 + wave(day, period: 4) * 2
        case .sleep:
            return nil
        }
    }

    func wave(_ day: Date, period: Double) -> Double {
        let index = Double(calendar.dateComponents([.day], from: referenceDate, to: day).day ?? 0)
        return sin(index / period * 2 * .pi)
    }
}
#endif
