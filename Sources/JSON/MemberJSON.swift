struct MemberJSON: JSONCodable, Hashable {
    /// The membership state of the user. One of: ["invite", "join", "knock", "leave", "ban"].
    let membership: Membership

    /// The display name for this user, if any. This is added by the homeserver.
    let displayname: String?
}

extension MemberJSON {
    enum Membership: String, Codable, Hashable {
        case invite
        case join
        case knock
        case leave
        case ban
    }
}
