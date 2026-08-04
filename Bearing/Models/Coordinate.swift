import Foundation

struct Coordinate: Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    /// Open-Meteo resolves forecasts on a grid of several kilometres, so sending a
    /// precise fix buys no accuracy and discloses more than the request needs.
    /// Two decimal places is roughly one kilometre.
    var coarse: Coordinate {
        Coordinate(
            latitude: (latitude * 100).rounded() / 100,
            longitude: (longitude * 100).rounded() / 100
        )
    }
}
