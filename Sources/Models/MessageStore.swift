import GRDB

class MessageStore {
    let pageSize: Int
    let roomID: RoomID

    private(set) var messages = [Message]() {
        didSet {
            if let first = messages.first, first.date < newestFetched {
                newestFetched = first.date
                totalFetchCount += messages.count
            }
        }
    }

    private(set) var totalFetchCount: Int = 0
    private(set) var totalNumberOfMessages: Int = 0
    private(set) var newestFetched: Date = Date()

    private let database: Database

    required init(database: Database, roomID: RoomID, pageSize: Int = 50, numPages _: Int = 3) {
        self.database = database
        self.pageSize = pageSize
        self.roomID = roomID
        self.database.dbQueue.add(transactionObserver: self, extent: .observerLifetime)
    }

    private func fetchAll(order: String) -> Result<[Message]> {
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

        let whereAndOrder: String
        let date: Date

        if let first = messages.first {
            whereAndOrder =
                """
                AND \(messagesDateColumn) \((order == "DESC") ? "<" : ">") ?
                ORDER BY \(messagesDateColumn) \(order)
                """
            date = (order == "DESC") ? first.date : messages.last!.date
        } else {
            whereAndOrder =
                """
                AND \(messagesDateColumn) < ?
                ORDER BY \(messagesDateColumn) DESC
                """
            date = Date()
        }

        let sql =
            """
            SELECT \(messagesTable).*, \(usersTable).*, \(attachmentsTable).* FROM \(messagesTable)
            JOIN \(usersTable) ON \(usersTable).\(usersIDColumn) = \(messagesTable).\(messagesSenderIDColumn)
            LEFT JOIN \(attachmentsTable) ON \(attachmentsTable).\(attachmentMessageID) = \(messagesTable).\(messageID)
            WHERE \(messageRoomIDColumn) = ?
            \(whereAndOrder)
            LIMIT ?
            """

        return Result {
            try database.dbQueue.inDatabase { db in
                try SQLRequest(sql, arguments: [roomID, date, pageSize], adapter: ScopeAdapter(suffixAdapters), cached: false)
                    .fetchAll(db)
            }
        }
    }

    func fetch(key: String) -> Result<Message?> {
        return Result {
            var message: Message?
            try database.dbQueue.read { db in
                message = try Message.fetchOne(db, key: key)
                message?.sender = try User.fetchOne(db, key: message?.senderID)
            }
            return message
        }
    }

    func save(_ record: Message) -> Result<Message> {
        return Result {
            try database.dbQueue.write { db in
                try record.save(db)
            }
            return record
        }
    }

    func delete(_ record: Message) -> Result<Bool> {
        return Result {
            try database.dbQueue.write { db in
                return try record.delete(db)
            }
        }
    }

    func fetchEarlier() -> Result<Int> {
        return Result {
            let newMessages = try self.fetchAll(order: "DESC").dematerialize()
            if newMessages.count != 0 {
                self.messages.removeAll()
                self.messages = newMessages.reversed()
            }
            return newMessages.count
        }
    }

    func fetchLater() -> Result<Int> {
        return Result {
            let newMessages = try self.fetchAll(order: "ASC").dematerialize()
            if newMessages.count != 0 {
                if self.messages.count == 0 {
                    self.messages = newMessages.reversed()
                } else {
                    self.messages.removeAll()
                    self.messages = newMessages
                }
            }
            return newMessages.count
        }
    }
}

extension MessageStore: TransactionObserver {
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return eventKind.tableName == Database.v0.messages.table
    }

    func databaseDidChange(with _: DatabaseEvent) {}

    func databaseDidCommit(_ db: GRDB.Database) {
        totalNumberOfMessages = try! Message.fetchCount(db)
    }

    func databaseDidRollback(_ db: GRDB.Database) {
        totalNumberOfMessages = try! Message.fetchCount(db)
    }
}
