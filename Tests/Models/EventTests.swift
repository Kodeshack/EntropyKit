@testable import EntropyKit
import XCTest

class EventTests: XCTestCase {
    func testParsing() throws {
        let json = """
            {
              "origin_server_ts": 1444812213737,
              "sender": "@alice:example.com",
              "event_id": "$1444812213350496Caaaa:example.com",
              "content": {
                "body": "hello world",
                "msgtype": "m.text"
              },
              "room_id": "!Xq3620DUiqCaoxq:example.com",
              "type": "m.room.message",
              "age": 1042
            }
        """.data(using: .utf8)

        let event = try Event.decode(json).dematerialize()
        XCTAssertEqual(event.id, "$1444812213350496Caaaa:example.com")
        XCTAssertEqual(event.senderID, "@alice:example.com")
        XCTAssertEqual(event.type, .message)
        XCTAssertEqual(event.date, Date(timeIntervalSince1970: 1_444_812_213_737.0 / 1000.0))
        XCTAssertEqual(event.roomID, "!Xq3620DUiqCaoxq:example.com")

        guard case let .message(message) = event.content else {
            XCTFail()
            return
        }

        XCTAssertEqual(message.body, "hello world")
        XCTAssertEqual(message.type, .text)
        XCTAssertNil(message.imageInfo)
        XCTAssertNil(message.thumbnailInfo)
        XCTAssertNil(message.imageURL)
        XCTAssertNil(message.thumbnailURL)
    }
}
