@testable import EntropyKit
import XCTest

class UserTests: XCTestCase {
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

    func testCreate() throws {
        let user = try User.create(id: "@NotBob:kodeshack", database: database) { user in
            user.displayname = "Not Bob"
        }
        XCTAssertEqual(user.id, "@NotBob:kodeshack")
        XCTAssertEqual(user.displayname, "Not Bob")

        let user2 = try User.create(id: "@NotBob:kodeshack", database: database)
        XCTAssertEqual(user2.id, "@NotBob:kodeshack")
        XCTAssertEqual(user2.displayname, "Not Bob")
    }

    func testUpdate() throws {
        let user = try User.create(id: "@BobTheBuilder", database: database)
        try user.update(database: database) { user in
            user.displayname = "Bob the Builder"
        }
        let user2 = try User.create(id: "@BobTheBuilder", database: database)
        XCTAssertEqual(user2.displayname, "Bob the Builder")
    }
}
