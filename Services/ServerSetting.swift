import Foundation

/// Where the server URL comes from, in the order the app resolves it:
/// `SETEC_SERVER` in the environment, then the value stored by the Settings
/// window. There is no third source — the app carries no built-in server,
/// because a client that ships with someone's tailnet host in it points every
/// other installation at that host (`DECISIONS.md`, 2026-09-21).
enum ServerSetting {
    static let environmentKey = "SETEC_SERVER"
    static let defaultsKey = "serverURL"

    /// What the Settings field shows while it is empty. A shape, not a
    /// destination: `.example.ts.net` is reserved and resolves nowhere.
    static let example = "https://setec.example.ts.net"

    /// True while the environment decides, in which case the Settings field is
    /// shown but cannot take effect until the next launch without it.
    static var isOverriddenByEnvironment: Bool {
        environmentURL != nil
    }

    static var environmentURL: URL? {
        guard let raw = ProcessInfo.processInfo.environment[environmentKey] else { return nil }
        return parse(raw)
    }

    /// `nil` when neither source names a server, which is the state a fresh
    /// installation starts in.
    static func resolve(defaults: UserDefaults = .standard) -> URL? {
        if let fromEnvironment = environmentURL {
            return fromEnvironment
        }
        if let stored = defaults.string(forKey: defaultsKey), let url = parse(stored) {
            return url
        }
        return nil
    }

    /// Accepts a bare host as well as a URL, because that is what a person
    /// types into the field.
    static func parse(_ raw: String) -> URL? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let candidate = text.contains("://") ? text : "https://\(text)"
        guard let url = URL(string: candidate), url.host() != nil else { return nil }
        return url
    }
}
