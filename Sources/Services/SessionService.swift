class SessionService {
    static func login(username: String, password: String, database: Database, completionHandler: @escaping (Result<Account>) -> Void) {
        MatrixAPI.default.login(username: username, password: password) { loginResponseResult in
            completionHandler(Result {
                let loginResponse = try loginResponseResult.dematerialize()
                return try Account.create(userID: loginResponse.userID, accessToken: loginResponse.accessToken, deviceID: loginResponse.deviceID, cryptoEngine: CryptoEngine(), database: database) { account in
                    account.nextBatch = ""
                }
            })
        }
    }

    static func logout(account: Account, completionHandler: @escaping (Error?) -> Void) throws {
        MatrixAPI.default.logout(accessToken: account.accessToken, completionHandler: completionHandler)
    }
}

extension SessionService {
    enum TokenError: Error {
        case emptyToken
        case invalidToken
    }
}
