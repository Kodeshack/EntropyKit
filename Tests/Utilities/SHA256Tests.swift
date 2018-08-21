@testable import EntropyKit
import XCTest

class SHA256Tests: XCTestCase {
    func testDigest() throws {
        var plaintext = "SHA256TEST".data(using: .ascii)!
        let expectedHash = Data(base64Encoded: "uUTAelcg9Uk4VdTU5wN91pO3CiQQsIqahuDs+S62QcM=")

        let hasher = SHA256()

        try plaintext.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) throws -> Void in
            hasher.update(data: bytes, length: plaintext.count)
        }

        let computedHash = hasher.finalize()

        XCTAssertEqual(expectedHash, computedHash)
    }
}
