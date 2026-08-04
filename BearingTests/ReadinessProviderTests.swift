import Dependencies
import Foundation
import ReadinessCore
import Testing
@testable import Bearing

struct ReadinessProviderTests {
    private let now = Date(timeIntervalSince1970: 1_785_000_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        return calendar
    }

    private func dailyValues(_ value: Double, days: Int = ReadinessWindow.totalDays) -> [DailyMetric] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
                .map { DailyMetric(day: $0, value: value) }
        }
    }

    private func firstSnapshot(
        from provider: LiveReadinessProvider
    ) async -> Result<ReadinessSnapshot, any Error>? {
        for await value in await provider.snapshot where value != nil {
            return value
        }
        return nil
    }

    @Test func computesAScoreFromMockedHealthData() async throws {
        let store = MockHealthStore(
            dailyValues: [.heartRateVariability: dailyValues(55), .restingHeartRate: dailyValues(58)]
        )

        let snapshot = try await withDependencies {
            $0.healthStore = store
            $0.date = .constant(now)
            $0.calendar = calendar
        } operation: {
            let provider = LiveReadinessProvider()
            await provider.refresh()
            return try #require(await firstSnapshot(from: provider)).get()
        }

        let score = try #require(snapshot.today.score)
        #expect(score.value == 50)
        #expect(score.confidence == .high)
        #expect(score.band == .fair)
    }

    @Test func requestsExactlyTheFortyTwoDayWindow() async throws {
        let store = MockHealthStore(dailyValues: [.heartRateVariability: dailyValues(55)])

        await withDependencies {
            $0.healthStore = store
            $0.date = .constant(now)
            $0.calendar = calendar
        } operation: {
            await LiveReadinessProvider().refresh()
        }

        let ranges = await store.requestedRanges
        #expect(ranges.count == 3)

        let range = try #require(ranges.first)
        let spannedDays = calendar.dateComponents([.day], from: range.from, to: range.to).day
        #expect(spannedDays == ReadinessWindow.totalDays)
        #expect(Set(ranges.map(\.from)).count == 1)
    }

    /// A failing query degrades to "no data for that metric" rather than failing the
    /// screen. HealthKit reports a denied read type as absent data, not as a denial,
    /// so an error here is indistinguishable from a user who granted nothing — and
    /// the honest answer in both cases is "not enough data", not a red error state.
    @Test func healthStoreFailureDegradesToInsufficientData() async throws {
        let store = MockHealthStore(error: HealthStoreError.queryFailed)

        let snapshot = try await withDependencies {
            $0.healthStore = store
            $0.date = .constant(now)
            $0.calendar = calendar
        } operation: {
            let provider = LiveReadinessProvider()
            await provider.refresh()
            return try #require(await firstSnapshot(from: provider)).get()
        }

        #expect(snapshot.today == .insufficientData(.noDataToday))
        #expect(snapshot.trend.isEmpty)
    }

    @Test func deniedSleepAccessRedistributesWeightsInsteadOfFailing() async throws {
        let store = MockHealthStore(
            dailyValues: [.heartRateVariability: dailyValues(55), .restingHeartRate: dailyValues(58)],
            sleep: []
        )

        let snapshot = try await withDependencies {
            $0.healthStore = store
            $0.date = .constant(now)
            $0.calendar = calendar
        } operation: {
            let provider = LiveReadinessProvider()
            await provider.refresh()
            return try #require(await firstSnapshot(from: provider)).get()
        }

        let score = try #require(snapshot.today.score)
        #expect(score.factors.contains { $0.metric == .sleep } == false)
        #expect(score.factors.count == 2)
    }

    @Test func aFreshUserWithOneWeekOfDataGetsInsufficientData() async throws {
        let store = MockHealthStore(dailyValues: [.heartRateVariability: dailyValues(55, days: 5)])

        let snapshot = try await withDependencies {
            $0.healthStore = store
            $0.date = .constant(now)
            $0.calendar = calendar
        } operation: {
            let provider = LiveReadinessProvider()
            await provider.refresh()
            return try #require(await firstSnapshot(from: provider)).get()
        }

        #expect(snapshot.today.score == nil)
    }

    @Test func trendNeverExceedsFourteenPoints() async throws {
        let store = MockHealthStore(
            dailyValues: [.heartRateVariability: dailyValues(55), .restingHeartRate: dailyValues(58)]
        )

        let snapshot = try await withDependencies {
            $0.healthStore = store
            $0.date = .constant(now)
            $0.calendar = calendar
        } operation: {
            let provider = LiveReadinessProvider()
            await provider.refresh()
            return try #require(await firstSnapshot(from: provider)).get()
        }

        #expect(snapshot.trend.count <= ReadinessWindow.trendDays)
        #expect(snapshot.trend.map(\.day) == snapshot.trend.map(\.day).sorted())
    }
}
