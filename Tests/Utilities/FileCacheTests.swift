@testable import EntropyKit
import XCTest

class FileCacheTests: XCTestCase {
    private let queue = DispatchQueue(label: "filecachetests", qos: .userInitiated, attributes: .initiallyInactive, autoreleaseFrequency: .workItem, target: nil)

    private func getCache() -> FileCache<String> {
        try! FileCache<String>(queue: queue, transformForCache: { value in
            value?.data(using: .utf8) ?? Data()
        }, transformFromCache: { data in
            if let data = data {
                return String(data: data, encoding: .utf8)
            } else {
                return nil
            }
        })
    }

    private func getDelegate(cb: @escaping FileCacheDeletageStub<String>.FileCacheDeletageStubCB) -> FileCacheDeletageStub<String> {
        FileCacheDeletageStub<String>(cb: cb)
    }

    func testSetGet() {
        let exp = expectation(description: "set get")
        let cache = getCache()

        cache.delegate = getDelegate { _, _ in
            XCTAssertEqual(cache.get("test"), "Foo")
            exp.fulfill()
        }

        cache.set("test", object: "Foo")

        queue.activate()
        waitForExpectations(timeout: 5)
    }

    func testSubscript() {
        let exp = expectation(description: "subscript")
        let cache = getCache()

        cache.delegate = getDelegate { _, _ in
            XCTAssertEqual(cache["test"], "Foo")
            exp.fulfill()
        }

        cache.set("test", object: "Foo")

        queue.activate()
        waitForExpectations(timeout: 5)
    }

    func testRemove() {
        let exp = expectation(description: "remove")
        let cache = getCache()

        cache.delegate = getDelegate { _, _ in
            XCTAssertEqual(cache.get("test"), "Foo")
            cache.remove("test")
            XCTAssertNil(cache.get("test"))
            exp.fulfill()
        }

        cache["test"] = "Foo"

        queue.activate()
        waitForExpectations(timeout: 5)
    }

    func testClear() {
        let exp = expectation(description: "clear")
        let cache = getCache()

        cache.delegate = getDelegate { key, _ in
            if key == "b" {
                cache.clear()
                XCTAssertNil(cache.get("a"))
                XCTAssertNil(cache.get("b"))
                exp.fulfill()
            }
        }

        cache["a"] = "0"
        cache["b"] = "1"

        queue.activate()
        waitForExpectations(timeout: 5)
    }
}

class FileCacheDeletageStub<T>: FileCacheDelegate {
    typealias FileCacheDeletageStubCB = (String, T?) -> Void
    private let cb: FileCacheDeletageStubCB

    init(cb: @escaping FileCacheDeletageStubCB) {
        self.cb = cb
    }

    func wroteCacheFile<V>(_: FileCache<V>, key: String, value: V?) {
        cb(key, value as? T)
    }
}
