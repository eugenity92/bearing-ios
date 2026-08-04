import Foundation

enum HealthMetric: String, CaseIterable, Sendable {
    case heartRateVariability
    case restingHeartRate
    case sleep
}

enum HealthStoreError: Error, Equatable, Sendable {
    case unavailableOnThisDevice
    case authorizationFailed
    case queryFailed
}
