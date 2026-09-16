import CryptoKit
import Foundation

/// The result of comparing every secret's active value against every other's.
///
/// setec's `/api/list` carries no digest, so the only way to know that two
/// secrets hold the same value is to fetch both. That is the one thing this
/// app otherwise never does — a value is fetched on Reveal, Copy and "Start
/// from current" and at no other time — so the scan never starts on its own.
/// It runs when the operator asks for it, and what it keeps is the digest:
/// the plaintext is hashed as each response arrives and is not held beyond it.
///
/// Digests are memory-only. A digest of a low-entropy value is guessable
/// offline, so it is no more storable than the value itself.
struct ReuseScan: Equatable {
    /// Secret name to the hex digest of its active value.
    var digests: [String: String]
    /// Secret name to the reason its value could not be read.
    var failures: [String: String]
    var finished: Date
    /// How many secrets the scan covered, including the failures.
    var attempted: Int

    /// Names whose active value is identical to at least one other secret's.
    var reusedNames: Set<String> {
        var byDigest: [String: [String]] = [:]
        for (name, digest) in digests {
            byDigest[digest, default: []].append(name)
        }
        return Set(byDigest.values.filter { $0.count > 1 }.flatMap(\.self))
    }

    /// The reused secrets grouped by the value they share, largest group
    /// first. The digest is the group's identity and is never shown.
    var groups: [[String]] {
        var byDigest: [String: [String]] = [:]
        for (name, digest) in digests {
            byDigest[digest, default: []].append(name)
        }
        return byDigest.values
            .filter { $0.count > 1 }
            .map { $0.sorted() }
            .sorted { ($1.count, $1[0]) < ($0.count, $0[0]) }
    }

    static func digest(of value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
