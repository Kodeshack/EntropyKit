@testable import EntropyKit
import XCTest

class SchedulerTests: XCTestCase {
    func testInit() {
        let s = Scheduler(name: "test", interval: 10)
        XCTAssertNotNil(s)
    }

    func testScheduledAction() {
        let exp = expectation(description: "scheduled action called")
        let s = Scheduler(name: "test", interval: 1)

        s.start { _ in
            exp.fulfill()
            s.stop()
        }

        waitForExpectations(timeout: 2)
    }

    func testScheduledRepeatedAction() {
        var counter = 0
        let exp = expectation(description: "scheduled action called")
        let s = Scheduler(name: "test", interval: 1)

        s.start { completionHandler in
            if counter == 1 {
                exp.fulfill()
                s.stop()
            } else {
                counter += 1
            }
            completionHandler()
        }

        waitForExpectations(timeout: 2)
    }
}
