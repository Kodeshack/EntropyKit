import Foundation

struct PlainMessageJSON: MessageJSON {
    let body: String
    let type: Message.MessageType

    var eventContent: Event.Content {
        return .message(self)
    }

    private enum CodingKeys: String, CodingKey {
        case body
        case type = "msgtype"
    }

    init(body: String, type: Message.MessageType) {
        self.body = body
        self.type = type
    }
}
