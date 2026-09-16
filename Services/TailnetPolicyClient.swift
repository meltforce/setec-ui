import Foundation

/// Reads the tailnet policy file from the Tailscale control API. setec has no
/// policy-read endpoint, so the grants of other principals cannot come from
/// the same server as the secrets (`DECISIONS.md`, 2026-09-16).
///
/// The credential is the read-only OAuth client `homelab/ts-oauth-client-{id,
/// secret}`, read from setec and exchanged for a bearer token; homelab
/// `SECRETS.md` § *Tailscale control API* documents the exchange and records
/// that the entries whose names contain "api key" are node auth keys that
/// answer 401 here.
struct TailnetPolicyClient: Sendable {
    static let clientIDSecret = "homelab/ts-oauth-client-id"
    static let clientSecretSecret = "homelab/ts-oauth-client-secret"
    static let tokenURL = URL(string: "https://api.tailscale.com/api/v2/oauth/token")!
    static let policyURL = URL(string: "https://api.tailscale.com/api/v2/tailnet/-/acl")!

    /// The capability label setec matches on.
    static let capability = "tailscale.com/cap/secrets"

    var setec: SetecClient
    var session: URLSession

    init(setec: SetecClient, session: URLSession = .shared) {
        self.setec = setec
        self.session = session
    }

    enum Failure: LocalizedError {
        case credential(String)
        case token(Int)
        case policy(Int)
        case decoding(String)

        var errorDescription: String? {
            switch self {
            case let .credential(name): "Cannot read \(name) from setec"
            case let .token(code): "The OAuth exchange answered HTTP \(code)"
            case let .policy(code): "The policy file answered HTTP \(code)"
            case let .decoding(message): "The policy file did not parse: \(message)"
            }
        }
    }

    func loadPolicy() async throws -> TailnetPolicy {
        let token = try await bearerToken()
        var request = URLRequest(url: Self.policyURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // The API answers HuJSON — JSON with comments and trailing commas —
        // unless JSON is requested explicitly. `JSONDecoder` reads neither.
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw Failure.policy(code) }
        return try TailnetPolicy(data: data)
    }

    private func bearerToken() async throws -> String {
        let id: String
        let secret: String
        do {
            id = try await setec.get(name: Self.clientIDSecret).value
            secret = try await setec.get(name: Self.clientSecretSecret).value
        } catch {
            throw Failure.credential(Self.clientIDSecret)
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
        return token
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
                parsed.append(GrantRule(
                    principals: sources,
                    capabilities: Set(actions.compactMap(SecretCapability.init(rawValue:))),
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
        for rule in rules where rule.patterns.contains(where: { scope.isCovered(by: $0) }) {
            for principal in rule.principals {
                merged[principal, default: []].formUnion(rule.capabilities)
            }
        }
        return merged
            .map { principal, capabilities in
                PrincipalAccess(
                    principal: principal,
                    note: note(for: principal),
                    capabilities: capabilities,
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
