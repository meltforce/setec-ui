import Foundation

/// Which two setec entries hold the Tailscale OAuth client the access matrix
/// reads the tailnet policy with. The names are a setting rather than a
/// constant: the names belong to the store the app is pointed at, and another
/// store has no reason to carry the same ones.
///
/// Blank is a valid answer and means the matrix is switched off — not that it
/// failed. A store with no policy credential is an ordinary configuration, and
/// the section says so instead of reporting an error.
enum AccessSetting {
    static let clientIDKey = "tailscaleOAuthClientIDSecret"
    static let clientSecretKey = "tailscaleOAuthClientSecretSecret"

    /// The app's own entries, under its own prefix. They hold a Tailscale
    /// OAuth client with the `policy_file:read` scope and nothing else; the
    /// exchange is in `TailnetPolicyClient`.
    static let defaultClientIDSecret = "setec-ui/ts-client-id"
    static let defaultClientSecretSecret = "setec-ui/ts-client-secret"

    struct Names: Equatable, Sendable {
        var clientID: String
        var clientSecret: String
    }

    /// Nil when either name is blank, which is what turns the matrix off.
    static func resolve(defaults: UserDefaults = .standard) -> Names? {
        let id = stored(defaults, clientIDKey, default: defaultClientIDSecret)
        let secret = stored(defaults, clientSecretKey, default: defaultClientSecretSecret)
        guard !id.isEmpty, !secret.isEmpty else { return nil }
        return Names(clientID: id, clientSecret: secret)
    }

    /// A key that was never written takes the default; a key written as an
    /// empty string is a deliberate blank and stays one.
    private static func stored(_ defaults: UserDefaults, _ key: String, default fallback: String) -> String {
        guard let value = defaults.string(forKey: key) else { return fallback }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
