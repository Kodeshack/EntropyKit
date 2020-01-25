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

    func unwrap<T: NSObject & NSCoding>() throws -> T {
        try! NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: blob)!
    }

    init(id: String, type: BlobType, data: NSSecureCoding) {
        self.id = id
        self.type = type
        blob = try! NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: true)
    }
}
