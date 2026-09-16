import Foundation

/// One secret as `/api/list` reports it: a name, the versions that exist, and
/// which of them is active. The API carries nothing else — no author, no
/// timestamp, no digest (`DECISIONS.md`, 2026-09-16).
struct Secret: Identifiable, Hashable, Sendable {
    var name: String
    /// Ascending, as the server reports them.
    var versions: [Int]
    var activeVersion: Int

    var id: String {
        name
    }

    init(name: String, versions: [Int], activeVersion: Int) {
        self.name = name
        self.versions = versions.sorted()
        self.activeVersion = activeVersion
    }

    init(_ info: SecretInfo) {
        self.init(name: info.name, versions: info.versions, activeVersion: info.activeVersion)
    }

    /// Everything up to and including the last slash, empty for an ungrouped
    /// name. `docker/immich/api-key` → `docker/immich/`.
    var prefix: String {
        guard let slash = name.lastIndex(of: "/") else { return "" }
        return String(name[...slash])
    }

    /// The part after the last slash.
    var leaf: String {
        guard let slash = name.lastIndex(of: "/") else { return name }
        return String(name[name.index(after: slash)...])
    }

    /// The first path level, which is what the sidebar groups by. Nil for a
    /// name without a slash.
    var group: String? {
        guard let slash = name.firstIndex(of: "/") else { return nil }
        return String(name[..<slash])
    }

    var latestVersion: Int {
        versions.last ?? activeVersion
    }

    /// True when activating a different version is possible at all.
    var hasRollback: Bool {
        versions.count > 1
    }

    /// True when a newer version exists than the one in use — the state a
    /// `put` without activation leaves behind.
    var latestIsActive: Bool {
        latestVersion == activeVersion
    }

    /// The number the next `put` will assign, as far as the client can tell.
    var nextVersion: Int {
        latestVersion + 1
    }
}

/// The sidebar's derived conditions. The design's three filters were
/// "Rotation over 90 days", "No rollback version" and "Changed this week";
/// two of those need a timestamp the API does not carry, so they are replaced
/// by conditions `/api/list` can answer (`DECISIONS.md`, 2026-09-16).
enum SmartFilter: String, CaseIterable, Identifiable, Sendable {
    case noRollback
    case latestNotActive
    case multipleVersions
    case reusedValue

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .noRollback: "No rollback version"
        case .latestNotActive: "Latest is not active"
        case .multipleVersions: "Multiple versions"
        case .reusedValue: "Reused value"
        }
    }

    /// What the row means, for the list header's subtitle.
    var explanation: String {
        switch self {
        case .noRollback: "One version only — there is nothing to activate instead."
        case .latestNotActive: "A newer version exists than the one consumers fetch."
        case .multipleVersions: "More than one version is stored."
        case .reusedValue: "The active value is identical to another secret's."
        }
    }

    /// `reusedValue` is the one filter that cannot be answered from the
    /// metadata: it needs the values, which only a scan has. Without one it
    /// matches nothing, and the list column says why instead of showing an
    /// empty result.
    func matches(_ secret: Secret, reusedNames: Set<String> = []) -> Bool {
        switch self {
        case .noRollback: !secret.hasRollback
        case .latestNotActive: !secret.latestIsActive
        case .multipleVersions: secret.hasRollback
        case .reusedValue: reusedNames.contains(secret.name)
        }
    }

    /// True when the filter is answered by a scan rather than by `/api/list`.
    var needsValues: Bool {
        self == .reusedValue
    }
}

/// What the sidebar selects. A group and a filter are mutually exclusive, and
/// search overrides both.
enum Scope: Hashable, Sendable {
    case all
    case group(String)
    case filter(SmartFilter)

    var title: String {
        switch self {
        case .all: "All secrets"
        case let .group(name): "\(name)/"
        case let .filter(filter): filter.title
        }
    }
}

/// What the list header's sort control offers. The design shows "Name ▾" and
/// names no second criterion; version count is the one other ordering the
/// metadata supports.
enum SecretSort: String, CaseIterable, Identifiable, Sendable {
    case nameAscending
    case nameDescending
    case versionCount

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .nameAscending: "Name"
        case .nameDescending: "Name, reversed"
        case .versionCount: "Versions"
        }
    }

    var shortTitle: String {
        switch self {
        case .nameAscending: "Name ▾"
        case .nameDescending: "Name ▴"
        case .versionCount: "Versions ▾"
        }
    }
}
