struct RoomEncryptionJSON: JSONCodable, Hashable {
    /// The encryption algorithm to be used to encrypt messages sent in this room. For example, `m.megolm.v1.aes-sha2`.
    let algorithm: CryptoEngine.Algorithm

    /// Megolm session rotation period in ms.
    /// Default is 1 Week.
    let rotationPeriodTime: UInt = 7 * 24 * 3600 * 1000
    let rotationPeriodMessages: UInt = 100

    private enum CodingKeys: String, CodingKey {
        case algorithm
        case rotationPeriodTime = "rotation_period_ms"
        case rotationPeriodMessages = "rotation_period_msgs"
    }
}
