import Foundation

/// Reads the tailnet policy file from the Tailscale control API. setec has no
/// policy-read endpoint, so the grants of other principals cannot come from
/// the same server as the secrets (`DECISIONS.md`, 2026-09-16).
///
/// The credential is a read-only OAuth client held in two setec entries, named
/// in Settings › Access matrix (`AccessSetting`), read from setec and exchanged
/// for a bearer token. A Tailscale *auth key* is not one of these: an auth key
/// registers a node and answers 401 against this API, so an entry whose name
/// reads like a key is not a substitute for the client.
struct TailnetPolicyClient: Sendable {
    static let tokenURL = URL(string: "https://api.tailscale.com/api/v2/oauth/token")!
    static let policyURL = URL(string: "https://api.tailscale.com/api/v2/tailnet/-/acl")!

    /// The capability label setec matches on.
    static let capability = "tailscale.com/cap/secrets"

    /// The one OAuth scope this app needs. It calls a single endpoint,
    /// `GET /api/v2/tailnet/-/acl`, and nothing else — no device, DNS or
    /// route call — so a client scoped to anything more is scoped too widely
    /// for it. Measured 2026-09-16: the fleet's shared read-only client
    /// returns `devices:core:read devices:posture_attributes:read
    /// devices:routes:read policy_file:read dns:read services:read`, of which
    /// only the fourth is used here.
    static let requiredScope = "policy_file:read"

    var setec: SetecClient
    var session: URLSession
    /// The setec entries holding the OAuth client, from `AccessSetting`.
    var names: AccessSetting.Names

    init(setec: SetecClient, names: AccessSetting.Names, session: URLSession = .shared) {
        self.setec = setec
        self.names = names
        self.session = session
    }

    /// The policy, and the scopes the token that fetched it actually carries.
    struct Result: Sendable {
        var policy: TailnetPolicy
        var scopes: [String]
    }

    enum Failure: LocalizedError {
        /// setec itself could not be reached. Kept apart from `credential`
        /// because the two have opposite remedies and look alike from here: a
        /// setec outage surfaces in every consumer as a credential problem
        /// rather than as a missing host. Observed 2026-09-18: the host running
        /// setec rebooted, and the git credential helper that reads from setec
        /// answered `could not read Username for https://git…`, which names the
        /// credential and not the cause.
        case unreachable(String)
        case credential(String)
        case token(Int)
        case policy(Int)
        case missingScope([String])
        case decoding(String)

        var errorDescription: String? {
            switch self {
            case let .unreachable(reason):
                """
                setec is unreachable, so the OAuth client could not be read — \(reason). \
                This is not a wrong entry name: nothing was asked and nothing answered.
                """
            case let .credential(detail): "Cannot read the OAuth client from setec — \(detail)"
            case let .token(code):
                code == 401
                    ? "The OAuth exchange refused the client (HTTP 401) — the two entries hold something else"
                    : "The OAuth exchange answered HTTP \(code)"
            case let .policy(code): "The policy file answered HTTP \(code)"
            case let .missingScope(granted):
                """
                The OAuth client has no \(TailnetPolicyClient.requiredScope) scope. \
                It carries \(granted.isEmpty ? "none" : granted.joined(separator: ", ")).
                """
            case let .decoding(message): "The policy file did not parse: \(message)"
            }
        }
    }

    func loadPolicy() async throws -> Result {
        let (token, scopes) = try await bearerToken()
        // Reported as a missing scope rather than as a bare 403: the client is
        // valid, it simply may not read this.
        guard scopes.isEmpty || scopes.contains(Self.requiredScope) else {
            throw Failure.missingScope(scopes)
        }
        var request = URLRequest(url: Self.policyURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // The API answers HuJSON — JSON with comments and trailing commas —
        // unless JSON is requested explicitly. `JSONDecoder` reads neither.
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            if code == 403, !scopes.contains(Self.requiredScope) {
                throw Failure.missingScope(scopes)
            }
            throw Failure.policy(code)
        }
        return try Result(policy: TailnetPolicy(data: data), scopes: scopes)
    }

    /// Returns the token and the scopes the server says it carries. The scope
    /// list is what the dialog shows, so a client that is scoped wrongly can
    /// be seen rather than guessed at.
    private func bearerToken() async throws -> (token: String, scopes: [String]) {
        let id: String
        let secret: String
        do {
            id = try await setec.get(name: names.clientID).value
            secret = try await setec.get(name: names.clientSecret).value
        } catch let failure as SetecClient.Failure {
            if case let .transport(reason) = failure {
                throw Failure.unreachable(reason)
            }
            // The name is reported back, because a wrong name is the likely
            // cause and the operator can only correct what is named.
            throw Failure.credential("\(names.clientID) / \(names.clientSecret): \(failure.localizedDescription)")
        }
        var request = URLRequest(url: Self.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "client_id", value: id),
            URLQueryItem(name: "client_secret", value: secret),
        ]
        request.httpBody = Data((form.percentEncodedQuery ?? "").utf8)

        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw Failure.token(code) }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = object["access_token"] as? String
        else {
            throw Failure.decoding("no access_token in the token response")
        }
        let scopes = (object["scope"] as? String)?
            .split(separator: " ")
            .map(String.init) ?? []
        return (token, scopes)
    }
}

/// The parts of the policy file this app reads: the secrets grants and the
/// group memberships that name what a `group:` row stands for.
struct TailnetPolicy: Sendable, Equatable {
    var rules: [GrantRule]
    var groups: [String: [String]]

    init(rules: [GrantRule], groups: [String: [String]]) {
        self.rules = rules
        self.groups = groups
    }

    /// Parsed with `JSONSerialization` rather than `Decodable`: a grant's
    /// `app` value is a dictionary of arbitrary capability labels, and only
    /// one of them is read here.
    init(data: Data) throws {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TailnetPolicyClient.Failure.decoding("the response is not a JSON object")
        }
        groups = (root["groups"] as? [String: [String]]) ?? [:]
        var parsed: [GrantRule] = []
        for grant in (root["grants"] as? [[String: Any]]) ?? [] {
            guard let app = grant["app"] as? [String: Any],
                  let entries = app[TailnetPolicyClient.capability] as? [[String: Any]],
                  let sources = grant["src"] as? [String]
            else {
                continue
            }
            for entry in entries {
                let actions = (entry["action"] as? [String]) ?? []
                let patterns = (entry["secret"] as? [String]) ?? []
                let known = Set(actions.compactMap(SecretCapability.init(rawValue:)))
                let others = Set(actions).subtracting(known.map(\.rawValue))
                parsed.append(GrantRule(
                    principals: sources,
                    capabilities: known,
                    otherActions: others,
                    patterns: patterns.map { SecretPattern(text: $0) }
                ))
            }
        }
        rules = parsed
    }

    /// The matrix rows for one scope, merged per principal: a principal named
    /// by two rules holds the union of what both grant.
    func access(in scope: AccessScope, identity: TailnetIdentity?) -> [PrincipalAccess] {
        var merged: [String: Set<SecretCapability>] = [:]
        var others: [String: Set<String>] = [:]
        for rule in rules where rule.patterns.contains(where: { scope.isCovered(by: $0) }) {
            for principal in rule.principals {
                merged[principal, default: []].formUnion(rule.capabilities)
                others[principal, default: []].formUnion(rule.otherActions)
            }
        }
        return merged
            .map { principal, capabilities in
                PrincipalAccess(
                    principal: principal,
                    note: note(for: principal),
                    capabilities: capabilities,
                    otherActions: others[principal] ?? [],
                    isSelf: isSelf(principal, identity: identity)
                )
            }
            .sorted { ($0.isSelf ? 0 : 1, $0.principal) < ($1.isSelf ? 0 : 1, $1.principal) }
    }

    private func note(for principal: String) -> String {
        if principal.hasPrefix("group:") {
            let count = groups[principal]?.count ?? 0
            return count == 1 ? "1 member" : "\(count) members"
        }
        if principal.hasPrefix("tag:") {
            return "tag"
        }
        if principal == "autogroup:admin" {
            return "tailnet admins"
        }
        if principal.hasPrefix("autogroup:") {
            return "autogroup"
        }
        return "user"
    }

    private func isSelf(_ principal: String, identity: TailnetIdentity?) -> Bool {
        guard let login = identity?.loginName else { return false }
        if principal == login {
            return true
        }
        return groups[principal]?.contains(login) ?? false
    }
}
