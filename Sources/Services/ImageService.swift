class ImageService {
    static func loadThumbnail(for message: Message, completionHandler: @escaping (Result<Image, Error>) -> Void) {
        guard let info = message.attachment?.thumbnailInfo ?? message.attachment?.info else {
            completionHandler(.failure(Attachment.AttachmentError.missingAttachment))
            return
        }

        MatrixAPI.default.downloadImage(mxcURL: info.mxcURL, cryptoInfo: info.cryptoInfo, completionHandler: completionHandler)
    }

    static func loadImage(for message: Message, completionHandler: @escaping (Result<Image, Error>) -> Void) {
        guard let info = message.attachment?.info else {
            completionHandler(.failure(Attachment.AttachmentError.missingAttachment))
            return
        }

        MatrixAPI.default.downloadImage(mxcURL: info.mxcURL, cryptoInfo: info.cryptoInfo, completionHandler: completionHandler)
    }
}

extension ImageService {
    static func uploadImage(filename: String, mimeType: String, data: Data, accessToken: String, completionHandler: @escaping (Result<String, Error>) -> Void) {
        MatrixAPI.default.upload(filename: filename, mimeType: mimeType, data: data, accessToken: accessToken, completionHandler: completionHandler)
    }
}
