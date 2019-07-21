@testable import EntropyKit
import OHHTTPStubs
import XCTest

class RoomServiceTests: XCTestCase {
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

    func testSendMessage() throws {
        stub(condition: { request in
            let data = (request as NSURLRequest).ohhttpStubs_HTTPBody()!
            let event = String(data: data, encoding: .utf8)

            let expected = "{\"body\":\"Hello.\",\"msgtype\":\"m.text\"}"

            return
                request.url?.absoluteString == "https://entropy.kodeshack.com/_matrix/client/r0/rooms/!wakeful_pigs:kodeshack/send/m.room.message/0?access_token=togepi"
                && request.httpMethod == "PUT"
                && event == expected

        }) { _ in
            let eventResp = ["event_id": "vaccines_cause_autism"]
            return OHHTTPStubsResponse(jsonObject: eventResp, statusCode: 200, headers: nil)
        }

        let account = try Account.create(userID: "NotBob@kodeshack", accessToken: "togepi", deviceID: "bar", database: database)
        let room = try Room.create(id: "!wakeful_pigs:kodeshack", database: database)

        let msg = PlainMessageJSON(body: "Hello.", type: .text)

        let exp = expectation(description: "send message")

        RoomService.send(message: msg, to: room.id, encrypted: false, account: account, database: database) { result in
            XCTAssertNil(result.failure)
            XCTAssertEqual(result.success?.id, "vaccines_cause_autism")
            if let id = result.success?.id {
                try! self.database.dbQueue.inDatabase { db in
                    let message = try Message.fetchOne(db, key: id)
                    XCTAssertEqual(message?.senderID, "NotBob@kodeshack")
                    XCTAssertEqual(message?.type, .text)
                    XCTAssertEqual(message?.body, "Hello.")
                }
            }

            exp.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testSendUnencryptedMedia() {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "testimage", withExtension: "png", subdirectory: "Fixtures") else {
            XCTFail()
            return
        }
        let data = try! Data(contentsOf: url)

        stub(condition: { request in
            guard
                request.url!.absoluteString.hasSuffix("/_matrix/client/r0/rooms/!wakeful_pigs:kodeshack/send/m.room.message/0?access_token=togepi"),
                request.httpMethod == "PUT"
            else { return false }

            let data = request.ohhttpStubs_httpBody!
            let event = String(data: data, encoding: .utf8)

            let expected = "{\"body\":\"testimage.png\",\"info\":{\"h\":1,\"mimetype\":\"image/png\",\"size\":82,\"w\":1},\"msgtype\":\"m.file\",\"url\":\"mxc://example.com/MTcwMzE5OTU\"}"

            return event == expected
        }) { _ in
            let eventResp = ["event_id": "message_sent"]
            return OHHTTPStubsResponse(jsonObject: eventResp, statusCode: 200, headers: nil)
        }

        stub(condition: { request in

            request.url!.absoluteString.hasSuffix("/_matrix/media/r0/upload?access_token=togepi&filename=testimage.png")
                && request.httpMethod == "POST"
        }) { _ in
            let eventResp = ["content_uri": "mxc://example.com/MTcwMzE5OTU"]
            return OHHTTPStubsResponse(jsonObject: eventResp, statusCode: 200, headers: nil)
        }

        let account = try! Account.create(userID: "NotBob@kodeshack", accessToken: "togepi", deviceID: "bar", database: database)
        let room = try! Room.create(id: "!wakeful_pigs:kodeshack", database: database)
        let info = FileMessageJSON.Info(width: 1, height: 1, size: UInt(data.count), mimeType: "image/png", thumbnailInfo: nil, thumbnailFile: nil)
        let exp = expectation(description: "sent media message")

        RoomService.sendMedia(filename: "testimage.png", data: data, info: info, roomID: room.id, account: account, database: database) { result in
            XCTAssertNil(result.failure)
            XCTAssertEqual(result.success?.id, "message_sent")
            if let id = result.success?.id {
                try! self.database.dbQueue.inDatabase { db in
                    let message = try Message.fetchOne(db, key: id)
                    XCTAssertEqual(message?.senderID, "NotBob@kodeshack")
                    XCTAssertEqual(message?.type, .file)
                    XCTAssertEqual(message?.body, "testimage.png")
                }
            }

            exp.fulfill()
        }

        waitForExpectations(timeout: 5)
    }
}
