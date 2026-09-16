import Foundation

/// A `URLProtocol` that answers from a recorded script instead of the network.
///
/// Its handler runs on a `URLSession` thread, so it must not touch the
/// `@MainActor` test class — doing so deadlocks and shows up as
/// `Executed 0 tests` with every test started and none finished
/// (`CLAUDE.md` § *Mac app*). Everything the stub sees is recorded in this
/// separate `@unchecked Sendable` box behind a lock.
final class StubExchange: @unchecked Sendable {
    struct Response {
        var status: Int
        var body: Data
    }

    struct Seen {
        var path: String
        var body: Data
        var headers: [String: String]
    }

    private let lock = NSLock()
    private var script: [String: Response] = [:]
    private var seen: [Seen] = []

    func answer(_ path: String, status: Int = 200, json: String) {
        lock.withLock { script[path] = Response(status: status, body: Data(json.utf8)) }
    }

    func response(for path: String) -> Response? {
        lock.withLock { script[path] }
    }

    func record(path: String, body: Data, headers: [String: String]) {
        lock.withLock { seen.append(Seen(path: path, body: body, headers: headers)) }
    }

    var requests: [Seen] {
        lock.withLock { seen }
    }

    func reset() {
        lock.withLock {
            script = [:]
            seen = []
        }
    }

    /// The JSON body of the last call to `path`, for asserting what was sent.
    func lastBody(to path: String) -> [String: Any]? {
        guard let sent = requests.last(where: { $0.path == path }) else { return nil }
        return try? JSONSerialization.jsonObject(with: sent.body) as? [String: Any]
    }
}

/// Not `final`: the two overridden class methods come from `URLProtocol`.
class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static let exchange = StubExchange()

    /// A session that routes every request through this protocol.
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let path = request.url?.path() ?? ""
        let body = request.httpBody ?? readStream() ?? Data()
        Self.exchange.record(path: path, body: body, headers: request.allHTTPHeaderFields ?? [:])
        let answer = Self.exchange.response(for: path) ?? StubExchange.Response(status: 404, body: Data("null".utf8))
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: answer.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: answer.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// `URLSession` moves a body into `httpBodyStream` before the protocol
    /// sees it, so the bytes are read back from there.
    private func readStream() -> Data? {
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        var buffer = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
