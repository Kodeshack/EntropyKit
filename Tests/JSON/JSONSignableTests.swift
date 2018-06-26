@testable import EntropyKit
import XCTest

class JSONSignableTests: XCTestCase {
    func testSignature() {
        let account = Account(userID: "@NotBob", accessToken: "OpenSesame", deviceID: "Spell", nextBatch: "")
        var object = KeysClaimResponse.DeviceOneTimeKey(key: "verySecretKey", signatures: nil)

        XCTAssertNil(object.signatures)
        object.sign(using: account)

        XCTAssertEqual(object.signatures?.count, 1)
        XCTAssertEqual(object.signatures?[account.userID]?.count, 1)

        guard let signature = object.signatures?[account.userID]?["\(CryptoEngine.CryptoKeys.ed25519.rawValue):\(account.deviceID)"] else {
            XCTFail()
            return
        }

        XCTAssertEqual(signature.count, 86)

        XCTAssertTrue(object.validate(deviceID: account.deviceID, userID: account.userID, ed25519Key: account.identityKeys.ed25519))
    }

    func testSignatureChecks() {
        let myAccount = Account(userID: "@NotBob", accessToken: "OpenSesame", deviceID: "Spell", nextBatch: "")
        let NSAAccount = Account(userID: "@NSABob", accessToken: "Backdoor", deviceID: "ICanHearYou", nextBatch: "")

        var object = KeysClaimResponse.DeviceOneTimeKey(key: "verySecretKey", signatures: nil)

        XCTAssertFalse(object.validate(deviceID: myAccount.deviceID, userID: myAccount.userID, ed25519Key: myAccount.identityKeys.ed25519))

        object.sign(using: myAccount)

        XCTAssertTrue(object.validate(deviceID: myAccount.deviceID, userID: myAccount.userID, ed25519Key: myAccount.identityKeys.ed25519))
        XCTAssertFalse(object.validate(deviceID: myAccount.deviceID, userID: myAccount.userID, ed25519Key: ""))
        XCTAssertFalse(object.validate(deviceID: "", userID: myAccount.userID, ed25519Key: myAccount.identityKeys.ed25519))
        XCTAssertFalse(object.validate(deviceID: NSAAccount.deviceID, userID: NSAAccount.userID, ed25519Key: myAccount.identityKeys.ed25519))
        XCTAssertFalse(object.validate(deviceID: myAccount.deviceID, userID: myAccount.userID, ed25519Key: NSAAccount.identityKeys.ed25519))
    }
}
