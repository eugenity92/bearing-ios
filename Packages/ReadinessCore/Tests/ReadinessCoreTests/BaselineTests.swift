import Foundation
import Testing
@testable import ReadinessCore

struct BaselineTests {
    @Test func meanOfKnownValues() {
        #expect(Baseline.mean([2, 4, 6, 8]) == 5)
    }

    @Test func meanOfEmptyIsNil() {
        #expect(Baseline.mean([]) == nil)
    }

    @Test func meanOfSingleValue() {
        #expect(Baseline.mean([42]) == 42)
    }

    @Test func sampleStandardDeviationUsesNMinusOne() throws {
        let deviation = try #require(Baseline.sampleStandardDeviation([2, 4, 4, 4, 5, 5, 7, 9]))
        #expect(abs(deviation - 2.13808993529939) < 0.0000001)
    }

    @Test func sampleStandardDeviationNeedsTwoValues() {
        #expect(Baseline.sampleStandardDeviation([1]) == nil)
        #expect(Baseline.sampleStandardDeviation([]) == nil)
    }

    @Test func identicalValuesGiveZeroDeviation() {
        #expect(Baseline.sampleStandardDeviation([5, 5, 5, 5]) == 0)
    }

    @Test func zScoreAtMeanIsZero() {
        #expect(Baseline.zScore(value: 50, mean: 50, standardDeviation: 10, floor: 1) == 0)
    }

    @Test func zScoreIsSignedByDirection() {
        #expect(Baseline.zScore(value: 70, mean: 50, standardDeviation: 10, floor: 1) == 2)
        #expect(Baseline.zScore(value: 30, mean: 50, standardDeviation: 10, floor: 1) == -2)
    }

    @Test func zScoreFloorPreventsDivisionByZero() {
        let z = Baseline.zScore(value: 60, mean: 50, standardDeviation: 0, floor: 1)
        #expect(z.isFinite)
        #expect(z == 10)
    }

    @Test func naturalLogsDropNonPositiveValues() {
        let logs = Baseline.naturalLogs(of: [1, 0, -5, Foundation.exp(1)])
        #expect(logs.count == 2)
        #expect(abs(logs[0]) < 0.0000001)
        #expect(abs(logs[1] - 1) < 0.0000001)
    }

    @Test(arguments: [(-10.0, 0.0), (0.0, 0.0), (50.0, 50.0), (100.0, 100.0), (140.0, 100.0)])
    func clampBoundsValues(input: Double, expected: Double) {
        #expect(Baseline.clamp(input, to: 0...100) == expected)
    }
}
