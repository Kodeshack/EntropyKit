import GRDB
import OLMKit

class E2EEService {
    enum E2EEError: Error {
        case deviceEd25519KeyMismatch(device: Device)
    }

    private let database: Database

    init(database: Database) {
        self.database = database
    }

    private func fetchAllUserRooms(without userID: UserID) -> Result<[UserID: [String]]> {
        return Result {
            let userRoomPairs: [(userID: UserID, roomID: String)] = try database.dbQueue.inDatabase { db -> [Row] in
                let roomsTable = Database.v0.rooms.table
                let roomID = Database.v0.rooms.id
                let roomsEncrypted = Database.v0.rooms.encrypted
                let roomsAnnounced = Database.v0.rooms.announced
                let usersRoomsTable = Database.v0.users_rooms.table
                let usersRoomsUserID = Database.v0.users_rooms.userID
                let usersRoomsRoomID = Database.v0.users_rooms.roomID

                let sqlRequest = SQLRequest<Void>(
                    "SELECT \(roomsTable).\(roomID),\(usersRoomsTable).\(usersRoomsUserID) FROM \(usersRoomsTable) " +
                        "JOIN \(roomsTable) ON \(roomsTable).\(roomID) = \(usersRoomsTable).\(usersRoomsRoomID) " +
                        "WHERE \(roomsTable).\(roomsEncrypted) = ? AND \(roomsTable).\(roomsAnnounced) = ?",
                    arguments: [true, false]
                )

                return try Row.fetchAll(db, sqlRequest)
            }.map { row in
                (
                    roomID: row[0]!,
                    userID: row[1]!
                )
            }

            // [(RoomID, UserID)] -> [UserID: [RoomID]]
            //
            // Group the array of (RoomID, UserID) tuples into a dictionary [UserID: [RoomID]].
            // Each UserID entry in the resulting dictionary will have an array of RoomIDs; exactly as
            // many as there are tuples containing the RoomID in the original array.
            // Filter just removes the current user from the payload because redundancy.
            //
            // Just don't ask... And don't trust git blame, Tobi totally wrote this.
            // 🔞 this is the best code.
            return Dictionary(grouping: userRoomPairs) { $0.userID }.mapValues { $0.map { $0.roomID } }.filter { $0.key != userID }
        }
    }

    func announceDevice(account: Account, completionHandler: @escaping (Result<Void>) -> Void = { _ in }) {
        let userRoomsResult = fetchAllUserRooms(without: account.userID)
        guard let userRooms = userRoomsResult.value else {
            completionHandler(.Error(userRoomsResult.error!))
            return
        }

        guard !userRooms.isEmpty else {
            completionHandler(.Value(()))
            return
        }

        let announcement = DeviceAnnouncementRequest(deviceID: account.deviceID, userRooms: userRooms, signUsing: account)
        MatrixAPI.default.announceDevice(accessToken: account.accessToken, transactionID: account.nextTransactionID(), deviceAnnouncementRequest: announcement) { result in
            completionHandler(Result {
                _ = try result.dematerialize()

                let rooms = Set(userRooms.flatMap { $1 }).map { Room(id: $0) }

                try self.database.dbQueue.inTransaction { db in
                    try rooms.forEach { room in
                        room.announced = true
                        try room.update(db)
                    }
                    return .commit
                }
            })
        }
    }

    // set request to nil to check key count <- this is pretty stupid
    func uploadKeys(account: Account, request: KeysUploadRequest?, queue: DispatchQueue, completionHandler: @escaping (Result<UInt>) -> Void = { _ in }) {
        MatrixAPI.default.uploadKeys(accessToken: account.accessToken, deviceID: account.deviceID, keysUploadRequest: request, queue: queue, completionHandler: completionHandler)
    }

    /// Extracts the new devices from the input `devices` array by comparing them against the devices stored in the DB.
    /// Also checks if a device's ed25519 key has changed if it finds a record matching the device id and user id.
    /// If the key has changed, an error is returned.
    /// From the matrix E2EE guide:
    /// "The client should check if the user_id/device_id correspond to a device it had seen
    /// previously. If it did, the client must check that the Ed25519 key hasn't changed.
    /// Again, if it has changed, no further processing should be done on the device."
    private func extractNew(devices: [Device]) -> Result<[Device]> {
        return Result {
            try database.dbQueue.inDatabase { db in
                let deviceKeys = devices.map { d -> [String: String] in
                    [Database.v0.devices.id: d.id, Database.v0.devices.userID: d.userID]
                }

                let knownDevices = try Device.filter(keys: deviceKeys).fetchAll(db)

                // We only need to save new devices which are not known. Otherwise we can simply
                // ignore them, except if the ed25519 keys don't match
                return try devices.filter { device in
                    if let other = knownDevices.first(where: { $0.id == device.id }) {
                        if device.ed25519Key != other.ed25519Key {
                            throw E2EEError.deviceEd25519KeyMismatch(device: device)
                        }

                        return false
                    } else {
                        return true
                    }
                }
            }
        }
    }

    /// Flatten the complex and deeply nested response object into a more convenient
    /// array of devices.
    ///
    /// @TODO: maybe transform into a Dictionary instead of an array for extractNew
    ///
    /// - Returns: All the devices that are contained in the reponse.
    private func flattenKeysQueryResponse(_ keysQueryReponse: KeysQueryResponse) -> [Device] {
        return keysQueryReponse.deviceKeys.flatMap { userDevices -> [Device] in
            userDevices.value.compactMap { item -> Device? in
                let deviceData = item.value

                if deviceData.deviceID != item.key || deviceData.userID != userDevices.key {
                    // @TODO: proper logging
                    print("Device ID or User ID do not match")
                    return nil
                }

                guard let curve25519Key = deviceData.keys["\(CryptoEngine.CryptoKeys.curve25519):\(deviceData.deviceID)"],
                    let ed25519Key = deviceData.keys["\(CryptoEngine.CryptoKeys.ed25519):\(deviceData.deviceID)"] else {
                    // @TODO: proper logging
                    print("Device is useless for crypto stuff")
                    return nil
                }

                let device = Device(
                    id: deviceData.deviceID,
                    userID: deviceData.userID,
                    displayname: deviceData.unsignedDeviceInfo?.deviceDisplayName,
                    curve25519Key: curve25519Key,
                    ed25519Key: ed25519Key,
                    algorithms: deviceData.algorithms
                )

                guard deviceData.validate(device: device) else {
                    // @TODO: proper logging
                    print("Device data signature is invalid")
                    return nil
                }

                return device
            }
        }
    }

    /// Removes devices from the database which don't seem to be active anymore (not sending any keys) by comparing
    /// a given device list with known devices in the DB.
    /// ∀ d ∈ DB \ devices, delete d
    private func removeOldDevices(userIDs: [UserID], devices: [Device]) -> Result<Void> {
        return Result {
            guard !userIDs.isEmpty, !devices.isEmpty else {
                return
            }

            try database.dbQueue.inDatabase { db in
                let userQs = Array(repeating: "?", count: userIDs.count).joined(separator: ",")
                let deviceQs = Array(repeating: "?", count: devices.count).joined(separator: ",")

                let deleteQuery =
                    "DELETE FROM \(Database.v0.devices.table) " +
                    "WHERE \(Database.v0.devices.userID) IN (\(userQs)) " +
                    "AND \(Database.v0.devices.id) IN " +
                    "(SELECT id FROM \(Database.v0.devices.table) " +
                    "WHERE \(Database.v0.devices.id) NOT IN (\(deviceQs)))"

                try db.execute(deleteQuery, arguments: StatementArguments(userIDs + devices.map { $0.id }))
            }
        }
    }

    /// Pls note, this also saves to DB
    func getDevices(account: Account, userIDs: [UserID], queue: DispatchQueue, completionHandler: @escaping (Result<[Device]>) -> Void) {
        let keysQueryRequest = KeysQueryRequest(deviceKeys: Dictionary(uniqueKeysWithValues: userIDs.map { ($0, []) }))

        MatrixAPI.default.queryKeys(accessToken: account.accessToken, keysQueryRequest: keysQueryRequest, queue: queue) { result in
            completionHandler(Result {
                let keysQueryReponse = try result.dematerialize()

                let devices = self.flattenKeysQueryResponse(keysQueryReponse)

                // From the matrix E2EE guide:
                // "The client should check if the user_id/device_id correspond to a device it had seen
                // previously. If it did, the client must check that the Ed25519 key hasn't changed.
                // Again, if it has changed, no further processing should be done on the device."
                // We ignore devices that already exist in the database.
                let newDevices = try self.extractNew(devices: devices).dematerialize()

                _ = try self.removeOldDevices(userIDs: userIDs, devices: devices).dematerialize()

                try self.database.dbQueue.inDatabase { db in
                    try newDevices.forEach { device in
                        try device.insert(db)
                    }
                }

                return newDevices
            })
        }
    }

    func fetchNonBlockedDevices(for roomID: RoomID, without deviceID: DeviceID) -> Result<[Device]> {
        return Result {
            let devices = try Device.fetchNotBlocked(forRoom: roomID, database: database).dematerialize()
            return devices.filter { $0.id != deviceID }
        }
    }

    private func ciphertexts(for devices: [Device], account: Account, sessionInfo: SessionInfo, olmEncrypt: (String, CryptoEngine.Curve25519Key) -> (String, OLMMessageType)?) -> [CryptoEngine.Curve25519Key: [CryptoEngine.Curve25519Key: EncryptedJSON.OlmCiphertext]] {
        // Encrypt the content as an m.room_key event using Olm, as below.
        // Once all of the key-sharing event contents have been assembled, the events should be sent.
        return Dictionary(uniqueKeysWithValues: devices.compactMap { device -> (CryptoEngine.Curve25519Key, [CryptoEngine.Curve25519Key: EncryptedJSON.OlmCiphertext])? in

            let keyData = RoomKeyJSON(
                algorithm: .megolm,
                ciphertext: nil,
                roomID: sessionInfo.roomID,
                sessionID: sessionInfo.sessionID,
                sessionKey: sessionInfo.sessionKey,
                chainIndex: sessionInfo.chainIndex
            )

            let olmEvent = OLMEvent(
                type: .roomKey,
                content: .roomKey(keyData),
                from: account,
                to: device.userID,
                on: device
            )

            guard let senderKey = device.curve25519Key else {
                return nil
            }

            guard let (body, type) = olmEncrypt(olmEvent.stringValue, senderKey) else {
                return nil
            }

            return (senderKey, [senderKey: EncryptedJSON.OlmCiphertext(body: body, type: type)])
        })
    }

    /// - Returns: Encrypted messages grouped by device and then by user
    private func groupSessionKeysMessages(for devices: [Device], ciphertexts: [CryptoEngine.Curve25519Key: [CryptoEngine.Curve25519Key: EncryptedJSON.OlmCiphertext]], curve25519Key: CryptoEngine.Curve25519Key) -> [UserID: [DeviceID: EncryptedJSON]] {
        return Dictionary(grouping: devices) { $0.userID } // group devices by user id: [UserID: [Device]]
            .mapValues { userDevices -> [DeviceID: EncryptedJSON] in
                Dictionary(uniqueKeysWithValues: userDevices.compactMap { userDevice in // [DeviceID: [EncryptedJSON]]
                    guard let deviceCurve25519Key = userDevice.curve25519Key else {
                        return nil
                    }

                    guard let cts = ciphertexts[deviceCurve25519Key] else {
                        return nil
                    }

                    let content = EncryptedJSON(
                        senderKey: curve25519Key,
                        ciphertexts: cts
                    )

                    return (userDevice.id, content)
                })
            }
    }

    struct SessionInfo {
        let roomID: RoomID
        let sessionID: String
        let sessionKey: String
        let chainIndex: UInt

        init(roomID: RoomID, session: CryptoEngine.OutboundGroupSession) {
            self.init(roomID: roomID, sessionID: session.sessionIdentifier, sessionKey: session.sessionKey, chainIndex: session.messageIndex)
        }

        init(roomID: RoomID, sessionID: String, sessionKey: String, chainIndex: UInt) {
            self.roomID = roomID
            self.sessionID = sessionID
            self.sessionKey = sessionKey
            self.chainIndex = chainIndex
        }
    }

    func publishGroupSessionKeys(for account: Account, sessionInfo: SessionInfo, olmEncrypt: (String, CryptoEngine.Curve25519Key) -> (String, OLMMessageType)?, queue: DispatchQueue, completionHandler: @escaping (Result<Void>) -> Void) {
        let devices: [Device]
        switch fetchNonBlockedDevices(for: sessionInfo.roomID, without: account.deviceID) {
        case let .Value(ds):
            devices = ds
        case let .Error(error):
            completionHandler(.Error(error))
            return
        }

        let ciphertexts = self.ciphertexts(for: devices, account: account, sessionInfo: sessionInfo, olmEncrypt: olmEncrypt)

        let messages = groupSessionKeysMessages(for: devices, ciphertexts: ciphertexts, curve25519Key: account.identityKeys.curve25519)

        let roomKeys = PublishRoomKeysRequest(messages: messages)

        MatrixAPI.default.publishSession(accessToken: account.accessToken, transactionID: account.nextTransactionID(), publishRoomKeysRequest: roomKeys, queue: queue, completionHandler: completionHandler)
    }
}
