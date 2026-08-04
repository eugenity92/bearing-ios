import Foundation
import Testing
@testable import Bearing

struct NetworkErrorMappingTests {
    @Test(arguments: [200, 201, 204, 299])
    func successStatusCodesProduceNoError(code: Int) {
        #expect(NetworkError(statusCode: code) == nil)
    }

    @Test func clientStatusCodesMapToNamedCases() {
        #expect(NetworkError(statusCode: 400) == .badRequest)
        #expect(NetworkError(statusCode: 401) == .unauthorized)
        #expect(NetworkError(statusCode: 403) == .forbidden)
        #expect(NetworkError(statusCode: 404) == .notFound)
    }

    @Test(arguments: [500, 502, 503, 599])
    func serverStatusCodesCarryTheirCode(code: Int) {
        #expect(NetworkError(statusCode: code) == .serverError(code))
    }

    @Test func unmappedStatusCodeFallsBackToOtherHTTPError() {
        #expect(NetworkError(statusCode: 418) == .otherHTTPError(418))
        #expect(NetworkError(statusCode: 302) == .otherHTTPError(302))
    }

    @Test(arguments: [
        URLError.Code.notConnectedToInternet,
        .dataNotAllowed,
        .networkConnectionLost,
        .cannotConnectToHost
    ])
    func connectivityCodesCollapseToNoInternet(code: URLError.Code) {
        #expect(NetworkError(urlErrorCode: code) == .noInternet)
    }

    @Test func timeoutAndCancellationAreDistinct() {
        #expect(NetworkError(urlErrorCode: .timedOut) == .timeout)
        #expect(NetworkError(urlErrorCode: .cancelled) == .cancelled)
    }

    @Test func unmappedURLErrorBecomesUnknown() {
        let error = NetworkError(urlErrorCode: .badServerResponse)
        guard case .unknown = error else {
            Issue.record("Expected .unknown, got \(error)")
            return
        }
    }
}
