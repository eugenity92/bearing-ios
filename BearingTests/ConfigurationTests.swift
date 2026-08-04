import Foundation
import Testing
@testable import Bearing

struct ConfigurationTests {
    @Test func forecastHostIsInjectedFromXcconfig() {
        #expect(Configuration[.openMeteoForecastHost] == "api.open-meteo.com")
    }

    @Test func airQualityHostIsInjectedFromXcconfig() {
        #expect(Configuration[.openMeteoAirQualityHost] == "air-quality-api.open-meteo.com")
    }

    @Test func hostsBecomeHTTPSURLs() {
        #expect(Configuration.url(.openMeteoForecastHost).absoluteString == "https://api.open-meteo.com")
        #expect(Configuration.url(.openMeteoAirQualityHost).absoluteString == "https://air-quality-api.open-meteo.com")
    }
}
