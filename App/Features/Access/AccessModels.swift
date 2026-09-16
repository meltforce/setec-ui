import Foundation

/// The actions setec subjects to access control (`design/api.md`
/// § *Permissions*), in the column order the matrix uses.
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

    /// The column heading. `create-version` is abbreviated because the column
    /// is 74 points wide; `explanation` is what the header's tooltip says.
    var columnTitle: String {
        switch self {
        case .info: "info"
        case .get: "get"
        case .put: "put"
        case .createVersion: "create"
        case .activate: "activate"
        case .delete: "delete"
        }
    }

    /// What the action permits, from `design/api.md`. Shown in the matrix's
    /// legend, because an abbreviated column heading explains nothing.
    var explanation: String {
        switch self {
        case .info:
            "Read a secret's metadata: which versions exist and which one is active, but not its value."
        case .get:
            "Fetch the value of a secret. It does not imply info, and info does not imply it."
        case .put:
            "Append a new version. The server assigns the number."
        case .createVersion:
            """
            Append a version under a caller-chosen number, failing if that number was ever used. \
            No rule in this tailnet grants it, and this app never calls it.
            """
        case .activate:
            "Make one of the existing versions the active one. This is the rollback."
        case .delete:
            "Remove a single version, or every version of a secret."
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
///
/// `otherActions` holds every action string the policy grants that is not one
/// of the six columns — `list` is the one this tailnet uses. They are kept
/// rather than dropped, because a matrix that silently omits a granted action
/// states something false about the grant.
struct GrantRule: Hashable, Sendable {
    var principals: [String]
    var capabilities: Set<SecretCapability>
    var otherActions: Set<String>
    var patterns: [SecretPattern]

    init(
        principals: [String],
        capabilities: Set<SecretCapability>,
        otherActions: Set<String> = [],
        patterns: [SecretPattern]
    ) {
        self.principals = principals
        self.capabilities = capabilities
        self.otherActions = otherActions
        self.patterns = patterns
    }
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
    var otherActions: Set<String>
    var isSelf: Bool

    var id: String {
        principal
    }
}
