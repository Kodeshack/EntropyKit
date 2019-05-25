import GRDB

typealias DeviceID = String

class Device: Record {
    let id: DeviceID
    let userID: UserID
    let displayname: String?
    let curve25519Key: CryptoEngine.Curve25519Key?
    let ed25519Key: CryptoEngine.Ed25519Key?
    let algorithms: [CryptoEngine.Algorithm]
    let verificationStatus: VerificationStatus

    init(id: DeviceID, userID: UserID, displayname: String? = nil, curve25519Key: CryptoEngine.Curve25519Key? = nil, ed25519Key: CryptoEngine.Ed25519Key? = nil, algorithms: [CryptoEngine.Algorithm] = []) {
        self.id = id
        self.userID = userID
        self.displayname = displayname
        self.curve25519Key = curve25519Key
        self.ed25519Key = ed25519Key
        self.algorithms = algorithms
        verificationStatus = .unverified
        super.init()
    }

    required init(row: Row) {
        id = row[Database.v0.devices.id]
        userID = row[Database.v0.devices.userID]
        displayname = row[Database.v0.devices.displayname]
        curve25519Key = row[Database.v0.devices.curve25519Key]
        ed25519Key = row[Database.v0.devices.ed25519Key]
        let algos: String = row[Database.v0.devices.algorithms]
        algorithms = algos.split(separator: ";").map { CryptoEngine.Algorithm(rawValue: String($0))! }
        verificationStatus = VerificationStatus(rawValue: row[Database.v0.devices.verificationStatus])!
        super.init(row: row)
    }

    override class var databaseTableName: String {
        return Database.v0.devices.table
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Database.v0.devices.id] = id
        container[Database.v0.devices.userID] = userID
        container[Database.v0.devices.displayname] = displayname
        container[Database.v0.devices.curve25519Key] = curve25519Key
        container[Database.v0.devices.ed25519Key] = ed25519Key
        container[Database.v0.devices.algorithms] = algorithms.map { $0.rawValue }.joined(separator: ";")
        container[Database.v0.devices.verificationStatus] = verificationStatus.rawValue
    }
}

extension Device {
    static func fetchNotBlocked(forRoom roomID: RoomID, database: Database) -> Result<[Device]> {
        return Result {
            try database.dbQueue.inDatabase { db -> [Device] in
                let usersRoomsTable = Database.v0.users_rooms.table
                let usersRoomsUserID = Database.v0.users_rooms.userID
                let usersRoomsRoomID = Database.v0.users_rooms.roomID
                let devicesTable = Database.v0.devices.table
                let devicesUserID = Database.v0.devices.userID
                let verificationStatus = Database.v0.devices.verificationStatus

                let sqlRequest = SQLRequest<Device>(
                    sql: "SELECT \(devicesTable).* FROM \(usersRoomsTable) " +
                        "JOIN \(devicesTable) ON \(usersRoomsTable).\(usersRoomsUserID) = \(devicesTable).\(devicesUserID) " +
                        "WHERE \(usersRoomsTable).\(usersRoomsRoomID) = ? " +
                        "AND NOT \(devicesTable).\(verificationStatus) = ?",
                    arguments: [roomID, VerificationStatus.blocked.rawValue]
                )

                return try Device.fetchAll(db, sqlRequest)
            }
        }
    }

    static func fetchOne(userID: UserID, deviceID: DeviceID, database: Database) -> Result<Device?> {
        return Result {
            try database.dbQueue.inDatabase { db -> Device? in
                try Device.fetchOne(db, key: [Database.v0.devices.id: deviceID, Database.v0.devices.userID: userID])
            }
        }
    }
}

extension Device {
    // We have to set the values manually so we do not breake the db in the future.
    enum VerificationStatus: UInt {
        case unverified = 0
        case verified = 1
        case blocked = 2
    }
}
