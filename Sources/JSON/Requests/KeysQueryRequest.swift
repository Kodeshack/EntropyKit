struct KeysQueryRequest: JSONEncodable {
    /// The time (in milliseconds) to wait when downloading keys from remote servers. 10 seconds is the recommended default.
    let timeout = 10000

    /// The keys to be downloaded. A map from user ID, to a list of device IDs,
    /// or to an empty list to indicate all devices for the corresponding user.
    let deviceKeys: [UserID: [DeviceID]]

    private enum CodingKeys: String, CodingKey {
        case deviceKeys = "device_keys"
    }
}
