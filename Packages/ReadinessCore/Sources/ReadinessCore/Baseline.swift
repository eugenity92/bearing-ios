import Foundation

public enum Baseline {
    public static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    public static func sampleStandardDeviation(_ values: [Double]) -> Double? {
        guard values.count > 1, let mean = mean(values) else { return nil }
        let sumOfSquaredDeviations = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return (sumOfSquaredDeviations / Double(values.count - 1)).squareRoot()
    }

    public static func zScore(value: Double, mean: Double, standardDeviation: Double, floor: Double) -> Double {
        (value - mean) / Swift.max(standardDeviation, floor)
    }

    public static func naturalLogs(of values: [Double]) -> [Double] {
        values.filter { $0 > 0 }.map(Foundation.log)
    }

    public static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
    }
}
