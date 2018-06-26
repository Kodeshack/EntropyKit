struct OLMEvent: JSONEncodable {
    let type: Event.EventsType
    let content: Event.Content
    let senderID: UserID
    let senderDeviceID: DeviceID
    let keys: [CryptoEngine.Ed25519Key: String]
    let recipient: String
    let recipientKeys: [CryptoEngine.Ed25519Key: String]

    private enum CodingKeys: String, CodingKey {
        case type
        case content
        case senderID = "sender"
        case senderDeviceID = "sender_device"
        case keys
        case recipient
        case recipientKeys = "recipient_keys"
    }

    init(type: Event.EventsType, content: Event.Content, from account: Account, to userID: UserID, on device: Device) {
        self.type = type
        self.content = content
        senderID = account.userID
        senderDeviceID = account.deviceID
        keys = [CryptoEngine.CryptoKeys.ed25519.rawValue: account.identityKeys.ed25519]
        recipient = userID
        recipientKeys = [CryptoEngine.CryptoKeys.ed25519.rawValue: device.ed25519Key!]
    }
}
