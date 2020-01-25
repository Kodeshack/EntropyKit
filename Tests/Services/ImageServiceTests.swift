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
        HTTPStubs.removeAllStubs()
        super.tearDown()
    }

    func testLoadMessageThumbnail() {
        let exp = expectation(description: "thumbnail request")

        stub(condition: pathStartsWith("/_matrix/media/")) { _ in
            HTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/testimage.png", type(of: self))!,
                statusCode: 200,
                headers: nil
            )
        }

        let now = Date()
        let info = FileMessageJSON.Info(width: nil, height: nil, size: 5, mimeType: "", thumbnailInfo: nil, thumbnailFile: nil)
        let fileMessageJSON = FileMessageJSON(type: .image, filename: "test", info: info, url: URL(string: "mxc://example.com/AQwafuaFswefuhsfAFAgsw")!)
        let content = Event.Content.fileMessage(fileMessageJSON)
        let event = Event(id: "eventID", type: .message, date: now, roomID: "roomID", content: content)
        let message = Message(id: "msgID", roomID: "roomID", date: now, senderID: "senderID", type: .image, body: "body")
        message.attachment = Attachment(event: event)

        ImageService.loadThumbnail(for: message) { result in
            XCTAssertNil(result.failure)
            XCTAssertNotNil(result.success)
            exp.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

    func testLoadMessageThumbnailFail() {
        let exp = expectation(description: "thumbnail request fail")

        let message = Message(id: "msgID", roomID: "roomID", date: Date(), senderID: "senderID", type: .image, body: "body")

        ImageService.loadThumbnail(for: message) { result in
            XCTAssertEqual(result.failure as? Attachment.AttachmentError, Attachment.AttachmentError.missingAttachment)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testLoadMessageImage() {
        let exp = expectation(description: "image request")

        stub(condition: pathStartsWith("/_matrix/media/")) { _ in
            HTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/testimage.png", type(of: self))!,
                statusCode: 200,
                headers: nil
            )
        }

        let now = Date()
        let info = FileMessageJSON.Info(width: nil, height: nil, size: 5, mimeType: "", thumbnailInfo: nil, thumbnailFile: nil)
        let fileMessageJSON = FileMessageJSON(type: .image, filename: "test", info: info, url: URL(string: "mxc://example.com/AQwafuaFswefuhsfAFAgsw")!)
        let content = Event.Content.fileMessage(fileMessageJSON)
        let event = Event(id: "eventID", type: .message, date: now, roomID: "roomID", content: content)
        let message = Message(id: "msgID", roomID: "roomID", date: now, senderID: "senderID", type: .image, body: "body")
        message.attachment = Attachment(event: event)

        ImageService.loadImage(for: message) { result in
            XCTAssertNil(result.failure)
            XCTAssertNotNil(result.success)
            exp.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

    func testLoadMessageImageFail() {
        let exp = expectation(description: "image request fail")

        let message = Message(id: "msgID", roomID: "roomID", date: Date(), senderID: "senderID", type: .image, body: "body")

        ImageService.loadImage(for: message) { result in
            XCTAssertEqual(result.failure as? Attachment.AttachmentError, Attachment.AttachmentError.missingAttachment)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testUploadImage() throws {
        let exp = expectation(description: "upload request")

        stub(condition: pathStartsWith("/_matrix/media/")) { _ in
            let response = ["content_uri": "mxc://example.com/AQwafuaFswefuhsfAFAgsw"]
            return HTTPStubsResponse(jsonObject: response, statusCode: 200, headers: nil)
        }

        let path = OHPathForFile("Fixtures/testimage.png", type(of: self))!
        let avatar = try Data(contentsOf: URL(string: "file://\(path)")!)

        ImageService.uploadImage(filename: "testimage.png", mimeType: "image/png", data: avatar, accessToken: "token") { result in
            XCTAssertNil(result.failure)
            XCTAssertEqual(result.success, "mxc://example.com/AQwafuaFswefuhsfAFAgsw")
            exp.fulfill()
        }
        waitForExpectations(timeout: 5)
    }
}
