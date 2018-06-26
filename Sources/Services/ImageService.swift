class ImageService {
    static func loadImage(mxcURL: URL, completionHandler: @escaping (Result<Image>) -> Void) {
        MatrixAPI.default.downloadImage(mxcURL: mxcURL, completionHandler: completionHandler)
    }
}

extension ImageService {
    static func uploadImage(file: Data, accessToken: String, completionHandler: @escaping (Result<String>) -> Void) {
        MatrixAPI.default.uploadImage(image: file, accessToken: accessToken, completionHandler: completionHandler)
    }
}
