import Foundation

protocol StringRepresentable: Sendable {
    var string: String { get }
}

extension RawRepresentable where RawValue == String {
    var string: String { rawValue }
}

enum HTTPMethod: String, Sendable {
    case get, post, put, delete
}

enum ContentType: String, Sendable {
    case json = "application/json"
}

struct Resource<T>: Sendable {
    let endpoint: URL
    let path: String?
    let method: HTTPMethod
    let params: [String: any Sendable]?
    let headers: [String: String]?
    let contentType: ContentType
    let acceptType: ContentType

    init(
        endpoint: URL,
        path: (any StringRepresentable)? = nil,
        method: HTTPMethod,
        params: [String: any Sendable]? = nil,
        headers: [String: String]? = nil,
        contentType: ContentType = .json,
        acceptType: ContentType = .json
    ) {
        self.endpoint = endpoint
        self.path = path?.string
        self.method = method
        self.params = params
        self.headers = headers
        self.contentType = contentType
        self.acceptType = acceptType
    }
}

extension Resource {
    var urlRequest: URLRequest? {
        guard let url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue.uppercased()

        if let params, method != .get, contentType == .json {
            guard let body = try? JSONSerialization.data(withJSONObject: params) else { return nil }
            request.httpBody = body
        }

        request.setValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")
        request.setValue(acceptType.rawValue, forHTTPHeaderField: "Accept")
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        return request
    }
}

private extension Resource {
    var url: URL? {
        var url = endpoint
        if let path { url.append(path: path) }

        guard method == .get, let params, !params.isEmpty else { return url }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = params
            .map { URLQueryItem(name: $0.key, value: "\($0.value)") }
            .sorted { $0.name < $1.name }
        return components?.url
    }
}

extension Resource: CustomDebugStringConvertible {
    var debugDescription: String {
        "\(method.rawValue.uppercased()) \(endpoint.absoluteString)/\(path ?? "")"
    }
}
