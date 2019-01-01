import GRDB

public class Attachment: Record {
    let messageID: String

    let info: Info
    let thumbnailInfo: Info?

    init?(event: Event) {
        guard let eventID = event.id else { return nil }
        guard event.type == .message else { return nil }

        guard case let .fileMessage(message) = event.content else { return nil }
        guard message.type == .file || message.type == .image else { return nil }

        messageID = eventID

        guard let mxcURL = message.file?.mxcURL ?? message.url else { return nil }

        info = Info(from: message.info, file: message.file, for: mxcURL)

        if
            let info = message.info.thumbnailInfo,
            let file = message.info.thumbnailFile,
            let thumbMxcURL = file.mxcURL {
            thumbnailInfo = Info(from: info, file: file, for: thumbMxcURL)
        } else {
            thumbnailInfo = nil
        }

        super.init()
    }

    required init(row: Row) {
        messageID = row[Database.v0.attachments.messageID]
        info = Info(from: row)

        // @TODO: probably check all values? This is more of a litmus test
        if row[Database.v0.attachments.thumbnailMXCURL] != nil {
            thumbnailInfo = Info(from: row, thumbnail: true)
        } else {
            thumbnailInfo = nil
        }

        super.init(row: row)
    }

    public override class var databaseTableName: String {
        return Database.v0.attachments.table
    }

    public override func encode(to container: inout PersistenceContainer) {
        container[Database.v0.attachments.messageID] = messageID
        info.encode(to: &container)
        thumbnailInfo?.encode(to: &container, thumbnail: true)
    }
}

extension Attachment {
    struct Info {
        let mxcURL: URL

        let mimetype: String
        let size: UInt

        let cryptoInfo: CryptoInfo?

        let width: UInt?
        let height: UInt?

        init(from info: FileMessageJSON.Info, file: EncryptedAttachment?, for mxcURL: URL) {
            self.mxcURL = mxcURL
            mimetype = info.mimeType
            size = info.size
            width = info.width
            height = info.height
            if let file = file {
                cryptoInfo = CryptoInfo(for: file)
            } else {
                cryptoInfo = nil
            }
        }

        init(from info: FileMessageJSON.Info.ThumbnailInfo, file: EncryptedAttachment, for mxcURL: URL) {
            self.mxcURL = mxcURL
            mimetype = info.mimetype
            size = info.size
            width = info.width
            height = info.height
            cryptoInfo = CryptoInfo(for: file)
        }

        init(from row: Row, thumbnail: Bool = false) {
            if !thumbnail {
                mxcURL = row[Database.v0.attachments.mxcURL]
                mimetype = row[Database.v0.attachments.MIMEType]
                size = row[Database.v0.attachments.size]
                width = row[Database.v0.attachments.width]
                height = row[Database.v0.attachments.height]
            } else {
                mxcURL = row[Database.v0.attachments.thumbnailMXCURL]
                mimetype = row[Database.v0.attachments.thumbnailMIMEType]
                size = row[Database.v0.attachments.thumbnailSize]
                width = row[Database.v0.attachments.thumbnailWidth]
                height = row[Database.v0.attachments.thumbnailHeight]
            }
            cryptoInfo = CryptoInfo(from: row, thumbnail: thumbnail)
        }

        func encode(to container: inout PersistenceContainer, thumbnail: Bool = false) {
            if !thumbnail {
                container[Database.v0.attachments.mxcURL] = mxcURL
                container[Database.v0.attachments.MIMEType] = mimetype
                container[Database.v0.attachments.size] = size
                container[Database.v0.attachments.width] = width
                container[Database.v0.attachments.height] = height
            } else {
                container[Database.v0.attachments.thumbnailMXCURL] = mxcURL
                container[Database.v0.attachments.thumbnailMIMEType] = mimetype
                container[Database.v0.attachments.thumbnailSize] = size
                container[Database.v0.attachments.thumbnailWidth] = width
                container[Database.v0.attachments.thumbnailHeight] = height
            }
            cryptoInfo?.encode(to: &container, thumbnail: thumbnail)
        }
    }
}

extension Attachment.Info {
    struct CryptoInfo {
        let algorithm: EncryptedAttachment.EncryptedAttachmentKey.AttachmentEncyptionKeyAlgorithm
        let key: Data
        let initializationVector: Data
        let sha256: String

        init(for file: EncryptedAttachment) {
            algorithm = file.key.algorithm
            key = file.key.key.data
            initializationVector = file.initializationVector.data
            sha256 = file.hashes.sha256
        }

        init(from row: Row, thumbnail: Bool = false) {
            if !thumbnail {
                algorithm = EncryptedAttachment.EncryptedAttachmentKey.AttachmentEncyptionKeyAlgorithm(rawValue: row[Database.v0.attachments.algorithm])!
                key = row[Database.v0.attachments.key]
                initializationVector = row[Database.v0.attachments.initializationVector]
                sha256 = row[Database.v0.attachments.sha256]
            } else {
                algorithm = EncryptedAttachment.EncryptedAttachmentKey.AttachmentEncyptionKeyAlgorithm(rawValue: row[Database.v0.attachments.thumbnailAlgorithm])!
                key = row[Database.v0.attachments.thumbnailKey]
                initializationVector = row[Database.v0.attachments.thumbnailInitializationVector]
                sha256 = row[Database.v0.attachments.thumbnailSha256]
            }
        }

        func encode(to container: inout PersistenceContainer, thumbnail: Bool = false) {
            if !thumbnail {
                container[Database.v0.attachments.algorithm] = algorithm.rawValue
                container[Database.v0.attachments.key] = key
                container[Database.v0.attachments.initializationVector] = initializationVector
                container[Database.v0.attachments.sha256] = sha256
            } else {
                container[Database.v0.attachments.thumbnailAlgorithm] = algorithm.rawValue
                container[Database.v0.attachments.thumbnailKey] = key
                container[Database.v0.attachments.thumbnailInitializationVector] = initializationVector
                container[Database.v0.attachments.thumbnailSha256] = sha256
            }
        }
    }
}

extension Attachment {
    enum AttachmentError: Error {
        case missingAttachment
    }
}
