import Foundation

protocol JSONDecodable: Decodable {
    static func decode(_ data: Data?) -> Result<Self, Error>
}

extension JSONDecodable {
    static func decode(_ data: Data?) -> Result<Self, Error> {
        guard let data = data else {
            return .failure(JSONError.emptyJSON)
        }

        return Result {
            try JSONDecoder().decode(Self.self, from: data)
        }
    }
}
