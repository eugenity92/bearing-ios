import Foundation

public enum SleepStage: String, Sendable, CaseIterable {
    case inBed
    case awake
    case core
    case deep
    case rem
    case unspecified

    /// `inBed` brackets the whole night including time spent awake, and counting it
    /// alongside the asleep stages double-counts. `awake` is time in bed but not asleep.
    public var isAsleep: Bool {
        switch self {
        case .core, .deep, .rem, .unspecified: true
        case .inBed, .awake: false
        }
    }
}

public struct SleepInterval: Hashable, Sendable {
    public let start: Date
    public let end: Date
    public let stage: SleepStage

    public init(start: Date, end: Date, stage: SleepStage) {
        self.start = start
        self.end = end
        self.stage = stage
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }
}
