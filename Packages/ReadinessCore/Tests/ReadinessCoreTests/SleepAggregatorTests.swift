import Foundation
import Testing
@testable import ReadinessCore

struct SleepAggregatorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        return calendar
    }

    private func date(_ string: String, timeZone: String = "Europe/Warsaw") -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: timeZone)!
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)!
    }

    private func interval(_ start: String, _ end: String, _ stage: SleepStage = .core) -> SleepInterval {
        SleepInterval(start: date(start), end: date(end), stage: stage)
    }

    @Test func identicalSamplesFromTwoSourcesCountOnce() throws {
        let hours = try #require(
            SleepAggregator.hours(
                on: date("2026-03-10 09:00"),
                intervals: [
                    interval("2026-03-09 23:00", "2026-03-10 07:00"),
                    interval("2026-03-09 23:00", "2026-03-10 07:00")
                ],
                calendar: calendar
            )
        )

        #expect(abs(hours - 8) < 0.001)
    }

    @Test func partiallyOverlappingSamplesBecomeTheirUnion() throws {
        let hours = try #require(
            SleepAggregator.hours(
                on: date("2026-03-10 09:00"),
                intervals: [
                    interval("2026-03-09 23:00", "2026-03-10 04:00"),
                    interval("2026-03-10 03:00", "2026-03-10 07:00")
                ],
                calendar: calendar
            )
        )

        #expect(abs(hours - 8) < 0.001)
    }

    @Test func separateSegmentsAreSummed() throws {
        let hours = try #require(
            SleepAggregator.hours(
                on: date("2026-03-10 09:00"),
                intervals: [
                    interval("2026-03-09 23:00", "2026-03-10 02:00"),
                    interval("2026-03-10 03:00", "2026-03-10 07:00")
                ],
                calendar: calendar
            )
        )

        #expect(abs(hours - 7) < 0.001)
    }

    @Test func inBedAndAwakeAreExcluded() throws {
        let hours = try #require(
            SleepAggregator.hours(
                on: date("2026-03-10 09:00"),
                intervals: [
                    interval("2026-03-09 22:30", "2026-03-10 07:30", .inBed),
                    interval("2026-03-09 23:00", "2026-03-10 07:00", .core),
                    interval("2026-03-10 03:00", "2026-03-10 03:30", .awake)
                ],
                calendar: calendar
            )
        )

        #expect(abs(hours - 8) < 0.001)
    }

    @Test(arguments: [SleepStage.core, .deep, .rem, .unspecified])
    func allAsleepStagesCount(stage: SleepStage) throws {
        let hours = try #require(
            SleepAggregator.hours(
                on: date("2026-03-10 09:00"),
                intervals: [interval("2026-03-09 23:00", "2026-03-10 07:00", stage)],
                calendar: calendar
            )
        )

        #expect(abs(hours - 8) < 0.001)
    }

    @Test func aNightCrossingMidnightLandsOnTheDayItEnds() throws {
        let intervals = [interval("2026-03-09 23:00", "2026-03-10 07:00")]

        #expect(SleepAggregator.hours(on: date("2026-03-10 09:00"), intervals: intervals, calendar: calendar) != nil)
        #expect(SleepAggregator.hours(on: date("2026-03-09 09:00"), intervals: intervals, calendar: calendar) == nil)
    }

    @Test func anAfternoonNapIsOutsideTheWindow() {
        let hours = SleepAggregator.hours(
            on: date("2026-03-10 20:00"),
            intervals: [interval("2026-03-10 14:00", "2026-03-10 15:30")],
            calendar: calendar
        )

        #expect(hours == nil)
    }

    @Test func sleepBeforeTheWindowOpensIsClipped() throws {
        let hours = try #require(
            SleepAggregator.hours(
                on: date("2026-03-10 09:00"),
                intervals: [interval("2026-03-09 16:00", "2026-03-09 20:00")],
                calendar: calendar
            )
        )

        #expect(abs(hours - 2) < 0.001)
    }

    @Test func springForwardNightLosesAnHourOfWallClockTime() throws {
        // Europe/Warsaw springs forward at 02:00 on 2026-03-29, so midnight to 07:00
        // reads as seven hours on the clock but is only six of actual sleep.
        // Adding 86,400 seconds instead of using Calendar gets this wrong silently.
        let hours = try #require(
            SleepAggregator.hours(
                on: date("2026-03-29 09:00"),
                intervals: [interval("2026-03-29 00:00", "2026-03-29 07:00")],
                calendar: calendar
            )
        )

        #expect(abs(hours - 6) < 0.001)
    }

    @Test func windowBoundariesAreWallClockAcrossDST() throws {
        let window = try #require(
            SleepAggregator.window(endingOn: date("2026-03-29 09:00"), calendar: calendar)
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")

        #expect(formatter.string(from: window.start) == "2026-03-28 18:00")
        #expect(formatter.string(from: window.end) == "2026-03-29 12:00")
    }

    @Test func noIntervalsGivesNilRatherThanZero() {
        #expect(SleepAggregator.hours(on: date("2026-03-10 09:00"), intervals: [], calendar: calendar) == nil)
    }

    @Test func zeroLengthIntervalsAreIgnored() {
        let hours = SleepAggregator.hours(
            on: date("2026-03-10 09:00"),
            intervals: [interval("2026-03-10 03:00", "2026-03-10 03:00")],
            calendar: calendar
        )

        #expect(hours == nil)
    }
}
