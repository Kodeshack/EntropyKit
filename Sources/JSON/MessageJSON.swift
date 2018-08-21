protocol MessageJSON: JSONCodable, Hashable {
    var body: String { get }
    var type: Message.MessageType { get }
    var eventContent: Event.Content { get }
}
