@testable import EntropyKit
import OHHTTPStubs
import XCTest

class AttachmentTests: XCTestCase {
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

    // make sure we correctly save the data to the DB and it's retrievable
    func testSaveAndLoadBytes() throws {
        let room = Room(id: "bobsroom")
        let user = User(id: "bob")

        let data = try Data(contentsOf: URL(fileURLWithPath: OHPathForFile("Fixtures/testimage.png", type(of: self))!))
        let encryptedData = "LgyZH4o2wqxw59Ggb0foZHSq3X7rTrs/1bvgl9SPAPxfxy+ecZbP1pxjahiWG9IJoMulxCxAN2zTiNPEF0I+8oIJXNRXH9rxHT4hBYBQONrH/w=="
        let keyData = Data(base64Encoded: "8FkpNeWfP6LQKBnW6tjSxKBathYSwhOavJlGMRnbJNk=")!
        let iv = Base64URL(base64: "CtzULW+iHPYAAAAAAAAAAA==")!

        let info = FileMessageJSON.Info(width: 1, height: 1, size: UInt(data.count), mimeType: "image/png", thumbnailInfo: nil, thumbnailFile: nil)
        let hashes = EncryptedAttachment.EncryptedAttachmentHashes(sha256: "2fUCPPLmL+YDkSosqHJaW1SLOLBK2VDS47UuwYxCZ2w")
        let key = EncryptedAttachment.EncryptedAttachmentKey.v2KeyInfo(key: keyData)
        let file = EncryptedAttachment(version: .v2, mxcURL: URL(string: "mxc://testimage.png")!, mimeType: "image/png", size: data.count, iv: iv, key: key, hashes: hashes)

        let fileMessageJSON = FileMessageJSON(type: .file, filename: "testimage.png", info: info, file: file)
        let event = Event(id: "testimage.png", senderID: user.id, type: .message, date: Date(), roomID: room.id, content: .fileMessage(fileMessageJSON))

        let message = Message(event: event)

        let attachment = Attachment(event: event)
        XCTAssertNotNil(attachment)

        try database.dbQueue.write { db in
            try room.save(db)
            try user.save(db)
            try message.save(db)
            try attachment?.save(db)
        }

        let dbAttachment = try database.dbQueue.read { db in
            try Attachment.fetchOne(db, key: "testimage.png")
        }
        XCTAssertNotNil(dbAttachment)

        let decrypted = try AttachmentEncryption.decrypt(ciphertext: Data(base64Encoded: encryptedData)!, info: dbAttachment!.info.cryptoInfo!).get()

        XCTAssertEqual(data, decrypted)
    }
}
