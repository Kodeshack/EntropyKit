@testable import EntropyKit
import XCTest

class EventPersistenceTests: XCTestCase {
    private var database: Database!
    private var dbPath: URL!

    override func setUp() {
        super.setUp()
        dbPath = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(type(of: self)).sqlite")
        try? FileManager.default.removeItem(at: dbPath)
        database = try! Database(path: dbPath)
    }

    override func tearDown() {
        try! FileManager.default.removeItem(at: dbPath)
        super.tearDown()
    }

    // MARK: Rooms

    func testPersistRoomCreate() throws {
        let event = Event(
            id: "test_event_id_create",
            senderID: "XCTest",
            type: .create,
            date: Date(),
            roomID: "created",
            content: .none
        )

        XCTAssertTrue(database.dbQueue.inDatabase { db in
            event.persist(db)
        }.isValue)

        try database.dbQueue.inDatabase { db in
            XCTAssertNotNil(try Room.fetchOne(db, key: event.roomID))
        }
    }

    func testPersistRoomName() throws {
        try database.dbQueue.inDatabase { db in
            try Room(id: "name").insert(db)
        }

        let event = Event(
            id: "test_event_id_name",
            senderID: "XCTest",
            type: .name,
            date: Date(),
            roomID: "name",
            content: .roomName(RoomNameJSON(name: "bar"))
        )

        XCTAssertNil(database.dbQueue.inDatabase { db in
            event.persist(db)
        }.error)

        try database.dbQueue.inDatabase { db in
            let room = try Room.fetchOne(db, key: event.roomID)
            XCTAssertEqual(room!.name, "bar")
        }
    }

    func testPersistRoomPreviousBatch() throws {
        try database.dbQueue.inDatabase { db in
            try Room(id: "prev").insert(db)
        }

        let event = Event(
            id: "test_event_id",
            senderID: "XCTest",
            type: .roomPrevBatch,
            date: Date(),
            roomID: "prev",
            content: .roomPrevBatch("bar")
        )

        XCTAssertNil(database.dbQueue.inDatabase { db in
            event.persist(db)
        }.error)

        try database.dbQueue.inDatabase { db in
            let room = try Room.fetchOne(db, key: event.roomID)
            XCTAssertEqual(room!.oldestState, "bar")
        }
    }

    func testPersistRoomEncryption() throws {
        try database.dbQueue.inDatabase { db in
            try Room(id: "testPersistRoomEncryption").insert(db)
        }

        let roomEncryptionJSON = RoomEncryptionJSON(algorithm: .megolm)

        let event = Event(
            id: "test_event_id",
            senderID: "XCTest",
            type: .encryption,
            date: Date(),
            roomID: "testPersistRoomEncryption",
            content: .roomEncryption(roomEncryptionJSON)
        )

        XCTAssertNil(database.dbQueue.inDatabase { db in
            event.persist(db)
        }.error)

        try database.dbQueue.inDatabase { db in
            let room = try Room.fetchOne(db, key: event.roomID)
            XCTAssertEqual(room!.encrypted, true)
            XCTAssertEqual(room!.encryptionAlgorithm, .megolm)
            XCTAssertEqual(room!.rotationPeriodTime, 604_800_000)
            XCTAssertEqual(room!.rotationPeriodMessages, 100)
        }
    }

    // MARK: Messages

    func testPersistMessage() throws {
        try database.dbQueue.inTransaction { db in
            try Room(id: "message_room").insert(db)
            try User(id: "XCTestMessageUser", displayname: "XCTestMessageUser").insert(db)
            try UserRoom(userID: "XCTestMessageUser", roomID: "message_room").insert(db)
            return .commit
        }

        let event = Event(
            id: "test_event_id_message",
            senderID: "XCTestMessageUser",
            type: .message,
            date: Date(),
            roomID: "message_room",
            content: .message(PlainMessageJSON(body: "hi", type: .text))
        )

        XCTAssertNil(database.dbQueue.inDatabase { db in
            event.persist(db)
        }.error)

        try database.dbQueue.inDatabase { db in
            let (sql, arguments, adapter) = Message.completeRequest(roomID: "message_room", offset: 0, limit: 1)
            let msg = try Message.fetchOne(db, sql: sql, arguments: arguments, adapter: adapter)

            XCTAssertNotNil(msg)
            XCTAssertEqual(msg?.id, "test_event_id_message")
            XCTAssertEqual(msg?.body, "hi")
            XCTAssertEqual(msg?.roomID, event.roomID)
            XCTAssertEqual(msg?.sender?.displayname, "XCTestMessageUser")
        }
    }

    // MARK: Users

    func testPersistMembership() throws {
        try database.dbQueue.inTransaction { db in
            try Room(id: "membership_room").insert(db)
            try User(id: "XCTestUser1", displayname: "XCTestUser1").insert(db)
            try User(id: "XCTestUser2", displayname: "XCTestUser2").insert(db)
            try UserRoom(userID: "XCTestUser2", roomID: "membership_room").insert(db)
            return .commit
        }

        let event1 = Event(
            id: "test_event_id_membership_1",
            senderID: "XCTestUser1",
            type: .member,
            date: Date(),
            roomID: "membership_room",
            content: .member(MemberJSON(membership: .join, displayname: "XCTestUser1"))
        )

        let event2 = Event(
            id: "test_event_id_membership_2",
            senderID: "XCTestUser2",
            type: .member,
            date: Date(),
            roomID: "membership_room",
            content: .member(MemberJSON(membership: .leave, displayname: "XCTestUser2"))
        )

        database.dbQueue.inDatabase { db in
            XCTAssertNil(event1.persist(db).error)
            XCTAssertNil(event2.persist(db).error)
        }

        try database.dbQueue.inDatabase { db in
            let usersRooms = try UserRoom.fetchAll(db)
            XCTAssertEqual(usersRooms.count, 1)
            XCTAssertEqual(usersRooms.first?.userID, "XCTestUser1")
        }
    }
}
