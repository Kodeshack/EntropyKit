import Alamofire

protocol JSONEncodable: Encodable, ParameterEncoding {}

extension JSONEncodable {
    var encoded: Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let data = try! encoder.encode(self)
        let json = String(data: data, encoding: .utf8)!.replacingOccurrences(of: "\\/", with: "/") // 🔞
        return json.data(using: .utf8)!
    }

    func encode(_ urlRequest: URLRequestConvertible, with _: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()

        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        urlRequest.httpBody = encoded

        return urlRequest
    }

    var stringValue: String {
        String(data: encoded, encoding: .utf8)!
    }

    #if DEBUG
        func print() {
            Swift.print(stringValue)
        }
    #endif
}
