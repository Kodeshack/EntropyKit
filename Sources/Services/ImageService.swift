class ImageService {
    static func loadImage(mxcURL: URL, completionHandler: @escaping (Result<Image>) -> Void) {
        MatrixAPI.default.downloadImage(mxcURL: mxcURL, completionHandler: completionHandler)
    }
}

extension ImageService {
    static func uploadImage(filename: String, mimeType: String, data: Data, accessToken: String, completionHandler: @escaping (Result<String>) -> Void) {
        MatrixAPI.default.__upload(filename: filename, mimeType: mimeType, data: data, accessToken: accessToken, completionHandler: completionHandler)
    }
}
