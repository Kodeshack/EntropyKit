import GRDB

public class Message: Record {
    public let id: String
    let roomID: RoomID
    public let date: Date
    let senderID: UserID
    public var sender: User?
    public let type: MessageType
    public let body: String

    public var image: Image?
    public var thumbnail: Image?

    var timestamp: UInt {
        return UInt(date.timeIntervalSince1970 * 1000)
    }

    init(id: String, roomID: RoomID, date: Date, senderID: UserID, type: MessageType, body: String) {
        self.id = id
        self.roomID = roomID
        self.date = date
        self.senderID = senderID
        self.type = type
        self.body = body
        super.init()
    }

    required init(row: Row) {
        id = row[Database.v0.messages.id]
        roomID = row[Database.v0.messages.roomID]
        date = row[Database.v0.messages.date]
        senderID = row[Database.v0.messages.senderID]
        type = MessageType(rawValue: row[Database.v0.messages.type])!
        body = row[Database.v0.messages.body]

        if let user = row.scopes["user"] {
            sender = User(row: user)
        }

        if type == .image {
            if let image = row.scopes["image"] {
                self.image = Image(row: image)
            }
        }

        super.init(row: row)
    }

    convenience init(event: Event) {
        let message = event.content.message!

        let type = message.type
        let body = message.body

        self.init(
            id: event.id!,
            roomID: event.roomID!,
            date: event.date!,
            senderID: event.senderID!,
            type: type,
            body: body
        )

        if self.type == .image {
            let imageInfo = message.imageInfo!
            let url = message.imageURL!
            let width = imageInfo.width
            let height = imageInfo.height
            let MIMEType = imageInfo.MIMEType
            let size = imageInfo.size

            image = Message.Image(id: id, messageID: id, url: url, width: width, height: height, MIMEType: MIMEType, size: size)

            if let thumbnailInfo = message.thumbnailInfo {
                let url = message.thumbnailURL!
                let width = thumbnailInfo.width
                let height = thumbnailInfo.height
                let MIMEType = thumbnailInfo.MIMEType
                let size = thumbnailInfo.size

                thumbnail = Message.Image(url: url, width: width, height: height, MIMEType: MIMEType, size: size)
            }
        }
    }

    public override class var databaseTableName: String {
        return Database.v0.messages.table
    }

    public override func encode(to container: inout PersistenceContainer) {
        container[Database.v0.messages.id] = id
        container[Database.v0.messages.roomID] = roomID
        container[Database.v0.messages.date] = date
        container[Database.v0.messages.senderID] = senderID
        container[Database.v0.messages.type] = type.rawValue
        container[Database.v0.messages.body] = body
    }

    var messageJSON: MessageJSON {
        return MessageJSON(body: body, type: type, imageInfo: image?.imageInfo, imageURL: image?.url, thumbnailInfo: thumbnail?.imageInfo, thumbnailURL: thumbnail?.url)
    }
}

extension Message {
    static func create(id: String, roomID: RoomID, date: Date, senderID: UserID, type: MessageType, body: String, database: Database, update: @escaping (Message) -> Void = { _ in }) throws -> Message {
        let message = try Message.load(id: id, database: database) ?? Message(id: id, roomID: roomID, date: date, senderID: senderID, type: type, body: body)
        update(message)
        try message.save(database: database)
        return message
    }

    func update(database: Database, update: @escaping (Message) -> Void) throws {
        update(self)
        try save(database: database)
    }

    static func load(id: String, database: Database) throws -> Message? {
        var message: Message?
        try database.dbQueue.inDatabase { db in
            message = try Message.fetchOne(db, key: id)
            message?.sender = try User.fetchOne(db, key: message?.senderID)
        }
        return message
    }

    func save(database: Database) throws {
        try database.dbQueue.inDatabase { db in
            try self.insert(db)
            try self.image?.insert(db)
        }
    }

    static func completeRequest(roomID: RoomID, offset: Int, limit: Int) -> (sql: String, arguments: StatementArguments, adapter: RowAdapter) {
        let messagesTable = Database.v0.messages.table
        let usersTable = Database.v0.users.table
        let usersIDColumn = Database.v0.users.id
        let messagesSenderIDColumn = Database.v0.messages.senderID
        let messagesDateColumn = Database.v0.messages.date
        let messageRoomIDColumn = Database.v0.messages.roomID
        let mediaTable = Database.v0.media.table
        let mediaMessageID = Database.v0.media.messageID
        let messageID = Database.v0.messages.id

        let suffixAdapters: [String: RowAdapter] = [
            "user": SuffixRowAdapter(fromIndex: 1),
            "image": SuffixRowAdapter(fromIndex: 2),
        ]

        let sql =
            """
            SELECT \(messagesTable).*, \(usersTable).*, \(mediaTable).* FROM \(messagesTable)
            JOIN \(usersTable) ON \(usersTable).\(usersIDColumn) = \(messagesTable).\(messagesSenderIDColumn)
            LEFT JOIN \(mediaTable) ON \(mediaTable).\(mediaMessageID) = \(messagesTable).\(messageID)
            WHERE \(messageRoomIDColumn) = ?
            ORDER BY \(messagesDateColumn) ASC
            LIMIT ? OFFSET ?
            """

        return (
            sql: sql,
            arguments: [roomID, limit, offset],
            adapter: ScopeAdapter(suffixAdapters)
        )
    }
}

extension Message {
    public enum MessageType: String, Codable {
        case text = "m.text"
        case emote = "m.emote"
        case notice = "m.notice"
        case image = "m.image"
        case file = "m.file"
        case location = "m.location"
        case video = "m.video"
        case audio = "m.audio"
    }
}

extension Message: Hashable, Equatable {
    public var hashValue: Int {
        return id.hashValue
    }

    public static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }
}
