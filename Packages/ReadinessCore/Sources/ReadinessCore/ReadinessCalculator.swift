import Foundation

public enum ReadinessCalculator {
    public static let minimumBaselineDays = 7
    public static let minimumSignalWeight = 0.5

    private static let hrvDeviationFloor = 0.05
    private static let restingHeartRateDeviationFloor = 1.0

    public static func evaluate(today: DayMetrics, baseline: [DayMetrics]) -> ReadinessResult {
        var factors: [ReadinessFactor] = []
        var baselineCounts: [Int] = []

        if let factor = heartRateVariabilityFactor(today: today, baseline: baseline) {
            factors.append(factor.factor)
            baselineCounts.append(factor.baselineDays)
        }

        if let factor = restingHeartRateFactor(today: today, baseline: baseline) {
            factors.append(factor.factor)
            baselineCounts.append(factor.baselineDays)
        }

        if let factor = sleepFactor(today: today) {
            factors.append(factor)
        }

        guard !factors.isEmpty else { return .insufficientData(.noDataToday) }

        let totalWeight = factors.reduce(0) { $0 + $1.weightApplied }
        guard totalWeight >= minimumSignalWeight else {
            return .insufficientData(baselineCounts.isEmpty ? .baselineTooShort : .notEnoughSignalWeight)
        }

        guard let smallestBaseline = baselineCounts.min(),
              let confidence = ReadinessConfidence(baselineDays: smallestBaseline) else {
            return .insufficientData(.baselineTooShort)
        }

        let weighted = factors.reduce(0) { $0 + $1.componentScore * $1.weightApplied }
        let value = Int((weighted / totalWeight).rounded())

        return .score(
            ReadinessScore(
                value: value,
                band: ReadinessBand(score: value),
                confidence: confidence,
                factors: factors
            )
        )
    }

    public static func sleepScore(hours: Double) -> Double {
        switch hours {
        case ..<4: 0
        case 4..<7.5: (hours - 4) / 3.5 * 100
        case 7.5...9: 100
        case 9..<11: 100 - (hours - 9) / 2 * 15
        default: 85
        }
    }
}

private extension ReadinessCalculator {
    struct BaselineFactor {
        let factor: ReadinessFactor
        let baselineDays: Int
    }

    static func heartRateVariabilityFactor(today: DayMetrics, baseline: [DayMetrics]) -> BaselineFactor? {
        guard let value = today.heartRateVariability, value > 0 else { return nil }

        let logs = Baseline.naturalLogs(of: baseline.compactMap(\.heartRateVariability))
        guard logs.count >= minimumBaselineDays,
              let mean = Baseline.mean(logs),
              let deviation = Baseline.sampleStandardDeviation(logs) else { return nil }

        let z = Baseline.zScore(
            value: Foundation.log(value),
            mean: mean,
            standardDeviation: deviation,
            floor: hrvDeviationFloor
        )

        return BaselineFactor(
            factor: ReadinessFactor(
                metric: .heartRateVariability,
                todayValue: value,
                baselineMean: Foundation.exp(mean),
                zScore: z,
                componentScore: Baseline.clamp(50 + 25 * z, to: 0...100),
                weightApplied: ReadinessMetric.heartRateVariability.weight
            ),
            baselineDays: logs.count
        )
    }

    static func restingHeartRateFactor(today: DayMetrics, baseline: [DayMetrics]) -> BaselineFactor? {
        guard let value = today.restingHeartRate else { return nil }

        let values = baseline.compactMap(\.restingHeartRate)
        guard values.count >= minimumBaselineDays,
              let mean = Baseline.mean(values),
              let deviation = Baseline.sampleStandardDeviation(values) else { return nil }

        // Negated: for resting heart rate, below your baseline is the good direction.
        let z = -Baseline.zScore(
            value: value,
            mean: mean,
            standardDeviation: deviation,
            floor: restingHeartRateDeviationFloor
        )

        return BaselineFactor(
            factor: ReadinessFactor(
                metric: .restingHeartRate,
                todayValue: value,
                baselineMean: mean,
                zScore: z,
                componentScore: Baseline.clamp(50 + 25 * z, to: 0...100),
                weightApplied: ReadinessMetric.restingHeartRate.weight
            ),
            baselineDays: values.count
        )
    }

    static func sleepFactor(today: DayMetrics) -> ReadinessFactor? {
        guard let hours = today.sleepHours else { return nil }

        return ReadinessFactor(
            metric: .sleep,
            todayValue: hours,
            baselineMean: nil,
            zScore: nil,
            componentScore: sleepScore(hours: hours),
            weightApplied: ReadinessMetric.sleep.weight
        )
    }
}
