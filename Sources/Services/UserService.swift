import Foundation

class UserService {
    private static let cache = MemoryCache<Image>()

    static func loadAvatar(userID: UserID, forceDownload: Bool = false, completionHandler: @escaping (Result<Image?>) -> Void) {
        if !forceDownload, let image = UserService.cache[userID] {
            completionHandler(.Value(image))
            return
        }

        MatrixAPI.default.getAvatarURL(userID: userID) { result in
            guard let avatarURLResponse = result.value else {
                completionHandler(.Error(result.error!))
                return
            }

            guard let url = avatarURLResponse.avatarURL else {
                UserService.cache[userID] = nil
                completionHandler(.Value(nil)) // No avatar
                return
            }

            downloadAvatar(userID: userID, url: url, completionHandler: completionHandler)
        }
    }

    private static func downloadAvatar(userID: UserID, url: URL, completionHandler: @escaping (Result<Image?>) -> Void) {
        MatrixAPI.default.downloadAvatar(mxcURL: url) { result in
            completionHandler(Result {
                let image = try result.dematerialize()
                UserService.cache[userID] = image
                return image
            })
        }
    }
}
