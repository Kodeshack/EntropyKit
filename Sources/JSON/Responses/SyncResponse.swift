import Foundation

struct SyncResponse: JSONDecodable {
    let nextBatch: String
    let otkCountMap: [String: UInt]
    let rooms: Rooms
    let toDevice: ToDevice
    let deviceLists: DeviceLists

    private enum CodingKeys: String, CodingKey {
        case nextBatch = "next_batch"
        case otkCountMap = "device_one_time_keys_count"
        case rooms
        case toDevice = "to_device"
        case deviceLists = "device_lists"
    }

    /// Can be nil when E2EE Stuff is not initialized yet.
    var otkCount: UInt? {
        return otkCountMap[CryptoEngine.CryptoKeys.signedCurve25519.rawValue]
    }
}

extension SyncResponse {
    struct Rooms: Codable {
        let join: [String: JoinedRoom]
    }
}

extension SyncResponse {
    struct JoinedRoom: Codable {
        let state: Events
        let timeline: Events

        struct Events: Codable {
            let events: [Event]
            let prev_batch: String?

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                var eventContainer = try container.nestedUnkeyedContainer(forKey: .events)

                var events = [Event]()
                while !eventContainer.isAtEnd {
                    if let event = try? eventContainer.decode(Event.self) {
                        events.append(event)
                    } else {
                        _ = try eventContainer.decode(EmptyJSON.self)
                    }
                }
                self.events = events
                prev_batch = try container.decodeIfPresent(String.self, forKey: .prev_batch)
            }
        }
    }
}

extension SyncResponse {
    struct ToDevice: JSONDecodable {
        let events: [ToDeviceEvent]
    }

    struct ToDeviceEvent: JSONCodable, Hashable {
        let senderID: String
        let type: Event.EventsType
        let content: Event.Content
        // set interally, when actually decrypting this event
        var senderKey: String?

        private enum CodingKeys: String, CodingKey {
            case senderID = "sender"
            case type
            case content
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            senderID = try container.decode(String.self, forKey: .senderID)
            type = try container.decode(Event.EventsType.self, forKey: .type)
            content = try Event.Content.decode(type: type, container: container, forKey: .content)
        }

        init(senderID: String, type: Event.EventsType, content: Event.Content) {
            self.senderID = senderID
            self.type = type
            self.content = content
        }
    }
}

extension SyncResponse {
    struct DeviceLists: JSONDecodable {
        let changed: [String]
    }
}
