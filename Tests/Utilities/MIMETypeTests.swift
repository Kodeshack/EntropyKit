@testable import EntropyKit
import XCTest

class MIMETypeTests: XCTestCase {
    func testMIMEFromExtension() {
        XCTAssertEqual("image/png", MIMEType.mime(for: "png"))
        XCTAssertEqual("image/jpeg", MIMEType.mime(for: "jpeg"))
        XCTAssertEqual("image/jpeg", MIMEType.mime(for: "jpg"))
        XCTAssertEqual("video/mp4", MIMEType.mime(for: "mp4"))
        XCTAssertEqual("audio/mpeg", MIMEType.mime(for: "mp3"))
        XCTAssertEqual("audio/x-m4a", MIMEType.mime(for: "m4a"))
        XCTAssertEqual("application/octet-stream", MIMEType.mime(for: "foo"))
    }

    func testExtensionFromMIME() {
        XCTAssertEqual("png", MIMEType.fileExtension(for: "image/png"))
        XCTAssertEqual("jpeg", MIMEType.fileExtension(for: "image/jpeg"))
        XCTAssertEqual("mp4", MIMEType.fileExtension(for: "video/mp4"))
        XCTAssertEqual("mp3", MIMEType.fileExtension(for: "audio/mp3"))
        XCTAssertEqual(nil, MIMEType.fileExtension(for: "application/octet-stream"))
    }

    func testDetectMIMEType() {
        let url = Bundle(for: type(of: self)).url(forResource: "testimage", withExtension: "png", subdirectory: "Fixtures")!
        let data = try! Data(contentsOf: url)

        XCTAssertEqual("audio/x-m4a", MIMEType.detectMIMEType(filename: "test.m4a", data: Data()))
        XCTAssertEqual("video/mp4", MIMEType.detectMIMEType(filename: "video.mp4", data: Data()))
        XCTAssertEqual("image/png", MIMEType.detectMIMEType(filename: "", data: data))
    }

    func testIsImage() {
        XCTAssertTrue(MIMEType.isImage(fileExtension: "png"))
        XCTAssertTrue(MIMEType.isImage(fileExtension: "jpg"))
        XCTAssertFalse(MIMEType.isImage(fileExtension: "mp4"))
        XCTAssertFalse(MIMEType.isImage(fileExtension: "mp3"))
        XCTAssertTrue(MIMEType.isImage(mime: "image/png"))
        XCTAssertTrue(MIMEType.isImage(mime: "image/jpeg"))
        XCTAssertFalse(MIMEType.isImage(mime: "video/mp4"))
        XCTAssertFalse(MIMEType.isImage(mime: "audio/mp3"))
    }

    func testIsAudio() {
        XCTAssertFalse(MIMEType.isAudio(fileExtension: "png"))
        XCTAssertFalse(MIMEType.isAudio(fileExtension: "jpg"))
        XCTAssertFalse(MIMEType.isAudio(fileExtension: "mp4"))
        XCTAssertTrue(MIMEType.isAudio(fileExtension: "mp3"))
        XCTAssertTrue(MIMEType.isAudio(fileExtension: "m4a"))
        XCTAssertFalse(MIMEType.isAudio(mime: "image/png"))
        XCTAssertFalse(MIMEType.isAudio(mime: "image/jpeg"))
        XCTAssertFalse(MIMEType.isAudio(mime: "video/mp4"))
        XCTAssertTrue(MIMEType.isAudio(mime: "audio/mp3"))
        XCTAssertTrue(MIMEType.isAudio(mime: "audio/x-m4a"))
    }

    func testIsVideo() {
        XCTAssertFalse(MIMEType.isMPEG4Video(fileExtension: "png"))
        XCTAssertFalse(MIMEType.isMPEG4Video(fileExtension: "jpg"))
        XCTAssertTrue(MIMEType.isMPEG4Video(fileExtension: "mp4"))
        XCTAssertFalse(MIMEType.isMPEG4Video(fileExtension: "mp3"))
        XCTAssertFalse(MIMEType.isMPEG4Video(mime: "image/png"))
        XCTAssertFalse(MIMEType.isMPEG4Video(mime: "image/jpeg"))
        XCTAssertTrue(MIMEType.isMPEG4Video(mime: "video/mp4"))
        XCTAssertFalse(MIMEType.isMPEG4Video(mime: "audio/mp3"))
    }

    func testDataPNG() {
        let url = Bundle(for: type(of: self)).url(forResource: "testimage", withExtension: "png", subdirectory: "Fixtures")!
        let data = try! Data(contentsOf: url)

        XCTAssertEqual("image/png", MIMEType.mime(for: data))
    }

    func testDataOther() {
        let url = Bundle(for: type(of: self)).url(forResource: "e2ee_keys_claim_response_query_response", withExtension: "json", subdirectory: "Fixtures")!
        let data = try! Data(contentsOf: url)

        XCTAssertEqual("application/octet-stream", MIMEType.mime(for: data))
    }

    func testExtensionFromMIMEFromData() {
        let url = Bundle(for: type(of: self)).url(forResource: "testimage", withExtension: "png", subdirectory: "Fixtures")!
        let data = try! Data(contentsOf: url)

        XCTAssertEqual("png", MIMEType.fileExtension(for: MIMEType.mime(for: data)))
    }
}
