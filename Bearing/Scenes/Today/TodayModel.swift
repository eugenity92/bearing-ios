import Dependencies
import Foundation
import ReadinessCore

@Observable
@MainActor
final class TodayModel {
    enum State: Equatable {
        case loading
        case loadFailed
        case loaded(readiness: ReadinessResult, trend: [DatedScore])
    }

    /// Readiness drives the screen's state. Outdoor conditions are tracked separately
    /// rather than folded into `.loaded`, because the two loads race — nesting them
    /// means whichever finishes second silently discards the other's result.
    private(set) var state: State = .loading
    private(set) var conditions: OutdoorConditions?
    private(set) var isConditionsUnavailable = false

    @ObservationIgnored
    @Dependency(\.readinessProvider) private var readinessProvider: any ReadinessProvider

    @ObservationIgnored
    @Dependency(\.outdoorConditionsService) private var outdoorConditionsService: any OutdoorConditionsService

    @ObservationIgnored
    @Dependency(\.locationService) private var locationService: any LocationService

    func onViewAppear() async {
        async let readiness: Void = loadReadiness()
        async let outdoor: Void = loadOutdoorConditions()
        _ = await (readiness, outdoor)
    }

    func retry() async {
        state = .loading
        conditions = nil
        isConditionsUnavailable = false
        await onViewAppear()
    }
}

private extension TodayModel {
    func loadReadiness() async {
        await readinessProvider.refresh()

        for await result in await readinessProvider.snapshot {
            guard let result else { continue }

            switch result {
            case .success(let snapshot):
                state = .loaded(readiness: snapshot.today, trend: snapshot.trend)
            case .failure:
                state = .loadFailed
            }
            return
        }
    }

    /// Supplementary: a location denial or a network failure degrades this one card
    /// and never fails the screen.
    func loadOutdoorConditions() async {
        guard let coordinate = try? await locationService.currentCoordinate() else {
            isConditionsUnavailable = true
            return
        }

        await outdoorConditionsService.fetch(for: coordinate)

        for await result in await outdoorConditionsService.conditions {
            guard let result else { continue }

            switch result {
            case .success(let value):
                conditions = value
            case .failure:
                isConditionsUnavailable = true
            }
            return
        }
    }
}
