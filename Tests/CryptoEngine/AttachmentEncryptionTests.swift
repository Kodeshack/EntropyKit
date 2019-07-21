@testable import EntropyKit
import OHHTTPStubs
import XCTest

class AttachmentEncryptionTests: XCTestCase {
    func testEncrypt() {
        let file = try! Data(contentsOf: URL(fileURLWithPath: OHPathForFile("Fixtures/testimage.png", type(of: self))!))

        let encryptedAttachment = try! AttachmentEncryption.encrypt(plainData: file, mimeType: "image/png").get()

        XCTAssertNotEqual(file, encryptedAttachment.ciphertext)

        let attachmentCryptoInfo = Attachment.Info.CryptoInfo(for: encryptedAttachment.info)
        let decryptedData = try! AttachmentEncryption.decrypt(ciphertext: encryptedAttachment.ciphertext, info: attachmentCryptoInfo).get()

        XCTAssertNotEqual(encryptedAttachment.ciphertext, decryptedData)
        XCTAssertEqual(file.base64EncodedString(), decryptedData.base64EncodedString())
    }
}
