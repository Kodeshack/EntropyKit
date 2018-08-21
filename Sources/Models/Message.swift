import GRDB

public class Message: Record {
    public let id: String
    let roomID: RoomID
    public let date: Date
    let senderID: UserID
    public var sender: User?
    public let type: MessageType
    public let body: String

    public var attachment: Attachment?

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

        super.init(row: row)

        if type == .image || type == .file {
            if let attachment = row.scopes[Database.v0.attachments.table] {
                self.attachment = Attachment(row: attachment)
            }
        }
    }

    convenience init(event: Event) {
        let type: MessageType
        let body: String

        if let message = event.content.fileMessage {
            type = message.type
            body = message.body
        } else {
            let message = event.content.message!
            type = message.type
            body = message.body
        }

        self.init(
            id: event.id!,
            roomID: event.roomID!,
            date: event.date!,
            senderID: event.senderID!,
            type: type,
            body: body
        )

        attachment = Attachment(event: event)
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

    var messageJSON: PlainMessageJSON {
        return PlainMessageJSON(body: body, type: type)
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
            try self.attachment?.insert(db)
        }
    }

    static func completeRequest(roomID: RoomID, offset: Int, limit: Int) -> (sql: String, arguments: StatementArguments, adapter: RowAdapter) {
        let messagesTable = Database.v0.messages.table
        let usersTable = Database.v0.users.table
        let usersIDColumn = Database.v0.users.id
        let messagesSenderIDColumn = Database.v0.messages.senderID
        let messagesDateColumn = Database.v0.messages.date
        let messageRoomIDColumn = Database.v0.messages.roomID
        let attachmentsTable = Database.v0.attachments.table
        let attachmentMessageID = Database.v0.attachments.messageID
        let messageID = Database.v0.messages.id

        let suffixAdapters: [String: RowAdapter] = [
            "user": SuffixRowAdapter(fromIndex: 1),
            "image": SuffixRowAdapter(fromIndex: 2),
        ]

        let sql =
            """
            SELECT \(messagesTable).*, \(usersTable).*, \(attachmentsTable).* FROM \(messagesTable)
            JOIN \(usersTable) ON \(usersTable).\(usersIDColumn) = \(messagesTable).\(messagesSenderIDColumn)
            LEFT JOIN \(attachmentsTable) ON \(attachmentsTable).\(attachmentMessageID) = \(messagesTable).\(messageID)
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
