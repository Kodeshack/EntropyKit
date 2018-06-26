struct NewDeviceJSON: JSONCodable, Hashable {
    let id: DeviceID
    let roomIDs: [RoomID]

    private enum CodingKeys: String, CodingKey {
        case id = "device_id"
        case roomIDs = "rooms"
    }
}
