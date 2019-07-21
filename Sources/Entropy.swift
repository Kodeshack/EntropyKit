#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

import GRDB

public class Entropy {
    public static let `default` = try! Entropy()
    public var state = State.notLoggedIn

    private let database: Database
    private var account: Account!
    private var syncService: SyncService?
    private var syncScheduler: Scheduler?

    public let rooms: ObservablePersistedList<Room>

    private init() throws {
        let databaseURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("\(Bundle.main.applicationName).sqlite")

        database = try Database(path: databaseURL)
        rooms = try ObservablePersistedList<Room>(database: database)
        try checkIfAccountExists()
    }

    private func checkIfAccountExists() throws {
        // @TODO: maybe this is a little risky, but it's not quite clear yet how some cases should
        // be handled elegantly.
        var account: Account?
        try database.dbQueue.read { db in
            account = try Account.fetchOne(db)
            try account?.fetchUser(db)
        }

        if let account = account {
            self.account = account
            account.setupCryptoEngine(database: database, load: true)
            MatrixAPI.default.baseURL = try Settings.loadHomeserver(from: database)!.absoluteString
            state = .loggedIn
        }
    }

    public func login(credentials: Validation.Credentials, completionHandler: @escaping (Result<Void, Error>) -> Void) {
        MatrixAPI.default.baseURL = credentials.homeserver.absoluteString
        try! Settings.storeHomeserver(credentials.homeserver, database: database)

        SessionService.login(username: credentials.username, password: credentials.password, database: database) { result in
            completionHandler(Result {
                self.account = try result.get()
                self.state = .loggedIn
            })
        }
    }
}

extension Entropy: SyncServiceDelegate {
    func syncStarted() {}

    func syncEnded(_ result: Result<SyncService.SyncResult, Error>) {
        print(result)
    }

    public func startSyncing() {
        syncService = SyncService(account: account, database: database)
        syncScheduler = Scheduler(name: "SyncServer", interval: 1000)
        syncService?.delegate = self
        syncScheduler?.start { [unowned self] completionHandler in
            self.syncService?.sync(completionHandler: completionHandler)
        }
    }
}

extension Entropy {
    public func messages(for roomID: RoomID, offset: Int = 0, limit: Int = 50) throws -> ObservablePersistedList<Message> {
        let (sql, arguments, adapter) = Message.completeRequest(roomID: roomID, offset: offset, limit: limit)
        return try ObservablePersistedList<Message>(database: database, sql: sql, arguments: arguments, adapater: adapter)
    }

    public func sendMessage(room: Room, body: String) {
        RoomService.send(message: PlainMessageJSON(body: body, type: .text), to: room.id, encrypted: room.encrypted, account: account, database: database) { result in
            if let error = result.failure { print(error) }
        }
    }

    public func sendMedia(room: Room, filename: String, data: Data) {
        let mimeType = MIMEType.detectMIMEType(filename: filename, data: data)
        let eventType: Message.MessageType = MIMEType.isImage(mime: mimeType) ? .image : .file
        let info = FileMessageJSON.Info(width: nil, height: nil, size: UInt(data.count), mimeType: mimeType, thumbnailInfo: nil, thumbnailFile: nil)
        RoomService.sendMedia(filename: filename, data: data, eventType: eventType, info: info, encrypted: room.encrypted, roomID: room.id, account: account, database: database) { result in
            if let error = result.failure { print(error) }
        }
    }
}

extension Entropy {
    #if canImport(UIKit)
        public func avatar(for userID: UserID, completionHandler: @escaping (Result<UIImage?, Error>, UserID) -> Void) {
            UserService.loadAvatar(userID: userID) { result in
                completionHandler(result, userID)
            }
        }

        public func thumbnail(for message: Message, completionHandler: @escaping (Result<UIImage, Error>, Message) -> Void) {
            ImageService.loadThumbnail(for: message) { result in
                completionHandler(result, message)
            }
        }

        public func image(for message: Message, completionHandler: @escaping (Result<UIImage, Error>, Message) -> Void) {
            ImageService.loadImage(for: message) { result in
                completionHandler(result, message)
            }
        }

    #elseif canImport(AppKit)
        public func avatar(for userID: UserID, completionHandler: @escaping (Result<NSImage?, Error>, UserID) -> Void) {
            UserService.loadAvatar(userID: userID) { result in
                completionHandler(result, userID)
            }
        }

        public func thumbnail(for message: Message, completionHandler: @escaping (Result<NSImage, Error>, Message) -> Void) {
            ImageService.loadThumbnail(for: message) { result in
                completionHandler(result, message)
            }
        }

        public func image(for message: Message, completionHandler: @escaping (Result<NSImage, Error>, Message) -> Void) {
            ImageService.loadImage(for: message) { result in
                completionHandler(result, message)
            }
        }
    #endif
}

extension Entropy {
    public enum State {
        case notLoggedIn
        case loggedIn
        case loggedOut
    }
}
