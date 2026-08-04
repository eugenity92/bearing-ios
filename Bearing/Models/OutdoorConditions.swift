import Foundation

struct OutdoorConditions: Codable, Equatable, Sendable {
    let temperature: Double?
    let apparentTemperature: Double?
    let windSpeed: Double?
    let precipitation: Double?
    let europeanAQI: Double?
    let particulates2_5: Double?
    let uvIndex: Double?
    let fetchedAt: Date
}

struct ForecastResponse: Decodable, Sendable {
    struct Current: Decodable, Sendable {
        let temperature: Double?
        let apparentTemperature: Double?
        let windSpeed: Double?
        let precipitation: Double?

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case windSpeed = "wind_speed_10m"
            case precipitation
        }
    }

    let current: Current?
}

struct AirQualityResponse: Decodable, Sendable {
    struct Current: Decodable, Sendable {
        let europeanAQI: Double?
        let particulates2_5: Double?
        let uvIndex: Double?

        enum CodingKeys: String, CodingKey {
            case europeanAQI = "european_aqi"
            case particulates2_5 = "pm2_5"
            case uvIndex = "uv_index"
        }
    }

    let current: Current?
}
