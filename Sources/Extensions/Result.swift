extension Swift.Result {
    public var isFailure: Bool {
        if case .failure = self {
            return true
        }
        return false
    }

    public var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    public var success: Success? {
        if case let .success(value) = self {
            return value
        }
        return nil
    }

    public var failure: Failure? {
        if case let .failure(error) = self {
            return error
        }
        return nil
    }
}
