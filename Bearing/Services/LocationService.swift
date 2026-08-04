import CoreLocation
import Dependencies
import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Location")

enum LocationError: Error, Equatable, Sendable {
    case denied
    case restricted
    case unavailable
}

protocol LocationService: Sendable {
    func currentCoordinate() async throws -> Coordinate
}

struct LiveLocationService: LocationService {
    func currentCoordinate() async throws -> Coordinate {
        try await LocationRequest().coordinate()
    }
}

/// `CLLocationManager` is not `Sendable` and its delegate is called on the queue the
/// manager was created on, so it is pinned to the main actor and every access happens
/// there. One instance serves exactly one request, which keeps continuation handling
/// trivially correct — there is no way to resume twice.
@MainActor
private final class LocationRequest: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Coordinate, any Error>?

    func coordinate() async throws -> Coordinate {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyKilometer

            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied:
                resume(with: .failure(LocationError.denied))
            case .restricted:
                resume(with: .failure(LocationError.restricted))
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            @unknown default:
                resume(with: .failure(LocationError.unavailable))
            }
        }
    }

    // The `manager` parameter is deliberately unused: it is not Sendable, so passing it
    // into the isolated closure is rejected under complete checking. `self.manager` is
    // the same object reached through main-actor isolation the compiler can verify.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            switch self.manager.authorizationStatus {
            case .notDetermined:
                break
            case .denied:
                resume(with: .failure(LocationError.denied))
            case .restricted:
                resume(with: .failure(LocationError.restricted))
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.requestLocation()
            @unknown default:
                resume(with: .failure(LocationError.unavailable))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last.map {
            Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }

        MainActor.assumeIsolated {
            guard let coordinate else {
                resume(with: .failure(LocationError.unavailable))
                return
            }
            resume(with: .success(coordinate))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        logger.error("Location request failed: \(error.localizedDescription, privacy: .private)")
        MainActor.assumeIsolated {
            resume(with: .failure(LocationError.unavailable))
        }
    }

    private func resume(with result: Result<Coordinate, any Error>) {
        guard let continuation else { return }
        self.continuation = nil
        manager.delegate = nil
        continuation.resume(with: result)
    }
}

#if DEBUG
private struct PreviewLocationService: LocationService {
    func currentCoordinate() async throws -> Coordinate {
        Coordinate(latitude: 52.2297, longitude: 21.0122)
    }
}
#endif

private enum LocationServiceKey: DependencyKey {
    static let liveValue: any LocationService = LiveLocationService()

    #if DEBUG
    static let previewValue: any LocationService = PreviewLocationService()
    #endif
}

extension DependencyValues {
    var locationService: any LocationService {
        get { self[LocationServiceKey.self] }
        set { self[LocationServiceKey.self] = newValue }
    }
}
