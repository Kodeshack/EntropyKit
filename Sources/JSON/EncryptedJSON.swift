import OLMKit

struct EncryptedJSON: JSONCodable, Hashable {
    /// Identity key from sender
    let senderKey: String
    let ciphertext: Ciphertext
    let algorithm: CryptoEngine.Algorithm

    /// Should only be missing when using olm
    let sessionID: String?

    /// Should only be missing when using olm
    let deviceID: DeviceID?

    private enum CodingKeys: String, CodingKey {
        case senderKey = "sender_key"
        case ciphertext
        case algorithm
        case sessionID = "session_id"
        case deviceID = "device_id"
    }

    init(senderKey: CryptoEngine.Curve25519Key, ciphertexts: [CryptoEngine.Curve25519Key: OlmCiphertext]) {
        self.senderKey = senderKey
        ciphertext = .olmCiphertext(ciphertexts)
        algorithm = .olm
        sessionID = nil
        deviceID = nil
    }

    init(senderKey: CryptoEngine.Ed25519Key, ciphertext: String, sessionID: String, deviceID: DeviceID) {
        self.senderKey = senderKey
        self.ciphertext = .megolmCiphertext(ciphertext)
        algorithm = .megolm
        self.sessionID = sessionID
        self.deviceID = deviceID
    }
}

extension EncryptedJSON {
    enum Ciphertext: Hashable {
        case olmCiphertext([String: OlmCiphertext])
        case megolmCiphertext(String)

        var olmCiphertext: [String: OlmCiphertext]? {
            if case let .olmCiphertext(ciphertext) = self {
                return ciphertext
            }
            return nil
        }

        var megolmCiphertext: String? {
            if case let .megolmCiphertext(ciphertext) = self {
                return ciphertext
            }
            return nil
        }
    }

    struct OlmCiphertext: JSONCodable, Hashable {
        let body: String
        let type: OLMMessageType
    }
}

extension OLMMessageType: Codable {}

extension EncryptedJSON {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        senderKey = try container.decode(String.self, forKey: .senderKey)
        algorithm = try container.decode(CryptoEngine.Algorithm.self, forKey: .algorithm)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID)

        switch algorithm {
        case .olm:
            ciphertext = .olmCiphertext(try container.decode([String: OlmCiphertext].self, forKey: .ciphertext))
        case .megolm:
            ciphertext = .megolmCiphertext(try container.decode(String.self, forKey: .ciphertext))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(senderKey, forKey: .senderKey)
        try container.encode(algorithm, forKey: .algorithm)
        try container.encodeIfPresent(sessionID, forKey: .sessionID)
        try container.encodeIfPresent(deviceID, forKey: .deviceID)

        switch self.ciphertext {
        case let .olmCiphertext(ciphertext):
            try container.encode(ciphertext, forKey: .ciphertext)
        case let .megolmCiphertext(ciphertext):
            try container.encode(ciphertext, forKey: .ciphertext)
        }
    }
}
