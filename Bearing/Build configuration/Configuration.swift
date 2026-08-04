import Foundation

enum Configuration {
    enum Key: String {
        case openMeteoForecastHost = "OPEN_METEO_FORECAST_HOST"
        case openMeteoAirQualityHost = "OPEN_METEO_AIR_QUALITY_HOST"
    }

    static subscript(key: Key) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key.rawValue) as? String else {
            fatalError("Missing Info.plist value for \(key.rawValue). Check the xcconfig for this configuration.")
        }
        return value
    }

    static func url(_ key: Key) -> URL {
        guard let url = URL(string: "https://" + Self[key]) else {
            fatalError("Invalid host in Info.plist for \(key.rawValue): \(Self[key])")
        }
        return url
    }
}
