@testable import EntropyKit
import XCTest

class MemoryCacheTests: XCTestCase {
    func testInit() {
        let cache = MemoryCache<Int>()
        XCTAssertNotNil(cache)
    }

    func testSetGet() {
        let cache = MemoryCache<Int>()

        cache.set("test", object: 10)
        XCTAssertEqual(cache.get("test"), 10)
    }

    func testSetGetTypes() {
        let cache = MemoryCache<Date>()
        let now = Date()

        cache.set("now", object: now)

        XCTAssertTrue(cache.get("now")! == now)
    }

    func testSubscript() {
        let cache = MemoryCache<Int>()

        cache["test"] = 10
        XCTAssertEqual(cache.get("test"), 10)
    }

    func testRemove() {
        let cache = MemoryCache<Int>()

        cache["test"] = 10
        XCTAssertEqual(cache.get("test"), 10)

        cache.remove("test")
        XCTAssertNil(cache.get("test"))
    }

    func testClear() {
        let cache = MemoryCache<Int>()

        cache["a"] = 0
        cache["b"] = 1

        cache.clear()

        XCTAssertNil(cache.get("a"))
        XCTAssertNil(cache.get("b"))
    }

    func testCostsSet() {
        let cache = MemoryCache<Int>(totalCostLimit: 100)

        cache["a", 50] = 0
        cache["b", 60] = 1
        cache["c", 40] = 2

        XCTAssertNil(cache.get("a"))
        XCTAssertEqual(cache.get("b"), 1)
        XCTAssertEqual(cache.get("c"), 2)
    }
}
