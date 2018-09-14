@testable import EntropyKit
import XCTest

class AsyncResultTests: XCTestCase {
    func testThen() {
        let promise = AsyncResult<Int>()

        let exp = expectation(description: "testThen")

        promise.then { result in
            XCTAssertEqual(1, result)
            exp.fulfill()
        }

        promise.resolve(with: 1)

        waitForExpectations(timeout: 1)
    }

    func testResolveImmediate() {
        let promise = AsyncResult<Int> { return 1 }

        let exp = expectation(description: "testResolveImmediate")

        promise.then { result in
            XCTAssertEqual(1, result)
            exp.fulfill()
        }

        promise.resolve(with: 1)

        waitForExpectations(timeout: 1)
    }

    func testChainThen() {
        let promise = AsyncResult<Int>()

        let exp1 = expectation(description: "testChainThen1")
        let exp2 = expectation(description: "testChainThen2")

        promise.then { result -> Int in
            XCTAssertEqual(1, result)
            exp1.fulfill()
            return 2
        }.then { result in
            XCTAssertEqual(2, result)
            exp2.fulfill()
        }

        promise.resolve(with: 1)

        waitForExpectations(timeout: 1)
    }

    func testReject() {
        let promise = AsyncResult<Int>()

        let exp = expectation(description: "testReject")

        promise.then { _ in
            XCTFail()
        }

        promise.catch { error in
            XCTAssertEqual(MatrixAPI.APIError.invalidEncoding, error as! MatrixAPI.APIError)
            exp.fulfill()
        }

        promise.reject(with: MatrixAPI.APIError.invalidEncoding)

        waitForExpectations(timeout: 1)
    }

    func testNestedPromisesInThens() {
        let promiseA = AsyncResult<Int>()
        let promiseB = AsyncResult<Int>()

        let exp = expectation(description: "testNestedPromisesInThens")

        promiseA.then { _ in
            promiseB
        }.then { result in
            XCTAssertEqual(2, result)
            exp.fulfill()
        }

        promiseA.resolve(with: 1)
        promiseB.resolve(with: 2)

        waitForExpectations(timeout: 1)
    }

    func testInitWithAsync() {
        let promiseA = AsyncResult<Int>()
        let promiseB = AsyncResult<Int>(async: {
            promiseA
        })

        let exp = expectation(description: "testInitWithAsync")

        promiseB.then { result in
            XCTAssertEqual(2, result)
            exp.fulfill()
        }

        promiseA.resolve(with: 2)

        waitForExpectations(timeout: 1)
    }

    func testInitWithImmediate() {
        let promise = AsyncResult<Int> { return 1 }

        let exp = expectation(description: "testInitWithImmediate")

        promise.then { result in
            XCTAssertEqual(1, result)
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
}
