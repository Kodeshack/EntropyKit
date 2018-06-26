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

        let msg = MessageJSON(body: "Hello.", type: .text)

        let exp = expectation(description: "send message")

        RoomService.send(message: msg, to: room.id, encrypted: false, account: account, database: database) { result in
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.id, "vaccines_cause_autism")
            if let id = result.value?.id {
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
}
