struct KeysUploadResponse: JSONCodable {
    /// For each key algorithm, the number of unclaimed one-time keys of that type currently held on the server for this device.
    let oneTimeKeyCounts: [CryptoEngine.CryptoKeys.RawValue: UInt]

    private enum CodingKeys: String, CodingKey {
        case oneTimeKeyCounts = "one_time_key_counts"
    }
}
