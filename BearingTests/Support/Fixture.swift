import Foundation

private final class BundleToken {}

enum Fixture {
    static func data(_ name: String) throws -> Data {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw FixtureError.notFound(name)
        }
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try JSONDecoder().decode(type, from: data(name))
    }
}

enum FixtureError: Error, CustomStringConvertible {
    case notFound(String)

    var description: String {
        switch self {
        case .notFound(let name):
            "Fixture \(name).json is not in the test bundle. Check it is a member of BearingTests resources."
        }
    }
}
