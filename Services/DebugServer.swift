#if DEBUG
import AppKit
import Foundation
import Network

/// A loopback endpoint DEBUG builds open so the agent can ask the running app
/// about itself: `make eval CMD=state`, `make eval CMD="action select {...}"`,
/// `make screenshot`. Line protocol, one request per line, one JSON line back.
///
/// The port is chosen by the system and written to
/// `$TMPDIR/<bundle-id>.debug-port`; the Makefile reads it from there.
///
/// Register providers from `AppDelegate.attach(store:)`. Everything runs on the
/// main actor, so a handler may touch views and stores directly.
@MainActor
final class DebugServer {
    static let shared = DebugServer()

    enum Failure: LocalizedError {
        case badParams(String)
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case let .badParams(name): "missing or invalid parameter: \(name)"
            case let .unknown(what): "unknown \(what)"
            }
        }
    }

    typealias StateProvider = () -> [String: Any]
    typealias ActionHandler = ([String: Any]) throws -> [String: Any]

    private var listener: NWListener?
    private var states: [String: StateProvider] = [:]
    private var actions: [String: ActionHandler] = [:]

    private init() {}

    func register(state name: String, _ provider: @escaping StateProvider) {
        states[name] = provider
    }

    func register(action name: String, _ handler: @escaping ActionHandler) {
        actions[name] = handler
    }

    func start() {
        guard listener == nil else { return }
        do {
            let parameters = NWParameters.tcp
            parameters.requiredInterfaceType = .loopback
            let listener = try NWListener(using: parameters)
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in self?.listenerChanged(state) }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            listener.start(queue: .global(qos: .utility))
            self.listener = listener
        } catch {
            Log.debugServer.error("listener failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Connections

    private func listenerChanged(_ state: NWListener.State) {
        switch state {
        case .ready:
            guard let port = listener?.port?.rawValue else { return }
            let file = portFile
            do {
                try String(port).write(to: file, atomically: true, encoding: .utf8)
                Log.debugServer.notice("listening on 127.0.0.1:\(port) (\(file.path, privacy: .public))")
            } catch {
                Log.debugServer
                    .error("cannot write port file: \(error.localizedDescription, privacy: .public)")
            }
        case let .failed(error):
            Log.debugServer.error("listener failed: \(error.localizedDescription, privacy: .public)")
        default:
            break
        }
    }

    private var portFile: URL {
        let id = Bundle.main.bundleIdentifier ?? "org.meltforce.app"
        return FileManager.default.temporaryDirectory.appending(path: "\(id).debug-port")
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        receiveLine(connection, buffer: Data())
    }

    private nonisolated func receiveLine(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            var buffer = buffer
            if let data {
                buffer.append(data)
            }
            if let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = String(bytes: buffer[..<newline], encoding: .utf8) ?? ""
                Task { @MainActor in
                    let reply = self.handle(line: line.trimmingCharacters(in: .whitespaces))
                    connection.send(
                        content: reply + Data("\n".utf8),
                        completion: .contentProcessed { _ in
                            connection.cancel()
                        }
                    )
                }
                return
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            self.receiveLine(connection, buffer: buffer)
        }
    }

    // MARK: - Protocol

    private func handle(line: String) -> Data {
        let parts = line.split(separator: " ", maxSplits: 2).map(String.init)
        let command = parts.first ?? ""
        let result: [String: Any]
        do {
            switch command {
            case "state":
                result = states.mapValues { $0() }
            case "action":
                guard parts.count >= 2 else { throw Failure.badParams("name") }
                guard let handler = actions[parts[1]] else { throw Failure.unknown("action \(parts[1])") }
                let params = try Self.parseParams(parts.count > 2 ? parts[2] : "{}")
                result = try ["ok": true, "result": handler(params)]
            case "screenshot":
                guard parts.count >= 2 else { throw Failure.badParams("path") }
                let path = parts.dropFirst().joined(separator: " ")
                try Self.screenshot(to: URL(fileURLWithPath: path))
                result = ["ok": true, "path": path]
            case "actions":
                result = ["actions": Array(actions.keys).sorted(), "states": Array(states.keys).sorted()]
            case "windows":
                result = [
                    "active": NSApp.isActive,
                    "windows": NSApp.windows.map { window in
                        [
                            "title": window.title,
                            "visible": window.isVisible,
                            "key": window.isKeyWindow,
                            "frame": [window.frame.minX, window.frame.minY, window.frame.width, window.frame.height],
                            "class": String(describing: type(of: window)),
                        ] as [String: Any]
                    },
                ]
            default:
                throw Failure
                    .unknown(
                        "command \(command). Known: state, action <name> <json>, screenshot <path>, actions, windows"
                    )
            }
        } catch {
            result = ["ok": false, "error": error.localizedDescription]
        }
        return (try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])) ??
            Data("{}".utf8)
    }

    private static func parseParams(_ text: String) throws -> [String: Any] {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any]
        else { throw Failure.badParams("json") }
        return dict
    }

    /// Renders the key window's content view. No Screen Recording grant is
    /// involved; the app draws itself into the bitmap.
    private static func screenshot(to url: URL) throws {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible),
              let view = window.contentView
        else { throw Failure.unknown("window to capture") }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw Failure.unknown("bitmap for \(view.bounds)")
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:])
        else { throw Failure.unknown("png encoder") }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try png.write(to: url)
        Log.debugServer.info("screenshot \(url.path, privacy: .public)")
    }
}
#endif
