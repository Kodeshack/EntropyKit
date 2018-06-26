@testable import EntropyKit
import OHHTTPStubs
import OLMKit
import XCTest

class E2EEServiceTests: XCTestCase {
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
        database.dbQueue.releaseMemory()
        database = nil
        OHHTTPStubs.removeAllStubs()
        try! FileManager.default.removeItem(at: dbPath)
        super.tearDown()
    }

    func testAnnounceDevice() throws {
        // Prime DB
        try database.dbQueue.inDatabase { db in
            try [Room(id: "foo"), Room(id: "bar")].forEach {
                $0.encrypted = true
                try $0.insert(db)
            }
            try [User(id: "NotBob"), User(id: "NotNotNotBob")].forEach { try $0.insert(db) }
            try [
                UserRoom(userID: "NotBob", roomID: "foo"),
                UserRoom(userID: "NotNotNotBob", roomID: "bar"),
                UserRoom(userID: "NotNotNotBob", roomID: "foo"),
            ].forEach { try $0.insert(db) }
        }

        stub(condition: pathStartsWith("/_matrix/client/r0/sendToDevice/m.new_device")) { _ in
            OHHTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
        }
        let exp = expectation(description: "announceDevice")

        let account = Account(userID: "NotBob", accessToken: "token", deviceID: "tests", nextBatch: "")

        E2EEService(database: database).announceDevice(account: account) { result in
            XCTAssertTrue(result.isValue)

            self.database.dbQueue.inDatabase { db in
                let rooms = try! Room.fetchAll(db, keys: ["foo", "bar"])
                rooms.forEach { XCTAssertTrue($0.announced) }
            }
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testUploadKeys() throws {
        stub(condition: pathStartsWith("/_matrix/client/r0/keys/upload")) { _ in
            let resp = KeysUploadResponse(oneTimeKeyCounts: [CryptoEngine.CryptoKeys.signedCurve25519.rawValue: 50])
            return OHHTTPStubsResponse(
                data: resp.encoded,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
        let exp = expectation(description: "uploadKeys")

        let account = Account(userID: "NotBob", accessToken: "token", deviceID: "tests", nextBatch: "")

        let deviceKeys = KeysUploadRequest.DeviceKeys(
            account: account,
            algorithms: [.olm, .megolm],
            keys: [
                "\(CryptoEngine.CryptoKeys.curve25519):\(account.deviceID)": account.identityKeys.curve25519,
                "\(CryptoEngine.CryptoKeys.ed25519):\(account.deviceID)": account.identityKeys.ed25519,
            ]
        )
        let keysUploadRequest = KeysUploadRequest(deviceKeys: deviceKeys, oneTimeKeys: account.getOneTimeKeys())

        E2EEService(database: database).uploadKeys(account: account, request: keysUploadRequest, queue: DispatchQueue.main) { result in
            XCTAssertTrue(result.isValue)
            XCTAssertEqual(result.value, 50)
            exp.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testGetDevices() throws {
        stub(condition: pathStartsWith("/_matrix/client/r0/keys/query")) { _ in
            OHHTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/e2ee_query_keys_response.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
        let exp = expectation(description: "getDevices")
        let account = try Account.create(userID: "@NotBob:kodeshack", accessToken: "token", deviceID: "tests", database: database)

        E2EEService(database: database).getDevices(account: account, userIDs: ["@NotBob:kodeshack"], queue: DispatchQueue.main) { result in
            XCTAssertTrue(result.isValue)
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    /// Security relevant test
    func testGetDevicesWithKeyMistmatch() throws {
        // Prime DB
        let account = try Account.create(userID: "@NotBob:kodeshack", accessToken: "token", deviceID: "LPUUCBBOJP", database: database)
        try database.dbQueue.inDatabase { db in
            try Device(id: "LPUUCBBOJP", userID: "@NotBob:kodeshack", curve25519Key: "zxQXu5mT2lK+XdLUlaGl7E+YKFrt79/FWCXmJHSK3GQ", ed25519Key: "INVALID").insert(db)
        }

        stub(condition: pathStartsWith("/_matrix/client/r0/keys/query")) { _ in
            OHHTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/e2ee_query_keys_response.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
        let exp = expectation(description: "getDevices")

        E2EEService(database: database).getDevices(account: account, userIDs: ["@NotBob:kodeshack"], queue: DispatchQueue.main) { result in
            if case let .deviceEd25519KeyMismatch(device)? = result.error as? E2EEService.E2EEError {
                XCTAssertEqual(device.id, "LPUUCBBOJP")
            } else {
                XCTFail()
            }
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testGetDevicesAndRemoveOld() throws {
        let account = try Account.create(userID: "@NotBob:kodeshack", accessToken: "token", deviceID: "tests", database: database)

        try database.dbQueue.inDatabase { db in
            try Device(id: "foo", userID: "@NotBob:kodeshack").insert(db)
        }

        stub(condition: pathStartsWith("/_matrix/client/r0/keys/query")) { _ in
            return OHHTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/e2ee_query_keys_response.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
        let exp = expectation(description: "getDevices")

        E2EEService(database: database).getDevices(account: account, userIDs: ["@NotBob:kodeshack"], queue: DispatchQueue.main) { result in
            XCTAssertTrue(result.isValue)

            self.database.dbQueue.inDatabase { db in
                try! XCTAssertNil(Device.fetchOne(db, key: [Database.v0.devices.id: "foo", Database.v0.devices.userID: "@NotBob:kodeshack"]))
            }

            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    /// Security relevant test
    func testGetDevicesUserIDMismatch() throws {
        stub(condition: pathStartsWith("/_matrix/client/r0/keys/query")) { _ in
            OHHTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/e2ee_query_keys_response_user_id_mismatch.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
        let exp = expectation(description: "getDevices")

        let account = try Account.create(userID: "@NotBob:kodeshack", accessToken: "token", deviceID: "tests", database: database)

        E2EEService(database: database).getDevices(account: account, userIDs: ["@NotBob:kodeshack"], queue: DispatchQueue.main) { result in
            XCTAssertTrue(result.isValue)
            XCTAssertEqual(result.value?.count, 0)

            self.database.dbQueue.inDatabase { db in
                try! XCTAssertEqual(Device.fetchCount(db), 0)
            }

            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    /// Security relevant test
    func testGetDevicesDeviceIDMismatch() throws {
        stub(condition: pathStartsWith("/_matrix/client/r0/keys/query")) { _ in
            OHHTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/e2ee_query_keys_response_device_id_mismatch.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
        let exp = expectation(description: "getDevices")

        let account = try Account.create(userID: "@NotBob:kodeshack", accessToken: "token", deviceID: "tests", database: database)

        E2EEService(database: database).getDevices(account: account, userIDs: ["@NotBob:kodeshack"], queue: DispatchQueue.main) { result in
            XCTAssertTrue(result.isValue)
            XCTAssertEqual(result.value?.count, 0)

            self.database.dbQueue.inDatabase { db in
                try! XCTAssertEqual(Device.fetchCount(db), 0)
            }

            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    /// Security relevant test
    func testGetDevicesSignatureMismatch() throws {
        stub(condition: pathStartsWith("/_matrix/client/r0/keys/query")) { _ in
            OHHTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/e2ee_query_keys_response_signature_mismatch.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
        let exp = expectation(description: "getDevices")

        let account = try Account.create(userID: "@NotBob:kodeshack", accessToken: "token", deviceID: "tests", database: database)

        E2EEService(database: database).getDevices(account: account, userIDs: ["@NotBob:kodeshack"], queue: DispatchQueue.main) { result in
            XCTAssertTrue(result.isValue)
            XCTAssertEqual(result.value?.count, 0)

            self.database.dbQueue.inDatabase { db in
                try! XCTAssertEqual(Device.fetchCount(db), 0)
            }

            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    /// Security relevant test
    func testGetDevicesMissingSignature() throws {
        stub(condition: pathStartsWith("/_matrix/client/r0/keys/query")) { _ in
            OHHTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/e2ee_query_keys_response_missing_keys.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
        let exp = expectation(description: "getDevices")

        let account = try Account.create(userID: "@NotBob:kodeshack", accessToken: "token", deviceID: "tests", database: database)

        E2EEService(database: database).getDevices(account: account, userIDs: ["@NotBob:kodeshack"], queue: DispatchQueue.main) { result in
            XCTAssertTrue(result.isValue)
            XCTAssertEqual(result.value?.count, 0)

            self.database.dbQueue.inDatabase { db in
                try! XCTAssertEqual(Device.fetchCount(db), 0)
            }

            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testPublishGroupSessionKeys() throws {
        // Prime DB
        try database.dbQueue.inDatabase { db in
            try [Room(id: "foo"), Room(id: "bar")].forEach {
                $0.encrypted = true
                try $0.insert(db)
            }

            try [User(id: "NotBob"), User(id: "NotNotNotBob")].forEach { try $0.insert(db) }

            try [
                UserRoom(userID: "NotBob", roomID: "foo"),
                UserRoom(userID: "NotNotNotBob", roomID: "bar"),
                UserRoom(userID: "NotNotNotBob", roomID: "foo"),
            ].forEach { try $0.insert(db) }

            try [
                Device(id: "foo", userID: "NotBob", curve25519Key: "zxQXu5mT2lK+XdLUlaGl7E+YKFrt79/FWCXmJHSK3GQ", ed25519Key: "vXAWJiziiTAGuNSjY3/mX76WxqRg/iBpyfD4xwLKy2A"),
                Device(id: "bar", userID: "NotBob", curve25519Key: "Jv5MW28R1BKQIYTWDEEseCcxJBnF0HZBijmQTqcsw24", ed25519Key: "SBYIgpwdR7pEPKkKR8l/wgujfUH4SCmCG5nWwlWhXhw"),
                Device(id: "baz", userID: "NotNotNotBob", curve25519Key: "jDuVZyjFM/p6HQArLu+liyX0wAzy1GrwLi4P/6JBdQA", ed25519Key: "TCnQ4nvQmZvi+eokaLmeavOEKV8Geh7BvOaj2tkgO5A"),
            ].forEach { try $0.insert(db) }
        }

        stub(condition: pathStartsWith("/_matrix/client/r0/sendToDevice/m.room.encrypted")) { request in
            XCTAssertFalse(request.ohhttpStubs_httpBody!.isEmpty)
            return OHHTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
        }
        let exp = expectation(description: "publishGroupSessionKeys")

        let account = Account(userID: "NotBob", accessToken: "token", deviceID: "tests", nextBatch: "")

        let olmEncrypt: (String, CryptoEngine.Curve25519Key) -> (String, OLMMessageType) = { _, _ in
            ("totally secure and encrypted", OLMMessageType(rawValue: 1)!)
        }

        let sessionInfo = E2EEService.SessionInfo(
            roomID: "foo",
            sessionID: "bar",
            sessionKey: "baz",
            chainIndex: 0
        )

        E2EEService(database: database).publishGroupSessionKeys(
            for: account,
            sessionInfo: sessionInfo,
            olmEncrypt: olmEncrypt,
            queue: DispatchQueue.main
        ) { result in
            XCTAssertNil(result.error)
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
}
