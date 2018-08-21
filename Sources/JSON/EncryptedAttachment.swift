
struct EncryptedAttachment: JSONCodable, Hashable {
    enum EncryptedAttachmentVersion: String, Codable, Hashable {
        case v2
    }

    let version: EncryptedAttachmentVersion
    var mxcURL: URL?
    let mimeType: String
    let size: Int?
    let initializationVector: Base64URL
    let key: EncryptedAttachmentKey
    let hashes: EncryptedAttachmentHashes

    init(version: EncryptedAttachmentVersion, mxcURL: URL?, mimeType: String, size: Int?, iv: Base64URL, key: EncryptedAttachmentKey, hashes: EncryptedAttachmentHashes) {
        self.version = version
        self.mxcURL = mxcURL
        self.mimeType = mimeType
        self.size = size
        initializationVector = iv
        self.key = key
        self.hashes = hashes
    }

    init(mimeType: String, size: Int?, iv: Data, key: Data, sha256Hash: Data) {
        let attachmentKey = EncryptedAttachmentKey.v2KeyInfo(key: key)

        let attachmentHashes = EncryptedAttachmentHashes(sha256: Base64.unpadBase64(sha256Hash.base64EncodedString()))

        self.init(version: .v2, mxcURL: nil, mimeType: mimeType, size: size, iv: Base64URL(data: iv), key: attachmentKey, hashes: attachmentHashes)
    }

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case mxcURL = "url"
        case mimeType = "mimetype"
        case size
        case key
        case initializationVector = "iv"
        case hashes
    }
}

extension EncryptedAttachment {
    struct EncryptedAttachmentKey: JSONCodable, Hashable {
        enum AttachmentEncyptionKeyAlgorithm: String, Codable, Hashable {
            case A256CTR
        }

        let algorithm: AttachmentEncyptionKeyAlgorithm
        let external: Bool
        let operations: [String]
        let type: String
        let key: Base64URL

        enum CodingKeys: String, CodingKey {
            case algorithm = "alg"
            case external = "ext"
            case operations = "key_ops"
            case type = "kty"
            case key = "k"
        }

        static func v2KeyInfo(key: Data) -> EncryptedAttachmentKey {
            return EncryptedAttachmentKey(
                algorithm: .A256CTR,
                external: true,
                operations: ["encrypt", "decrypt"],
                type: "oct",
                key: Base64URL(data: key)
            )
        }
    }

    struct EncryptedAttachmentHashes: JSONCodable, Hashable {
        let sha256: String
    }
}
