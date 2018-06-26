struct LoginResponse: JSONDecodable {
    /// The fully-qualified Matrix ID that has been registered.
    let userID: UserID

    /// An access token for the account. This access token can then be used to authorize other requests.
    let accessToken: String

    /// ID of the logged-in device. Will be the same as the corresponding parameter in the request, if one was specified.
    let deviceID: DeviceID

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case accessToken = "access_token"
        case deviceID = "device_id"
    }
}
