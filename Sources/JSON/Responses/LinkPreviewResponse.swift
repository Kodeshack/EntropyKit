import Foundation

struct LinkPreviewResponse: JSONDecodable {
    let title: String
    let description: String?

    /// An MXC URI to the image. `nil` if there is no image.
    let imageMXCURL: URL?

    // For internal purposes.
    /// The preview image. `nil` if there is no image.
    var image: Image?

    private enum CodingKeys: String, CodingKey {
        case title = "og:title"
        case description = "og:description"
        case imageMXCURL = "og:image"
    }
}
