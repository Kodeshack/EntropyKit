import Foundation

protocol JSONDecodable: Decodable {
    static func decode(_ data: Data?) -> Result<Self>
}

extension JSONDecodable {
    static func decode(_ data: Data?) -> Result<Self> {
        guard let data = data else {
            return .Error(JSONError.emptyJSON)
        }

        do {
            return .Value(try JSONDecoder().decode(Self.self, from: data))
        } catch {
            return .Error(error)
        }
    }
}
