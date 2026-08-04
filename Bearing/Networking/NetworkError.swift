import Foundation

enum NetworkError: Error, Sendable {
    case noInternet
    case timeout
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case cancelled
    case serverError(Int)
    case otherHTTPError(Int)
    case noData
    case decodingFailed
    case unknown(any Error)
}

extension NetworkError {
    init?(statusCode: Int) {
        switch statusCode {
        case 200...299: return nil
        case 400: self = .badRequest
        case 401: self = .unauthorized
        case 403: self = .forbidden
        case 404: self = .notFound
        case 500...599: self = .serverError(statusCode)
        default: self = .otherHTTPError(statusCode)
        }
    }

    init(urlErrorCode: URLError.Code) {
        switch urlErrorCode {
        case .notConnectedToInternet, .dataNotAllowed, .networkConnectionLost, .cannotConnectToHost:
            self = .noInternet
        case .timedOut:
            self = .timeout
        case .cancelled:
            self = .cancelled
        default:
            self = .unknown(URLError(urlErrorCode))
        }
    }
}

extension NetworkError: CustomStringConvertible {
    var description: String {
        switch self {
        case .noInternet: "No internet connection"
        case .timeout: "The request timed out"
        case .badRequest: "Bad request"
        case .unauthorized: "Unauthorized"
        case .forbidden: "Forbidden"
        case .notFound: "Not found"
        case .cancelled: "The request was cancelled"
        case .serverError(let code): "Server error (\(code))"
        case .otherHTTPError(let code): "Unexpected HTTP status (\(code))"
        case .noData: "The response contained no data"
        case .decodingFailed: "The response could not be decoded"
        case .unknown(let error): "Unexpected error: \(error.localizedDescription)"
        }
    }
}

extension NetworkError: Equatable {
    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.noInternet, .noInternet), (.timeout, .timeout), (.badRequest, .badRequest),
             (.unauthorized, .unauthorized), (.forbidden, .forbidden), (.notFound, .notFound),
             (.cancelled, .cancelled), (.noData, .noData), (.decodingFailed, .decodingFailed):
            true
        case (.serverError(let lhs), .serverError(let rhs)),
             (.otherHTTPError(let lhs), .otherHTTPError(let rhs)):
            lhs == rhs
        default:
            false
        }
    }
}
