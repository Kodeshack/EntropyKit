struct KeysClaimRequest: JSONEncodable {
    /// The time (in milliseconds) to wait when downloading keys from remote servers. 10 seconds is the recommended default.
    let timeout = 10000

    /// The keys to be claimed. A map from user ID, to a map from device ID to algorithm name.
    let oneTimeKeys: [UserID: [DeviceID: CryptoEngine.CryptoKeys]]

    private enum CodingKeys: String, CodingKey {
        case timeout
        case oneTimeKeys = "one_time_keys"
    }

    init(devices: [Device]) {
        var requestedOneTimeKeys = [UserID: [DeviceID: CryptoEngine.CryptoKeys]]()

        devices
            .forEach { device in
            var dict = requestedOneTimeKeys[device.userID] ?? [:]
            dict[device.id] = .signedCurve25519
            requestedOneTimeKeys[device.userID] = dict
        }

        oneTimeKeys = requestedOneTimeKeys
    }
}
