struct KeysUploadRequest: JSONEncodable {
    /// Identity keys for the device. May be absent if no new identity keys are required.
    let deviceKeys: DeviceKeys?

    /// One-time keys for "pre-key" messages.
    /// The names of the properties should be in the format <algorithm>:<key_id>.
    /// The format of the key is determined by the key algorithm.
    ///
    /// May be absent if no new one-time keys are required.
    let oneTimeKeys: [String: OneTimeKeyObject]?

    private enum CodingKeys: String, CodingKey {
        case deviceKeys = "device_keys"
        case oneTimeKeys = "one_time_keys"
    }
}

extension KeysUploadRequest {
    struct DeviceKeys: JSONEncodable, JSONSignable {
        /// The ID of the user the device belongs to. Must match the user ID used when logging in.
        let userID: UserID

        /// The ID of the device these keys belong to. Must match the device ID used when logging in.
        let deviceID: DeviceID

        /// The encryption algorithms supported by this device.
        let algorithms: [CryptoEngine.Algorithm]

        /// identity keys. The names of the properties should be in the format <algorithm>:<device_id>.
        /// The keys themselves should be encoded as specified by the key algorithm.
        let keys: [String: String]

        var signatures: [UserID: [String: String]]?
        var withoutUnsignables: DeviceKeys {
            var copy = self
            copy.signatures = nil
            return copy
        }

        private enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case deviceID = "device_id"
            case algorithms
            case keys
            case signatures
        }

        init(account: Account, algorithms: [CryptoEngine.Algorithm], keys: [String: String]) {
            userID = account.userID
            deviceID = account.deviceID
            self.algorithms = algorithms
            self.keys = keys
            sign(using: account)
        }
    }
}

extension KeysUploadRequest {
    struct OneTimeKeyObject: JSONEncodable, JSONSignable {
        let key: String
        var signatures: [UserID: [String: String]]?
        var withoutUnsignables: OneTimeKeyObject {
            var copy = self
            copy.signatures = nil
            return copy
        }

        init(key: String, signUsing account: Account) {
            self.key = key
            sign(using: account)
        }
    }
}
