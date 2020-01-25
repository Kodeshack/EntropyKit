import GRDB

extension Event {
    enum PersistenceError: Error {
        case missingRoomID(Event)
        case roomNotFound(String)
        case persistenceFunctionNotFound(Event)
    }

    func persist(_ db: GRDB.Database) -> Result<Void, Error> {
        Result {
            switch self.type {
            case .create:
                try self.persistRoomCreate(db)
            case .aliases:
                logMissingPersistenceFunction(self)
            case .canonicalAlias:
                logMissingPersistenceFunction(self)
            case .joinRules:
                logMissingPersistenceFunction(self)
            case .member:
                try self.persistMembership(db)
            case .powerLevels:
                logMissingPersistenceFunction(self)
            case .redaction:
                logMissingPersistenceFunction(self)
            case .guestAccess:
                logMissingPersistenceFunction(self)
            case .historyVisibility:
                logMissingPersistenceFunction(self)
            case .message:
                try self.persistMessage(db)
            case .feedback:
                logMissingPersistenceFunction(self)
            case .name:
                try self.persistRoomName(db)
            case .topic:
                logMissingPersistenceFunction(self)
            case .avatar:
                logMissingPersistenceFunction(self)
            case .encryption:
                try self.persistRoomEncryption(db)
            case .encrypted:
                logMissingPersistenceFunction(self)
            case .roomPrevBatch:
                try self.persistRoomPreviousBatch(db)
            case .roomKey, .roomKeyRequest, .newDevice: // handled by crypto engine
                break
            }
        }
    }

    private func logMissingPersistenceFunction(_ event: Event) {
        Swift.print("--> Missing persistence function for:", event)
    }
}

// MARK: Rooms

extension Event {
    private func persistRoomCreate(_ db: GRDB.Database) throws {
        guard let roomID = self.roomID else {
            throw PersistenceError.missingRoomID(self)
        }

        let room = Room(id: roomID)

        try room.insert(db)
    }

    private func persistRoomName(_ db: GRDB.Database) throws {
        guard let roomID = self.roomID else {
            throw PersistenceError.missingRoomID(self)
        }

        guard let room = try Room.fetchOne(db, key: roomID) else {
            throw PersistenceError.roomNotFound(roomID)
        }

        room.name = content.roomName!.name

        try room.update(db)
    }

    private func persistRoomPreviousBatch(_ db: GRDB.Database) throws {
        guard let roomID = self.roomID else {
            throw PersistenceError.missingRoomID(self)
        }

        guard let room = try Room.fetchOne(db, key: roomID) else {
            throw PersistenceError.roomNotFound(roomID)
        }

        room.oldestState = content.roomPrevBatch

        try room.update(db)
    }

    private func persistRoomEncryption(_ db: GRDB.Database) throws {
        guard let roomID = self.roomID else {
            throw PersistenceError.missingRoomID(self)
        }

        guard let room = try Room.fetchOne(db, key: roomID) else {
            throw PersistenceError.roomNotFound(roomID)
        }

        room.encrypted = true
        room.encryptionAlgorithm = content.roomEncryption!.algorithm
        room.rotationPeriodMessages = content.roomEncryption!.rotationPeriodMessages
        room.rotationPeriodTime = content.roomEncryption!.rotationPeriodTime

        try room.update(db)
    }
}

// MARK: Messages

extension Event {
    private func persistMessage(_ db: GRDB.Database) throws {
        let message = Message(event: self)
        try message.insert(db)
        try message.attachment?.insert(db)
    }
}

// MARK: Users

extension Event {
    private func persistMembership(_ db: GRDB.Database) throws {
        let userRoom = UserRoom(event: self)

        if let membership = content.member?.membership {
            switch membership {
            case .join:
                try User(event: self)?.insert(db)
                try userRoom.insert(db)
            case .leave:
                try userRoom.delete(db)
            case .invite:
                // @TODO: logging while not handling
                logMissingPersistenceFunction(self)
            case .knock:
                // @TODO: logging while not handling
                logMissingPersistenceFunction(self)
            case .ban:
                // @TODO: logging while not handling
                logMissingPersistenceFunction(self)
            }
        }
    }
}
