@testable import EntropyKit
import OHHTTPStubs
import XCTest

class ImageServiceTests: XCTestCase {
    private var database: Database!
    private var dbPath: URL!

    override func setUp() {
        super.setUp()
        dbPath = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(type(of: self)).sqlite")
        database = try! Database(path: dbPath)
        MatrixAPI.default.baseURL = "https://entropy.kodeshack.com"
    }

    override func tearDown() {
        try! FileManager.default.removeItem(at: dbPath)
        OHHTTPStubs.removeAllStubs()
        super.tearDown()
    }

    func testLoadImage() {
        let exp = expectation(description: "avatar request")

        stub(condition: pathStartsWith("/_matrix/media/")) { _ in
            OHHTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/testimage.png", type(of: self))!,
                statusCode: 200,
                headers: nil
            )
        }

        ImageService.loadImage(mxcURL: URL(string: "mxc://genericPopCultureReference")!) { result in
            XCTAssertNil(result.error)
            XCTAssertNotNil(result.value)
            exp.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

    func testUploadImage() throws {
        let exp = expectation(description: "upload request")

        stub(condition: pathStartsWith("/_matrix/media/")) { _ in
            let response = ["content_uri": "mxc://example.com/AQwafuaFswefuhsfAFAgsw"]
            return OHHTTPStubsResponse(jsonObject: response, statusCode: 200, headers: nil)
        }

        let path = OHPathForFile("Fixtures/testimage.png", type(of: self))!
        let avatar = try Data(contentsOf: URL(string: "file://\(path)")!)

        ImageService.uploadImage(filename: "testimage.png", mimeType: "image/png", data: avatar, accessToken: "token") { result in
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value, "mxc://example.com/AQwafuaFswefuhsfAFAgsw")
            exp.fulfill()
        }
        waitForExpectations(timeout: 5)
    }
}
