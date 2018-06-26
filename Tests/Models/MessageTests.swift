@testable import EntropyKit
import XCTest

class MessageTests: XCTestCase {
    private var database: Database!
    private var dbPath: URL!

    override func setUp() {
        super.setUp()
        dbPath = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(type(of: self)).sqlite")
        database = try! Database(path: dbPath)
    }

    override func tearDown() {
        try! FileManager.default.removeItem(at: dbPath)
        super.tearDown()
    }

    func testInit() {
        let currentDate = Date()

        let message = Message(
            id: "a87b9344-2c9a-41b9-93c9-d43dcefdff7c",
            roomID: "Wakeful_Pigs",
            date: currentDate,
            senderID: "Captain Hazel Boffin-Blackshaw",
            type: .text,
            body: "pine forest burning\nthe brown allegheny roars\ncoagulation"
        )

        XCTAssertEqual(message.id, "a87b9344-2c9a-41b9-93c9-d43dcefdff7c")
        XCTAssertEqual(message.roomID, "Wakeful_Pigs")
        XCTAssertEqual(message.date, currentDate)
        XCTAssertEqual(message.senderID, "Captain Hazel Boffin-Blackshaw")
        XCTAssertEqual(message.type, .text)
        XCTAssertEqual(message.body, "pine forest burning\nthe brown allegheny roars\ncoagulation")
    }

    func testCreate() throws {
        let room = try Room.create(id: "The Calm Humans", database: database)
        let user = try User.create(id: "Petty Officer Archie Coldbath-Cargill", database: database)

        let message = try Message.create(id: "foo", roomID: room.id, date: Date(), senderID: user.id, type: .text, body: "Bar", database: database) { message in
            message.sender = user
        }

        try database.dbQueue.inDatabase { db in
            let m = try Message.fetchOne(db, key: message.id)!
            XCTAssertEqual(m.roomID, room.id)
            XCTAssertEqual(m.senderID, user.id)
            XCTAssertEqual(m.type, .text)
            XCTAssertEqual(m.body, "Bar")
        }
    }

    func testCompleteRequest() throws {
        let room = try Room.create(id: "The Calm Humans", database: database)
        let user = try User.create(id: "Petty Officer Archie Coldbath-Cargill", database: database)

        _ = try Message.create(id: "foo", roomID: room.id, date: Date(), senderID: user.id, type: .text, body: "Bar", database: database)

        try database.dbQueue.inDatabase { db in
            let (sql, arguments, adapter) = Message.completeRequest(roomID: "The Calm Humans", offset: 0, limit: 1)
            let messages = try Message.fetchAll(db, sql, arguments: arguments, adapter: adapter)

            XCTAssertEqual(messages.count, 1)
            let message = messages[0]

            XCTAssertEqual(message.id, "foo")
            XCTAssertEqual(message.roomID, room.id)
            XCTAssertEqual(message.senderID, user.id)
            XCTAssertEqual(message.sender!.id, user.id)
            XCTAssertEqual(message.type, .text)
            XCTAssertEqual(message.body, "Bar")
        }
    }
}
