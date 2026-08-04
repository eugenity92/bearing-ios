import Dependencies
import Foundation
import Sharing

@Observable
@MainActor
final class HealthAccessModel {
    private(set) var isRequesting = false
    private(set) var didFail = false

    @ObservationIgnored
    @Dependency(\.healthStore) private var healthStore: any HealthStore

    @ObservationIgnored
    @Shared(.hasRequestedHealthAccess) var hasRequestedHealthAccess: Bool

    var isHealthDataAvailable: Bool { healthStore.isAvailable }

    func requestAccess() async {
        guard !isRequesting else { return }
        isRequesting = true
        didFail = false

        do {
            try await healthStore.requestAuthorization(for: Set(HealthMetric.allCases))
            $hasRequestedHealthAccess.withLock { $0 = true }
        } catch {
            didFail = true
        }

        isRequesting = false
    }

    /// There is deliberately no "skip" that silently proceeds without asking: the
    /// previous build queried HealthKit before requesting anything and every query
    /// failed with "Authorization not determined".
    func continueWithoutHealthData() {
        $hasRequestedHealthAccess.withLock { $0 = true }
    }
}

extension SharedReaderKey where Self == AppStorageKey<Bool>.Default {
    static var hasRequestedHealthAccess: Self {
        Self[.appStorage(AppStorageKeys.hasRequestedHealthAccess.rawValue), default: false]
    }
}
