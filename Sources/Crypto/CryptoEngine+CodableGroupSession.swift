import Foundation
import OLMKit

/// Pls no touch. ¯\_(ツ)_/¯
extension CryptoEngine {
    @objc(CryptoEngine_CodableGroupSession)
    class CodableGroupSession: NSObject {
        enum CodableGroupSessionError: Error {
            case roomNotFound
        }

        fileprivate var remainingMessagesCount: Int
        fileprivate let validUntil: Date

        fileprivate enum CodingKeys: String {
            case session
            case remainingMessagesCount
            case validUnit
            case messageIndicies
            case forceRotation
        }

        /// The exact values when to rotate are not necessarily specified. When no values were sent,
        /// we use the values suggested in the guide.
        /// As a result, we can't (shouldn't) enforce the check in the inbound sessions, to guarantee
        /// compatability with other (less well behaved) clients.
        /// Cool kidz send their values 😎.
        var needsRotation: Bool {
            return remainingMessagesCount <= 0 || Date() > validUntil
        }

        init(remainingMessagesCount: Int, validUntil: Date) {
            self.remainingMessagesCount = remainingMessagesCount
            self.validUntil = validUntil
        }
    }

    @objc(CryptoEngine_InboundGroupSession)
    class InboundGroupSession: CodableGroupSession, NSSecureCoding {
        enum InboundGroupSessionErrors: Error {
            case possibleReplayAttackDetected
        }

        static var supportsSecureCoding = true

        private let session: OLMInboundGroupSession
        private var messageIndicies = [UInt]()
        private let lock = NSLock()

        required init?(coder aDecoder: NSCoder) {
            session = aDecoder.decodeObject(of: OLMInboundGroupSession.self, forKey: CodingKeys.session.rawValue)!
            messageIndicies = aDecoder.decodeObject(of: NSArray.self, forKey: CodingKeys.messageIndicies.rawValue)! as! [UInt]
            super.init(
                remainingMessagesCount: aDecoder.decodeInteger(forKey: CodingKeys.remainingMessagesCount.rawValue),
                validUntil: aDecoder.decodeObject(of: NSDate.self, forKey: CodingKeys.validUnit.rawValue)! as Date
            )
        }

        /// Waits for all other operations on this session to be completed before running.
        func encode(with aCoder: NSCoder) {
            lock.lock()
            defer { self.lock.unlock() }
            aCoder.encode(session, forKey: CodingKeys.session.rawValue)
            aCoder.encode(remainingMessagesCount, forKey: CodingKeys.remainingMessagesCount.rawValue)
            aCoder.encode(validUntil, forKey: CodingKeys.validUnit.rawValue)
            aCoder.encode(messageIndicies, forKey: CodingKeys.messageIndicies.rawValue)
        }

        init(session: OLMInboundGroupSession, roomID: String, database: Database) throws {
            let dbRoom = try database.dbQueue.inDatabase { db in
                try Room.fetchOne(db, sql: "SELECT * FROM \(Database.v0.rooms.table) WHERE \(Database.v0.rooms.id) = ?", arguments: [roomID])
            }

            guard let room = dbRoom else {
                throw CodableGroupSessionError.roomNotFound
            }

            self.session = session
            super.init(
                remainingMessagesCount: Int(room.rotationPeriodMessages!),
                validUntil: Date() + TimeInterval(room.rotationPeriodTime!)
            )
        }

        convenience init(sessionKey: String, roomID: String, database: Database) throws {
            let session = try OLMInboundGroupSession(inboundGroupSessionWithSessionKey: sessionKey)
            try self.init(session: session, roomID: roomID, database: database)
        }

        /// Also checks for possible replay attacks using the provided message indicies.
        /// Waits for all other operations on this session to be completed before running.
        func decryptMessage(_ message: String) throws -> String {
            lock.lock()
            defer { self.lock.unlock() }

            // We check the rotation and log if the session is due for rotation,
            // but not actually throw an error because the exact values when to rotate
            // are not necessarily specified. When no values were sent, we use the values suggested
            // in the guide.
            if needsRotation {
                // @TODO: proper logging
                print("Decrypting using an inbound sessions that should have been rotated.")
            }

            var index = UInt(0)
            let plaintext = try session.decryptMessage(message, messageIndex: &index)

            guard !messageIndicies.contains(index) else {
                throw InboundGroupSessionErrors.possibleReplayAttackDetected
            }

            messageIndicies.append(index)

            remainingMessagesCount -= 1
            return plaintext
        }
    }

    @objc(CryptoEngine_OutboundGroupSession)
    class OutboundGroupSession: CodableGroupSession, NSSecureCoding {
        enum OutboundGroupSessionError: Error {
            case needsRotation
        }

        static var supportsSecureCoding = true

        private let session: OLMOutboundGroupSession

        /// Do not set to false! This happens implicitly when this session is replaced by the new session.
        private var forceRotation: Bool {
            didSet {
                assert(forceRotation == true)
            }
        }

        private let lock = NSLock()

        var sessionIdentifier: String {
            return session.sessionIdentifier()
        }

        var sessionKey: String {
            return session.sessionKey()
        }

        var messageIndex: UInt {
            return self.session.messageIndex()
        }

        override var needsRotation: Bool {
            return super.needsRotation || forceRotation
        }

        /// Waits for all other operations on this session to be completed before running.
        func encryptMessage(_ message: String) throws -> String {
            lock.lock()
            defer { self.lock.unlock() }

            guard !needsRotation else {
                throw OutboundGroupSessionError.needsRotation
            }

            let ciphertext = try session.encryptMessage(message)
            remainingMessagesCount -= 1
            return ciphertext
        }

        /// Forces a rotation. Use this after a device was blocked or deleted.
        /// Waits for all other operations on this session to be completed before running.
        func invalidateSession() {
            lock.lock()
            defer { self.lock.unlock() }
            forceRotation = true
        }

        required init?(coder aDecoder: NSCoder) {
            session = aDecoder.decodeObject(of: OLMOutboundGroupSession.self, forKey: CodingKeys.session.rawValue)!
            forceRotation = aDecoder.decodeBool(forKey: CodingKeys.forceRotation.rawValue)
            super.init(
                remainingMessagesCount: aDecoder.decodeInteger(forKey: CodingKeys.remainingMessagesCount.rawValue),
                validUntil: aDecoder.decodeObject(of: NSDate.self, forKey: CodingKeys.validUnit.rawValue)! as Date
            )
        }

        /// Waits for all other operations on this session to be completed before running.
        func encode(with aCoder: NSCoder) {
            lock.lock()
            defer { self.lock.unlock() }
            aCoder.encode(session, forKey: CodingKeys.session.rawValue)
            aCoder.encode(forceRotation, forKey: CodingKeys.forceRotation.rawValue)
            aCoder.encode(remainingMessagesCount, forKey: CodingKeys.remainingMessagesCount.rawValue)
            aCoder.encode(validUntil, forKey: CodingKeys.validUnit.rawValue)
        }

        convenience init(roomID: RoomID, database: Database) throws {
            let olmSession = OLMOutboundGroupSession(outboundGroupSession: ())!
            try self.init(session: olmSession, roomID: roomID, database: database)
        }

        init(session: OLMOutboundGroupSession, roomID: RoomID, database: Database) throws {
            let dbRoom = try database.dbQueue.inDatabase { db in
                try Room.fetchOne(db, sql: "SELECT * FROM \(Database.v0.rooms.table) WHERE \(Database.v0.rooms.id) = ?", arguments: [roomID])
            }

            guard let room = dbRoom else {
                throw CodableGroupSessionError.roomNotFound
            }

            self.session = session
            forceRotation = false
            super.init(
                remainingMessagesCount: Int(room.rotationPeriodMessages!),
                validUntil: Date() + TimeInterval(room.rotationPeriodTime!)
            )
        }
    }
}
