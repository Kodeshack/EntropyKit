/*
 Copyright (c) 2016 Matthijs Hollemans and contributors

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

@testable import EntropyKit
import Foundation
import XCTest

class DequeTest: XCTestCase {
    func testEmpty() {
        var deque = Deque<Int>()
        XCTAssertTrue(deque.isEmpty)
        XCTAssertEqual(deque.count, 0)
        XCTAssertEqual(deque.peekFront(), nil)
        XCTAssertNil(deque.dequeue())
    }

    func testOneElement() {
        var deque = Deque<Int>()

        deque.enqueue(123)
        XCTAssertFalse(deque.isEmpty)
        XCTAssertEqual(deque.count, 1)
        XCTAssertEqual(deque.peekFront(), 123)

        let result = deque.dequeue()
        XCTAssertEqual(result, 123)
        XCTAssertTrue(deque.isEmpty)
        XCTAssertEqual(deque.count, 0)
        XCTAssertEqual(deque.peekFront(), nil)
    }

    func testTwoElements() {
        var deque = Deque<Int>()

        deque.enqueue(123)
        deque.enqueue(456)
        XCTAssertFalse(deque.isEmpty)
        XCTAssertEqual(deque.count, 2)
        XCTAssertEqual(deque.peekFront(), 123)

        let result1 = deque.dequeue()
        XCTAssertEqual(result1, 123)
        XCTAssertFalse(deque.isEmpty)
        XCTAssertEqual(deque.count, 1)
        XCTAssertEqual(deque.peekFront(), 456)

        let result2 = deque.dequeue()
        XCTAssertEqual(result2, 456)
        XCTAssertTrue(deque.isEmpty)
        XCTAssertEqual(deque.count, 0)
        XCTAssertEqual(deque.peekFront(), nil)
    }

    func testMakeEmpty() {
        var deque = Deque<Int>()

        deque.enqueue(123)
        deque.enqueue(456)
        XCTAssertNotNil(deque.dequeue())
        XCTAssertNotNil(deque.dequeue())
        XCTAssertNil(deque.dequeue())

        deque.enqueue(789)
        XCTAssertEqual(deque.count, 1)
        XCTAssertEqual(deque.peekFront(), 789)

        let result = deque.dequeue()
        XCTAssertEqual(result, 789)
        XCTAssertTrue(deque.isEmpty)
        XCTAssertEqual(deque.count, 0)
        XCTAssertEqual(deque.peekFront(), nil)
    }
}
