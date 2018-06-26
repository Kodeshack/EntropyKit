import GRDB

extension Message {
    public class Image: Record {
        let id: String
        let messageID: String
        let thumbnailID: String?
        let url: URL
        let width: UInt
        let height: UInt
        let MIMEType: String
        let size: UInt // Bytes
        let thumbnail: Image?

        init(id: String = "", messageID: String = "", url: URL, width: UInt, height: UInt, MIMEType: String, size: UInt) {
            self.id = id
            self.messageID = messageID
            self.url = url
            self.width = width
            self.height = height
            self.MIMEType = MIMEType
            self.size = size
            thumbnailID = nil
            thumbnail = nil
            super.init()
        }

        required init(row: Row) {
            id = row[Database.v0.media.id]
            messageID = row[Database.v0.media.messageID]
            thumbnailID = row[Database.v0.media.thumbnailID]
            url = row[Database.v0.media.url]
            height = row[Database.v0.media.height]
            width = row[Database.v0.media.width]
            size = row[Database.v0.media.size]
            MIMEType = row[Database.v0.media.type]

            if let thumbnail = row.scopes["thumbnail"] {
                self.thumbnail = Image(row: thumbnail)
            } else {
                thumbnail = nil
            }

            super.init(row: row)
        }

        var imageInfo: MessageJSON.ImageInfo {
            return MessageJSON.ImageInfo(height: height, width: width, size: size, MIMEType: MIMEType)
        }

        public override class var databaseTableName: String {
            return Database.v0.media.table
        }

        public override func encode(to container: inout PersistenceContainer) {
            container[Database.v0.media.id] = id
            container[Database.v0.media.messageID] = messageID
            container[Database.v0.media.thumbnailID] = thumbnailID
            container[Database.v0.media.url] = url
            container[Database.v0.media.height] = height
            container[Database.v0.media.width] = width
            container[Database.v0.media.size] = size
            container[Database.v0.media.type] = MIMEType
        }
    }
}
