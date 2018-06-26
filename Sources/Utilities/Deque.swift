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

/// Deque (pronounced "deck"), a double-ended queue
/// All enqueuing and dequeuing operations are O(1).
struct Deque<T> {
    private var array: [T?]
    private var head: Int
    private var capacity: Int
    private let originalCapacity: Int

    init(_ capacity: Int = 10) {
        self.capacity = max(capacity, 1)
        originalCapacity = self.capacity
        array = [T?](repeating: nil, count: capacity)
        head = capacity
    }

    var isEmpty: Bool {
        return count == 0
    }

    var count: Int {
        return array.count - head
    }

    mutating func enqueue(_ element: T) {
        array.append(element)
    }

    mutating func enqueueFront(_ element: T) {
        if head == 0 {
            capacity *= 2
            let emptySpace = [T?](repeating: nil, count: capacity)
            array.insert(contentsOf: emptySpace, at: 0)
            head = capacity
        }

        head -= 1
        array[head] = element
    }

    mutating func dequeue() -> T? {
        guard head < array.count, let element = array[head] else { return nil }

        array[head] = nil
        head += 1

        if capacity >= originalCapacity && head >= capacity * 2 {
            let amountToRemove = capacity + capacity / 2
            array.removeFirst(amountToRemove)
            head -= amountToRemove
            capacity /= 2
        }
        return element
    }

    mutating func dequeueBack() -> T? {
        if isEmpty {
            return nil
        } else {
            return array.removeLast()
        }
    }

    func peekFront() -> T? {
        if isEmpty {
            return nil
        } else {
            return array[head]
        }
    }

    func peekBack() -> T? {
        if isEmpty {
            return nil
        } else {
            return array.last!
        }
    }
}
