import Foundation

// No, not that kind of room service
class RoomService {
    static func send<M: MessageJSON>(message: M, to roomID: String, encrypted: Bool, account: Account, database: Database) -> AsyncResult<Message> {
        let asyncResult = AsyncResult<Message>()
        let eventType = encrypted ? Event.EventsType.encrypted : Event.EventsType.message
        let completionHandler = { (result: Result<Message>) -> Void in
            asyncResult.resolveOrReject(using: result)
        }

        if encrypted {
            let msgEvent = Event(type: .message, roomID: roomID, content: message.eventContent)
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

        return asyncResult
    }

    static func sendMedia(filename: String, data: Data, eventType: Message.MessageType = .file, info: FileMessageJSON.Info, encrypted: Bool = false, roomID: RoomID, account: Account, database: Database) -> AsyncResult<Message> {

        let payload: Data
        var encryptionInfo: EncryptedAttachment?
        let mimeType: String

        if encrypted {
            let encryptionResult = AttachmentEncryption.encrypt(plainData: data, mimeType: info.mimeType)
            guard let encryption = encryptionResult.value else { return AsyncResult<Message>(error: encryptionResult.error!) }
            encryptionInfo = encryption.info
            payload = encryption.ciphertext
            mimeType = "application/octet-stream"
        } else {
            payload = data
            mimeType = info.mimeType
        }

        return MatrixAPI.default.upload(filename: filename, mimeType: mimeType, data: payload, accessToken: account.accessToken)
            .then { contentURI -> AsyncResult<Message> in
                let file: FileMessageJSON
                if var encryptionInfo = encryptionInfo, let mxcURL = URL(string: contentURI) {
                    encryptionInfo.mxcURL = mxcURL
                    file = FileMessageJSON(type: eventType, filename: filename, info: info, file: encryptionInfo)
                } else if let mxcURL = URL(string: contentURI) {
                    file = FileMessageJSON(type: eventType, filename: filename, info: info, url: mxcURL)
                } else {
                    throw MatrixAPI.APIError.invalidFile
                }
                return RoomService.send(message: file, to: roomID, encrypted: encrypted, account: account, database: database)
            }
    }

    private static func sendRequest<M: MessageJSON>(account: Account, roomID: String, body: JSONEncodable, eventType: Event.EventsType, message: M, database: Database, completionHandler: @escaping (Result<Message>) -> Void) {
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
