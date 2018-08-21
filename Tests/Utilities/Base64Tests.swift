@testable import EntropyKit
import XCTest

class Base64Tests: XCTestCase {
    struct JSONWithBase64: JSONCodable {
        let base64: Base64
        static let data = "{\"base64\":\"AQIDBEA/bg==\"}".data(using: .ascii)!
    }

    struct JSONWithBase64URL: JSONCodable {
        let base64url: Base64URL
        static let data = "{\"base64url\":\"AQIDBEA_bg\"}".data(using: .ascii)!
    }

    let data = Data([1, 2, 3, 4, 64, 63, 110])
    let dataBase64 = "AQIDBEA/bg=="
    let dataBase64url = "AQIDBEA_bg"

    // MARK: - Base64

    func testBase64InitFromData() {
        let base64 = Base64(data: data)
        XCTAssertEqual(dataBase64, base64.string)
    }

    func testBase64InitFromBase64() {
        let base64 = Base64(base64: dataBase64)
        XCTAssertNotNil(base64)
        XCTAssertEqual(data, base64?.data)
    }

    func testBase64InitFromBase64urlString() {
        let base64 = Base64(base64url: dataBase64url)
        XCTAssertNotNil(base64)
        XCTAssertEqual(data, base64?.data)
    }

    func testBase64InitFromBase64urlStruct() {
        let base64url = Base64URL(base64url: dataBase64url)!
        let base64 = Base64(base64url: base64url)
        XCTAssertNotNil(base64)
        XCTAssertEqual(data, base64.data)
    }

    func testBase64Decode() {
        let decoder = JSONDecoder()
        let jsonWithBase64 = try! decoder.decode(JSONWithBase64.self, from: JSONWithBase64.data)
        XCTAssertEqual(data, jsonWithBase64.base64.data)
    }

    func testBase64Encode() {
        let base64 = Base64(data: data)
        let jsonData = JSONWithBase64(base64: base64).encoded

        XCTAssertEqual(JSONWithBase64.data, jsonData)
    }

    // MARK: - Base64URL

    func testBase64URLInitFromData() {
        let base64url = Base64URL(data: data)
        XCTAssertEqual(dataBase64url, base64url.string)
    }

    func testBase64URLInitFromBase64() {
        let base64url = Base64URL(base64: dataBase64)
        XCTAssertNotNil(base64url)
        XCTAssertEqual(data, base64url?.data)
    }

    func testBase64URLInitFromBase64urlString() {
        let base64url = Base64URL(base64url: dataBase64url)
        XCTAssertNotNil(base64url)
        XCTAssertEqual(data, base64url?.data)
    }

    func testBase64URLInitFromBase64Struct() {
        let base64url = Base64URL(base64: Base64(data: data))
        XCTAssertEqual(data, base64url.data)
    }

    func testBase64URLDecode() {
        let decoder = JSONDecoder()
        let jsonWithBase64 = try! decoder.decode(JSONWithBase64URL.self, from: JSONWithBase64URL.data)
        XCTAssertEqual(data, jsonWithBase64.base64url.data)
    }

    func testBase64URLEncode() {
        let base64url = Base64URL(data: data)
        let jsonData = JSONWithBase64URL(base64url: base64url).encoded

        XCTAssertEqual(JSONWithBase64URL.data, jsonData)
    }
}
