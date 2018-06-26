import Foundation
import GRDB

struct Event: JSONCodable, Hashable {
    var id: String?
    var senderID: UserID?
    let type: EventsType
    var date: Date?
    let content: Content
    var roomID: RoomID?

    private enum CodingKeys: String, CodingKey {
        case id = "event_id"
        case senderID = "sender"
        case type
        case date = "origin_server_ts"
        case roomID = "room_id"
        case content
    }

    init(id: String? = nil, senderID: UserID? = nil, type: EventsType, date: Date = Date(), roomID: RoomID?, content: Content) {
        self.id = id
        self.senderID = senderID
        self.type = type
        self.date = date
        self.roomID = roomID
        self.content = content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        senderID = try container.decodeIfPresent(String.self, forKey: .senderID)
        type = try container.decode(EventsType.self, forKey: .type)

        if let originServerTimeStamp = try container.decodeIfPresent(Int.self, forKey: .date) {
            date = Date(timeIntervalSince1970: Double(originServerTimeStamp) / 1000.0)
        }

        roomID = try container.decodeIfPresent(String.self, forKey: .roomID)
        content = try Content.decode(type: type, container: container, forKey: .content)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        //try container.encode(self.id, forKey: .id)
        try container.encodeIfPresent(senderID, forKey: .senderID)
        try container.encode(type, forKey: .type)
        //try container.encode(Int(self.date.timeIntervalSince1970 * 1000), forKey: .date)
        try container.encodeIfPresent(roomID, forKey: .roomID)
        try container.encode(content, forKey: .content)
    }
}

extension Event {
    enum EventsType: String, Codable {
        // Rooms
        case aliases = "m.room.aliases"
        case canonicalAlias = "m.room.canonical_alias"
        case create = "m.room.create"
        case guestAccess = "m.room.guest_access"
        case historyVisibility = "m.room.history_visibility"
        case joinRules = "m.room.join_rules"
        case member = "m.room.member"
        case powerLevels = "m.room.power_levels"
        case redaction = "m.room.redaction"

        // Instant Messaging
        case avatar = "m.room.avatar"
        case feedback = "m.room.message.feedback"
        case message = "m.room.message"
        case name = "m.room.name"
        case topic = "m.room.topic"

        // E2EE
        /// Sent when a room activates encryption
        case encryption = "m.room.encryption"
        /// Encrypted events such as messages
        case encrypted = "m.room.encrypted"
        /// Used to initiate megolm sessions
        case roomKey = "m.room_key"

        /// Sent when a user requests it's own room keys from a differen device
        /// @TODO: not handled yet, just here for parsing
        case roomKeyRequest = "m.room_key_request"

        /// a new device has entered an encrypted room
        case newDevice = "m.new_device"

        // Synthetic internal events
        case roomPrevBatch = "entropy.room.prev_batch"
    }
}
