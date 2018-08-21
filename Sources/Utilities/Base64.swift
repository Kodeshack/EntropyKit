
enum Base64Error: Error {
    case invalidBase64Data
}


/// Represents data encoded using standard base64 (RFC 3548 or RFC 4648).
/// String representation is always padded.
struct Base64: Codable, Hashable {
    let data: Data

    var string: String {
        return data.base64EncodedString()
    }

    init(data: Data) {
        self.data = data
    }

    init?(base64url: String) {
        let base64 = Base64.base64urlToBase64(base64url)
        guard let data = Data(base64Encoded: base64) else { return nil }
        self.data = data
    }

    init?(base64: String) {
        guard let data = Data(base64Encoded: Base64.padBase64(base64)) else { return nil }
        self.data = data
    }

    init(base64url: Base64URL) {
        data = base64url.data
    }

    init(from decoder: Decoder) throws {
        let base64 = try decoder.singleValueContainer().decode(String.self)
        guard let data = Data(base64Encoded: base64) else { throw Base64Error.invalidBase64Data }
        self.data = data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }

    fileprivate static func padBase64(_ base64: String) -> String {
        if base64.count % 4 != 0 {
            return base64.appending(String(repeating: "=", count: 4 - base64.count % 4))
        }
        return base64
    }

    static func unpadBase64(_ base64: String) -> String {
        if let padding = base64.firstIndex(of: "=") {
            return String(base64[..<padding])
        }
        return base64
    }

    static func base64urlToBase64(_ base64url: String) -> String {
        let base64 = base64url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        return padBase64(base64)
    }

    fileprivate static func base64ToBase64url(_ base64: String) -> String {
        let base64url = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return unpadBase64(base64url)
    }
}

/// Represents data encoded with base64url with URL and filename-safe Alphabet (RFC 4648).
/// String representation is always unpadded.
struct Base64URL: Codable, Hashable {
    let data: Data
    var string: String {
        return Base64.base64ToBase64url(data.base64EncodedString())
    }

    init(data: Data) {
        self.data = data
    }

    init?(base64url: String) {
        let base64 = Base64.base64urlToBase64(base64url)
        guard let data = Data(base64Encoded: base64) else { return nil }
        self.data = data
    }

    init?(base64: String) {
        guard let data = Data(base64Encoded: Base64.padBase64(base64)) else { return nil }
        self.data = data
    }

    init(base64: Base64) {
        data = base64.data
    }

    init(from decoder: Decoder) throws {
        var base64 = try decoder.singleValueContainer().decode(String.self)
        base64 = Base64.base64urlToBase64(base64)
        guard let data = Data(base64Encoded: base64) else { throw Base64Error.invalidBase64Data }
        self.data = data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}
