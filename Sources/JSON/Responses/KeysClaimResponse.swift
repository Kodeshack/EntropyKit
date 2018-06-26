struct KeysClaimResponse: JSONCodable {
    /// If any remote homeservers could not be reached, they are recorded here.
    /// The names of the properties are the names of the unreachable servers.
    ///
    /// If the homeserver could be reached, but the user or device was unknown, no failure is recorded.
    /// Instead, the corresponding user or device is missing from the one_time_keys result.
    let failures: [String: String]

    /// One-time keys for the queried devices.
    /// A map from user ID, to a map from <algorithm>:<key_id> to the key object.
    let oneTimeKeys: [UserID: [DeviceID: [String: DeviceOneTimeKey]]]

    private enum CodingKeys: String, CodingKey {
        case failures
        case oneTimeKeys = "one_time_keys"
    }
}

extension KeysClaimResponse {
    struct DeviceOneTimeKey: JSONDecodable, JSONSignable {
        let key: String
        var signatures: [UserID: [String: String]]?
        var withoutUnsignables: KeysClaimResponse.DeviceOneTimeKey {
            var copy = self
            copy.signatures = nil
            return copy
        }
    }
}
