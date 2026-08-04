import Dependencies
import Foundation
import Testing
@testable import Bearing

struct OutdoorConditionsServiceTests {
    private let warsaw = Coordinate(latitude: 52.2297, longitude: 21.0122)
    private let fetchedAt = Date(timeIntervalSince1970: 1_785_000_000)

    private func fixtures(airQuality: String = "air-quality") throws -> [String: Data] {
        [
            "v1/forecast": try Fixture.data("forecast"),
            "v1/air-quality": try Fixture.data(airQuality)
        ]
    }

    @Test func mergesBothResponsesIntoOneValue() async throws {
        let network = MockNetworkService(fixtures: try fixtures())

        let conditions = try await withDependencies {
            $0.networkService = network
            $0.date = .constant(fetchedAt)
        } operation: {
            let service = LiveOutdoorConditionsService()
            await service.fetch(for: warsaw)
            return try #require(await firstResult(from: service)).get()
        }

        #expect(conditions.temperature == 32.3)
        #expect(conditions.apparentTemperature == 33.1)
        #expect(conditions.windSpeed == 5.0)
        #expect(conditions.europeanAQI == 56)
        #expect(conditions.particulates2_5 == 10.3)
        #expect(conditions.fetchedAt == fetchedAt)
    }

    @Test func nullFieldsSurviveAsNilRatherThanFailingTheDecode() async throws {
        let network = MockNetworkService(fixtures: try fixtures(airQuality: "air-quality-nulls"))

        let conditions = try await withDependencies {
            $0.networkService = network
            $0.date = .constant(fetchedAt)
        } operation: {
            let service = LiveOutdoorConditionsService()
            await service.fetch(for: warsaw)
            return try #require(await firstResult(from: service)).get()
        }

        #expect(conditions.europeanAQI == nil)
        #expect(conditions.uvIndex == nil)
        #expect(conditions.particulates2_5 == 8.1)
        #expect(conditions.temperature == 32.3)
    }

    @Test func networkFailurePropagatesAsFailureResult() async throws {
        let network = MockNetworkService(error: NetworkError.noInternet)

        let result = await withDependencies {
            $0.networkService = network
            $0.date = .constant(fetchedAt)
        } operation: {
            let service = LiveOutdoorConditionsService()
            await service.fetch(for: warsaw)
            return await firstResult(from: service)
        }

        guard case .failure(let error) = try #require(result) else {
            Issue.record("Expected a failure result")
            return
        }
        #expect(error as? NetworkError == .noInternet)
    }

    @Test func coordinateIsRoundedBeforeLeavingTheDevice() async throws {
        let network = MockNetworkService(fixtures: try fixtures())

        await withDependencies {
            $0.networkService = network
            $0.date = .constant(fetchedAt)
        } operation: {
            await LiveOutdoorConditionsService().fetch(for: warsaw)
        }

        let params = await network.requestedParams
        #expect(params.count == 2)

        for sent in params {
            #expect(sent["latitude"] as? Double == 52.23)
            #expect(sent["longitude"] as? Double == 21.01)
        }
    }

    @Test func bothEndpointsAreRequested() async throws {
        let network = MockNetworkService(fixtures: try fixtures())

        await withDependencies {
            $0.networkService = network
            $0.date = .constant(fetchedAt)
        } operation: {
            await LiveOutdoorConditionsService().fetch(for: warsaw)
        }

        #expect(Set(await network.requestedPaths) == ["v1/forecast", "v1/air-quality"])
    }

    private func firstResult(
        from service: LiveOutdoorConditionsService
    ) async -> Result<OutdoorConditions, any Error>? {
        for await value in await service.conditions where value != nil {
            return value
        }
        return nil
    }
}
