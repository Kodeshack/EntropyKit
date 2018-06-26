@testable import EntropyKit
import OLMKit
import XCTest

class CryptoEngine_CodableGroupSessionTests: XCTestCase {
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

    /// Security relevant test
    func testReplayAttack() throws {
        let room = try Room.create(id: "roomID", database: database, update: { room in
            room.encrypted = true
            room.rotationPeriodTime = 100
            room.rotationPeriodMessages = 50
        })

        let outboundSession = try CryptoEngine.OutboundGroupSession(session: OLMOutboundGroupSession(outboundGroupSession: ()), roomID: room.id, database: database)
        let inboundSession = try CryptoEngine.InboundGroupSession(sessionKey: outboundSession.sessionKey, roomID: room.id, database: database)

        let message = try outboundSession.encryptMessage("foo")

        XCTAssertEqual(try inboundSession.decryptMessage(message), "foo")

        XCTAssertThrowsError(try inboundSession.decryptMessage(message), "possibleReplayAttackDetected") { error in
            XCTAssertEqual(error as! CryptoEngine.InboundGroupSession.InboundGroupSessionErrors, .possibleReplayAttackDetected)
        }

        XCTAssertThrowsError(try inboundSession.decryptMessage(message), "possibleReplayAttackDetected") { error in
            XCTAssertEqual(error as! CryptoEngine.InboundGroupSession.InboundGroupSessionErrors, .possibleReplayAttackDetected)
        }
    }

    /// Security relevant test
    func testRotationMessageCount() throws {
        let room = try Room.create(id: "roomID", database: database, update: { room in
            room.encrypted = true
            room.rotationPeriodTime = 100
            room.rotationPeriodMessages = 2
        })

        let outboundSession = try CryptoEngine.OutboundGroupSession(session: OLMOutboundGroupSession(outboundGroupSession: ()), roomID: room.id, database: database)
        let inboundSession = try CryptoEngine.InboundGroupSession(sessionKey: outboundSession.sessionKey, roomID: room.id, database: database)

        let message1 = try outboundSession.encryptMessage("message 1")
        let message2 = try outboundSession.encryptMessage("message 2")

        XCTAssertEqual(try inboundSession.decryptMessage(message1), "message 1")
        XCTAssertEqual(try inboundSession.decryptMessage(message2), "message 2")

        XCTAssertTrue(inboundSession.needsRotation)
        XCTAssertTrue(outboundSession.needsRotation)
        XCTAssertThrowsError(try outboundSession.encryptMessage("message 3"), "needsRotation") { error in
            XCTAssertEqual(error as! CryptoEngine.OutboundGroupSession.OutboundGroupSessionError, .needsRotation)
        }
    }

    /// Security relevant test
    func testRotationValidUntil() throws {
        let room = try Room.create(id: "roomID", database: database, update: { room in
            room.encrypted = true
            room.rotationPeriodTime = 0
            room.rotationPeriodMessages = 50
        })

        let outboundSession = try CryptoEngine.OutboundGroupSession(session: OLMOutboundGroupSession(outboundGroupSession: ()), roomID: room.id, database: database)

        XCTAssertTrue(outboundSession.needsRotation)
        XCTAssertThrowsError(try outboundSession.encryptMessage("message 1"), "needsRotation") { error in
            XCTAssertEqual(error as! CryptoEngine.OutboundGroupSession.OutboundGroupSessionError, .needsRotation)
        }
    }
}
