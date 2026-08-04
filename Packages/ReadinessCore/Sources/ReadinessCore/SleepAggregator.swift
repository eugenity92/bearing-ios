import Foundation

public enum SleepAggregator {
    public static let windowStartHour = 18
    public static let windowEndHour = 12

    /// The window a night is attributed to: 18:00 the previous day through 12:00 on `day`.
    /// Built with calendar arithmetic rather than a fixed 86,400 seconds so that
    /// daylight-saving transitions produce the correct wall-clock boundaries.
    public static func window(endingOn day: Date, calendar: Calendar) -> DateInterval? {
        let startOfDay = calendar.startOfDay(for: day)

        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: startOfDay),
              let start = calendar.date(bySettingHour: windowStartHour, minute: 0, second: 0, of: previousDay),
              let end = calendar.date(bySettingHour: windowEndHour, minute: 0, second: 0, of: startOfDay)
        else { return nil }

        return DateInterval(start: start, end: end)
    }

    public static func merge(_ intervals: [SleepInterval]) -> [DateInterval] {
        let asleep = intervals
            .filter { $0.stage.isAsleep && $0.end > $0.start }
            .map { DateInterval(start: $0.start, end: $0.end) }
            .sorted { $0.start < $1.start }

        return asleep.reduce(into: [DateInterval]()) { merged, next in
            guard let last = merged.last else {
                merged.append(next)
                return
            }

            if next.start <= last.end {
                merged[merged.count - 1] = DateInterval(
                    start: last.start,
                    end: Swift.max(last.end, next.end)
                )
            } else {
                merged.append(next)
            }
        }
    }

    public static func hours(
        on day: Date,
        intervals: [SleepInterval],
        calendar: Calendar
    ) -> Double? {
        guard let window = window(endingOn: day, calendar: calendar) else { return nil }

        let clipped = intervals.compactMap { interval -> SleepInterval? in
            let start = Swift.max(interval.start, window.start)
            let end = Swift.min(interval.end, window.end)
            guard end > start else { return nil }
            return SleepInterval(start: start, end: end, stage: interval.stage)
        }

        let merged = merge(clipped)
        guard !merged.isEmpty else { return nil }

        return merged.reduce(0) { $0 + $1.duration } / 3600
    }
}
