@testable import EntropyKit
import XCTest

class FileMessageJSONTests: XCTestCase {
    func testParsing() throws {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "e2ee_image", withExtension: "json", subdirectory: "Fixtures") else {
            XCTFail()
            return
        }

        let data = try Data(contentsOf: url)
        let message = try FileMessageJSON.decode(data).get()

        XCTAssertEqual(message.info.thumbnailInfo?.mimetype, "image/png")
    }
}
