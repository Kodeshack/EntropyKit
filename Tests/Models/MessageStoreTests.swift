@testable import EntropyKit
import XCTest

class MessageStoreTests: XCTestCase {
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
        database = nil
        try! FileManager.default.removeItem(at: dbPath)
        super.tearDown()
    }

    func testInsert() {
        let user = User(id: "user_id")
        try! user.save(database: database)
        let room = Room(id: "room_id")
        try! room.save(database: database)

        let store = try! MessageStore(database: database, roomID: room.id)
        let message = Message(id: "message_id", roomID: room.id, date: Date(), senderID: user.id, type: .text, body: "body")

        XCTAssertNil(store.save(message).error)

        let dbMsg = try! store.fetch(key: "message_id").dematerialize()
        XCTAssertNotNil(dbMsg)
    }


    func testDelete() {
        let user = User(id: "user_id")
        try! user.save(database: database)
        let room = Room(id: "room_id")
        try! room.save(database: database)

        let store = try! MessageStore(database: database, roomID: room.id)
        let message = Message(id: "message_id", roomID: room.id, date: Date(), senderID: user.id, type: .text, body: "body")

        XCTAssertNil(store.save(message).error)

        var dbMsg = try! store.fetch(key: "message_id").dematerialize()
        XCTAssertNotNil(dbMsg)

        XCTAssert(try! store.delete(message).dematerialize())

        dbMsg = try! store.fetch(key: "message_id").dematerialize()
        XCTAssertNil(dbMsg)
    }


    func testWindow() {
        let user1 = User(id: "user_1")
        try! user1.save(database: database)
        let user2 = User(id: "user_2")
        try! user2.save(database: database)
        let room = Room(id: "room_id")
        try! room.save(database: database)

        var messages = [Message]()

        var lastDate = Date(timeIntervalSince1970: 795_398_400)
        (0 ... 99).forEach { i in
            let user = (i % 2 == 0) ? user1 : user2
            lastDate = Date(timeInterval: TimeInterval(exactly: 60)!, since: lastDate)
            let message = Message(id: "message_\(i)", roomID: room.id, date: lastDate, senderID: user.id, type: .text, body: "")
            try! message.save(database: database)
            messages.append(message)
        }

        let store = try! MessageStore(database: database, roomID: room.id, pageSize: 25, numPages: 3)

        XCTAssertEqual(store.totalFetchCount, 25)
        (0 ... 24).forEach { i in
            XCTAssertEqual(store.messages[i].id, messages[messages.count - 25 + i].id)
        }

        XCTAssertEqual(try! store.fetchEarlier().dematerialize(), 25)
        XCTAssertEqual(store.totalFetchCount, 50)
        (0 ... 24).forEach { i in
            XCTAssertEqual(store.messages[i].id, messages[messages.count - 50 + i].id)
        }

        XCTAssertEqual(try! store.fetchLater().dematerialize(), 25)
        XCTAssertEqual(store.totalFetchCount, 50)
        (0 ... 24).forEach { i in
            XCTAssertEqual(store.messages[i].id, messages[messages.count - 25 + i].id)
        }

        XCTAssertEqual(try! store.fetchEarlier().dematerialize(), 25)
        XCTAssertEqual(try! store.fetchEarlier().dematerialize(), 25)
        XCTAssertEqual(store.totalFetchCount, 75)
        (0 ... 24).forEach { i in
            XCTAssertEqual(store.messages[i].id, messages[messages.count - 75 + i].id)
        }

        XCTAssertEqual(try! store.fetchLater().dematerialize(), 25)
        XCTAssertEqual(store.totalFetchCount, 75)
        (0 ... 24).forEach { i in
            XCTAssertEqual(store.messages[i].id, messages[messages.count - 50 + i].id)
        }

        XCTAssertEqual(try! store.fetchLater().dematerialize(), 25)
        XCTAssertEqual(store.totalFetchCount, 75)
        (0 ... 24).forEach { i in
            XCTAssertEqual(store.messages[i].id, messages[messages.count - 25 + i].id)
        }
    }

    func testRelativeFetchTrivial() {
        let user1 = User(id: "user_1")
        try! user1.save(database: database)
        let user2 = User(id: "user_2")
        try! user2.save(database: database)
        let room = Room(id: "room_id")
        try! room.save(database: database)


        var messages = [Message]()

        var lastDate = Date(timeIntervalSince1970: 795_398_400)
        (0 ... 99).forEach { i in
            let user = (i % 2 == 0) ? user1 : user2
            lastDate = Date(timeInterval: TimeInterval(exactly: 60)!, since: lastDate)
            let message = Message(id: "message_\(i)", roomID: room.id, date: lastDate, senderID: user.id, type: .text, body: "")
            try! message.save(database: database)
            messages.append(message)
        }

        let store = try! MessageStore(database: database, roomID: room.id, pageSize: 25, numPages: 3)

        XCTAssertEqual(store.totalFetchCount, 25)

        XCTAssertEqual(store.fetchRelativeMessage(index: 0), messages[messages.count - 25])
        XCTAssertEqual(store.fetchRelativeMessage(index: 24), messages[messages.count - 1])
    }

    func testRelativeFetchTrivialBackwards() {
        let user1 = User(id: "user_1")
        try! user1.save(database: database)
        let user2 = User(id: "user_2")
        try! user2.save(database: database)
        let room = Room(id: "room_id")
        try! room.save(database: database)


        var messages = [Message]()

        var lastDate = Date(timeIntervalSince1970: 795_398_400)
        (0 ... 99).forEach { i in
            let user = (i % 2 == 0) ? user1 : user2
            lastDate = Date(timeInterval: TimeInterval(exactly: 60)!, since: lastDate)
            let message = Message(id: "message_\(i)", roomID: room.id, date: lastDate, senderID: user.id, type: .text, body: "")
            try! message.save(database: database)
            messages.append(message)
        }

        let store = try! MessageStore(database: database, roomID: room.id, pageSize: 25, numPages: 3)

        XCTAssertEqual(store.totalFetchCount, 25)
        XCTAssertEqual(try! store.fetchEarlier().dematerialize(), 25)
        XCTAssertEqual(store.fetchRelativeMessage(index: 0), messages[messages.count - 50])
        XCTAssertEqual(store.fetchRelativeMessage(index: 24), messages[messages.count - 26])
    }

    func testRelativeFetchNonTrivial() {
        let user1 = User(id: "user_1")
        try! user1.save(database: database)
        let user2 = User(id: "user_2")
        try! user2.save(database: database)
        let room = Room(id: "room_id")
        try! room.save(database: database)


        var messages = [Message]()

        var lastDate = Date(timeIntervalSince1970: 795_398_400)
        (0 ... 99).forEach { i in
            let user = (i % 2 == 0) ? user1 : user2
            lastDate = Date(timeInterval: TimeInterval(exactly: 60)!, since: lastDate)
            let message = Message(id: "message_\(i)", roomID: room.id, date: lastDate, senderID: user.id, type: .text, body: "")
            try! message.save(database: database)
            messages.append(message)
        }

        let store = try! MessageStore(database: database, roomID: room.id, pageSize: 25, numPages: 3)

        XCTAssertEqual(store.totalFetchCount, 25)
        XCTAssertEqual(try! store.fetchEarlier().dematerialize(), 25)
        XCTAssertEqual(try! store.fetchLater().dematerialize(), 25)

        XCTAssertEqual(store.fetchRelativeMessage(index: 0), nil)
        XCTAssertEqual(store.fetchRelativeMessage(index: 24), nil)

        XCTAssertEqual(store.fetchRelativeMessage(index: 25), messages[messages.count - 25])
        XCTAssertEqual(store.fetchRelativeMessage(index: 49), messages[messages.count - 1])
    }
}
