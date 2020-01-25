@testable import EntropyKit
import OHHTTPStubs
import OLMKit
import XCTest

class CryptoEngineTests: XCTestCase {
    private var database: Database!
    private var dbPath: URL!

    override func setUp() {
        super.setUp()
        dbPath = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(type(of: self)).sqlite")
        try? FileManager.default.removeItem(at: dbPath)
        database = try! Database(path: dbPath)
        MatrixAPI.default.baseURL = "https://entropy.kodeshack.com"
    }

    override func tearDown() {
        database.dbQueue.releaseMemory()
        database = nil
        HTTPStubs.removeAllStubs()
        try! FileManager.default.removeItem(at: dbPath)
        super.tearDown()
    }

    private func getCryptoEngine(userID: UserID = "@NotBob:kodeshack", deviceID: DeviceID = "TEST_DEVICE_ID", database: Database? = nil) throws -> (Account, CryptoEngine) {
        let database = database ?? self.database!

        let exp = XCTestExpectation(description: "getCryptoEngine")

        let keysUploadStub = stub(condition: pathStartsWith("/_matrix/client/r0/keys/upload")) { _ in
            let resp = KeysUploadResponse(oneTimeKeyCounts: [CryptoEngine.CryptoKeys.signedCurve25519.rawValue: 50])
            return HTTPStubsResponse(
                data: resp.encoded,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }

        let keysQueryStub = stub(condition: pathStartsWith("/_matrix/client/r0/keys/query")) { _ in
            let resp = KeysQueryResponse(failures: [:], deviceKeys: [:])
            return HTTPStubsResponse(
                data: resp.encoded,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }

        let ce = CryptoEngine()

        let delegate = CryptoEngineTestsDelegate()

        delegate.errorCB = { _, _ in
            XCTFail()
            exp.fulfill()
        }

        delegate.finishedWorkCB = { _ in
            exp.fulfill()
            ce.delegate = nil
        }

        ce.delegate = delegate

        let account = try Account.create(userID: userID, accessToken: "token", deviceID: deviceID, cryptoEngine: ce, database: database)

        let waiter = XCTWaiter.wait(for: [exp], timeout: 1)

        guard waiter == .completed else {
            fatalError("unexpected waiter result")
        }

        HTTPStubs.removeStub(keysUploadStub)
        HTTPStubs.removeStub(keysQueryStub)

        return (account, ce)
    }

    func testSetup() throws {
        let keysUploadStub = stub(condition: pathStartsWith("/_matrix/client/r0/keys/upload")) { _ in
            let resp = KeysUploadResponse(oneTimeKeyCounts: [CryptoEngine.CryptoKeys.signedCurve25519.rawValue: 50])
            return HTTPStubsResponse(
                data: resp.encoded,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }

        let keysQueryStub = stub(condition: pathStartsWith("/_matrix/client/r0/keys/query")) { _ in
            HTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/e2ee_query_keys_response.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }

        let exp = expectation(description: "testSetup")

        let ce = CryptoEngine()

        let delegate = CryptoEngineTestsDelegate()
        delegate.errorCB = { _, _ in
            XCTFail()
            exp.fulfill()
        }

        delegate.finishedWorkCB = { _ in
            exp.fulfill()
        }

        ce.delegate = delegate

        _ = try Account.create(userID: "@NotBob:kodeshack", accessToken: "token", deviceID: "tests", cryptoEngine: ce, database: database)

        waitForExpectations(timeout: 1)
        HTTPStubs.removeStub(keysUploadStub)
        HTTPStubs.removeStub(keysQueryStub)
    }

    func testEncryptDecrypt() throws {
        let (account, cryptoEngine) = try getCryptoEngine(userID: "@NotNotBob:kodeshack")

        _ = try User.create(id: "@NotBob:kodeshack", database: database)

        _ = try Room.create(id: "roomID", database: database, update: { room in
            room.encrypted = true
            room.rotationPeriodTime = 100
            room.rotationPeriodMessages = 50
        })

        _ = try UserRoom.create(userID: "@NotNotBob:kodeshack", roomID: "roomID", database: database)
        _ = try UserRoom.create(userID: "@NotBob:kodeshack", roomID: "roomID", database: database)

        try database.dbQueue.inDatabase { db in
            try Device(id: "LPUUCBBOJP", userID: "@NotBob:kodeshack", curve25519Key: "2Wt5GjmxsqjcsiXaOPn0GvBD8I6EuSm9NBsI9aBQzFg", ed25519Key: "nD+ycerK+wWVDfcMt8CPlqthIW95Yss6YWIzkqmoqf8", algorithms: [CryptoEngine.Algorithm.olm, CryptoEngine.Algorithm.megolm]).save(db)
        }

        stub(condition: pathStartsWith("/_matrix/client/r0/sendToDevice/m.room.encrypted")) { request in
            XCTAssertFalse(request.ohhttpStubs_httpBody!.isEmpty)

            let json = try! JSONSerialization.jsonObject(with: request.ohhttpStubs_httpBody!, options: []) as! [String: [String: [String: Any]]]
            let toDeviceEvent = json["messages"]!["@NotBob:kodeshack"]!["LPUUCBBOJP"] as! [String: Any]

            XCTAssertEqual(toDeviceEvent["algorithm"] as! String, "m.olm.v1.curve25519-aes-sha2")
            XCTAssertEqual((toDeviceEvent["ciphertext"] as! [String: [String: Any]]).first!.value["type"] as! Int, 0)
            XCTAssertEqual(toDeviceEvent["sender_key"] as! String, account.identityKeys.curve25519)

            return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
        }

        stub(condition: pathStartsWith("/_matrix/client/r0/keys/claim")) { _ in
            HTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/e2ee_keys_claim_response.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }

        // set delegate
        let delegate = CryptoEngineTestsDelegate()
        delegate.errorCB = { _, error in
            XCTFail(error.localizedDescription)
        }
        cryptoEngine.delegate = delegate

        let cryptoExpectation = expectation(description: "cryptoExpectation")
        let event = Event(type: .message, roomID: "roomID", content: .message(PlainMessageJSON(body: "hi", type: .text)))
        cryptoEngine.enqueue(.event(event: event, roomID: "roomID", cb: { result in
            XCTAssertNil(result.failure)
            guard let cipher = result.success else {
                XCTFail()
                return
            }

            cryptoEngine.enqueue(.encryptedEvent(event: cipher, roomID: "roomID", cb: { decryptionResult in
                XCTAssertNil(decryptionResult.failure)
                let outputEvent = decryptionResult.success
                XCTAssertEqual(event.content.message?.body, outputEvent?.content.message?.body)
                XCTAssertEqual(event.roomID, outputEvent?.roomID)
                XCTAssertEqual(outputEvent?.senderID, "@NotNotBob:kodeshack")

                cryptoExpectation.fulfill()
            }))
        }))

        waitForExpectations(timeout: 1)
    }

    func testDecryptToDevice() throws {
        let dbPathB = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(type(of: self))_B.sqlite")
        try? FileManager.default.removeItem(at: dbPathB)
        var databaseB = try! Database(path: dbPathB)

        defer {
            databaseB.dbQueue.releaseMemory()
            try! FileManager.default.removeItem(at: dbPathB)
        }

        let (accountA, cryptoEngineA) = try getCryptoEngine(userID: "@UserA:kodeshack", deviceID: "DEVICE_A")
        let (accountB, cryptoEngineB) = try getCryptoEngine(userID: "@UserB:kodeshack", deviceID: "DEVICE_B", database: databaseB)

        _ = try Room.create(id: "roomID", database: database, update: { room in
            room.encrypted = true
            room.rotationPeriodTime = 100
            room.rotationPeriodMessages = 50
        })

        _ = try Room.create(id: "roomID", database: databaseB, update: { room in
            room.encrypted = true
            room.rotationPeriodTime = 100
            room.rotationPeriodMessages = 50
        })

        _ = try User.create(id: "@UserB:kodeshack", database: database)
        _ = try User.create(id: "@UserA:kodeshack", database: databaseB)

        _ = try UserRoom.create(userID: "@UserA:kodeshack", roomID: "roomID", database: database)
        _ = try UserRoom.create(userID: "@UserB:kodeshack", roomID: "roomID", database: database)
        _ = try UserRoom.create(userID: "@UserA:kodeshack", roomID: "roomID", database: databaseB)
        _ = try UserRoom.create(userID: "@UserB:kodeshack", roomID: "roomID", database: databaseB)

        try database.dbQueue.inDatabase { db in
            try Device(id: "DEVICE_A", userID: "@UserA:kodeshack", curve25519Key: accountA.identityKeys.curve25519, ed25519Key: accountA.identityKeys.ed25519, algorithms: [CryptoEngine.Algorithm.olm, CryptoEngine.Algorithm.megolm]).save(db)

            try Device(id: "DEVICE_B", userID: "@UserB:kodeshack", curve25519Key: accountB.identityKeys.curve25519, ed25519Key: accountB.identityKeys.ed25519, algorithms: [CryptoEngine.Algorithm.olm, CryptoEngine.Algorithm.megolm]).save(db)
        }

        try databaseB.dbQueue.inDatabase { db in
            try Device(id: "DEVICE_A", userID: "@UserA:kodeshack", curve25519Key: accountA.identityKeys.curve25519, ed25519Key: accountA.identityKeys.ed25519, algorithms: [CryptoEngine.Algorithm.olm, CryptoEngine.Algorithm.megolm]).save(db)

            try Device(id: "DEVICE_B", userID: "@UserB:kodeshack", curve25519Key: accountB.identityKeys.curve25519, ed25519Key: accountB.identityKeys.ed25519, algorithms: [CryptoEngine.Algorithm.olm, CryptoEngine.Algorithm.megolm]).save(db)
        }

        stub(condition: pathStartsWith("/_matrix/client/r0/keys/claim")) { _ in
            let otk = accountB.getOneTimeKeys(keyCountOnServer: 0).first!
            var otkReponse = KeysClaimResponse.DeviceOneTimeKey(key: otk.value.key, signatures: nil)
            otkReponse.sign(using: accountB)
            let keysClaimResponse = KeysClaimResponse(failures: [:], oneTimeKeys: [
                "@UserB:kodeshack": [
                    "DEVICE_B": [
                        "\(otk.key)": otkReponse,
                    ],
                ],
            ])

            return HTTPStubsResponse(
                data: keysClaimResponse.encoded,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }

        var toDeviceEvent: SyncResponse.ToDeviceEvent!
        stub(condition: pathStartsWith("/_matrix/client/r0/sendToDevice/m.room.encrypted")) { request in
            XCTAssertFalse(request.ohhttpStubs_httpBody!.isEmpty)

            let json = try! JSONSerialization.jsonObject(with: request.ohhttpStubs_httpBody!, options: []) as! [String: [String: [String: Any]]]
            let eventJSON = try! JSONSerialization.data(withJSONObject: json["messages"]!["@UserB:kodeshack"]!["DEVICE_B"]!, options: [])
            let event = try! EncryptedJSON.decode(eventJSON).get()

            toDeviceEvent = SyncResponse.ToDeviceEvent(senderID: "@UserA:kodeshack", type: .encrypted, content: .encrypted(event))

            return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
        }

        // set delegate
        let delegate = CryptoEngineTestsDelegate()
        delegate.errorCB = { _, error in
            XCTFail(error.localizedDescription)
        }
        cryptoEngineA.delegate = delegate
        cryptoEngineB.delegate = delegate

        let cryptoExpectation = expectation(description: "cryptoExpectation")
        let event = Event(type: .message, roomID: "roomID", content: .message(PlainMessageJSON(body: "hi", type: .text)))
        cryptoEngineA.enqueue(.event(event: event, roomID: "roomID", cb: { result in
            XCTAssertNil(result.failure)

            cryptoEngineB.enqueue(.encryptedToDeviceEvent(event: toDeviceEvent, cb: { decryptionResult in
                XCTAssertNil(decryptionResult.failure)
                let outputEvent = decryptionResult.success!

                XCTAssertEqual(outputEvent.senderID, "@UserA:kodeshack")
                XCTAssertEqual(outputEvent.type, .roomKey) // Event.EventsType.roomKey
                XCTAssertNotNil(outputEvent.content)
                XCTAssertEqual(outputEvent.senderKey, accountA.identityKeys.curve25519)

                guard case let .roomKey(content) = outputEvent.content else {
                    XCTFail()
                    return
                }

                XCTAssertEqual(content.algorithm, .megolm)
                XCTAssertEqual(content.roomID, "roomID")
                XCTAssertEqual(content.chainIndex, 0)
                XCTAssertFalse(content.sessionID.isEmpty)

                cryptoExpectation.fulfill()
            }))
        }))

        waitForExpectations(timeout: 1)
    }

    func testMemberChange() throws {
        let (account, cryptoEngine) = try getCryptoEngine(userID: "@NotNotBob:kodeshack")

        _ = try User.create(id: "@NotBob:kodeshack", database: database)

        _ = try Room.create(id: "roomID", database: database, update: { room in
            room.encrypted = true
            room.rotationPeriodTime = 100
            room.rotationPeriodMessages = 50
        })

        _ = try UserRoom.create(userID: "@NotBob:kodeshack", roomID: "roomID", database: database)

        stub(condition: pathStartsWith("/_matrix/client/r0/keys/query")) { _ in
            HTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/e2ee_keys_claim_response_query_response.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }

        stub(condition: pathStartsWith("/_matrix/client/r0/sendToDevice/m.room.encrypted")) { request in
            XCTAssertFalse(request.ohhttpStubs_httpBody!.isEmpty)
            return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
        }

        // set delegate
        let delegate = CryptoEngineTestsDelegate()
        delegate.errorCB = { _, error in
            XCTFail(error.localizedDescription)
        }
        cryptoEngine.delegate = delegate

        // Send message to create initial sessions
        stub(condition: pathStartsWith("/_matrix/client/r0/rooms/roomID/send/m.room.encrypted")) { _ in
            let resp = EventResponse(eventID: "foo")
            return HTTPStubsResponse(
                data: resp.encoded,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }

        stub(condition: pathStartsWith("/_matrix/client/r0/keys/claim")) { _ in
            HTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/e2ee_keys_claim_response.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }

        let initMemberExp = expectation(description: "initMemberExp")
        delegate.finishedWorkCB = { _ in
            initMemberExp.fulfill()
            delegate.finishedWorkCB = { _ in }
        }
        cryptoEngine.enqueue(.memberChange(userID: "@NotBob:kodeshack", change: .join))
        waitForExpectations(timeout: 1)

        let initMessageExp = expectation(description: "initMessageExp")
        RoomService.send(message: PlainMessageJSON(body: "init", type: .text), to: "roomID", encrypted: true, account: account, database: database) { _ in
            initMessageExp.fulfill()
        }
        waitForExpectations(timeout: 1)

        // Actual member change (join)

        let memberChangedExp = expectation(description: "memberChangedExp")
        delegate.finishedWorkCB = { _ in
            memberChangedExp.fulfill()
            delegate.finishedWorkCB = { _ in }
        }
        cryptoEngine.enqueue(.memberChange(userID: "@NotBob:kodeshack", change: .join))
        waitForExpectations(timeout: 1)

        // Verify that the devices were saved in the DB
        try database.dbQueue.inDatabase { db in
            XCTAssertEqual(try Device.fetchAll(db).count, 1)
        }

        // Send another message to confirm that the sessions were rotated
        stub(condition: pathStartsWith("/_matrix/client/r0/rooms/roomID/send/m.room.encrypted")) { _ in
            let resp = EventResponse(eventID: "bar")
            return HTTPStubsResponse(
                data: resp.encoded,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }

        let anotherMessageExp = expectation(description: "anotherMessageExp")

        RoomService.send(message: PlainMessageJSON(body: "another", type: .text), to: "roomID", encrypted: true, account: account, database: database) { _ in
            anotherMessageExp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testUpdateOTKCountNoChange() throws {
        let (account, cryptoEngine) = try getCryptoEngine()

        stub(condition: pathStartsWith("/_matrix/client/r0/keys/upload")) { _ in
            XCTFail()
            let resp = KeysUploadResponse(oneTimeKeyCounts: [CryptoEngine.CryptoKeys.signedCurve25519.rawValue: 50])
            return HTTPStubsResponse(
                data: resp.encoded,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }

        let count = UInt(account.getOneTimeKeys().count)
        cryptoEngine.enqueue(.otkCountUpdate(count))
    }

    func testRoomKeyEvent() throws {
        let (account, cryptoEngine) = try getCryptoEngine(userID: "@NotNotBob:kodeshack")

        let room = try Room.create(id: "roomID", database: database, update: { room in
            room.encrypted = true
            room.rotationPeriodTime = 100
            room.rotationPeriodMessages = 50
        })

        let delegate = CryptoEngineTestsDelegate()
        delegate.errorCB = { _, error in
            XCTFail(error.localizedDescription)
        }
        cryptoEngine.delegate = delegate

        let exp = expectation(description: "testRoomKeyEvent")

        delegate.finishedWorkCB = { _ in
            exp.fulfill()
            delegate.finishedWorkCB = { _ in }
        }

        let session = OLMOutboundGroupSession(outboundGroupSession: ())!

        let event = RoomKeyJSON(algorithm: .megolm, ciphertext: nil, roomID: room.id, sessionID: session.sessionIdentifier(), sessionKey: session.sessionKey(), chainIndex: 0)
        var toDeviceEvent = SyncResponse.ToDeviceEvent(senderID: account.userID, type: .roomKey, content: .roomKey(event))
        toDeviceEvent.senderKey = account.identityKeys.curve25519

        account.roomKeyEvent(event: toDeviceEvent)

        waitForExpectations(timeout: 1)
    }

    func testVeryImportantChecks() throws {
        let (account, cryptoEngine) = try getCryptoEngine(userID: "@UserA:kodeshack", deviceID: "DEVICE_A")

        let delegate = CryptoEngineTestsDelegate()
        delegate.errorCB = { _, error in
            XCTFail(error.localizedDescription)
        }
        cryptoEngine.delegate = delegate

        let room = try Room.create(id: "roomID", database: database, update: { room in
            room.encrypted = true
            room.rotationPeriodTime = 100
            room.rotationPeriodMessages = 50
        })

        _ = try User.create(id: "@UserB:kodeshack", database: database)
        _ = try User.create(id: "@UserC:kodeshack", database: database)
        _ = try UserRoom.create(userID: "@UserA:kodeshack", roomID: room.id, database: database)
        _ = try UserRoom.create(userID: "@UserB:kodeshack", roomID: room.id, database: database)
        _ = try UserRoom.create(userID: "@UserC:kodeshack", roomID: room.id, database: database)

        let olmAccount = OLMAccount(newAccount: ())!
        let olmSession = try OLMSession(outboundSessionWith: olmAccount, theirIdentityKey: account.identityKeys.curve25519, theirOneTimeKey: account.getOneTimeKeys().first!.value.key)
        let curve25519Key = olmAccount.identityKeys()![CryptoEngine.CryptoKeys.curve25519.rawValue]! as! CryptoEngine.Curve25519Key
        let ed25519Key = olmAccount.identityKeys()![CryptoEngine.CryptoKeys.ed25519.rawValue]! as! CryptoEngine.Ed25519Key

        try database.dbQueue.inDatabase { db in
            try Device(
                id: "DEVICE_A",
                userID: "@UserA:kodeshack",
                curve25519Key: account.identityKeys.curve25519,
                ed25519Key: account.identityKeys.ed25519,
                algorithms: [CryptoEngine.Algorithm.olm, CryptoEngine.Algorithm.megolm]
            ).save(db)
            try Device(
                id: "DEVICE_B",
                userID: "@UserB:kodeshack",
                curve25519Key: curve25519Key,
                ed25519Key: ed25519Key,
                algorithms: [CryptoEngine.Algorithm.olm, CryptoEngine.Algorithm.megolm]
            ).save(db)
            try Device(
                id: "DEVICE_C",
                userID: "@UserC:kodeshack",
                curve25519Key: curve25519Key,
                ed25519Key: ed25519Key,
                algorithms: [CryptoEngine.Algorithm.olm, CryptoEngine.Algorithm.megolm]
            ).save(db)
        }

        let events: [(String, XCTestExpectation, CryptoEngine.CryptoEngineError?)] = [
            (constructImportantChecksPayload(senderID: "@UserB:kodeshack", deviceID: "DEVICE_B", ed25519Key: ed25519Key, recipientID: account.userID, recipientEd25519Key: account.identityKeys.ed25519, type: .message, content: PlainMessageJSON(body: "foo", type: .text)), nil),
            (constructImportantChecksPayload(senderID: "@UserB:kodeshack", deviceID: "DEVICE_UNKNOWN", ed25519Key: ed25519Key, recipientID: account.userID, recipientEd25519Key: account.identityKeys.ed25519, type: .message, content: PlainMessageJSON(body: "foo", type: .text)), CryptoEngine.CryptoEngineError.unknownDevice(deviceID: "DEVICE_UNKNOWN")),
            (constructImportantChecksPayload(senderID: "@UNKNOWN:kodeshack", deviceID: "DEVICE_B", ed25519Key: ed25519Key, recipientID: account.userID, recipientEd25519Key: account.identityKeys.ed25519, type: .message, content: PlainMessageJSON(body: "foo", type: .text)), CryptoEngine.CryptoEngineError.unknownDevice(deviceID: "DEVICE_B")),
            (constructImportantChecksPayload(senderID: "@UserC:kodeshack", deviceID: "DEVICE_C", ed25519Key: ed25519Key, recipientID: account.userID, recipientEd25519Key: account.identityKeys.ed25519, type: .message, content: PlainMessageJSON(body: "foo", type: .text)), CryptoEngine.CryptoEngineError.validationFailed(mismatch: "sender")),
            (constructImportantChecksPayload(senderID: "@UserB:kodeshack", deviceID: "DEVICE_B", ed25519Key: ed25519Key, recipientID: "@UNKNOWN:kodeshack", recipientEd25519Key: account.identityKeys.ed25519, type: .message, content: PlainMessageJSON(body: "foo", type: .text)), CryptoEngine.CryptoEngineError.validationFailed(mismatch: "recipientID")),
            (constructImportantChecksPayload(senderID: "@UserB:kodeshack", deviceID: "DEVICE_B", ed25519Key: "INVALID_KEY", recipientID: account.userID, recipientEd25519Key: account.identityKeys.ed25519, type: .message, content: PlainMessageJSON(body: "foo", type: .text)), CryptoEngine.CryptoEngineError.validationFailed(mismatch: "senderKeys")),
            (constructImportantChecksPayload(senderID: "@UserB:kodeshack", deviceID: "DEVICE_B", ed25519Key: ed25519Key, recipientID: account.userID, recipientEd25519Key: "INVALID_KEY", type: .message, content: PlainMessageJSON(body: "foo", type: .text)), CryptoEngine.CryptoEngineError.validationFailed(mismatch: "recipientKeys")),
        ].map { ($0.0, expectation(description: "\($0)"), $0.1) }

        try events.forEach { event in
            let (msgEvent, exp, error) = event

            let olmMessage = try olmSession.encryptMessage(msgEvent)
            let olmCiphertext = EncryptedJSON.OlmCiphertext(body: olmMessage.ciphertext, type: olmMessage.type)
            let event = EncryptedJSON(senderKey: curve25519Key, ciphertexts: [
                account.identityKeys.curve25519: olmCiphertext,
            ])
            let toDeviceEvent = SyncResponse.ToDeviceEvent(senderID: "@UserB:kodeshack", type: .encrypted, content: .encrypted(event))

            account.decrypt(toDeviceEvent: toDeviceEvent) { result in
                guard let error = error else {
                    XCTAssertNil(result.failure)
                    exp.fulfill()
                    return
                }

                XCTAssertEqual("\(result.failure!)", "\(error)")
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 2)
    }

    private func constructImportantChecksPayload(senderID: UserID, deviceID: DeviceID, ed25519Key: CryptoEngine.Ed25519Key, recipientID: UserID, recipientEd25519Key: CryptoEngine.Ed25519Key, type: Event.EventsType, content: JSONEncodable) -> String {
        """
        {
            "sender": "\(senderID)",
            "sender_device": "\(deviceID)",
            "keys": {
                "ed25519": "\(ed25519Key)"
            },
            "recipient": "\(recipientID)",
            "recipient_keys": {
                "ed25519": "\(recipientEd25519Key)"
            },
            "type": "\(type.rawValue)",
            "content": \(content.stringValue)
        }
        """
    }
}

private class CryptoEngineTestsDelegate: CryptoEngineDelegate {
    var errorCB: ((CryptoEngine, Error) -> Void)!
    var startedWorkCB: ((CryptoEngine) -> Void) = { _ in }
    var finishedWorkCB: ((CryptoEngine) -> Void) = { _ in }

    func handleError(_ sender: CryptoEngine, _ error: Error) {
        errorCB(sender, error)
    }

    func hasStartedWork(_ sender: CryptoEngine) {
        startedWorkCB(sender)
    }

    func hasFinishedWork(_ sender: CryptoEngine) {
        finishedWorkCB(sender)
    }
}
