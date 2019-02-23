@testable import EntropyKit
import OHHTTPStubs
import XCTest

class MatrixAPITests: XCTestCase {
    override func setUp() {
        super.setUp()
        MatrixAPI.default.baseURL = "https://entropy.kodeshack.com"
    }

    override func tearDown() {
        OHHTTPStubs.removeAllStubs()
        super.tearDown()
    }

    // MARK: Images

    func testDownloadImage() {
        let exp = expectation(description: "downloadImage")

        stub(condition: pathStartsWith("/_matrix/media/")) { _ in
            OHHTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/testimage.png", type(of: self))!,
                statusCode: 200,
                headers: nil
            )
        }

        MatrixAPI.default.downloadImage(mxcURL: URL(string: "mxc://matrix.org/SDGdghriugerRg")!) { result in
            XCTAssertNil(result.error)
            XCTAssertNotNil(result.value)
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testUploadImage() throws {
        let exp = expectation(description: "uploadImage")

        stub(condition: pathStartsWith("/_matrix/media/")) { _ in
            let response = ["content_uri": "mxc://example.com/AQwafuaFswefuhsfAFAgsw"]
            return OHHTTPStubsResponse(jsonObject: response, statusCode: 200, headers: nil)
        }

        let path = OHPathForFile("Fixtures/testimage.png", type(of: self))!
        let avatar = try Data(contentsOf: URL(string: "file://\(path)")!)

        MatrixAPI.default.upload(filename: "testimage.png", mimeType: "image/png", data: avatar, accessToken: "") { result in
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value, "mxc://example.com/AQwafuaFswefuhsfAFAgsw")
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    // MARK: Files

    func testDownloadFile() {
        let exp = expectation(description: "downloadFile")

        stub(condition: pathStartsWith("/_matrix/media/")) { _ in
            OHHTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/testimage.png", type(of: self))!,
                statusCode: 200,
                headers: nil
            )
        }

        MatrixAPI.default.downloadFile(mxcURL: URL(string: "mxc://matrix.org/SDGdghriugerRg")!) { result in
            XCTAssertNil(result.error)
            XCTAssertNotNil(result.value)
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testDownloadEncryptedFile() throws {
        let exp = expectation(description: "downloadEncryptedFile")

        let data = try Data(contentsOf: URL(fileURLWithPath: OHPathForFile("Fixtures/testimage.png", type(of: self))!))
        let encryptedData = "LgyZH4o2wqxw59Ggb0foZHSq3X7rTrs/1bvgl9SPAPxfxy+ecZbP1pxjahiWG9IJoMulxCxAN2zTiNPEF0I+8oIJXNRXH9rxHT4hBYBQONrH/w=="

        stub(condition: pathStartsWith("/_matrix/media/")) { _ in
            OHHTTPStubsResponse(
                data: Data(base64Encoded: encryptedData)!,
                statusCode: 200,
                headers: nil
            )
        }

        let keyData = Data(base64Encoded: "8FkpNeWfP6LQKBnW6tjSxKBathYSwhOavJlGMRnbJNk=")!
        let iv = Base64URL(base64: "CtzULW+iHPYAAAAAAAAAAA==")!
        let hashes = EncryptedAttachment.EncryptedAttachmentHashes(sha256: "2fUCPPLmL+YDkSosqHJaW1SLOLBK2VDS47UuwYxCZ2w")
        let key = EncryptedAttachment.EncryptedAttachmentKey.v2KeyInfo(key: keyData)
        let file = EncryptedAttachment(version: .v2, mxcURL: URL(string: "mxc://testimage.png")!, mimeType: "image/png", size: data.count, iv: iv, key: key, hashes: hashes)
        let cryptoInfo = Attachment.Info.CryptoInfo(for: file)
        MatrixAPI.default.downloadFile(mxcURL: URL(string: "mxc://matrix.org/SDGdghriugerRg")!, cryptoInfo: cryptoInfo) { result in
            XCTAssertEqual(result.value, data)
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    // MARK: Users

    func testGetAvatarURL() {
        let exp = expectation(description: "getAvatarURL")

        stub(condition: pathStartsWith("/_matrix/client/")) { _ in
            let avatarResponse = ["avatar_url": "mxc://matrix.org/SDGdghriugerRg"]
            return OHHTTPStubsResponse(jsonObject: avatarResponse, statusCode: 200, headers: nil)
        }

        MatrixAPI.default.getAvatarURL(userID: "@test:user") { result in
            XCTAssertNil(result.error)
            XCTAssertNotNil(result.value)
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testDownloadAvatar() {
        let exp = expectation(description: "downloadAvatar")

        stub(condition: pathStartsWith("/_matrix/media/")) { _ in
            OHHTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/testimage.png", type(of: self))!,
                statusCode: 200,
                headers: nil
            )
        }

        MatrixAPI.default.downloadAvatar(mxcURL: URL(string: "mxc://matrix.org/SDGdghriugerRg")!) { result in
            XCTAssertNil(result.error)
            XCTAssertNotNil(result.value)
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    // MARK: Sessions

    func testLogin() {
        let exp = expectation(description: "login")

        stub(condition: pathStartsWith("/_matrix/client/r0/login")) { _ in
            let loginResp = ["user_id": "@NotBob:kodeshack", "access_token": "foo", "device_id": "bar"]
            return OHHTTPStubsResponse(jsonObject: loginResp, statusCode: 200, headers: nil)
        }

        MatrixAPI.default.login(username: "NotBob", password: "psswd") { result in
            XCTAssertNil(result.error)
            XCTAssertNotNil(result.value)
            XCTAssertEqual(result.value?.userID, "@NotBob:kodeshack")
            XCTAssertEqual(result.value?.accessToken, "foo")
            XCTAssertEqual(result.value?.deviceID, "bar")
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testLogout() {
        let exp = expectation(description: "logout")

        stub(condition: pathStartsWith("/_matrix/client/r0/logout")) { _ in
            OHHTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
        }

        MatrixAPI.default.logout(accessToken: "foo") { error in
            XCTAssertNil(error)
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    // MARK: Sending Messages

    func testSend() {
        let exp = expectation(description: "send")

        stub(condition: { request in
            let data = (request as NSURLRequest).ohhttpStubs_HTTPBody()!
            let event = String(data: data, encoding: .utf8)

            let expected = "{\"body\":\"Hello.\",\"msgtype\":\"m.text\"}"

            return
                request.url?.absoluteString == "https://entropy.kodeshack.com/_matrix/client/r0/rooms/!wakeful_pigs:kodeshack/send/m.room.message/5?access_token=togepi"
                && request.httpMethod == "PUT"
                && event == expected

        }) { _ in
            let eventResp = ["event_id": "vaccines_cause_autism"]
            return OHHTTPStubsResponse(jsonObject: eventResp, statusCode: 200, headers: nil)
        }

        let msg = PlainMessageJSON(body: "Hello.", type: .text)

        MatrixAPI.default.send(body: msg, eventType: .message, to: "!wakeful_pigs:kodeshack", accessToken: "togepi", transactionID: 5) { result in
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.eventID, "vaccines_cause_autism")
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    // MARK: Sending Messages

    func testSync() {
        let exp = expectation(description: "sync")

        stub(condition: isHost("entropy.kodeshack.com")) { _ in
            OHHTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/simple_sync.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }

        MatrixAPI.default.sync(timeout: 0, nextBatch: "foo", accessToken: "bar", queue: DispatchQueue.main) { result in
            XCTAssertNil(result.error)
            XCTAssertNotNil(result.value)
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    // MARK: Link Preview

    func testRequestLinkPreviewInfo() {
        let exp = expectation(description: "preview")

        stub(condition: isHost("entropy.kodeshack.com")) { _ in
            OHHTTPStubsResponse(
                fileAtPath: OHPathForFile("Fixtures/preview.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }

        MatrixAPI.default.requestLinkPreviewInfo(for: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!, accessToken: "secret") { result in
            guard let info = result.value else {
                XCTAssertNil(result.error)
                return
            }

            XCTAssertEqual(info.title, "Rick Astley - Never Gonna Give You Up (Video)")
            XCTAssertEqual(info.description, "Rick Astley - Never Gonna Give You Up (Official Music Video) - Listen On Spotify: http://smarturl.it/AstleySpotify Download Rick's Number 1 album \"\"50\"\" - ht...")
            XCTAssertNil(info.imageMXCURL)
            XCTAssertNil(info.image)

            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
}
