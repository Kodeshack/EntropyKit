import GRDB

public typealias UserID = String

public class User: Record {
    struct UserError: Error {
        let message: String
    }

    public let id: UserID
    public var displayname: String

    init(id: UserID, displayname: String? = nil) {
        self.id = id
        self.displayname = displayname ?? id
        super.init()
    }

    required init(row: Row) {
        id = row[Database.v0.users.id]
        displayname = row[Database.v0.users.displayname]
        super.init(row: row)
    }

    convenience init(event: Event) throws {
        guard case let .member(membership) = event.content else {
            throw UserError(message: "event.content.member is nil")
        }
        self.init(id: event.senderID!, displayname: membership.displayname)
    }

    public override class var databaseTableName: String {
        return Database.v0.users.table
    }

    public override func encode(to container: inout PersistenceContainer) {
        container[Database.v0.users.id] = id
        container[Database.v0.users.displayname] = displayname
    }
}

extension User {
    static func create(id: UserID, database: Database, update: @escaping (User) -> Void = { _ in }) throws -> User {
        let user = try User.load(id: id, database: database) ?? User(id: id)
        update(user)
        try user.save(database: database)
        return user
    }

    func update(database: Database, update: @escaping (User) -> Void) throws {
        update(self)
        try save(database: database)
    }

    static func load(id: UserID, database: Database) throws -> User? {
        var user: User?
        try database.dbQueue.inDatabase { db in
            user = try User.fetchOne(db, key: id)
        }
        return user
    }

    func save(database: Database) throws {
        try database.dbQueue.inDatabase { db in
            try self.insert(db)
        }
    }
}

extension User {
    // @TODO: caching
    func fetchDevices(database: Database) throws -> [Device] {
        return try database.dbQueue.inDatabase { db in
            let userID = Column(Database.v0.devices.userID)
            return try Device.filter(userID == self.id).fetchAll(db)
        }
    }
}
