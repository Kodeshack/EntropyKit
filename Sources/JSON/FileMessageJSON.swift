
struct FileMessageJSON: MessageJSON {
    let body: String
    let type: Message.MessageType
    let info: Info
    let file: EncryptedAttachment?
    let url: URL?

    var eventContent: Event.Content {
        return .fileMessage(self)
    }

    init(type: Message.MessageType, filename: String, info: Info, file: EncryptedAttachment) {
        self.type = type
        body = filename
        self.info = info
        url = nil
        self.file = file
    }

    init(type: Message.MessageType, filename: String, info: Info, url: URL) {
        self.type = type
        body = filename
        self.info = info
        self.url = url
        file = nil
    }

    private enum CodingKeys: String, CodingKey {
        case body
        case type = "msgtype"
        case info
        case file
        case url
    }
}

extension FileMessageJSON {
    struct Info: JSONCodable, Hashable {
        let width: UInt?
        let height: UInt?
        let size: UInt
        let mimeType: String
        let thumbnailInfo: ThumbnailInfo?
        let thumbnailFile: EncryptedAttachment?

        init(width: UInt?, height: UInt?, size: UInt, mimeType: String, thumbnailInfo: ThumbnailInfo?, thumbnailFile: EncryptedAttachment?) {
            self.width = width
            self.height = height
            self.size = size
            self.mimeType = mimeType
            self.thumbnailInfo = thumbnailInfo
            self.thumbnailFile = thumbnailFile
        }

        private enum CodingKeys: String, CodingKey {
            case width = "w"
            case height = "h"
            case size
            case mimeType = "mimetype"
            case thumbnailInfo = "thumbnail_info"
            case thumbnailFile = "thumbnail_file"
        }
    }
}

extension FileMessageJSON.Info {
    struct ThumbnailInfo: JSONCodable, Hashable {
        let width: UInt
        let height: UInt
        let size: UInt
        let mimetype: String

        private enum CodingKeys: String, CodingKey {
            case width = "w"
            case height = "h"
            case size
            case mimetype
        }
    }
}
