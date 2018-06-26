struct LoginRequest: JSONEncodable {
    /// The fully qualified user ID or just local part of the user ID, to log in.
    let userID: UserID

    /// Required when type is m.login.password. The user's password.
    let password: String

    /// The login type being used.
    let loginType: LoginType

    /// ID of the client device. If this does not correspond to a known client device, a new device will be created.
    /// The server will auto-generate a device_id if this is not specified.
    let deviceID: DeviceID?

    private enum CodingKeys: String, CodingKey {
        case userID = "user"
        case password
        case loginType = "type"
        case deviceID = "device_id"
    }

    init(userID: UserID, password: String, loginType: LoginType = .password, deviceID: DeviceID? = nil) {
        self.userID = userID
        self.password = password
        self.loginType = loginType
        self.deviceID = deviceID
    }
}

extension LoginRequest {
    enum LoginType: String, Encodable {
        /// The client submits a username and secret password, both sent in plain-text
        case password = "m.login.password"

        /// The user completes a Google ReCaptcha 2.0 challenge
        case recaptcha = "m.login.recaptcha"

        /// Authentication is supported via OAuth2 URLs. This login consists of multiple requests.
        case oauth2 = "m.login.oauth2"

        /// Authentication is supported by authorising an email address with an identity server.
        case email = "m.login.email.identity"

        /// The client submits a login token.
        case token = "m.login.token"

        /// Dummy authentication always succeeds and requires no extra parameters.
        /// Its purpose is to allow servers to not require any form of User-Interactive Authentication to perform a request.
        case dummy = "m.login.dummy"
    }
}
