import Foundation
import GRDB
import OLMKit

class CryptoEngine {
    enum Algorithm: String, Codable {
        case olm = "m.olm.v1.curve25519-aes-sha2"
        case megolm = "m.megolm.v1.aes-sha2"
    }

    enum CryptoKeys: String, Codable {
        case curve25519
        case signedCurve25519 = "signed_curve25519"
        case ed25519
    }

    typealias Curve25519Key = String
    typealias Ed25519Key = String

    private let dispatchQueue: DispatchQueue
    private let backgroundQueue: DispatchQueue
    private var queue: Deque<CryptoEngineTask>
    private var account: Account!
    private var e2eeService: E2EEService!
    private var database: Database!

    private var state: State

    weak var delegate: CryptoEngineDelegate?

    // MARK: OLM properties

    private var olmSessions = ThreadSafeDictionary<Curve25519Key, OLMSession>()
    private var megolmInboundSessions = ThreadSafeDictionary<String, InboundGroupSession>()

    // MARK: Megolm properties

    private var megolmOutboundSessions = ThreadSafeDictionary<String, OutboundGroupSession>()

    init() {
        state = .uninitialised
        queue = Deque()
        dispatchQueue = DispatchQueue(label: "CryptoEngine", qos: .userInitiated)
        backgroundQueue = DispatchQueue(label: "CryptoEngineBackground", qos: .userInitiated)
    }

    func setup(account: Account, db: Database, load: Bool) {
        self.account = account
        e2eeService = E2EEService(database: db)
        database = db
        dispatchQueue.async {
            if load {
                self.queue.enqueue(.load(db: db))
            } else {
                self.queue.enqueue(.createAccount)
            }
            self.run()
        }
    }

    enum CryptoEngineError: Error {
        case invalidTransition(State, Transition)
        case invalidTask(State, CryptoEngineTask)
        case olmSessionNotFound(senderKey: CryptoEngine.Curve25519Key)
        case couldNotCreateOLMMessage
        case inboundMegOLMSessionNotFound(sessionID: String)
        case outboundMegOLMSessionNotFound(senderKey: CryptoEngine.Curve25519Key)
        case invalidRoomKeyEvent(SyncResponse.ToDeviceEvent)
        case noMessageForMe
        case validationFailed(mismatch: String)
        case unknownDevice(deviceID: DeviceID)
        case triedToDecryptUnecryptedEvent
        case invalidToDeviceEvent(SyncResponse.ToDeviceEvent)
    }

    private func run() {
        #if DEBUG
            DispatchQueue.main.async { // must be async, else deadlock
                self.delegate?.hasStartedWork(self)
            }
        #endif

        while let input = queue.dequeue() {
            if let transition = nextTransition(input: input) {
                // @TODO: proper logging:
                // print("\(state) -> \(transition)")
                let (nextState, ouput) = transition.exec()
                queue.enqueueFront(ouput)
                state = nextState
            } else {
                assert(state == .ready || state == .fatalError)
            }
        }

        #if DEBUG
            DispatchQueue.main.async { // must be async, else deadlock
                self.delegate?.hasFinishedWork(self)
            }
        #endif

        assert(state == .ready || state == .fatalError)
    }

    private func nextTransition(input: CryptoEngineTask) -> Transition? {
        switch (state, input) {
        case (.uninitialised, .createAccount): return .createAccount(createAccount)
        case let (.uninitialised, .load(db)): return .load(db, load)

        case (.accountCreated, .none): return .uploadPublicAndOTKs(uploadPublicAndOTKs)

        case let (.uploadedPublicAndOTKs, .devicesChanged(userIDs)): return .devicesChanged(userIDs, devicesChanged)

        case (.ready, .none): return nil
        case let (.ready, .event(event, roomID, cb)): return .encrypt((event, roomID, cb), encrypt)
        case let (.ready, .encryptedEvent(event, roomID, cb)): return .decrypt((event, roomID, cb), decrypt)
        case let (.ready, .encryptedToDeviceEvent(event, cb)): return .decryptToDeviceEvent((event, cb), decryptToDeviceEvent)
        case let (.ready, .roomKeyEvent(event)): return .roomKey(event, roomKey)
        case let (.ready, .devicesChanged(userIDs)): return .devicesChanged(userIDs, devicesChanged)
        case let (.ready, .memberChange(userID, change)): return .memberChange((userID, change), memberChange)
        case let (.ready, .otkCountUpdate(newCount)): return .otkCountChange(newCount, otkCountChange)

        case let (.needToEncrypt, .event(event, roomID, cb)): return .encryptEvent((event, roomID, cb), encryptEvent)
        case let (.needToEncrypt, .announceSession(roomID)): return .claimDeviceOTKs(roomID, claimDeviceOTKs)

        case let (.claimedDeviceOTKs, .roomID(roomID)): return .createOutboundMegOLMSession(roomID, createOutboundMegOLMSession)
        case let (.createdOutboundMegOLMSession, .roomID(roomID)): return .publishOutboundMegOLMSession(roomID, publishOutboundMegOLMSession)

        case (.fatalError, _): return nil

        // This should not happen
        case (.accountCreated, _): return .fatalError(CryptoEngineError.invalidTask(state, input), error)
        case (.claimedDeviceOTKs, _): return .fatalError(CryptoEngineError.invalidTask(state, input), error)
        case (.createdOutboundMegOLMSession, _): return .fatalError(CryptoEngineError.invalidTask(state, input), error)
        case (.needToEncrypt, _): return .fatalError(CryptoEngineError.invalidTask(state, input), error)
        case (.ready, _): return .fatalError(CryptoEngineError.invalidTask(state, input), error)
        case (.uninitialised, _): return .fatalError(CryptoEngineError.invalidTask(state, input), error)
        case (.uploadedPublicAndOTKs, _): return .fatalError(CryptoEngineError.invalidTask(state, input), error)
        }
    }

    /// Must/should no be called from within the crypto engine.
    func enqueue(_ task: CryptoEngineTask) {
        dispatchQueue.async {
            let needsWakeUp = self.queue.isEmpty
            self.queue.enqueue(task)

            // this will be true even if we're still handling an item
            // that was popped but not yet fully dealt with...
            // maybe check the current state, or check if currently in an transition
            if needsWakeUp, self.state == .ready {
                self.run()
            }
        }
    }

    private func notifyDelegate(_ error: Error) {
        DispatchQueue.main.async {
            self.delegate?.handleError(self, error)
        }
    }
}

extension CryptoEngine {
    private func error(_: Error) -> State {
        // @TODO: Log this shit!
        return .fatalError
    }
}

extension CryptoEngine {
    private func createAccount() -> State {
        DispatchQueue.main.sync {
            self.account.setOlmAccount(OLMAccount(newAccount: ()))
        }
        return .accountCreated
    }
}

extension CryptoEngine {
    private func uploadPublicAndOTKs() -> (State, CryptoEngineTask) {
        var identityKeys: Account.IdentityKeys?
        var deviceID: DeviceID?
        var otk: [String: KeysUploadRequest.OneTimeKeyObject]?

        DispatchQueue.main.sync {
            identityKeys = self.account.identityKeys
            deviceID = self.account.deviceID
            otk = self.account.getOneTimeKeys()
        }

        let deviceKeys = KeysUploadRequest.DeviceKeys(
            account: account,
            algorithms: [.olm, .megolm],
            keys: [
                "\(CryptoKeys.curve25519):\(deviceID!)": identityKeys!.curve25519,
                "\(CryptoKeys.ed25519):\(deviceID!)": identityKeys!.ed25519,
            ]
        )
        let keysUploadRequest = KeysUploadRequest(deviceKeys: deviceKeys, oneTimeKeys: otk!)

        let sem = DispatchSemaphore(value: 0)
        var retVal: (State, CryptoEngineTask)!
        e2eeService.uploadKeys(account: account, request: keysUploadRequest, queue: backgroundQueue) { result in
            defer { sem.signal() }
            guard result.isValue else {
                retVal = (.fatalError, .error(result.error!))
                self.notifyDelegate(result.error!)
                return
            }

            retVal = (.uploadedPublicAndOTKs, .devicesChanged(userIDs: []))
        }
        sem.wait()
        return retVal
    }
}

extension CryptoEngine {
    /// Load all the blobs!
    private func load(db: Database) -> (State, CryptoEngineTask) {
        do {
            try db.dbQueue.inDatabase { db in
                let blobs = try CryptoBlob.fetchAll(db)

                try blobs.forEach { blob in
                    switch blob.type {
                    case .olmAccount:
                        self.account.setOlmAccount(try blob.unwrap())
                    case .olmSession:
                        self.olmSessions[blob.id] = try blob.unwrap()
                    case .inboundGroupSession:
                        let session: InboundGroupSession = try blob.unwrap()
                        self.megolmInboundSessions[blob.id] = session
                        if session.needsRotation {
                            try blob.delete(db)
                        }
                    case .outboundGroupSession:
                        self.megolmOutboundSessions[blob.id] = try blob.unwrap()
                    }
                }
            }
        } catch {
            return (.fatalError, .error(error))
        }
        return (.ready, .none)
    }

    func save(_ db: GRDB.Database) throws {
        try account.blob.save(db)

        try olmSessions.forEach { sessionItem in
            try CryptoBlob(id: sessionItem.key, type: .olmSession, data: sessionItem.value).save(db)
        }

        try megolmInboundSessions.forEach { mois in
            try CryptoBlob(id: mois.key, type: .inboundGroupSession, data: mois.value).save(db)
        }

        try megolmOutboundSessions.forEach { moos in
            try CryptoBlob(id: moos.key, type: .outboundGroupSession, data: moos.value).save(db)
        }
    }
}

extension CryptoEngine {
    private func encrypt(task: (event: Event, roomID: RoomID, cb: (Result<Event>) -> Void)) -> (State, CryptoEngineTask) {
        if let session = self.megolmOutboundSessions[task.roomID], !session.needsRotation {
            return (.needToEncrypt, .event(event: task.event, roomID: task.roomID, cb: task.cb))
        } else {
            // requeue the event to be decrypted "later". To keep the flow of the automata clean.
            queue.enqueueFront(.event(event: task.event, roomID: task.roomID, cb: task.cb))
            return (.needToEncrypt, .announceSession(roomID: task.roomID))
        }
    }
}

extension CryptoEngine {
    private func fetchNonBlockedDevicesAndOTK(roomID: RoomID) -> Result<[DeviceID: Device]> {
        return Result {
            let devices = try e2eeService.fetchNonBlockedDevices(for: roomID, without: account.deviceID).dematerialize()

            let sessions = olmSessions.keys

            return Dictionary(uniqueKeysWithValues:
                devices
                    .filter { $0.id != account.deviceID }
                    .filter { !sessions.contains($0.curve25519Key!) } // ignore if we already have a session
                    .map { device in (device.id, device) })
        }
    }

    private func sessionData(from oneTimeKeys: KeysClaimResponse, using devicesByID: [DeviceID: Device]) -> [(curve25519Key: Curve25519Key, oneTimeKey: String)] {
        return oneTimeKeys.oneTimeKeys.flatMap { userDevices in
            userDevices.value.compactMap { deviceItem in
                guard let deviceOneTimeKey = deviceItem.value.first?.value else {
                    return nil
                }

                guard
                    let device = devicesByID[deviceItem.key],
                    deviceOneTimeKey.validate(deviceID: deviceItem.key, userID: device.userID, ed25519Key: device.ed25519Key!)
                else {
                    // @TODO: logging?
                    return nil
                }

                return (curve25519Key: device.curve25519Key!, oneTimeKey: deviceOneTimeKey.key)
            }
        }
    }

    private func claimDeviceOTKs(roomID: RoomID) -> (State, CryptoEngineTask) {
        let deviceFetchResult = fetchNonBlockedDevicesAndOTK(roomID: roomID)
        guard let devicesByID = deviceFetchResult.value else {
            notifyDelegate(deviceFetchResult.error!)
            return (.ready, .none)
        }

        let sem = DispatchSemaphore(value: 0)
        var retVal: (State, CryptoEngineTask)!

        let keyClaimRequest = KeysClaimRequest(devices: devicesByID.values.map { $0 })
        MatrixAPI.default.claimKeys(accessToken: account.accessToken, keysClaimRequest: keyClaimRequest, queue: backgroundQueue) { result in
            defer { sem.signal() }
            guard let oneTimeKeys = result.value else {
                retVal = (.fatalError, .error(result.error!))
                return
            }

            let sessionData = self.sessionData(from: oneTimeKeys, using: devicesByID)

            var newSessions: [(curve25519Key: Curve25519Key, sessionResult: Result<OLMSession>)]!
            DispatchQueue.main.sync {
                newSessions = sessionData.map { (curve25519Key: $0.curve25519Key, sessionResult: self.account.createOLMSession(for: $0.curve25519Key, oneTimeKey: $0.oneTimeKey)) }
            }

            newSessions.compactMap { newSession -> (curve25519Key: Curve25519Key, session: OLMSession)? in
                if let error = newSession.sessionResult.error {
                    print(error)
                    self.notifyDelegate(error)
                    return nil
                }
                return (curve25519Key: newSession.curve25519Key, session: newSession.sessionResult.value!)
            }.forEach { newSession in
                self.olmSessions[newSession.curve25519Key] = newSession.session
            }

            retVal = (.claimedDeviceOTKs, .roomID(roomID))
        }
        sem.wait()
        return retVal
    }
}

extension CryptoEngine {
    private func createOutboundMegOLMSession(roomID: RoomID) -> (State, CryptoEngineTask) {
        let senderKey = account.identityKeys.curve25519

        let session: OutboundGroupSession
        do {
            session = try OutboundGroupSession(roomID: roomID, database: database)
        } catch {
            // @TODO: proper logging
            print(error)
            notifyDelegate(error)
            return (.ready, .none)
        }

        megolmOutboundSessions[roomID] = session

        do {
            // It should store these details as an inbound session, just as it would when receiving them via an m.room_key event.
            try createInboundGroupSession(roomID: roomID, senderKey: senderKey, sessionID: session.sessionIdentifier, sessionKey: session.sessionKey)
        } catch {
            // @TODO: proper logging
            print(error)
            notifyDelegate(error)
            return (.ready, .none)
        }

        return (.createdOutboundMegOLMSession, .roomID(roomID))
    }

    private func createInboundGroupSession(roomID: String, senderKey: String, sessionID: String, sessionKey: String) throws {
        let megolmSessionIdentifier = roomID + senderKey + sessionID
        megolmInboundSessions[megolmSessionIdentifier] = try InboundGroupSession(sessionKey: sessionKey, roomID: roomID, database: database)
    }
}

extension CryptoEngine {
    private func publishOutboundMegOLMSession(roomID: String) -> State {
        let session = megolmOutboundSessions[roomID]!

        // @TODO: this is a little hacky
        let olmEncrypt = { (text: String, senderKey: CryptoEngine.Curve25519Key) -> (String, OLMMessageType)? in
            guard let session = self.olmSessions[senderKey] else {
                // @TODO: error handling/logging
                // This is not critical, some devices do not have enough OTKs so this is kinda expected
                print("OLMSessionNotFound(\(senderKey))")
                return nil
            }

            do {
                let msg = try session.encryptMessage(text)
                return (msg.ciphertext, msg.type)
            } catch {
                // @TODO: proper logging
                print(error)
                self.notifyDelegate(error)
                return nil
            }
        }

        let sem = DispatchSemaphore(value: 0)
        let sessionInfo = E2EEService.SessionInfo(roomID: roomID, session: session)
        e2eeService.publishGroupSessionKeys(for: account, sessionInfo: sessionInfo, olmEncrypt: olmEncrypt, queue: backgroundQueue) { result in
            defer { sem.signal() }
            if let error = result.error {
                // @TODO: proper logging
                print(error)
                self.notifyDelegate(error)
            }
        }
        sem.wait()
        return .ready
    }
}

extension CryptoEngine {
    private func encryptEvent(task: (event: Event, roomID: String, cb: (Result<Event>) -> Void)) -> State {
        task.cb(Result {
            let session = self.megolmOutboundSessions[task.roomID]!
            let ciphertext = try session.encryptMessage(task.event.stringValue)

            let encryptedJSON = EncryptedJSON(
                senderKey: self.account.identityKeys.curve25519,
                ciphertext: ciphertext,
                sessionID: session.sessionIdentifier,
                deviceID: self.account.deviceID
            )

            return Event(
                senderID: self.account.userID,
                type: .encrypted,
                roomID: task.roomID,
                content: .encrypted(encryptedJSON)
            )
        })
        return .ready
    }
}

extension CryptoEngine {
    private func decrypt(task: (event: Event, roomID: String, cb: (Result<Event>) -> Void)) -> State {
        let event = task.event

        guard let encryptedContent = event.content.encrypted else {
            task.cb(.Error(CryptoEngineError.triedToDecryptUnecryptedEvent))
            return .ready
        }
        guard encryptedContent.algorithm == .megolm else {
            fatalError("Found OLM Event, not good!")
        }

        let result = Result<Event> {
            let senderKey = encryptedContent.senderKey
            let sessionID = encryptedContent.sessionID!
            let ciphertext = encryptedContent.ciphertext.megolmCiphertext!

            let megolmSessionIdentifier = task.roomID + senderKey + sessionID

            guard let session = self.megolmInboundSessions[megolmSessionIdentifier] else {
                throw CryptoEngine.CryptoEngineError.inboundMegOLMSessionNotFound(sessionID: sessionID)
            }

            let json = try session.decryptMessage(ciphertext)

            var decryptedEvent = try Event.decode(json.data(using: .utf8)).dematerialize()
            decryptedEvent.id = event.id
            decryptedEvent.date = event.date
            decryptedEvent.senderID = event.senderID

            return decryptedEvent
        }

        task.cb(result)
        return .ready
    }

    private func decryptOLMJSON(encryptedContent: EncryptedJSON) -> Result<String> {
        let curve25519Key = account.identityKeys.curve25519
        guard let ciphertext = encryptedContent.ciphertext.olmCiphertext?[curve25519Key] else {
            return .Error(CryptoEngine.CryptoEngineError.noMessageForMe)
        }

        return Result {
            let type = ciphertext.type
            let body = ciphertext.body
            let senderKey = encryptedContent.senderKey

            if type == .preKey {
                if let session = self.olmSessions[encryptedContent.senderKey] {
                    if !session.matchesInboundSession(from: senderKey, oneTimeKeyMessage: body) {
                        self.olmSessions[senderKey] = try account.createOLMSession(from: body, with: senderKey).dematerialize()
                    }
                } else {
                    self.olmSessions[senderKey] = try account.createOLMSession(from: body, with: senderKey).dematerialize()
                }
            }

            guard let session = self.olmSessions[senderKey] else {
                throw CryptoEngine.CryptoEngineError.olmSessionNotFound(senderKey: senderKey)
            }

            guard let message = OLMMessage(ciphertext: body, type: type) else {
                throw CryptoEngine.CryptoEngineError.couldNotCreateOLMMessage
            }

            return try session.decryptMessage(message)
        }
    }

    private func decryptToDeviceEvent(task: (event: SyncResponse.ToDeviceEvent, cb: (Result<SyncResponse.ToDeviceEvent>) -> Void)) -> State {
        let event = task.event

        task.cb(Result {
            guard let encryptedContent = event.content.encrypted else {
                throw CryptoEngine.CryptoEngineError.invalidToDeviceEvent(event)
            }

            let json = try self.decryptOLMJSON(encryptedContent: encryptedContent).dematerialize()

            let cryptoInfo = try OLMCryptoInfo.decode(json.data(using: .utf8)).dematerialize()

            // very important checks
            guard let senderDevice = try Device.fetchOne(userID: cryptoInfo.senderID, deviceID: cryptoInfo.senderDeviceID, database: self.database).dematerialize() else { throw CryptoEngineError.unknownDevice(deviceID: cryptoInfo.senderDeviceID) }
            guard cryptoInfo.senderID == event.senderID else { throw CryptoEngineError.validationFailed(mismatch: "sender") }
            guard cryptoInfo.recipientID == account.userID else { throw CryptoEngineError.validationFailed(mismatch: "recipientID") }
            guard cryptoInfo.keys[CryptoKeys.ed25519.rawValue] == senderDevice.ed25519Key else { throw CryptoEngineError.validationFailed(mismatch: "senderKeys") }
            guard cryptoInfo.recipientKeys[CryptoKeys.ed25519.rawValue] == account.identityKeys.ed25519 else { throw CryptoEngineError.validationFailed(mismatch: "recipientKeys") }

            var decryptedEvent = try SyncResponse.ToDeviceEvent.decode(json.data(using: .utf8)).dematerialize()
            decryptedEvent.senderKey = encryptedContent.senderKey
            return decryptedEvent
        })
        return .ready
    }

    private struct OLMCryptoInfo: JSONDecodable {
        let senderID: UserID
        let senderDeviceID: DeviceID
        let keys: [String: String]
        let recipientID: UserID
        let recipientKeys: [String: String]

        private enum CodingKeys: String, CodingKey {
            case senderID = "sender"
            case senderDeviceID = "sender_device"
            case keys
            case recipientID = "recipient"
            case recipientKeys = "recipient_keys"
        }
    }
}

extension CryptoEngine {
    private func roomKey(event: SyncResponse.ToDeviceEvent) -> State {
        do {
            guard let roomKeyData = event.content.roomKey else {
                throw CryptoEngine.CryptoEngineError.invalidRoomKeyEvent(event)
            }

            try createInboundGroupSession(roomID: roomKeyData.roomID, senderKey: event.senderKey!, sessionID: roomKeyData.sessionID, sessionKey: roomKeyData.sessionKey)
        } catch {
            // @TODO: proper logging
            print(error)
            notifyDelegate(error)
        }

        return .ready
    }
}

extension CryptoEngine {
    private func devicesChanged(userIDs: [UserID]) -> State {
        let sem = DispatchSemaphore(value: 0)

        var nextState: State!
        e2eeService.getDevices(account: account, userIDs: userIDs, queue: backgroundQueue) { result in
            defer { sem.signal() }
            if let error = result.error {
                // @TODO: proper logging
                print(error)
                self.notifyDelegate(error)
                nextState = .ready
                return
            }

            // @TODO
            // This is less than efficient...
            // What we should be doing here is checking:
            // 1. if a device has been deleted, rotate the corresponding room outbound sessions
            // 2. if a device was added, send it the existing outbound session keys
            // See https://github.com/Kodeshack/EntropyKit/issues/1
            self.megolmOutboundSessions.forEach { _, session in
                session.invalidateSession()
            }

            nextState = .ready
        }

        sem.wait()
        return nextState
    }
}

extension CryptoEngine {
    private func otkCountChange(count: UInt) -> State {
        var otkObjects: [String: KeysUploadRequest.OneTimeKeyObject]?
        DispatchQueue.main.sync {
            otkObjects = self.account.getOneTimeKeys(keyCountOnServer: count)
        }

        guard let otkos = otkObjects, !otkos.isEmpty else {
            return .ready
        }

        let sem = DispatchSemaphore(value: 0)
        let keysUploadRequest = KeysUploadRequest(deviceKeys: nil, oneTimeKeys: otkObjects)
        e2eeService.uploadKeys(account: account, request: keysUploadRequest, queue: backgroundQueue) { result in
            defer { sem.signal() }
            if let error = result.error {
                // @TODO: proper logging
                print(error)
                self.notifyDelegate(error)
            }
        }
        sem.wait()
        return .ready
    }
}

extension CryptoEngine {
    private func memberChange(task: (userID: UserID, change: MemberJSON.Membership)) -> (State, CryptoEngineTask) {
        switch task.change {
        case .join:
            return (.ready, .devicesChanged(userIDs: [task.userID]))
        case .ban, .leave:
            // @TODO: Rotate only sessions with this user.
            rotateSessions()
            return (.ready, .none)
        case .invite, .knock:
            return (.ready, .none)
        }
    }

    private func rotateSessions() {
        megolmOutboundSessions.forEach { _, session in
            session.invalidateSession()
        }
    }
}
