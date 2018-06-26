@testable import EntropyKit
import XCTest

class RoomTests: XCTestCase {
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
        let room = Room(id: "Prince Fred Sweetecok-Danvers")

        XCTAssertEqual(room.id, "Prince Fred Sweetecok-Danvers")
    }

    func testCreate() throws {
        let room = try Room.create(id: "SuperSpecialSecretRoom", database: database) { room in
            room.name = "myRoom"
        }

        XCTAssertEqual(room.id, "SuperSpecialSecretRoom")
        XCTAssertEqual(room.name, "myRoom")

        let room2 = try Room.create(id: "SuperSpecialSecretRoom", database: database)
        XCTAssertEqual(room2.id, "SuperSpecialSecretRoom")
        XCTAssertEqual(room2.name, "myRoom")
    }

    func testUpdate() throws {
        let room = try Room.create(id: "mooR", database: database)
        try room.update(database: database) { room in
            room.name = "reverseMe"
        }
        let room2 = try Room.create(id: "mooR", database: database)
        XCTAssertEqual(room2.name, "reverseMe")
    }
}
