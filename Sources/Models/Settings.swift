import GRDB

class Settings {
    private static let userDefaults = UserDefaults.standard

    static var userAgent: String? {
        get {
            return userDefaults.string(forKey: Keys.userAgent)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.userAgent)
        }
    }

    static func storeHomeserver(_ homeserver: URL, database: Database) throws {
        try database.dbQueue.write { db in
            try Setting(key: Settings.Keys.homeserver, value: homeserver.absoluteString).insert(db)
        }
    }

    static func loadHomeserver(from database: Database) throws -> URL? {
        return try database.dbQueue.read { db -> URL? in
            if let homeserver = try Setting.fetchOne(db, key: Settings.Keys.homeserver) {
                return URL(string: homeserver.value)
            }
            return nil
        }
    }

    private struct Keys {
        static let homeserver = "homeserver"
        static let userAgent = "UserAgent"
    }
}

class Setting: Record {
    let key: String
    let value: String

    init(key: String, value: String) {
        self.key = key
        self.value = value
        super.init()
    }

    required init(row: Row) {
        key = row[Database.v0.settings.key]
        value = row[Database.v0.settings.value]
        super.init(row: row)
    }

    override class var databaseTableName: String {
        return Database.v0.settings.table
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Database.v0.settings.key] = key
        container[Database.v0.settings.value] = value
    }
}
