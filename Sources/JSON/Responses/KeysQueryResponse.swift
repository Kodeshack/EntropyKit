struct KeysQueryResponse: JSONCodable {
    /// If any remote homeservers could not be reached, they are recorded here.
    /// The names of the properties are the names of the unreachable servers.
    ///
    /// If the homeserver could be reached, but the user or device was unknown, no failure is recorded.
    /// Instead, the corresponding user or device is missing from the device_keys result.
    let failures: [String: String]

    /// Information on the queried devices. A map from user ID, to a map from device ID to device information.
    /// For each device, the information returned will be the same as uploaded via /keys/upload, with the addition of an unsigned property.
    let deviceKeys: [UserID: [DeviceID: DeviceKeys]]

    private enum CodingKeys: String, CodingKey {
        case failures
        case deviceKeys = "device_keys"
    }
}

extension KeysQueryResponse {
    struct DeviceKeys: JSONCodable, JSONSignable {
        /// The ID of the user the device belongs to. Must match the user ID used when logging in.
        let userID: UserID

        /// The ID of the device these keys belong to. Must match the device ID used when logging in.
        let deviceID: DeviceID

        /// The encryption algorithms supported by this device.
        let algorithms: [CryptoEngine.Algorithm]

        /// identity keys. The names of the properties should be in the format <algorithm>:<device_id>.
        /// The keys themselves should be encoded as specified by the key algorithm.
        let keys: [String: String]

        /// Additional data added to the device key information by intermediate servers, and not covered by the signatures.
        var unsignedDeviceInfo: UnsignedDeviceInfo?

        var signatures: [UserID: [String: String]]?
        var withoutUnsignables: DeviceKeys {
            var copy = self
            copy.signatures = nil
            copy.unsignedDeviceInfo = nil
            return copy
        }

        private enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case deviceID = "device_id"
            case algorithms
            case keys
            case signatures
            case unsignedDeviceInfo = "unsigned"
        }
    }
}

extension KeysQueryResponse.DeviceKeys {
    struct UnsignedDeviceInfo: JSONCodable {
        /// The display name which the user set on the device.
        let deviceDisplayName: String?

        private enum CodingKeys: String, CodingKey {
            case deviceDisplayName = "device_display_name"
        }
    }
}
