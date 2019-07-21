import Foundation

public class Validation {
    public enum ValidationError: Error {
        case usernameNil
        case passwordNil
        case homeserverNil
        case homeserverIsInvalidURL
        case emptyUsername
        case emptyPassword
        case emptyHomeserver
    }

    public typealias Credentials = (username: String, password: String, homeserver: URL)

    /// Validates and cleans the given credentials. Will return an error if literally anything is
    /// wrong, it's almost a little ridiculous. GLHF :)
    /// Will prepend `https://` when no scheme is specified in the homeserver string.
    ///
    /// - Returns: Cleaned and validated inputs.
    public static func validateLoginCredentials(username: String?, password: String?, homeserver: String?) -> Result<Credentials, Error> {
        return Result {
            (
                username: try validate(username: username),
                password: try validate(password: password),
                homeserver: try validate(homeserver: homeserver)
            )
        }
    }

    private static func validate(username: String?) throws -> String {
        guard var username = username else {
            throw ValidationError.usernameNil
        }
        username = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !username.isEmpty else {
            throw ValidationError.emptyUsername
        }

        return username
    }

    private static func validate(password: String?) throws -> String {
        guard let password = password else {
            throw ValidationError.passwordNil
        }

        guard !password.isEmpty else {
            throw ValidationError.emptyPassword
        }

        return password
    }

    private static func validate(homeserver: String?) throws -> URL {
        guard var homeserverString = homeserver else {
            throw ValidationError.homeserverNil
        }

        guard !homeserverString.isEmpty else {
            throw ValidationError.emptyHomeserver
        }

        if !homeserverString.lowercased().hasPrefix("http://"), !homeserverString.lowercased().hasPrefix("https://") {
            homeserverString = "https://\(homeserverString)"
        }

        guard let homeserver = URL(string: homeserverString) else {
            throw ValidationError.homeserverIsInvalidURL
        }

        return homeserver
    }
}
