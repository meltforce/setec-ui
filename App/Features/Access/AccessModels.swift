import Foundation

/// The actions setec subjects to access control (`design/api.md`
/// § *Permissions*), in the column order the matrix uses. `list` is a seventh
/// action the tailnet policy also grants; it is not a column because it is not
/// an operation on a single secret.
enum SecretCapability: String, CaseIterable, Identifiable, Sendable {
    case info
    case get
    case put
    case createVersion = "create-version"
    case activate
    case delete

    var id: String {
        rawValue
    }

    /// The abbreviated column heading: info, get, put, c-ver, activ, del.
    var columnTitle: String {
        switch self {
        case .info: "info"
        case .get: "get"
        case .put: "put"
        case .createVersion: "c-ver"
        case .activate: "activ"
        case .delete: "del"
        }
    }
}

/// What a secret name pattern in a grant covers. setec matches a trailing `*`
/// as a prefix and everything else exactly.
struct SecretPattern: Hashable, Sendable {
    var text: String

    func matches(name: String) -> Bool {
        guard text.hasSuffix("*") else { return text == name }
        return name.hasPrefix(String(text.dropLast()))
    }

    /// True when the pattern could cover any name inside `group/`. Used for
    /// the matrix, which is shown per group rather than per secret.
    func overlaps(group: String) -> Bool {
        let prefix = "\(group)/"
        guard text.hasSuffix("*") else { return text.hasPrefix(prefix) }
        let stem = String(text.dropLast())
        return stem.hasPrefix(prefix) || prefix.hasPrefix(stem)
    }
}

/// One `tailscale.com/cap/secrets` entry: which principals may perform which
/// actions on which name patterns.
struct GrantRule: Hashable, Sendable {
    var principals: [String]
    var capabilities: Set<SecretCapability>
    var patterns: [SecretPattern]
}

/// What the matrix shows the user has to look at: the scope of the question.
enum AccessScope: Hashable, Sendable {
    case group(String)
    case name(String)

    var title: String {
        switch self {
        case let .group(group): "\(group)/*"
        case let .name(name): name
        }
    }

    func isCovered(by pattern: SecretPattern) -> Bool {
        switch self {
        case let .group(group): pattern.overlaps(group: group)
        case let .name(name): pattern.matches(name: name)
        }
    }
}

/// A row of the matrix: a tailnet principal and the capabilities it holds in
/// the scope shown.
struct PrincipalAccess: Identifiable, Hashable, Sendable {
    var principal: String
    /// "4 members", "tag", "you" — what the principal is, not what it may do.
    var note: String
    var capabilities: Set<SecretCapability>
    var isSelf: Bool

    var id: String {
        principal
    }
}
