import EntropyKit
import XCTest

class UnicodeScalarTests: XCTestCase {
    func testIsEmoji() {
        XCTAssertFalse("5".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertFalse("b".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertFalse("ø".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertFalse("∫".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertFalse("€".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertFalse("‰".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertFalse("@".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertFalse("π".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertFalse("«".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertFalse(">".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertFalse("®".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertFalse("⏎".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)

        XCTAssertTrue("🤓".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertTrue("👨‍👨‍👧‍👧".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertTrue("🤷‍♂️".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertTrue("🤷🏼‍♂️".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertTrue("🤷🏻‍♀️".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertTrue("👧".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertTrue("🏎".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertTrue("👍🏻".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertTrue("🦄".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertTrue("🥐".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertTrue("🥅".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertTrue("💻".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertTrue("🉑".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
        XCTAssertTrue("🏁".unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil)
    }
}
