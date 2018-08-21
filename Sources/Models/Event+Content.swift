import Foundation

extension Event {
    enum Content: Hashable {
        case member(MemberJSON)
        case message(PlainMessageJSON)
        case fileMessage(FileMessageJSON)
        case roomName(RoomNameJSON)
        case roomPrevBatch(String)
        case roomEncryption(RoomEncryptionJSON)
        case encrypted(EncryptedJSON)
        case roomKey(RoomKeyJSON)
        case newDevice(NewDeviceJSON)
        case none

        var data: Data {
            switch self {
            case let .member(member):
                return member.encoded
            case let .message(message):
                return message.encoded
            case let .fileMessage(fileMessage):
                return fileMessage.encoded
            case let .roomName(roomName):
                return roomName.encoded
            case let .roomPrevBatch(prevBatch):
                let encoder = JSONEncoder()
                encoder.outputFormatting = .sortedKeys
                return try! encoder.encode(prevBatch)
            case let .roomEncryption(roomEncryption):
                return roomEncryption.encoded
            case let .roomKey(roomKey):
                return roomKey.encoded
            case let .encrypted(encrypted):
                return encrypted.encoded
            case let .newDevice(newDevice):
                return newDevice.encoded
            case .none:
                return Data()
            }
        }

        var member: MemberJSON? {
            if case let .member(member) = self {
                return member
            }
            return nil
        }

        var message: PlainMessageJSON? {
            if case let .message(message) = self {
                return message
            }
            return nil
        }

        var fileMessage: FileMessageJSON? {
            if case let .fileMessage(message) = self {
                return message
            }
            return nil
        }

        var roomName: RoomNameJSON? {
            if case let .roomName(roomName) = self {
                return roomName
            }
            return nil
        }

        var roomPrevBatch: String? {
            if case let .roomPrevBatch(prevBatch) = self {
                return prevBatch
            }
            return nil
        }

        var roomEncryption: RoomEncryptionJSON? {
            if case let .roomEncryption(roomEncryption) = self {
                return roomEncryption
            }
            return nil
        }

        var roomKey: RoomKeyJSON? {
            if case let .roomKey(roomKey) = self {
                return roomKey
            }
            return nil
        }

        var newDevice: NewDeviceJSON? {
            if case let .newDevice(newDevice) = self {
                return newDevice
            }
            return nil
        }

        var encrypted: EncryptedJSON? {
            if case let .encrypted(encrypted) = self {
                return encrypted
            }
            return nil
        }
    }
}

extension Event.Content: JSONEncodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .member(member):
            try container.encode(member)
        case let .message(message):
            try container.encode(message)
        case let .fileMessage(fileMessage):
            try container.encode(fileMessage)
        case let .roomName(name):
            try container.encode(name)
        case let .roomEncryption(encryption):
            try container.encode(encryption)
        case let .encrypted(encrypted):
            try container.encode(encrypted)
        case let .roomKey(roomKey):
            try container.encode(roomKey)
        default:
            break
        }
    }

    static func decode<T>(type: Event.EventsType, container: KeyedDecodingContainer<T>, forKey key: T) throws -> Event.Content {
        switch type {
        case .member:
            return .member(try container.decode(MemberJSON.self, forKey: key))
        case .message:
            let message = try container.decode(PlainMessageJSON.self, forKey: key)
            switch message.type {
            case .image, .video, .audio, .file:
                return .fileMessage(try container.decode(FileMessageJSON.self, forKey: key))
            default:
                return .message(message)
            }
        case .name:
            return .roomName(try container.decode(RoomNameJSON.self, forKey: key))
        case .encryption:
            return .roomEncryption(try container.decode(RoomEncryptionJSON.self, forKey: key))
        case .encrypted:
            return .encrypted(try container.decode(EncryptedJSON.self, forKey: key))
        case .roomKey:
            return .roomKey(try container.decode(RoomKeyJSON.self, forKey: key))
        case .newDevice:
            return .newDevice(try container.decode(NewDeviceJSON.self, forKey: key))
        case .roomKeyRequest:
            // @TODO: handle this at a later stage
            return .none
        default:
            return .none
        }
    }
}
