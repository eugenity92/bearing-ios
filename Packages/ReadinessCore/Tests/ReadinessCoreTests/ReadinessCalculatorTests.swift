import Foundation
import Testing
@testable import ReadinessCore

struct ReadinessCalculatorTests {
    private let day = Date(timeIntervalSince1970: 1_785_000_000)

    private func baseline(
        hrv: [Double]? = nil,
        restingHeartRate: [Double]? = nil,
        count: Int = 28
    ) -> [DayMetrics] {
        (0..<count).map { index in
            DayMetrics(
                day: day.addingTimeInterval(Double(-index - 1) * 86_400),
                heartRateVariability: hrv.map { $0[index % $0.count] },
                restingHeartRate: restingHeartRate.map { $0[index % $0.count] }
            )
        }
    }

    @Test func todayAtBaselineMeanScoresFifty() throws {
        // 27 days so the three values repeat evenly — an uneven cycle shifts the
        // geometric mean off 50 and the anchor stops being exact.
        let result = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, heartRateVariability: 50),
            baseline: baseline(hrv: [40, 50, 62.5], count: 27)
        )

        let factor = try #require(result.score?.factors.first)
        #expect(abs(factor.componentScore - 50) < 0.5)
    }

    @Test func twoDeviationsAboveScoresOneHundred() throws {
        let values = [45.0, 50, 55, 50, 45, 55, 50, 50, 45, 55]
        let logs = Baseline.naturalLogs(of: values)
        let mean = try #require(Baseline.mean(logs))
        let deviation = try #require(Baseline.sampleStandardDeviation(logs))
        let twoAbove = Foundation.exp(mean + 2 * deviation)

        let result = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, heartRateVariability: twoAbove),
            baseline: baseline(hrv: values)
        )

        #expect(abs(try #require(result.score?.factors.first).componentScore - 100) < 0.5)
    }

    @Test func extremeValuesClampRatherThanOverflow() throws {
        let low = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, heartRateVariability: 1),
            baseline: baseline(hrv: [45, 50, 55])
        )
        let high = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, heartRateVariability: 5_000),
            baseline: baseline(hrv: [45, 50, 55])
        )

        #expect(try #require(low.score?.factors.first).componentScore == 0)
        #expect(try #require(high.score?.factors.first).componentScore == 100)
    }

    @Test func logTransformIsActuallyApplied() throws {
        // Symmetric in log space (50/2 and 50*2) should land symmetrically about 50.
        let values = [40.0, 50, 62.5, 40, 50, 62.5, 40, 50, 62.5, 40]
        let halved = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, heartRateVariability: 25),
            baseline: baseline(hrv: values)
        )
        let doubled = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, heartRateVariability: 100),
            baseline: baseline(hrv: values)
        )

        let below = try #require(halved.score?.factors.first).componentScore
        let above = try #require(doubled.score?.factors.first).componentScore
        #expect(abs((50 - below) - (above - 50)) < 0.5)
    }

    @Test func flatBaselineDoesNotProduceNaN() throws {
        let result = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, heartRateVariability: 60),
            baseline: baseline(hrv: [50])
        )

        let factor = try #require(result.score?.factors.first)
        #expect(factor.componentScore.isFinite)
        #expect(try #require(factor.zScore).isFinite)
    }

    @Test func lowerRestingHeartRateRaisesTheScore() throws {
        let lower = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, restingHeartRate: 52, sleepHours: 8),
            baseline: baseline(restingHeartRate: [58, 60, 62])
        )
        let higher = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, restingHeartRate: 68, sleepHours: 8),
            baseline: baseline(restingHeartRate: [58, 60, 62])
        )

        let lowerScore = try #require(lower.score?.factors.first { $0.metric == .restingHeartRate })
        let higherScore = try #require(higher.score?.factors.first { $0.metric == .restingHeartRate })
        #expect(lowerScore.componentScore > higherScore.componentScore)
    }

    @Test(arguments: [
        (3.0, 0.0), (4.0, 0.0), (5.75, 50.0), (7.5, 100.0),
        (8.0, 100.0), (9.0, 100.0), (10.0, 92.5), (11.0, 85.0), (13.0, 85.0)
    ])
    func sleepScoreIsPiecewiseLinear(hours: Double, expected: Double) {
        #expect(abs(ReadinessCalculator.sleepScore(hours: hours) - expected) < 0.001)
    }

    @Test func weightsAreRedistributedWhenHRVIsMissing() throws {
        let result = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, restingHeartRate: 60, sleepHours: 8),
            baseline: baseline(restingHeartRate: [60])
        )

        let score = try #require(result.score)
        #expect(score.factors.count == 2)
        // RHR at its own baseline scores 50 (weight .3), sleep at 8h scores 100 (weight .2).
        // Renormalised: (50*0.3 + 100*0.2) / 0.5 = 70
        #expect(score.value == 70)
    }

    @Test func sleepAloneIsNotEnoughSignal() {
        let result = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, sleepHours: 8),
            baseline: baseline(hrv: [50])
        )

        #expect(result.score == nil)
    }

    @Test func restingHeartRateAloneIsNotEnoughSignal() {
        let result = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, restingHeartRate: 60),
            baseline: baseline(restingHeartRate: [60])
        )

        #expect(result.score == nil)
    }

    @Test func heartRateVariabilityAloneIsEnough() {
        let result = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, heartRateVariability: 50),
            baseline: baseline(hrv: [50])
        )

        #expect(result.score != nil)
    }

    @Test func noDataTodayIsReportedAsSuch() {
        let result = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day),
            baseline: baseline(hrv: [50])
        )

        #expect(result == .insufficientData(.noDataToday))
    }

    @Test func aShortBaselineDropsTheComponent() {
        let result = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, heartRateVariability: 50),
            baseline: baseline(hrv: [50], count: 6)
        )

        #expect(result.score == nil)
    }

    @Test(arguments: [(7, ReadinessConfidence.low), (13, .low), (14, .medium), (27, .medium), (28, .high)])
    func confidenceTracksBaselineLength(days: Int, expected: ReadinessConfidence) throws {
        let result = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, heartRateVariability: 50),
            baseline: baseline(hrv: [50], count: days)
        )

        #expect(try #require(result.score).confidence == expected)
    }

    @Test func scoreIsMonotonicInHeartRateVariability() throws {
        let values = [40.0, 45, 50, 55, 60, 40, 45, 50, 55, 60]
        var previous = -1.0

        for hrv in stride(from: 20.0, through: 120.0, by: 5.0) {
            let result = ReadinessCalculator.evaluate(
                today: DayMetrics(day: day, heartRateVariability: hrv),
                baseline: baseline(hrv: values)
            )
            let score = Double(try #require(result.score).value)
            #expect(score >= previous)
            previous = score
        }
    }

    @Test func factorsExposeTheirIntermediateValues() throws {
        let result = ReadinessCalculator.evaluate(
            today: DayMetrics(day: day, heartRateVariability: 60),
            baseline: baseline(hrv: [50])
        )

        let factor = try #require(result.score?.factors.first)
        #expect(factor.todayValue == 60)
        #expect(abs(try #require(factor.baselineMean) - 50) < 0.001)
        #expect(factor.weightApplied == 0.5)
    }

    @Test(arguments: [(0, ReadinessBand.low), (39, .low), (40, .fair), (59, .fair),
                      (60, .good), (79, .good), (80, .high), (100, .high)])
    func bandBoundaries(score: Int, expected: ReadinessBand) {
        #expect(ReadinessBand(score: score) == expected)
    }
}
