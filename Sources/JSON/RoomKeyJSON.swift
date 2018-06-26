struct RoomKeyJSON: JSONCodable, Hashable {
    let algorithm: CryptoEngine.Algorithm
    let ciphertext: String?
    let roomID: String
    let sessionID: String
    let sessionKey: String
    let chainIndex: UInt

    private enum CodingKeys: String, CodingKey {
        case algorithm
        case ciphertext
        case roomID = "room_id"
        case sessionID = "session_id"
        case sessionKey = "session_key"
        case chainIndex = "chain_index"
    }
}
