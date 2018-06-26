@testable import EntropyKit
import XCTest

class CacheHierarchyTests: XCTestCase {
    func testInit() {
        let testCache1 = MemoryCache<String>()
        let testCache2 = MemoryCache<String>()
        _ = CacheHierarchy<String>(testCache1, testCache2)
    }

    func testSetWithoutPropagation() {
        let testCache1 = MemoryCache<String>()
        let testCache2 = MemoryCache<String>()
        let cache = CacheHierarchy<String>(testCache1, testCache2)
        cache.set("Foo", object: "Bar")
        XCTAssertEqual(testCache1["Foo"]!, "Bar")
        XCTAssertNil(testCache2["Foo"])
    }

    func testSetWithPropagation() {
        let testCache1 = MemoryCache<String>()
        let testCache2 = MemoryCache<String>()
        let cache = CacheHierarchy<String>(propagate: true, caches: testCache1, testCache2)
        cache.set("Foo", object: "Bar")
        XCTAssertEqual(testCache1["Foo"]!, "Bar")
        XCTAssertEqual(testCache2["Foo"]!, "Bar")
    }

    func testGet() {
        let testCache1 = MemoryCache<String>()
        let testCache2 = MemoryCache<String>()
        let cache = CacheHierarchy<String>(testCache1, testCache2)

        testCache1["Foo"] = "Bar"
        XCTAssertEqual(cache["Foo"]!, "Bar")

        testCache1.clear()

        testCache2["Foo"] = "Bar"
        XCTAssertEqual(cache["Foo"]!, "Bar")
        XCTAssertEqual(testCache1["Foo"]!, "Bar")
    }

    func testRemoveWithoutPropagation() {
        let testCache1 = MemoryCache<String>()
        let testCache2 = MemoryCache<String>()
        let cache = CacheHierarchy<String>(testCache1, testCache2)

        testCache1["Foo"] = "Bar"
        testCache2["Foo"] = "Bar"

        cache.remove("Foo")

        XCTAssertNil(testCache1["Foo"])
        XCTAssertEqual(cache["Foo"]!, "Bar")
        XCTAssertEqual(testCache1["Foo"]!, "Bar") // propagated up from cache 2
    }

    func testRemoveWithPropagation() {
        let testCache1 = MemoryCache<String>()
        let testCache2 = MemoryCache<String>()
        let cache = CacheHierarchy<String>(propagate: true, caches: testCache1, testCache2)

        testCache1["Foo"] = "Bar"
        testCache2["Foo"] = "Bar"

        cache.remove("Foo")

        XCTAssertNil(testCache1["Foo"])
        XCTAssertNil(testCache2["Foo"])
        XCTAssertNil(cache["Foo"])
    }

    func testClearWithoutPropagation() {
        let testCache1 = MemoryCache<String>()
        let testCache2 = MemoryCache<String>()
        let cache = CacheHierarchy<String>(testCache1, testCache2)

        testCache1["Foo"] = "Bar"
        testCache2["Foo"] = "Bar"

        cache.clear()

        XCTAssertNil(testCache1["Foo"])
        XCTAssertEqual(cache["Foo"]!, "Bar")
        XCTAssertEqual(testCache1["Foo"]!, "Bar") // propagated up from cache 2
    }

    func testClearWithPropagation() {
        let testCache1 = MemoryCache<String>()
        let testCache2 = MemoryCache<String>()
        let cache = CacheHierarchy<String>(propagate: true, caches: testCache1, testCache2)

        testCache1["Foo"] = "Bar"
        testCache2["Foo"] = "Bar"

        cache.clear()

        XCTAssertNil(testCache1["Foo"])
        XCTAssertNil(testCache2["Foo"])
        XCTAssertNil(cache["Foo"])
    }
}
