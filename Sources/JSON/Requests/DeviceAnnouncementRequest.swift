struct DeviceAnnouncementRequest: JSONSignable {
    let messages: [String: [String: DeviceInfo]]
    var signatures: [UserID: [String: String]]?
    var withoutUnsignables: DeviceAnnouncementRequest {
        var copy = self
        copy.signatures = nil
        return copy
    }

    init(deviceID: DeviceID, userRooms: [String: [String]], signUsing account: Account) {
        messages = Dictionary(uniqueKeysWithValues: userRooms.map { userID, roomIDs in
            (userID, ["*": DeviceInfo(deviceID: deviceID, roomIDs: roomIDs)])
        })
        sign(using: account)
    }

    struct DeviceInfo: JSONCodable {
        let deviceID: DeviceID
        let roomIDs: [RoomID]

        private enum CodingKeys: String, CodingKey {
            case deviceID = "device_id"
            case roomIDs = "rooms"
        }
    }
}
