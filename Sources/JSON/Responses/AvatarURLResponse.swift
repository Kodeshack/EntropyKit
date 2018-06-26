import Foundation

struct AvatarURLResponse: JSONDecodable {
    let avatarURL: URL?

    private enum CodingKeys: String, CodingKey {
        case avatarURL = "avatar_url"
    }
}
