import Foundation

/// A small JSON client over `URLSession`. Errors carry the URL and status, so
/// a log line or a toast says what failed without a debugger.
struct HTTPClient: Sendable {
    var baseURL: URL
    var headers: [String: String] = [:]
    var session: URLSession = .shared

    enum Failure: LocalizedError {
        case transport(URL, String)
        case status(URL, Int, String)
        case decoding(URL, String)

        var errorDescription: String? {
            switch self {
            case let .transport(url, message):
                "Cannot reach \(url.host() ?? url.absoluteString): \(message)"
            case let .status(url, code, body): "HTTP \(code) from \(url.path)\(body.isEmpty ? "" : ": \(body)")"
            case let .decoding(url, message): "Unexpected response from \(url.path): \(message)"
            }
        }
    }

    func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        try await request(path: path, method: "GET", body: nil, as: type)
    }

    func send<T: Decodable>(
        _ path: String,
        method: String = "POST",
        body: some Encodable,
        as type: T.Type = T.self
    ) async throws -> T {
        try await request(path: path, method: method, body: JSONEncoder().encode(body), as: type)
    }

    private func request<T: Decodable>(
        path: String,
        method: String,
        body: Data?,
        as _: T.Type
    ) async throws -> T {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let reason = error.localizedDescription
            Log.net
                .error(
                    "\(method, privacy: .public) \(url.absoluteString, privacy: .public): \(reason, privacy: .public)"
                )
            throw Failure.transport(url, error.localizedDescription)
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200 ..< 300).contains(code) else {
            let excerpt = String(bytes: data.prefix(300), encoding: .utf8) ?? ""
            Log.net.warning("\(method, privacy: .public) \(url.path, privacy: .public) -> \(code)")
            throw Failure.status(url, code, excerpt)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw Failure.decoding(url, error.localizedDescription)
        }
    }
}
