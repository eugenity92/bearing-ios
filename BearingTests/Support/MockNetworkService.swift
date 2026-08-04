import Foundation
@testable import Bearing

actor MockNetworkService: NetworkService {
    private var fixtures: [String: Data]
    private var error: (any Error)?
    private(set) var requestedPaths: [String] = []
    private(set) var requestedParams: [[String: any Sendable]] = []

    init(fixtures: [String: Data] = [:], error: (any Error)? = nil) {
        self.fixtures = fixtures
        self.error = error
    }

    func sendRequest<T: Decodable & Sendable>(with resource: Resource<T>) async throws -> T {
        requestedPaths.append(resource.path ?? "")
        requestedParams.append(resource.params ?? [:])

        if let error { throw error }

        guard let path = resource.path, let data = fixtures[path] else {
            throw NetworkError.noData
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
