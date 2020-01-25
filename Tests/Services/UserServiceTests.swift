@testable import EntropyKit
import OHHTTPStubs
import XCTest

class UserServiceTests: XCTestCase {
    // private var matrixAPI: MatrixAPI!
    private var database: Database!
    private var dbPath: URL!

    override func setUp() {
        super.setUp()
        dbPath = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(type(of: self)).sqlite")
        database = try! Database(path: dbPath)
        MatrixAPI.default.baseURL = "https://entropy.kodeshack.com"
    }

    override func tearDown() {
        try! FileManager.default.removeItem(at: dbPath)
        HTTPStubs.removeAllStubs()
        super.tearDown()
    }

    func testLoadAvatar() {
        let exp = expectation(description: "avatar request")

        stub(condition: pathStartsWith("/_matrix/client/")) { _ in
            let avatarResponse = ["avatar_url": "mxc://matrix.org/SDGdghriugerRg"]
            return HTTPStubsResponse(jsonObject: avatarResponse, statusCode: 200, headers: nil)
        }

        stub(condition: pathStartsWith("/_matrix/media/")) { _ in
            HTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/testimage.png", type(of: self))!,
                statusCode: 200,
                headers: nil
            )
        }

        let user = User(id: "@test:user")
        UserService.loadAvatar(userID: user.id, forceDownload: true) { result in
            XCTAssertNil(result.failure)
            XCTAssertNotNil(result.success!)
            exp.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

    func testLoadAvatarEmptyResponse() {
        let exp = expectation(description: "avatar request")

        stub(condition: pathStartsWith("/_matrix/client/")) { _ in
            let avatarResponse = [String: String]()
            return HTTPStubsResponse(jsonObject: avatarResponse, statusCode: 200, headers: nil)
        }

        let user = User(id: "@test:user")
        UserService.loadAvatar(userID: user.id, forceDownload: true) { result in
            XCTAssertNil(result.failure)
            XCTAssertNil(result.success!)
            exp.fulfill()
        }
        waitForExpectations(timeout: 5)
    }
}
