import Foundation

public enum ReadinessBand: String, Sendable {
    case low, fair, good, high

    public init(score: Int) {
        switch score {
        case ..<40: self = .low
        case 40..<60: self = .fair
        case 60..<80: self = .good
        default: self = .high
        }
    }
}

public enum ReadinessConfidence: String, Sendable {
    case low, medium, high

    public init?(baselineDays: Int) {
        switch baselineDays {
        case ..<7: return nil
        case 7..<14: self = .low
        case 14..<28: self = .medium
        default: self = .high
        }
    }
}

public struct ReadinessFactor: Hashable, Sendable {
    public let metric: ReadinessMetric
    public let todayValue: Double
    public let baselineMean: Double?
    public let zScore: Double?
    public let componentScore: Double
    public let weightApplied: Double
}

public struct ReadinessScore: Hashable, Sendable {
    public let value: Int
    public let band: ReadinessBand
    public let confidence: ReadinessConfidence
    public let factors: [ReadinessFactor]
}

public enum InsufficientDataReason: String, Sendable {
    case noDataToday
    case baselineTooShort
    case notEnoughSignalWeight
}

public enum ReadinessResult: Hashable, Sendable {
    case score(ReadinessScore)
    case insufficientData(InsufficientDataReason)

    public var score: ReadinessScore? {
        switch self {
        case .score(let score): score
        case .insufficientData: nil
        }
    }
}
