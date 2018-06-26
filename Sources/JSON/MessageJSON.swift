import Foundation

struct MessageJSON: JSONCodable, Hashable {
    let body: String
    let type: Message.MessageType

    let imageInfo: ImageInfo?
    let thumbnailInfo: ImageInfo?
    let imageURL: URL?
    let thumbnailURL: URL?

    private enum CodingKeys: String, CodingKey {
        case body
        case type = "msgtype"
        case imageInfo = "info"
        case thumbnailInfo = "thumbnail_info"
        case imageURL = "url"
        case thumbnailURL = "thumbnail_url"
    }

    init(body: String, type: Message.MessageType, imageInfo: ImageInfo? = nil, imageURL: URL? = nil, thumbnailInfo: ImageInfo? = nil, thumbnailURL: URL? = nil) {
        assert(type != .image || (imageInfo != nil && imageURL != nil), "Image message without image!")
        self.body = body
        self.type = type
        self.imageInfo = imageInfo
        self.imageURL = imageURL
        self.thumbnailInfo = thumbnailInfo
        self.thumbnailURL = thumbnailURL
    }
}

extension MessageJSON {
    struct ImageInfo: Codable, Hashable {
        let height: UInt
        let width: UInt
        let size: UInt
        let MIMEType: String
        private enum CodingKeys: String, CodingKey {
            case height = "h"
            case width = "w"
            case size
            case MIMEType = "mimetype"
        }
    }
}
