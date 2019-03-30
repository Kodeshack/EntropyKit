@testable import EntropyKit
import XCTest

class AccountTests: XCTestCase {
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

    func testCreate() throws {
        let user = try User.create(id: "@NotBob:kodeshack", database: database) { user in
            user.displayname = "Not Bob"
        }

        let account = try Account.create(userID: "@NotBob:kodeshack", accessToken: "123", deviceID: "bar", database: database)
        XCTAssertEqual(account.userID, "@NotBob:kodeshack")
        XCTAssertEqual(account.userID, user.id)
        XCTAssertEqual(account.accessToken, "123")
        XCTAssertEqual(account.nextBatch, "")
        XCTAssertEqual(account.deviceID, "bar")

        if let id = account.user?.id {
            XCTAssertEqual(id, user.id)
        } else {
            XCTFail()
        }

        let account1 = try Account.create(userID: "@NotBob:kodeshack1", accessToken: "456", deviceID: "bar", database: database)

        try database.dbQueue.read { db in
            let count = try Account.fetchAll(db).filter { $0.userID == account1.userID }.count
            XCTAssertEqual(count, 1)
        }
    }

    func testNextTransactionID() throws {
        let account = try Account.create(userID: "Robin", accessToken: "hurrdurr", deviceID: "notsonewanymoresmartphone", database: database)
        // get 10 ids and hope that they are distinct.
        let ids = (0 ..< 10).map { _ in account.nextTransactionID() }
        var distinctIDs = Set(ids)
        XCTAssertEqual(distinctIDs.count, 10)

        try account.save(database: database)

        let dbAcc = try Account.create(userID: "Robin", accessToken: "hurrdurr", deviceID: "notsonewanymoresmartphone", database: database)
        distinctIDs.insert(dbAcc.nextTransactionID())
        XCTAssertEqual(distinctIDs.count, 11)
    }

    func testInitializers() {
        let user = User(id: "@NotBob:kodeshack", displayname: "Not Bob")
        let account = Account(user: user, accessToken: "123", deviceID: "bar", nextBatch: "s4348_31504_4864_4482_61_12_334")

        XCTAssertEqual(account.userID, "@NotBob:kodeshack")
        XCTAssertEqual(account.userID, user.id)
        XCTAssertEqual(account.accessToken, "123")
        XCTAssertEqual(account.nextBatch, "s4348_31504_4864_4482_61_12_334")
        XCTAssertEqual(account.deviceID, "bar")
    }

    func testUpdate() throws {
        let account = try Account.create(userID: "@BobTheBuilder", accessToken: "Dot", deviceID: "bar", database: database)
        try account.update(database: database) { account in
            account.user!.displayname = "Dot"
        }
        let account2 = try Account.create(userID: "@BobTheBuilder", accessToken: "Dot", deviceID: "bar", database: database)
        XCTAssertEqual(account2.user!.displayname, "Dot")
    }
}
