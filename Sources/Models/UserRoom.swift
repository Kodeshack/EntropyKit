import GRDB

class UserRoom: Record {
    let userID: UserID
    let roomID: RoomID

    init(userID: UserID, roomID: RoomID) {
        self.userID = userID
        self.roomID = roomID
        super.init()
    }

    required init(row: Row) {
        userID = row[Database.v0.users_rooms.userID]
        roomID = row[Database.v0.users_rooms.roomID]
        super.init(row: row)
    }

    convenience init(event: Event) {
        self.init(userID: event.senderID!, roomID: event.roomID!)
    }

    override class var databaseTableName: String {
        return Database.v0.users_rooms.table
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Database.v0.users_rooms.userID] = userID
        container[Database.v0.users_rooms.roomID] = roomID
    }
}

extension UserRoom {
    static func create(userID: UserID, roomID: RoomID, database: Database) throws -> UserRoom {
        let user = try UserRoom.load(userID: userID, roomID: roomID, database: database) ?? UserRoom(userID: userID, roomID: roomID)
        try user.save(database: database)
        return user
    }

    static func load(userID: UserID, roomID: RoomID, database: Database) throws -> UserRoom? {
        var user: UserRoom?
        try database.dbQueue.inDatabase { db in
            user = try UserRoom.fetchOne(db, key: [Database.v0.users_rooms.userID: userID, Database.v0.users_rooms.roomID: roomID])
        }
        return user
    }

    func save(database: Database) throws {
        try database.dbQueue.inDatabase { db in
            try self.insert(db)
        }
    }
}
