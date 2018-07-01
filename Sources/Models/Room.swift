import GRDB

public typealias RoomID = String

public class Room: Record, Hashable, Equatable {
    public let id: RoomID
    public var name: String?
    public var encrypted: Bool

    var oldestState: String?
    var unreadCount = UInt(0)
    var encryptionAlgorithm: CryptoEngine.Algorithm?
    var rotationPeriodTime: UInt?
    var rotationPeriodMessages: UInt?
    var announced: Bool

    public var hashValue: Int {
        return id.hashValue
    }

    public static func == (lhs: Room, rhs: Room) -> Bool {
        return lhs.id == rhs.id
    }

    /// The room's smart name. Either the room name or a concatenation of the users' displaynames if the room name is `nil`. Returns "Empty Room" if no users are present.
    /// - Bug: [Issue #5](https://github.com/Kodeshack/EntropyKit/issues/5).
    public var smartName: String {
        return name ?? "Empty Room"
    }

    init(id: RoomID) {
        self.id = id
        encrypted = false
        encryptionAlgorithm = nil
        announced = false
        super.init()
    }

    required init(row: Row) {
        id = row[Database.v0.rooms.id]
        name = row[Database.v0.rooms.name]
        oldestState = row[Database.v0.rooms.oldestState]
        encrypted = row[Database.v0.rooms.encrypted]
        rotationPeriodTime = row[Database.v0.rooms.rotationPeriodTime]
        rotationPeriodMessages = row[Database.v0.rooms.rotationPeriodMessages]
        announced = row[Database.v0.rooms.announced]

        if let algorithm = row[Database.v0.rooms.encryptionAlgorithm] as? String {
            encryptionAlgorithm = CryptoEngine.Algorithm(rawValue: algorithm)
        }

        super.init(row: row)
    }

    public override class var databaseTableName: String {
        return Database.v0.rooms.table
    }

    public override func encode(to container: inout PersistenceContainer) {
        container[Database.v0.rooms.id] = id
        container[Database.v0.rooms.name] = name
        container[Database.v0.rooms.oldestState] = oldestState
        container[Database.v0.rooms.encrypted] = encrypted
        container[Database.v0.rooms.encryptionAlgorithm] = encryptionAlgorithm?.rawValue
        container[Database.v0.rooms.rotationPeriodTime] = rotationPeriodTime
        container[Database.v0.rooms.rotationPeriodMessages] = rotationPeriodMessages
        container[Database.v0.rooms.announced] = announced
    }
}

extension Room {
    static func create(id: RoomID, database: Database, update: @escaping (Room) -> Void = { _ in }) throws -> Room {
        let room = try Room.load(id: id, database: database) ?? Room(id: id)
        update(room)
        try room.save(database: database)
        return room
    }

    func update(_ db: GRDB.Database) throws {
        var columns = Set<String>()
        if name != nil {
            columns.insert(Database.v0.rooms.name)
        }

        if oldestState != nil {
            columns.insert(Database.v0.rooms.oldestState)
        }

        if encrypted { // can't deactivate encryption once it's been enabled
            columns.insert(Database.v0.rooms.encrypted)
        }

        if encryptionAlgorithm != nil {
            columns.insert(Database.v0.rooms.encryptionAlgorithm)
        }

        if rotationPeriodTime != nil {
            columns.insert(Database.v0.rooms.rotationPeriodTime)
        }

        if rotationPeriodMessages != nil {
            columns.insert(Database.v0.rooms.rotationPeriodMessages)
        }

        if announced { // can't unannounce
            columns.insert(Database.v0.rooms.announced)
        }

        if columns.count != 0 {
            try update(db, columns: columns)
        }
    }

    func update(database: Database, update: @escaping (Room) -> Void) throws {
        update(self)
        try database.dbQueue.inDatabase { db in
            try self.update(db)
        }
    }

    static func load(id: RoomID, database: Database) throws -> Room? {
        var room: Room?
        try database.dbQueue.inDatabase { db in
            room = try Room.fetchOne(db, key: id)
        }
        return room
    }

    func load(database: Database) throws {
        var room: Room?
        try database.dbQueue.inDatabase { db in
            room = try Room.fetchOne(db, key: self.id)
        }
        name = room?.name
        oldestState = room?.oldestState
    }

    func save(database: Database) throws {
        try database.dbQueue.inDatabase { db in
            try self.insert(db)
        }
    }
}
