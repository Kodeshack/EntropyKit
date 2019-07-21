import GRDB
import OLMKit

class Account: Record {
    let userID: UserID
    var user: User?
    let deviceID: DeviceID
    var nextBatch: String
    let accessToken: String

    private var transactionID: UInt
    private var cryptoEngine: CryptoEngine?
    private var olmAccount: OLMAccount

    var blob: CryptoBlob {
        return CryptoBlob(id: userID, type: .olmAccount, data: olmAccount)
    }

    init(userID: UserID, accessToken: String, deviceID: DeviceID, nextBatch: String, cryptoEngine: CryptoEngine? = nil) {
        self.userID = userID
        self.deviceID = deviceID
        self.nextBatch = nextBatch
        self.accessToken = accessToken
        transactionID = 0
        olmAccount = OLMAccount(newAccount: ())
        super.init()
        self.cryptoEngine = cryptoEngine
    }

    required init(row: Row) {
        userID = row[Database.v0.accounts.userID]
        deviceID = row[Database.v0.accounts.deviceID]
        nextBatch = row[Database.v0.accounts.nextBatch]
        accessToken = row[Database.v0.accounts.accessToken]
        transactionID = row[Database.v0.accounts.transactionID]
        olmAccount = OLMAccount()
        super.init(row: row)
        cryptoEngine = CryptoEngine()
    }

    convenience init(user: User, accessToken: String, deviceID: DeviceID, nextBatch: String, cryptoEngine: CryptoEngine? = nil) {
        self.init(userID: user.id, accessToken: accessToken, deviceID: deviceID, nextBatch: nextBatch, cryptoEngine: cryptoEngine)
        self.user = user
    }

    override class var databaseTableName: String {
        return Database.v0.accounts.table
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Database.v0.accounts.userID] = userID
        container[Database.v0.accounts.deviceID] = deviceID
        container[Database.v0.accounts.nextBatch] = nextBatch
        container[Database.v0.accounts.accessToken] = accessToken
        container[Database.v0.accounts.transactionID] = transactionID
    }

    func fetchUser(_ db: GRDB.Database) throws {
        user = try User.fetchOne(db, key: userID)
    }

    /// Get the next transaction id.
    ///
    /// The client-server API typically uses HTTP PUT to submit requests with a client-generated transaction identifier.
    /// This means that these requests are idempotent. The scope of a transaction identifier is a particular access token.
    /// It only serves to identify new requests from retransmits. After the request has finished, the transaction id value should be changed
    /// (how is not specified; a monotonically increasing integer is recommended).
    ///
    /// - Returns: The next transaction id to be used.
    func nextTransactionID() -> UInt {
        defer {
            transactionID += 1
        }
        return transactionID
    }

    override func update(_ db: GRDB.Database, columns: Set<String>) throws {
        try super.update(db, columns: columns)
        try cryptoEngine?.save(db)
    }
}

extension Account {
    static func create(userID: UserID, accessToken: String, deviceID: DeviceID, cryptoEngine: CryptoEngine? = nil, database: Database, update: @escaping (Account) -> Void = { _ in }) throws -> Account {
        let user = try User.create(id: userID, database: database)

        let account: Account
        if let dbAccount = try Account.load(user: user, database: database) {
            account = dbAccount
            account.setupCryptoEngine(database: database, load: true)
        } else {
            account = Account(user: user, accessToken: accessToken, deviceID: deviceID, nextBatch: "", cryptoEngine: cryptoEngine)
            account.setupCryptoEngine(database: database, load: false)
        }
        update(account)
        try account.save(database: database)
        return account
    }

    func update(database: Database, update: @escaping (Account) -> Void) throws {
        update(self)
        try save(database: database)
    }

    static func load(user: User, database: Database) throws -> Account? {
        var account: Account?
        try database.dbQueue.read { db in
            account = try Account.fetchOne(db, key: user.id)
            account?.user = user
        }
        account?.setupCryptoEngine(database: database, load: true)

        return account
    }

    func save(database: Database) throws {
        try database.dbQueue.write { db in
            try self.insert(db)
            try self.cryptoEngine?.save(db)
        }
        try user?.save(database: database)
    }
}

// MARK: OLMAccount Bridge

extension Account {
    /// This is kinda unswifty, but we require this to keep the olm account private and thus safe.
    func setOlmAccount(_ olmAccount: OLMAccount) {
        self.olmAccount = olmAccount
    }

    /// only returns the curve25519 keys
    private var oneTimeKeys: [String: String] {
        let allOneTimeKeys = olmAccount.oneTimeKeys() as! [String: [String: String]]

        defer {
            self.olmAccount.markOneTimeKeysAsPublished()
        }

        return allOneTimeKeys[CryptoEngine.CryptoKeys.curve25519.rawValue]!
    }

    var maxOneTimeKeyCount: UInt {
        return olmAccount.maxOneTimeKeys()
    }

    struct IdentityKeys {
        let curve25519: CryptoEngine.Curve25519Key
        let ed25519: CryptoEngine.Ed25519Key
    }

    var identityKeys: IdentityKeys {
        let identityKeys = olmAccount.identityKeys()
        return IdentityKeys(
            curve25519: identityKeys![CryptoEngine.CryptoKeys.curve25519.rawValue] as! CryptoEngine.Curve25519Key,
            ed25519: identityKeys![CryptoEngine.CryptoKeys.ed25519.rawValue] as! CryptoEngine.Ed25519Key
        )
    }

    func signature(for data: JSONEncodable) -> String {
        return olmAccount.signMessage(data.encoded)!
    }

    private func generateOneTimeKeys(numberOfKeys: Int) {
        olmAccount.generateOneTimeKeys(UInt(numberOfKeys))
    }

    /// Generate the correct amount of OTKs if necessary and return OTK Objects ready for uploading.
    func getOneTimeKeys(keyCountOnServer: UInt = 0) -> [String: KeysUploadRequest.OneTimeKeyObject] {
        let numKeysToUpload = (maxOneTimeKeyCount / 2) - keyCountOnServer
        let currentKeyCount = self.oneTimeKeys.count
        let numKeysToGenerate = Int(numKeysToUpload) - currentKeyCount
        if numKeysToGenerate > 0 {
            generateOneTimeKeys(numberOfKeys: numKeysToGenerate)
        }

        let oneTimeKeys = self.oneTimeKeys.map { item -> (String, KeysUploadRequest.OneTimeKeyObject) in
            let otkObj = KeysUploadRequest.OneTimeKeyObject(key: item.value, signUsing: self)
            return ("\(CryptoEngine.CryptoKeys.signedCurve25519.rawValue):\(item.key)", otkObj)
        }

        return Dictionary(uniqueKeysWithValues: oneTimeKeys)
    }
}

// MARK: OLM

extension Account {
    func createOLMSession(from body: String, with senderKey: CryptoEngine.Curve25519Key) -> Result<OLMSession, Error> {
        return Result {
            let session = try OLMSession(inboundSessionWith: self.olmAccount, theirIdentityKey: senderKey, oneTimeKeyMessage: body)
            self.olmAccount.removeOneTimeKeys(for: session)
            return session
        }
    }

    func createOLMSession(for identityKey: CryptoEngine.Curve25519Key, oneTimeKey: String) -> Result<OLMSession, Error> {
        return Result {
            try OLMSession(outboundSessionWith: self.olmAccount, theirIdentityKey: identityKey, theirOneTimeKey: oneTimeKey)
        }
    }
}

// MARK: crypto api

extension Account {
    /// Call this function after initialization of the `Account` to setup its `CryptoEngine`.
    func setupCryptoEngine(database: Database, load: Bool) {
        cryptoEngine?.setup(account: self, db: database, load: load)
    }

    func encrypt(event: Event, in roomID: String, completionHandler: @escaping (Result<Event, Error>) -> Void) {
        cryptoEngine?.enqueue(.event(event: event, roomID: roomID, cb: completionHandler))
    }

    func decrypt(event: Event, completionHandler: @escaping (Result<Event, Error>) -> Void) {
        cryptoEngine?.enqueue(.encryptedEvent(event: event, roomID: event.roomID!, cb: completionHandler))
    }

    func decrypt(toDeviceEvent: SyncResponse.ToDeviceEvent, completionHandler: @escaping (Result<SyncResponse.ToDeviceEvent, Error>) -> Void) {
        cryptoEngine?.enqueue(.encryptedToDeviceEvent(event: toDeviceEvent, cb: completionHandler))
    }

    func roomKeyEvent(event: SyncResponse.ToDeviceEvent) {
        cryptoEngine?.enqueue(.roomKeyEvent(event: event))
    }

    func devicesChanged(userIDs: [String]) {
        cryptoEngine?.enqueue(.devicesChanged(userIDs: userIDs))
    }

    func memberChange(userID: String, change: MemberJSON.Membership) {
        cryptoEngine?.enqueue(.memberChange(userID: userID, change: change))
    }

    func updateOTKCount(_ count: UInt) {
        cryptoEngine?.enqueue(.otkCountUpdate(count))
    }
}
