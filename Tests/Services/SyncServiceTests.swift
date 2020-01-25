@testable import EntropyKit
import OHHTTPStubs
import XCTest

class SyncServiceTests: XCTestCase {
    private var database: Database!
    private var dbPath: URL!

    override func setUp() {
        super.setUp()
        dbPath = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(type(of: self)).sqlite")
        database = try! Database(path: dbPath)
        MatrixAPI.default.baseURL = "https://entropy.kodeshack.com"
    }

    override func tearDown() {
        try! FileManager.default.removeItem(at: dbPath)
        HTTPStubs.removeAllStubs()
        super.tearDown()
    }

    func testInit() {
        let account = Account(userID: "@NotBob:kodeshack", accessToken: "foo", deviceID: "bar", nextBatch: "", cryptoEngine: CryptoEngine())
        let s = SyncService(account: account, database: database, timeout: 100)
        XCTAssertNotNil(s)
    }

    func testSync() {
        stub(condition: isHost("entropy.kodeshack.com")) { _ in
            HTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/simple_sync.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
        let exp = expectation(description: "sync request")
        let user = try! User.create(id: "@NotBob:kodeshack", database: database)
        let account = Account(user: user, accessToken: "foo", deviceID: "bar", nextBatch: "", cryptoEngine: nil)
        try! database.dbQueue.write { db in
            try! account.save(db)
        }
        let s = SyncService(account: account, database: database, timeout: 100)

        let delegate = SyncServiceTestsDelegate(cbSyncStart: {}, cbSyncEnd: { result in
            defer { exp.fulfill() }
            guard case let .success(value) = result else {
                XCTFail(result.failure!.localizedDescription)
                return
            }

            XCTAssertEqual(value.nextBatch, "s2083_14017_186_2207_51_12_180")
            XCTAssertEqual(value.events.count, 15)
            XCTAssertEqual(value.events.filter { $0.type == .create }.count, 1)
            XCTAssertEqual(value.events.filter { $0.type == .member }.count, 7)
            XCTAssertEqual(value.events.filter { $0.type == .roomPrevBatch }.count, 1)
            XCTAssertEqual(value.events.filter { $0.type == .message }.count, 1)
            XCTAssertEqual(value.events.filter { $0.type == .name }.count, 1)
            XCTAssertEqual(value.otkCount, 10)
            XCTAssertEqual(value.devicesChanged, ["@alice:example.com"])
        })

        s.delegate = delegate

        s.sync {}

        waitForExpectations(timeout: 90)
    }
}

private class SyncServiceTestsDelegate: SyncServiceDelegate {
    private let cbSyncStart: () -> Void
    private let cbSyncEnd: (Result<SyncService.SyncResult, Error>) -> Void

    public init(cbSyncStart: @escaping () -> Void, cbSyncEnd: @escaping (Result<SyncService.SyncResult, Error>) -> Void) {
        self.cbSyncStart = cbSyncStart
        self.cbSyncEnd = cbSyncEnd
    }

    func syncStarted() {
        cbSyncStart()
    }

    func syncEnded(_ result: Result<SyncService.SyncResult, Error>) {
        cbSyncEnd(result)
    }
}
