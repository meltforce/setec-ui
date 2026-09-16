import Foundation
import Security

/// The rules the New secret sheet enforces on a name, and the prefix
/// completion it offers. A name is a flat string; the slashes are a naming
/// convention the sidebar reads, not a namespace object, so there is nothing
/// to create here beyond the string itself.
enum SecretName {
    /// The design's rule: lowercase letters, digits, dot, underscore, hyphen
    /// and slash, starting and ending on a letter or digit.
    static let pattern = "^[a-z0-9][a-z0-9._\\-/]*[a-z0-9]$"

    enum Verdict: Equatable {
        case empty
        case invalid
        case collision
        case newGroup(String)
        case available

        var isAcceptable: Bool {
            switch self {
            case .newGroup, .available: true
            case .empty, .invalid, .collision: false
            }
        }
    }

    /// Leading slashes are dropped rather than rejected, so a pasted
    /// `/prod/db/password` becomes a valid name instead of an error.
    static func normalize(_ input: String) -> String {
        var name = input.trimmingCharacters(in: .whitespacesAndNewlines)
        while name.hasPrefix("/") {
            name.removeFirst()
        }
        return name
    }

    static func isWellFormed(_ name: String) -> Bool {
        name.range(of: pattern, options: .regularExpression) != nil
    }

    /// The verdict for a typed name against the names that already exist.
    static func verdict(for input: String, existing: Set<String>) -> Verdict {
        let name = normalize(input)
        guard !name.isEmpty else { return .empty }
        guard isWellFormed(name) else { return .invalid }
        guard !existing.contains(name) else { return .collision }
        guard let slash = name.firstIndex(of: "/") else { return .available }
        let group = String(name[..<slash])
        let exists = existing.contains { $0.hasPrefix("\(group)/") }
        return exists ? .available : .newGroup(group)
    }

    /// One candidate per path level of every existing name: `docker/`,
    /// `docker/immich/`, and so on, each with the number of secrets beneath it.
    static func prefixes(in names: some Sequence<String>) -> [Candidate] {
        var counts: [String: Int] = [:]
        for name in names {
            var level = ""
            for part in name.split(separator: "/").dropLast() {
                level += "\(part)/"
                counts[level, default: 0] += 1
            }
        }
        return counts
            .map { Candidate(prefix: $0.key, count: $0.value) }
            .sorted { ($0.prefix.count, $0.prefix) < ($1.prefix.count, $1.prefix) }
    }

    struct Candidate: Identifiable, Hashable, Sendable {
        var prefix: String
        var count: Int

        var id: String {
            prefix
        }
    }

    /// Candidates that continue what was typed, case-insensitively, longest
    /// common ground first. The best one is what the field shows as ghost text.
    static func completions(for input: String, from candidates: [Candidate], limit: Int = 5) -> [Candidate] {
        let typed = normalize(input).lowercased()
        // Nothing typed means nothing to complete: a list of arbitrary
        // prefixes under an empty field is noise, not a suggestion.
        guard !typed.isEmpty else { return [] }
        return candidates
            .filter { $0.prefix.lowercased().hasPrefix(typed) && $0.prefix.count > typed.count }
            .sorted { ($0.prefix.count, $0.prefix) < ($1.prefix.count, $1.prefix) }
            .prefix(limit)
            .map(\.self)
    }

    /// The top-level prefixes the sheet offers as chips.
    static func groups(in names: some Sequence<String>) -> [String] {
        var seen = Set<String>()
        for name in names {
            guard let slash = name.firstIndex(of: "/") else { continue }
            seen.insert(String(name[..<slash]))
        }
        return seen.sorted()
    }
}

/// The generator behind the sheet's "Generate" link. The alphabet drops the
/// characters that are read wrong when a value is transcribed by hand
/// (l, I, 1, o, O, 0).
enum SecretValueGenerator {
    static let alphabet = Array("abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789-_")

    static func generate(length: Int = 32) -> String {
        precondition(length > 0)
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed with \(status)")
        // The alphabet has 58 entries, so the modulo is biased; drawing a new
        // byte for the values above the last whole multiple removes the bias.
        var result = ""
        var index = 0
        let ceiling = 256 - (256 % alphabet.count)
        while result.count < length {
            if index == bytes.count {
                let again = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
                precondition(again == errSecSuccess, "SecRandomCopyBytes failed with \(again)")
                index = 0
            }
            let byte = Int(bytes[index])
            index += 1
            guard byte < ceiling else { continue }
            result.append(alphabet[byte % alphabet.count])
        }
        return result
    }
}
