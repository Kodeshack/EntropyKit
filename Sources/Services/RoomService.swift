import Foundation

// No, not that kind of room service
class RoomService {
    static func send(message: MessageJSON, to roomID: String, encrypted: Bool, account: Account, database: Database, completionHandler: @escaping (Result<Message>) -> Void = { _ in }) {
        let eventType = encrypted ? Event.EventsType.encrypted : Event.EventsType.message

        if encrypted {
            let msgEvent = Event(type: .message, roomID: roomID, content: .message(message))
            account.encrypt(event: msgEvent, in: roomID) { result in
                switch result {
                case let .Value(event):
                    RoomService.sendRequest(account: account, roomID: roomID, body: event.content, eventType: eventType, message: message, database: database, completionHandler: completionHandler)
                case let .Error(error):
                    completionHandler(.Error(error))
                }
            }
        } else {
            RoomService.sendRequest(account: account, roomID: roomID, body: message, eventType: eventType, message: message, database: database, completionHandler: completionHandler)
        }
    }

    private static func sendRequest(account: Account, roomID: String, body: JSONEncodable, eventType: Event.EventsType, message: MessageJSON, database: Database, completionHandler: @escaping (Result<Message>) -> Void = { _ in }) {
        let date = Date() // save date
        let txnID = account.nextTransactionID()
        MatrixAPI.default.send(body: body, eventType: eventType, to: roomID, accessToken: account.accessToken, transactionID: txnID) { eventResponseResult in
            completionHandler(Result {
                let eventResponse = try eventResponseResult.dematerialize()
                return try Message.create(id: eventResponse.eventID, roomID: roomID, date: date, senderID: account.userID, type: message.type, body: message.body, database: database) { m in
                    m.sender = account.user
                }
            })
        }
    }
}
