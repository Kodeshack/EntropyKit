#if canImport(UIKit)
    import UIKit
    typealias Image = UIImage
#elseif canImport(AppKit)
    import AppKit
    typealias Image = NSImage
#else
    #error("Can neither import UIKit nor AppKit, something's very wrong.")
#endif

import Alamofire

class MatrixAPI {
    enum APIError: Error {
        case invalidFile
        case invalidEncoding
    }

    static let `default` = MatrixAPI()

    var baseURL: String!

    private enum APINamespace {
        case client
        case media

        func url(baseURL: String) -> String {
            switch self {
            case .client:
                return "\(baseURL)/_matrix/client/r0"
            case .media:
                return "\(baseURL)/_matrix/media/r0"
            }
        }
    }

    private enum Endpoint: String {
        case login
        case logout
        case download
        case upload
        case profile
        case rooms
        case sync
        case previewURL = "preview_url"

        // E2EE
        case claimKeys = "keys/claim"
        case newDevice = "sendToDevice/m.new_device"
        case keyUpload = "keys/upload"
        case queryKeys = "keys/query"
        case publishSession = "sendToDevice/m.room.encrypted"
    }

    static var defaultUserAgent: String {
        let headers = Alamofire.SessionManager.defaultHTTPHeaders
        return headers["User-Agent"]!
    }

    var userAgent: String {
        get {
            let configuration = sessionManager.session.configuration
            let headers = configuration.httpAdditionalHeaders
            return headers!["User-Agent"] as! String
        }
        set {
            sessionManager = MatrixAPI.createSessionManager(for: newValue)
        }
    }

    private var sessionManager: SessionManager

    init() {
        sessionManager = MatrixAPI.createSessionManager(for: Settings.userAgent)

        // Register to update User-Agent when needed.
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: OperationQueue.main) { _ in
            let setUserAgent = Settings.userAgent ?? MatrixAPI.defaultUserAgent
            if self.userAgent != setUserAgent {
                self.userAgent = setUserAgent
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private static func createSessionManager(for userAgent: String?) -> SessionManager {
        let configuration = URLSessionConfiguration.default
        var defaultHeaders = Alamofire.SessionManager.defaultHTTPHeaders

        if let userAgent = userAgent {
            defaultHeaders["User-Agent"] = userAgent
        }
        configuration.httpAdditionalHeaders = defaultHeaders
        return Alamofire.SessionManager(configuration: configuration)
    }

    private func createRequest(for endpoint: Endpoint, path: String? = nil, accessToken: String? = nil, transactionID: UInt? = nil, method: HTTPMethod = .get, payload: ParameterEncoding? = nil) -> DataRequest {
        let url = constructURL(for: endpoint, path: path, using: accessToken, transactionID: transactionID)

        let request: DataRequest
        if let payload = payload {
            request = sessionManager.request(url, method: method, encoding: payload)
        } else {
            request = sessionManager.request(url, method: method)
        }

        return request
            .validate()
            .validate(contentType: ["application/json"])
    }

    private func createRequest(in apiNamespace: APINamespace = .client, for endpoint: Endpoint, path: String? = nil, accessToken: String? = nil, transactionID: UInt? = nil, method: HTTPMethod = .get, parameters: Parameters) -> DataRequest {
        let url = constructURL(for: endpoint, path: path, in: apiNamespace, transactionID: transactionID)

        var parameters = parameters
        parameters["access_token"] = accessToken

        let request = sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.queryString)

        return request
            .validate()
            .validate(contentType: ["application/json"])
    }

    func getMediaURL(_ mxcURL: URL, accessToken: String? = nil) -> URL {
        let string = mxcURL.absoluteString
        let startIndex = string.index(string.startIndex, offsetBy: "mxc://".count) // remove the mxc://
        let path = String(string[startIndex...])
        return URL(string: constructURL(for: .download, path: path, in: .media, using: accessToken))!
    }

    private func constructURL(for endpoint: Endpoint, path: String? = nil, in apiNamespace: APINamespace = .client, using accessToken: String? = nil, transactionID: UInt? = nil) -> String {
        var url = "\(apiNamespace.url(baseURL: baseURL))/\(endpoint.rawValue)"

        if let path = path {
            url += "/\(path)"
        }

        if let txnID = transactionID {
            url += "/\(txnID)"
        }

        if let accessToken = accessToken, !accessToken.isEmpty {
            url += "?access_token=\(accessToken)"
        }

        return url
    }

    private func createRequest(url: URL) -> DataRequest {
        return sessionManager.request(url).validate()
    }
}

// MARK: Images

extension MatrixAPI {
    /// Downloads the image from the given mxc URL.
    ///
    /// - Parameters:
    ///   - mxcURL: mxc url to download.
    ///   - queue: Dispatch queue on which to execute the callback. Defaults to main queue.
    ///   - completionHandler: Called with the resulting NSImage instance (or Error) when the request has ended (whether successfully or unsuccessfully).
    func downloadImage(mxcURL: URL, queue: DispatchQueue = DispatchQueue.main, completionHandler: @escaping (Result<Image>) -> Void) {
        createRequest(url: getMediaURL(mxcURL)).responseData(queue: queue) { response in
            completionHandler(Result {
                let data = try response.result.unwrap()
                guard let image = Image(data: data) else {
                    throw APIError.invalidFile
                }
                return image
            })
        }
    }

    /// Uploads an image
    ///
    /// - Parameters:
    ///   - image: image data to upload.
    ///   - queue: Dispatch queue on which to execute the callback. Defaults to main queue.
    ///   - completionHandler: Called with the resulting content URI (or Error) when the request has ended (whether successfully or unsuccessfully).
    func uploadImage(image: Data, accessToken: String, queue: DispatchQueue = DispatchQueue.main, completionHandler: @escaping (Result<String>) -> Void) {
        let url = constructURL(for: .upload, in: .media, using: accessToken)
        sessionManager.upload(image, to: url, method: .post)
            .validate()
            .validate(contentType: ["application/json"])
            .responseJSON(queue: queue) { response in

                guard response.result.isSuccess else {
                    completionHandler(.Error(response.result.error!))
                    return
                }

                let uploadResponseResult = UploadResponse.decode(response.data)
                guard let uploadResponse = uploadResponseResult.value else {
                    completionHandler(.Error(uploadResponseResult.error!))
                    return
                }

                completionHandler(.Value(uploadResponse.contentURI))
            }
    }
}

// MARK: Users

extension MatrixAPI {
    /// Retrieve a full avatar url response object from the server.
    ///
    /// - Parameters:
    ///   - userID: ID for which to retrieve the information.
    ///   - queue: Dispatch queue on which to execute the callback. Defaults to main queue.
    ///   - completionHandler: Called when the request has ended (whether successfully or unsuccessfully).
    func getAvatarURL(userID: UserID, queue: DispatchQueue = DispatchQueue.main, completionHandler: @escaping (Result<AvatarURLResponse>) -> Void) {
        createRequest(for: .profile, path: "\(userID)/avatar_url")
            .responseJSON(queue: queue) { response in
                guard response.result.isSuccess else {
                    completionHandler(.Error(response.result.error!))
                    return
                }

                completionHandler(AvatarURLResponse.decode(response.data))
            }
    }

    /// Downloads the avatar from the given mxc url.
    /// NOTE: this does not save the image anywhere, just returns an instance of NSImage.
    ///
    /// - Parameters:
    ///   - mxcURL: mxc url to download.
    ///   - queue: Dispatch queue on which to execute the callback. Defaults to main queue.
    ///   - completionHandler: Called with the resulting NSImage instance (or Error) when the request has ended (whether successfully or unsuccessfully).
    func downloadAvatar(mxcURL: URL, queue: DispatchQueue = DispatchQueue.main, completionHandler: @escaping (Result<Image>) -> Void) {
        downloadImage(mxcURL: mxcURL, queue: queue, completionHandler: completionHandler)
    }
}

// MARK: Login/Logout

extension MatrixAPI {
    /// Login using the username and password method. Returns the login response object, not a ready account.
    ///
    /// - Parameters:
    ///   - username: username to login with.
    ///   - password: password to login with.
    ///   - queue: Dispatch queue on which to execute the callback. Defaults to main queue.
    ///   - completionHandler: Called with the resulting login data (or Error) when the request has ended (whether successfully or unsuccessfully).
    func login(username: String, password: String, queue: DispatchQueue = DispatchQueue.main, completionHandler: @escaping (Result<LoginResponse>) -> Void) {
        let request = LoginRequest(userID: username, password: password)
        createRequest(for: .login, method: .post, payload: request)
            .responseJSON(queue: queue) { response in
                guard response.result.isSuccess else {
                    completionHandler(.Error(response.result.error!))
                    return
                }

                completionHandler(LoginResponse.decode(response.data))
            }
    }

    /// Logout by invalidating the supplied access token.
    ///
    /// - Parameters:
    ///   - accessToken: Token to invalidate.
    ///   - queue: Dispatch queue on which to execute the callback. Defaults to main queue.
    ///   - completionHandler: Called when the request has ended (whether successfully or unsuccessfully). In a success case there is no extra data.
    func logout(accessToken: String, queue: DispatchQueue = DispatchQueue.main, completionHandler: @escaping (Error?) -> Void) {
        createRequest(for: .logout, accessToken: accessToken, method: .post)
            .responseJSON(queue: queue) { response in
                completionHandler(response.error)
            }
    }
}

// MARK: Sending Messages

extension MatrixAPI {
    /// Send an event to a room.
    ///
    /// https://matrix.org/docs/spec/client_server/r0.3.0.html#put-matrix-client-r0-rooms-roomid-send-eventtype-txnid
    ///
    /// - Parameters:
    ///   - body: Event data to send.
    ///   - eventType: Event type that is sent.
    ///   - roomID: Room the message will be sent to.
    ///   - accessToken: User's access token.
    ///   - transactionID: Transaction ID for this request.
    ///   - queue: Dispatch queue on which to execute the callback.
    ///   - completionHandler: Called with the response (or error) when the request has ended (whether successfully or unsuccessfully).
    func send(body: JSONEncodable, eventType: Event.EventsType, to roomID: RoomID, accessToken: String, transactionID: UInt, queue: DispatchQueue = DispatchQueue.main, completionHandler: @escaping (Result<EventResponse>) -> Void) {
        createRequest(for: .rooms, path: "\(roomID)/send/\(eventType.rawValue)", accessToken: accessToken, transactionID: transactionID, method: .put, payload: body)
            .responseJSON(queue: queue) { response in
                guard response.result.isSuccess else {
                    completionHandler(.Error(response.result.error!))
                    return
                }

                completionHandler(EventResponse.decode(response.data))
            }
    }
}

// MARK: Syncing

extension MatrixAPI {
    /// Send a sync request to the server.
    ///
    /// - Parameters:
    ///   - timeout: Time to wait before the server will end the request.
    ///   - nextBatch: Next batch to request from the server.
    ///   - accessToken: User's access token.
    ///   - queue: Dispatch queue on which to execute the callback.
    ///   - completionHandler: Called with the response (or error) when the request has ended (whether successfully or unsuccessfully).
    func sync(timeout: Int, nextBatch: String = "", accessToken: String, queue: DispatchQueue, completionHandler: @escaping (Result<SyncResponse>) -> Void = { _ in }) {
        var params: Parameters = [
            "timeout": timeout,
        ]

        // we need to check this manually because a empty string will cause an error on the server
        if !nextBatch.isEmpty {
            params["since"] = nextBatch
        }

        createRequest(for: .sync, accessToken: accessToken, parameters: params)
            .responseJSON(queue: queue) { response in
                guard response.result.isSuccess else {
                    completionHandler(.Error(response.result.error!))
                    return
                }

                completionHandler(SyncResponse.decode(response.data))
            }
    }
}

// MARK: E2EE

extension MatrixAPI {
    /// Claim one time keys for devices to create OLM sessions.
    ///
    /// https://matrix.org/docs/guides/e2e_implementation.html#curve25519-one-time-keys
    /// https://matrix.org/docs/spec/client_server/r0.3.0.html#claiming-one-time-keys
    ///
    /// - Parameters:
    ///   - accessToken: User's access token.
    ///   - keysClaimRequest: Keys to claim.
    ///   - queue: Dispatch queue on which to execute the callback.
    ///   - completionHandler: Called with the response (or error) when the request has ended (whether successfully or unsuccessfully).
    func claimKeys(accessToken: String, keysClaimRequest: KeysClaimRequest, queue: DispatchQueue, completionHandler: @escaping (Result<KeysClaimResponse>) -> Void) {
        createRequest(for: .claimKeys, accessToken: accessToken, method: .post, payload: keysClaimRequest)
            .responseData(queue: queue) { response in
                completionHandler(Result {
                    let data = try response.result.unwrap()
                    return try KeysClaimResponse.decode(data).dematerialize()
                })
            }
    }

    /// Announce this device to the other devices on the server.
    ///
    /// https://matrix.org/docs/guides/e2e_implementation.html#sending-new-device-announcements
    /// https://matrix.org/docs/spec/client_server/r0.3.0.html#put-matrix-client-r0-sendtodevice-eventtype-txnid
    ///
    /// - Parameters:
    ///   - accessToken: User's access token.
    ///   - transactionID: Transaction ID for this request.
    ///   - deviceAnnouncementRequest: The device that will be announces (should be the device that this code is running on).
    ///   - completionHandler: Called with the response (or error) when the request has ended (whether successfully or unsuccessfully).
    func announceDevice(accessToken: String, transactionID: UInt, deviceAnnouncementRequest: DeviceAnnouncementRequest, completionHandler: @escaping (Result<()>) -> Void) {
        createRequest(for: .newDevice, accessToken: accessToken, transactionID: transactionID, method: .put, payload: deviceAnnouncementRequest)
            .responseData { response in
                completionHandler(Result {
                    let data = try response.result.unwrap()
                    _ = try EmptyJSON.decode(data).dematerialize()
                })
            }
    }

    /// Upload the keys for this device that enable other devices to send this device encrypted messages.
    ///
    /// https://matrix.org/docs/guides/e2e_implementation.html#creating-and-registering-device-keys
    /// https://matrix.org/docs/guides/e2e_implementation.html#creating-and-registering-one-time-keys
    /// https://matrix.org/docs/spec/client_server/r0.3.0.html#post-matrix-client-r0-keys-upload
    /// https://matrix.org/docs/spec/client_server/r0.3.0.html#uploading-keys
    ///
    /// - Parameters:
    ///   - accessToken: User's access token.
    ///   - deviceID: Keys to claim.
    ///   - keysUploadRequest: Keys to upload. Set request to nil to check key count (<- this is pretty stupid).
    ///   - queue: Dispatch queue on which to execute the callback.
    ///   - completionHandler: Called with the response (or error) when the request has ended (whether successfully or unsuccessfully).
    func uploadKeys(accessToken: String, deviceID: String, keysUploadRequest: KeysUploadRequest?, queue: DispatchQueue, completionHandler: @escaping (Result<UInt>) -> Void) {
        createRequest(for: .keyUpload, path: deviceID, accessToken: accessToken, method: .post, payload: keysUploadRequest ?? EmptyJSON())
            .responseData(queue: queue) { response in
                completionHandler(Result {
                    let data = try response.result.unwrap()

                    let keysUploadReponse = try KeysUploadResponse.decode(data).dematerialize()
                    guard let signedCurve25519KeyCount = keysUploadReponse.oneTimeKeyCounts[CryptoEngine.CryptoKeys.signedCurve25519.rawValue] else {
                        throw JSONError.invalidFormat
                    }
                    return signedCurve25519KeyCount
                })
            }
    }

    /// Get device and identity keys from server.
    ///
    /// https://matrix.org/docs/spec/client_server/r0.3.0.html#post-matrix-client-r0-keys-query
    ///
    /// - Parameters:
    ///   - accessToken: User's access token.
    ///   - keysQueryRequest: Keys to query.
    ///   - queue: Dispatch queue on which to execute the callback.
    ///   - completionHandler: Called with the response (or error) when the request has ended (whether successfully or unsuccessfully).
    func queryKeys(accessToken: String, keysQueryRequest: KeysQueryRequest, queue: DispatchQueue, completionHandler: @escaping (Result<KeysQueryResponse>) -> Void) {
        createRequest(for: .queryKeys, accessToken: accessToken, method: .post, payload: keysQueryRequest)
            .responseData(queue: queue) { response in
                completionHandler(Result {
                    let data = try response.result.unwrap()
                    return try KeysQueryResponse.decode(data).dematerialize()
                })
            }
    }

    /// Publish this device's sessions to be used by other devices.
    /// We do not know, how we got here, but this works ¯\_(ツ)_/¯
    ///
    /// https://matrix.org/docs/guides/e2e_implementation.html#starting-a-megolm-session
    ///
    /// - Parameters:
    ///   - accessToken: User's access token.
    ///   - transactionID: Transaction ID for this request.
    ///   - publishRoomKeysRequest: Session keys to publish.
    ///   - queue: Dispatch queue on which to execute the callback.
    ///   - completionHandler: Called with the response (or error) when the request has ended (whether successfully or unsuccessfully).
    func publishSession(accessToken: String, transactionID: UInt, publishRoomKeysRequest: PublishRoomKeysRequest, queue: DispatchQueue, completionHandler: @escaping (Result<Void>) -> Void) {
        createRequest(for: .publishSession, accessToken: accessToken, transactionID: transactionID, method: .put, payload: publishRoomKeysRequest)
            .responseJSON(queue: queue) { response in
                completionHandler(Result {
                    _ = try response.result.unwrap()
                })
            }
    }
}

// MARK: Link Preview

extension MatrixAPI {
    /// Requests the preview info of a given URL from the server.
    ///
    /// - Parameters:
    ///   - url: The URL to get a preview of.
    ///   - timestamp: The preferred point in time to return a preview for. The server may return a newer version if it does not have the requested version available.
    ///   - accessToken: User's access token.
    ///   - queue: Dispatch queue on which to execute the callback.
    ///   - completionHandler: Called with the response (or error) when the request has ended (whether successfully or unsuccessfully).
    func requestLinkPreviewInfo(for url: URL, at timestamp: UInt? = nil, accessToken: String, queue: DispatchQueue = DispatchQueue.main, completionHandler: @escaping (Result<LinkPreviewResponse>) -> Void) {
        var parameters = ["url": url.absoluteString]

        if let timestamp = timestamp {
            parameters["ts"] = String(timestamp)
        }

        createRequest(in: .media, for: .previewURL, accessToken: accessToken, parameters: parameters)
            .responseData(queue: queue) { response in
                let infoResult = Result<LinkPreviewResponse> {
                    let data = try response.result.unwrap()
                    return try LinkPreviewResponse.decode(data).dematerialize()
                }

                guard var info = infoResult.value else {
                    completionHandler(.Error(infoResult.error!))
                    return
                }

                guard let mxcURL = info.imageMXCURL else {
                    completionHandler(.Value(info))
                    return
                }

                MatrixAPI.default.downloadImage(mxcURL: mxcURL, queue: queue) { result in
                    completionHandler(Result {
                        info.image = try result.dematerialize()
                        return info
                    })
                }
            }
    }
}
