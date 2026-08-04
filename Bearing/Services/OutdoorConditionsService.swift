import Dependencies
import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "OutdoorConditions")

private enum OutdoorConditionsPath: String, StringRepresentable {
    case airQuality = "v1/air-quality"
    case forecast = "v1/forecast"
}

private typealias Path = OutdoorConditionsPath

protocol OutdoorConditionsService: Sendable {
    var conditions: AsyncStream<Result<OutdoorConditions, any Error>?> { get async }
    func fetch(for coordinate: Coordinate) async
}

private actor LiveOutdoorConditionsService: OutdoorConditionsService {
    private let streamable = CurrentValueStreamable<Result<OutdoorConditions, any Error>?>(nil)

    @Dependency(\.networkService) private var networkService: any NetworkService
    @Dependency(\.date) private var date: DateGenerator

    var conditions: AsyncStream<Result<OutdoorConditions, any Error>?> {
        get async { await streamable.updates }
    }

    func fetch(for coordinate: Coordinate) async {
        let coarse = coordinate.coarse
        let params: [String: any Sendable] = [
            "latitude": coarse.latitude,
            "longitude": coarse.longitude,
            "timezone": "auto"
        ]

        do {
            async let forecast = networkService.sendRequest(
                with: Resource<ForecastResponse>(
                    endpoint: Configuration.url(.openMeteoForecastHost),
                    path: Path.forecast,
                    method: .get,
                    params: params.merging(
                        ["current": "temperature_2m,apparent_temperature,wind_speed_10m,precipitation"]
                    ) { _, new in new }
                )
            )

            async let airQuality = networkService.sendRequest(
                with: Resource<AirQualityResponse>(
                    endpoint: Configuration.url(.openMeteoAirQualityHost),
                    path: Path.airQuality,
                    method: .get,
                    params: params.merging(["current": "european_aqi,pm2_5,uv_index"]) { _, new in new }
                )
            )

            let conditions = try await OutdoorConditions(
                forecast: forecast.current,
                airQuality: airQuality.current,
                fetchedAt: date.now
            )
            await streamable.update { $0 = .success(conditions) }
        } catch {
            logger.error("Failed to fetch outdoor conditions: \(error.localizedDescription, privacy: .private)")
            await streamable.update { $0 = .failure(error) }
        }
    }
}

extension OutdoorConditions {
    init(forecast: ForecastResponse.Current?, airQuality: AirQualityResponse.Current?, fetchedAt: Date) {
        self.init(
            temperature: forecast?.temperature,
            apparentTemperature: forecast?.apparentTemperature,
            windSpeed: forecast?.windSpeed,
            precipitation: forecast?.precipitation,
            europeanAQI: airQuality?.europeanAQI,
            particulates2_5: airQuality?.particulates2_5,
            uvIndex: airQuality?.uvIndex,
            fetchedAt: fetchedAt
        )
    }
}

#if DEBUG
private actor PreviewOutdoorConditionsService: OutdoorConditionsService {
    private let streamable = CurrentValueStreamable<Result<OutdoorConditions, any Error>?>(nil)

    var conditions: AsyncStream<Result<OutdoorConditions, any Error>?> {
        get async { await streamable.updates }
    }

    func fetch(for coordinate: Coordinate) async {
        try? await Task.sleep(for: .seconds(1))
        await streamable.update {
            $0 = .success(
                OutdoorConditions(
                    temperature: 21.4,
                    apparentTemperature: 20.8,
                    windSpeed: 9.2,
                    precipitation: 0,
                    europeanAQI: 34,
                    particulates2_5: 7.1,
                    uvIndex: 3.2,
                    fetchedAt: Date(timeIntervalSince1970: 1_785_000_000)
                )
            )
        }
    }
}
#endif

private enum OutdoorConditionsServiceKey: DependencyKey {
    static let liveValue: any OutdoorConditionsService = LiveOutdoorConditionsService()

    #if DEBUG
    static let previewValue: any OutdoorConditionsService = PreviewOutdoorConditionsService()
    #endif
}

extension DependencyValues {
    var outdoorConditionsService: any OutdoorConditionsService {
        get { self[OutdoorConditionsServiceKey.self] }
        set { self[OutdoorConditionsServiceKey.self] = newValue }
    }
}
