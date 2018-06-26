struct EventResponse: JSONCodable {
    let eventID: String

    private enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
    }
}
