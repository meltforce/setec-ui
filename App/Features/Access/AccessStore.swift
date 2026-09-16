import Foundation
import Observation

/// Holds the tailnet policy the access matrix renders. Display-only: the user
/// is assumed to hold every capability and no action in the app is gated on a
/// grant. The matrix exists because the grants of *other* principals are
/// information only the policy has.
@MainActor
@Observable
final class AccessStore {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
        /// No credential names are configured. Not a failure — the matrix is
        /// switched off, and the section says that rather than an error.
        case disabled
    }

    private(set) var state: State = .idle
    private(set) var policy: TailnetPolicy?
    private var client: TailnetPolicyClient?
    private var identityProvider: @MainActor () -> TailnetIdentity?

    init(client: TailnetPolicyClient?, identity: @escaping @MainActor () -> TailnetIdentity? = { nil }) {
        self.client = client
        identityProvider = identity
        if client == nil {
            state = .disabled
        }
    }

    /// Points the store at different credential entries and reloads. Passing
    /// nil switches the matrix off. The Settings window writes through here,
    /// so a corrected name takes effect without a relaunch.
    func use(client: TailnetPolicyClient?) async {
        self.client = client
        policy = nil
        guard client != nil else {
            state = .disabled
            return
        }
        state = .idle
        await load()
    }

    static func preview(_ policy: TailnetPolicy? = nil) -> AccessStore {
        let store = AccessStore(client: nil)
        store.policy = policy ?? TailnetPolicy(
            rules: [
                GrantRule(
                    principals: ["autogroup:admin"],
                    capabilities: Set(SecretCapability.allCases),
                    patterns: [SecretPattern(text: "*")]
                ),
                GrantRule(
                    principals: ["tag:homelab"],
                    capabilities: [.get],
                    patterns: [SecretPattern(text: "docker/*")]
                ),
            ],
            groups: [:]
        )
        store.state = .loaded
        return store
    }

    /// Whether the matrix has anything to show, which the section reads to
    /// decide between "switched off" and "could not be read".
    var isConfigured: Bool {
        state != .disabled
    }

    /// Reads the policy once per launch. A failure leaves the section stating
    /// where the grants would have come from; it never shows an empty matrix
    /// as if it were complete.
    func load() async {
        guard let client else {
            state = .disabled
            return
        }
        guard state != .loading else { return }
        state = .loading
        do {
            let loaded = try await client.loadPolicy()
            policy = loaded
            state = .loaded
            Log.app.notice("policy loaded: \(loaded.rules.count) secrets grants")
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            Log.app.error("policy load failed: \(String(describing: error), privacy: .public)")
        }
    }

    func rows(in scope: AccessScope) -> [PrincipalAccess] {
        policy?.access(in: scope, identity: identityProvider()) ?? []
    }

    /// What the section header's right-hand control names as the source.
    func ruleCount(in scope: AccessScope) -> Int {
        guard let policy else { return 0 }
        return policy.rules.count { rule in rule.patterns.contains { scope.isCovered(by: $0) } }
    }
}
