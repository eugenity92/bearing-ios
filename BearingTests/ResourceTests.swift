import Foundation
import Testing
@testable import Bearing

struct ResourceTests {
    private let endpoint = URL(string: "https://api.open-meteo.com")!

    private enum TestPath: String, StringRepresentable {
        case forecast = "v1/forecast"
    }

    @Test func getParamsBecomeSortedQueryItems() throws {
        let resource = Resource<String>(
            endpoint: endpoint,
            path: TestPath.forecast,
            method: .get,
            params: ["longitude": 21.01, "latitude": 52.23, "current": "temperature_2m"]
        )

        let request = try #require(resource.urlRequest)
        #expect(
            request.url?.absoluteString ==
                "https://api.open-meteo.com/v1/forecast?current=temperature_2m&latitude=52.23&longitude=21.01"
        )
    }

    @Test func getWithoutParamsHasNoQuery() throws {
        let resource = Resource<String>(endpoint: endpoint, path: TestPath.forecast, method: .get)
        let request = try #require(resource.urlRequest)

        #expect(request.url?.absoluteString == "https://api.open-meteo.com/v1/forecast")
        #expect(request.url?.query == nil)
    }

    @Test func nilPathLeavesEndpointUntouched() throws {
        let resource = Resource<String>(endpoint: endpoint, method: .get)
        let request = try #require(resource.urlRequest)

        #expect(request.url?.absoluteString == "https://api.open-meteo.com")
    }

    @Test func postParamsBecomeJSONBodyAndNotQuery() throws {
        let resource = Resource<String>(
            endpoint: endpoint,
            path: TestPath.forecast,
            method: .post,
            params: ["latitude": 52.23]
        )

        let request = try #require(resource.urlRequest)
        #expect(request.url?.query == nil)
        #expect(request.httpMethod == "POST")

        let body = try #require(request.httpBody)
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(decoded?["latitude"] as? Double == 52.23)
    }

    @Test func contentTypeAndAcceptHeadersAreAlwaysSet() throws {
        let request = try #require(Resource<String>(endpoint: endpoint, method: .get).urlRequest)

        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func explicitHeadersAreApplied() throws {
        let resource = Resource<String>(
            endpoint: endpoint,
            method: .get,
            headers: ["X-Trace-Id": "abc123"]
        )

        let request = try #require(resource.urlRequest)
        #expect(request.value(forHTTPHeaderField: "X-Trace-Id") == "abc123")
    }

    @Test func methodIsUppercased() throws {
        #expect(try #require(Resource<String>(endpoint: endpoint, method: .delete).urlRequest).httpMethod == "DELETE")
    }

    @Test func debugDescriptionDoesNotLeakParameters() {
        let resource = Resource<String>(
            endpoint: endpoint,
            path: TestPath.forecast,
            method: .get,
            params: ["latitude": 52.23, "longitude": 21.01]
        )

        #expect(resource.debugDescription == "GET https://api.open-meteo.com/v1/forecast")
    }
}
