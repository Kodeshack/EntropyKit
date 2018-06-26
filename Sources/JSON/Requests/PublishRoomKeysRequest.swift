struct PublishRoomKeysRequest: JSONEncodable {
    let messages: [UserID: [DeviceID: EncryptedJSON]]
}
