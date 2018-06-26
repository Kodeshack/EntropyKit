import GRDB

struct CryptoBlob: FetchableRecord, PersistableRecord, Codable {
    static let databaseTableName = Database.v0.cryptoBlobs.table

    enum BlobType: UInt, Codable {
        case olmAccount
        case olmSession
        case inboundGroupSession
        case outboundGroupSession
    }

    let id: String
    let type: BlobType
    let blob: Data

    func unwrap<T>() throws -> T {
        return NSKeyedUnarchiver.unarchiveObject(with: blob) as! T
    }

    init(id: String, type: BlobType, data: NSSecureCoding) {
        self.id = id
        self.type = type
        blob = NSKeyedArchiver.archivedData(withRootObject: data)
    }
}
