import EntropyKit
import XCTest

class StringTests: XCTestCase {
    func testisEmojiOnly() {
        XCTAssertFalse("🏁b".isEmojiOnly)
        XCTAssertFalse("0".isEmojiOnly)
        XCTAssertFalse("2🥐".isEmojiOnly)
        XCTAssertFalse("⏎".isEmojiOnly)
        XCTAssertFalse("😃@".isEmojiOnly)

        XCTAssertTrue("👨‍👨‍👧‍👧".isEmojiOnly)
        XCTAssertTrue("🤷‍♂️".isEmojiOnly)
        XCTAssertTrue("🤷🏼‍♂️".isEmojiOnly)
        XCTAssertTrue("🤷🏻‍♀️".isEmojiOnly)
        XCTAssertTrue("👨👩👧👧".isEmojiOnly)
        XCTAssertTrue("👏🏻🙈".isEmojiOnly)
        XCTAssertTrue("🏎🏎🏎🏎🏎".isEmojiOnly)
        XCTAssertTrue("😇🤓".isEmojiOnly)
    }

    func testGlyphCount() {
        XCTAssertEqual("🏁b".count, 2)
        XCTAssertEqual("0".count, 1)
        XCTAssertEqual("2🥐".count, 2)
        XCTAssertEqual("⏎".count, 1)
        XCTAssertEqual("😃@".count, 2)

        XCTAssertEqual("👨‍👨‍👧‍👧".count, 1)
        XCTAssertEqual("🤷‍♂️".count, 1)
        XCTAssertEqual("🤷🏼‍♂️".count, 1)
        XCTAssertEqual("🤷🏻‍♀️".count, 1)
        XCTAssertEqual("👨👩👧👧".count, 4)
        XCTAssertEqual("👏🏻🙈".count, 2)
        XCTAssertEqual("🏎🏎🏎🏎🏎".count, 5)
        XCTAssertEqual("😇🤓".count, 2)
    }
}
