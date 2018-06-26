struct UploadResponse: JSONDecodable {
    let contentURI: String

    private enum CodingKeys: String, CodingKey {
        case contentURI = "content_uri"
    }
}
