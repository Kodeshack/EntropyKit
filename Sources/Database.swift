import Foundation
import GRDB

class Database {
    var dbQueue: DatabaseQueue

    init(path: URL) throws {
        dbQueue = try DatabaseQueue(path: path.path)

        var migrator = DatabaseMigrator()
        migrator.registerMigration(v0.version) { db in

            try db.create(table: v0.users.table) { t in
                t.column(v0.users.id, .text).primaryKey(onConflict: .replace)
                t.column(v0.users.displayname, .text)
            }

            try db.create(table: v0.accounts.table) { t in
                t.column(v0.accounts.userID, .text).primaryKey(onConflict: .replace).references(v0.users.table)
                t.column(v0.accounts.deviceID, .text).notNull()
                t.column(v0.accounts.nextBatch, .text)
                t.column(v0.accounts.accessToken, .text).notNull()
                t.column(v0.accounts.transactionID, .integer).notNull()
            }

            try db.create(table: v0.rooms.table) { t in
                t.column(v0.rooms.id, .text).primaryKey(onConflict: .replace)
                t.column(v0.rooms.name, .text)
                t.column(v0.rooms.oldestState, .text)
                t.column(v0.rooms.encrypted, .boolean).notNull()
                t.column(v0.rooms.encryptionAlgorithm, .text)
                t.column(v0.rooms.rotationPeriodTime, .integer)
                t.column(v0.rooms.rotationPeriodMessages, .integer)
                t.column(v0.rooms.announced, .boolean).notNull()
            }

            try db.create(table: v0.messages.table) { t in
                t.column(v0.messages.id, .text).primaryKey(onConflict: .replace)
                t.column(v0.messages.roomID, .text).notNull().references(v0.rooms.table, column: v0.rooms.id, deferred: true)
                t.column(v0.messages.date, .datetime).notNull()
                t.column(v0.messages.senderID, .text).notNull().references(v0.users.table, column: v0.users.id, deferred: true)
                t.column(v0.messages.type, .text).notNull()
                t.column(v0.messages.body, .text).notNull()
            }

            try db.create(table: v0.media.table) { t in
                t.column(v0.media.id, .text).primaryKey(onConflict: .replace)
                t.column(v0.media.messageID, .text).notNull().references(v0.messages.table, column: v0.messages.id, onDelete: .cascade, deferred: true)
                t.column(v0.media.thumbnailID, .text).references(v0.media.table, column: v0.media.id, onDelete: .cascade, deferred: true)
                t.column(v0.media.url, .text).notNull()
                t.column(v0.media.width, .integer).notNull()
                t.column(v0.media.height, .integer).notNull()
                t.column(v0.media.size, .integer).notNull()
                t.column(v0.media.type, .text).notNull()
            }

            try db.create(table: v0.users_rooms.table) { t in
                t.column(v0.users_rooms.userID, .text).references(v0.users.table, column: v0.users.id, deferred: true)
                t.column(v0.users_rooms.roomID, .text).references(v0.rooms.table, column: v0.rooms.id, deferred: true)
                t.primaryKey([v0.users_rooms.userID, v0.users_rooms.roomID], onConflict: .replace)
            }

            try db.create(table: v0.settings.table) { t in
                t.column(v0.settings.key, .text).primaryKey(onConflict: .replace)
                t.column(v0.settings.value, .text)
            }

            try db.create(table: v0.devices.table) { t in
                t.column(v0.devices.id, .text).notNull()
                t.column(v0.devices.userID, .text).notNull().references(v0.users.table, column: v0.users.id, onDelete: .cascade, deferred: true)
                t.column(v0.devices.displayname, .text)
                t.column(v0.devices.curve25519Key, .text)
                t.column(v0.devices.ed25519Key, .text)
                t.column(v0.devices.algorithms, .text)
                t.column(v0.devices.verificationStatus, .integer).notNull()
                t.primaryKey([v0.devices.id, v0.devices.userID])
            }

            try db.create(table: v0.cryptoBlobs.table) { t in
                t.column(v0.cryptoBlobs.id, .text)
                t.column(v0.cryptoBlobs.type, .integer)
                t.column(v0.cryptoBlobs.blob, .blob)
                t.primaryKey([v0.cryptoBlobs.id, v0.cryptoBlobs.type], onConflict: .replace)
            }
        }

        try migrator.migrate(dbQueue)
    }
}

extension Database {
    struct v0 {
        static let version = "v0"
        struct users {
            static let table = "users"
            static let id = "id"
            static let username = "username"
            static let displayname = "displayname"
            static let avatar = "avatar"
        }

        struct accounts {
            static let table = "accounts"
            static let userID = "user_id"
            static let deviceID = "device_id"
            static let nextBatch = "next_batch"
            static let accessToken = "access_token"
            static let transactionID = "transaction_id"
        }

        struct rooms {
            static let table = "rooms"
            static let id = "id"
            static let name = "name"
            static let oldestState = "oldest_state"
            static let encrypted = "encrypted"
            static let encryptionAlgorithm = "encryption_algorithm"
            static let rotationPeriodTime = "rotation_period_time"
            static let rotationPeriodMessages = "rotation_period_messages"
            static let announced = "announced"
        }

        struct messages {
            static let table = "messages"
            static let id = "id"
            static let roomID = "room_id"
            static let date = "date"
            static let senderID = "sender_id"
            static let type = "type"
            static let body = "body"
        }

        struct media {
            static let table = "media"
            static let id = "id"
            static let messageID = "message_id"
            static let thumbnailID = "thumbnail_id"
            static let url = "url"
            static let width = "width"
            static let height = "height"
            static let size = "size"
            static let type = "type"
        }

        struct users_rooms {
            static let table = "users_rooms"
            static let userID = "user_id"
            static let roomID = "room_id"
        }

        struct settings {
            static let table = "settings"
            static let key = "key"
            static let value = "value"
        }

        struct devices {
            static let table = "devices"
            static let id = "id"
            static let userID = "user_id"
            static let displayname = "displayname"
            static let curve25519Key = "curve25519_key"
            static let ed25519Key = "ed25519_key"
            static let algorithms = "algorithms"
            static let verificationStatus = "verification_status"
        }

        struct cryptoBlobs {
            static let table = "crypto_blobs"
            static let id = "id"
            static let type = "type"
            static let blob = "blob"
        }
    }
}
