import Foundation

/// Everything the window shows that is computed from the secret list rather
/// than stored: the sidebar tree and its counts, filter membership, the
/// visible list, and the autocomplete candidates. `design/handoff.md`
/// § *State Management* is the full list.
@MainActor
extension SecretStore {
    var existingNames: Set<String> {
        Set(secrets.map(\.name))
    }

    var prefixCandidates: [SecretName.Candidate] {
        SecretName.prefixes(in: secrets.map(\.name))
    }

    var topLevelGroups: [String] {
        SecretName.groups(in: secrets.map(\.name))
    }

    /// Sidebar rows: every first path level with the number of secrets under it.
    var groupCounts: [(group: String, count: Int)] {
        var counts: [String: Int] = [:]
        for secret in secrets {
            guard let group = secret.group else { continue }
            counts[group, default: 0] += 1
        }
        return counts.map { (group: $0.key, count: $0.value) }.sorted { $0.group < $1.group }
    }

    var ungroupedCount: Int {
        secrets.count { $0.group == nil }
    }

    func count(for filter: SmartFilter) -> Int {
        secrets.count { filter.matches($0) }
    }

    /// The list column's contents. A non-empty search overrides scope and
    /// filter and searches every secret, as the design specifies.
    var visible: [Secret] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard needle.isEmpty else {
            return sorted(secrets.filter { $0.name.lowercased().contains(needle) })
        }
        switch scope {
        case .all: return sorted(secrets)
        case let .group(group): return sorted(secrets.filter { $0.group == group })
        case let .filter(filter): return sorted(secrets.filter { filter.matches($0) })
        }
    }

    func sorted(_ list: [Secret]) -> [Secret] {
        switch sort {
        case .nameAscending: list
        case .nameDescending: list.sorted { $0.name > $1.name }
        case .versionCount: list.sorted {
                ($0.versions.count, $1.name) > ($1.versions.count, $0.name)
            }
        }
    }

    var listTitle: String {
        let needle = query.trimmingCharacters(in: .whitespaces)
        return needle.isEmpty ? scope.title : "Search: \(needle)"
    }

    var selected: Secret? {
        guard let selectedName else { return nil }
        return secrets.first { $0.name == selectedName }
    }

    /// The group whose grants the access matrix shows.
    var selectedGroup: String? {
        selected?.group
    }
}
