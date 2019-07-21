import Foundation

class UserService {
    private static let cache = MemoryCache<Image>()

    static func loadAvatar(userID: UserID, forceDownload: Bool = false, completionHandler: @escaping (Result<Image?, Error>) -> Void) {
        if !forceDownload, let image = UserService.cache[userID] {
            completionHandler(.success(image))
            return
        }

        MatrixAPI.default.getAvatarURL(userID: userID) { result in
            guard let avatarURLResponse = result.success else {
                completionHandler(.failure(result.failure!))
                return
            }

            guard let url = avatarURLResponse.avatarURL else {
                UserService.cache[userID] = nil
                completionHandler(.success(nil)) // No avatar
                return
            }

            downloadAvatar(userID: userID, url: url, completionHandler: completionHandler)
        }
    }

    private static func downloadAvatar(userID: UserID, url: URL, completionHandler: @escaping (Result<Image?, Error>) -> Void) {
        MatrixAPI.default.downloadAvatar(mxcURL: url) { result in
            completionHandler(Result {
                let image = try result.get()
                UserService.cache[userID] = image
                return image
            })
        }
    }
}
