import Foundation

/// The setec HTTP API (`design/api.md`). Every method is an HTTPS POST with a
/// JSON body; the caller is authenticated by its tailnet identity, so there is
/// no credential to carry. `Sec-X-Tailscale-No-Browsers` is required by the
/// server and refuses browser-originated calls.
///
/// Values are base64 in transit. They are decoded at this boundary and handed
/// on as `String`; nothing here writes them anywhere.
struct SetecClient: Sendable {
    var server: URL
    var session: URLSession

    init(server: URL, session: URLSession = .shared) {
        self.server = server
        self.session = session
    }

    enum Failure: LocalizedError, Equatable {
        case transport(String)
        case badRequest(String)
        case forbidden(String)
        case notFound(String)
        case server(Int, String)
        case decoding(String)
        case notBase64(String)

        var errorDescription: String? {
            switch self {
            case let .transport(message): "Cannot reach the server: \(message)"
            case let .badRequest(path): "The server rejected the request to \(path)"
            case let .forbidden(name): "Not permitted for \(name)"
            case let .notFound(name): "No such secret: \(name)"
            case let .server(code, path): "HTTP \(code) from \(path)"
            case let .decoding(message): "Unexpected response: \(message)"
            case let .notBase64(name): "The value of \(name) is not valid base64"
            }
        }
    }

    // MARK: - Operations

    /// Metadata for every secret the caller may see. No values.
    func list() async throws -> [SecretInfo] {
        try await call("/api/list", body: Empty(), as: [SecretInfo].self, subject: "list")
    }

    /// Metadata for one secret.
    func info(name: String) async throws -> SecretInfo {
        try await call("/api/info", body: NameRequest(name: name), as: SecretInfo.self, subject: name)
    }

    /// The value of the active version.
    func get(name: String) async throws -> SecretValue {
        try await value(from: GetRequest(name: name, version: nil), subject: name)
    }

    /// The value of one specific version.
    func get(name: String, version: Int) async throws -> SecretValue {
        try await value(from: GetRequest(name: name, version: version), subject: name)
    }

    /// Appends a version. The server returns the version number it assigned,
    /// and returns the existing active version unchanged when the value is
    /// identical to it.
    @discardableResult
    func put(name: String, value: String) async throws -> Int {
        let encoded = Data(value.utf8).base64EncodedString()
        return try await call(
            "/api/put",
            body: PutRequest(name: name, value: encoded),
            as: Int.self,
            subject: name
        )
    }

    /// Makes one of the existing versions the active one. This is the rollback
    /// mechanism; the API has no rollback call.
    func activate(name: String, version: Int) async throws {
        try await callDiscardingResult(
            "/api/activate",
            body: VersionRequest(name: name, version: version),
            subject: name
        )
    }

    /// Deletes every version of a secret.
    func delete(name: String) async throws {
        try await callDiscardingResult("/api/delete", body: NameRequest(name: name), subject: name)
    }

    /// Deletes a single non-active version.
    func deleteVersion(name: String, version: Int) async throws {
        try await callDiscardingResult(
            "/api/delete-version",
            body: VersionRequest(name: name, version: version),
            subject: name
        )
    }

    // MARK: - Transport

    private func value(from request: GetRequest, subject: String) async throws -> SecretValue {
        let wire = try await call("/api/get", body: request, as: WireValue.self, subject: subject)
        guard let data = Data(base64Encoded: wire.value),
              let text = String(data: data, encoding: .utf8)
        else {
            throw Failure.notBase64(subject)
        }
        return SecretValue(value: text, version: wire.version)
    }

    private func call<Response: Decodable>(
        _ path: String,
        body: some Encodable,
        as _: Response.Type,
        subject: String
    ) async throws -> Response {
        let data = try await send(path, body: body, subject: subject)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw Failure.decoding(error.localizedDescription)
        }
    }

    /// For the calls whose response body is `null`.
    private func callDiscardingResult(_ path: String, body: some Encodable, subject: String) async throws {
        _ = try await send(path, body: body, subject: subject)
    }

    private func send(_ path: String, body: some Encodable, subject: String) async throws -> Data {
        var request = URLRequest(url: server.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("setec", forHTTPHeaderField: "Sec-X-Tailscale-No-Browsers")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            Log.net.error("POST \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw Failure.transport(error.localizedDescription)
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        Log.net.debug("POST \(path, privacy: .public) -> \(code)")
        switch code {
        case 200 ..< 300: return data
        case 400: throw Failure.badRequest(path)
        case 403: throw Failure.forbidden(subject)
        case 404: throw Failure.notFound(subject)
        default: throw Failure.server(code, path)
        }
    }
}

// MARK: - Wire types

/// The Go field names are capitalised; the Swift properties are not, so
/// every wire type carries an explicit `CodingKeys`.
struct SecretInfo: Decodable, Sendable, Hashable {
    var name: String
    var versions: [Int]
    var activeVersion: Int

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case versions = "Versions"
        case activeVersion = "ActiveVersion"
    }
}

struct SecretValue: Sendable, Hashable {
    var value: String
    var version: Int
}

struct Empty: Encodable {}

struct NameRequest: Encodable {
    var name: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
    }
}

struct VersionRequest: Encodable {
    var name: String
    var version: Int

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case version = "Version"
    }
}

struct PutRequest: Encodable {
    var name: String
    var value: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case value = "Value"
    }
}

struct GetRequest: Encodable {
    var name: String
    var version: Int?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case version = "Version"
    }
}

struct WireValue: Decodable {
    var value: String
    var version: Int

    enum CodingKeys: String, CodingKey {
        case value = "Value"
        case version = "Version"
    }
}
