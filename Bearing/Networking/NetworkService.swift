import Dependencies
import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Network")

protocol NetworkService: Sendable {
    func sendRequest<T: Decodable & Sendable>(with resource: Resource<T>) async throws -> T
}

struct LiveNetworkService: NetworkService {
    private let urlSession: URLSession

    init(configuration: URLSessionConfiguration = .default) {
        configuration.timeoutIntervalForRequest = 30
        urlSession = URLSession(configuration: configuration)
    }

    func sendRequest<T: Decodable & Sendable>(with resource: Resource<T>) async throws -> T {
        guard let urlRequest = resource.urlRequest else {
            logger.error("\(resource.debugDescription, privacy: .private) could not be turned into a URLRequest")
            throw NetworkError.badRequest
        }

        logger.notice("\(resource.debugDescription, privacy: .private) sending")

        let data = try await fetchData(from: urlRequest)
        guard !data.isEmpty else { throw NetworkError.noData }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.error("\(resource.debugDescription, privacy: .private) failed to decode: \(error.localizedDescription)")
            throw NetworkError.decodingFailed
        }
    }
}

private extension LiveNetworkService {
    func fetchData(from urlRequest: URLRequest) async throws -> Data {
        try await withTaskCancellationHandler {
            do {
                let (data, response) = try await urlSession.data(for: urlRequest)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.unknown(URLError(.badServerResponse))
                }
                if let error = NetworkError(statusCode: httpResponse.statusCode) { throw error }
                return data
            } catch let error as URLError {
                throw NetworkError(urlErrorCode: error.code)
            } catch let error as NetworkError {
                throw error
            } catch {
                throw NetworkError.unknown(error)
            }
        } onCancel: {
            urlSession.getAllTasks { tasks in
                tasks
                    .filter { $0.originalRequest?.url == urlRequest.url }
                    .forEach { $0.cancel() }
            }
        }
    }
}

private enum NetworkServiceKey: DependencyKey {
    static let liveValue: any NetworkService = LiveNetworkService()
}

extension DependencyValues {
    var networkService: any NetworkService {
        get { self[NetworkServiceKey.self] }
        set { self[NetworkServiceKey.self] = newValue }
    }
}
