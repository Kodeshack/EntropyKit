import OLMKit

protocol JSONSignable: JSONEncodable {
    /// Signatures for the device key object. A map from user ID, to a map from <algorithm>:<device_id> to the signature.
    ///
    /// The signature is calculated using the process described at Signing JSON.
    /// - See: https://matrix.org/docs/spec/appendices.html#signing-json
    var signatures: [UserID: [String: String]]? { get set }

    /// Return a copy of itself without any of the properties which should
    /// not be included in the calculation of a signature.
    var withoutUnsignables: Self { get }
}

extension JSONSignable {
    /// Signs the JSON using the fingerprint from the given account.
    ///
    /// - Parameter account: The account used for signing
    mutating func sign(using account: Account) {
        let signature = account.signature(for: withoutUnsignables)
        signatures = [account.userID: ["ed25519:\(account.deviceID)": signature]]
    }

    /// Validates the signature of the JSON.
    ///
    /// - Parameter device: The device used for signing
    func validate(device: Device) -> Bool {
        guard let ed25519Key = device.ed25519Key else {
            return false
        }
        return validate(deviceID: device.id, userID: device.userID, ed25519Key: ed25519Key)
    }

    /// Validates the signature of the JSON.
    ///
    /// - Parameters:
    ///   - deviceID: ID of the device to validate against
    ///   - ed25519Key: ed25519 key of the device to validate against
    func validate(deviceID: DeviceID, userID: UserID, ed25519Key: CryptoEngine.Ed25519Key) -> Bool {
        guard let signature = signatures?[userID]?["ed25519:\(deviceID)"] else {
            return false
        }

        let utility = OLMUtility()
        do {
            try utility.verifyEd25519Signature(signature, key: ed25519Key, message: withoutUnsignables.encoded)
            return true
        } catch {
            return false
        }
    }
}
