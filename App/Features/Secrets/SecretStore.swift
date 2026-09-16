import Foundation
import Observation

/// The one observable object the window reads. It holds the secret list, the
/// selection and everything derived from them; it fetches a value only when
/// Reveal, Copy or "Start from current" asks for one, and it keeps no value
/// beyond the moment it is shown.
@MainActor
@Observable
final class SecretStore {
    // MARK: - State

    enum Loading: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// A value held in memory for as long as it is on screen. Never encoded,
    /// never logged, never written to disk.
    struct Revealed: Equatable {
        var name: String
        var version: Int
        var value: String
    }

    enum Sheet: Identifiable, Equatable {
        case newSecret
        case newVersion(String)
        case deleteSecret(String)
        case deleteVersion(String, Int)

        var id: String {
            switch self {
            case .newSecret: "new"
            case let .newVersion(name): "version:\(name)"
            case let .deleteSecret(name): "delete:\(name)"
            case let .deleteVersion(name, version): "delete-version:\(name):v\(version)"
            }
        }
    }

    private(set) var secrets: [Secret] = []
    private(set) var loading: Loading = .idle
    private(set) var lastSynced: Date?
    private(set) var identity: TailnetIdentity?

    var scope: Scope = .all {
        didSet {
            if scope != oldValue {
                scopeChanged()
            }
        }
    }

    var query = ""
    var sort: SecretSort = .nameAscending
    var selectedName: String? {
        didSet {
            if selectedName != oldValue {
                selectionChanged()
            }
        }
    }

    private(set) var revealed: Revealed?
    private(set) var isFetchingValue = false
    private(set) var copyConfirmed = false
    private(set) var busy: String?

    /// The left half of the detail status bar: the last call this window made.
    private(set) var lastCall = "No request yet"
    /// The error strip above the columns. The design carries no error state;
    /// this is the placeholder flagged for design review (`ROADMAP.md`).
    private(set) var problem: String?

    var sheet: Sheet?

    /// The last reuse scan, and the progress of one that is running. Both are
    /// memory-only and are dropped when the server changes.
    private(set) var reuseScan: ReuseScan?
    private(set) var reuseProgress: ReuseProgress?
    private var reuseTask: Task<Void, Never>?

    struct ReuseProgress: Equatable {
        var done: Int
        var total: Int
    }

    private(set) var server: URL
    private var client: SetecClient
    private var hideTask: Task<Void, Never>?
    private var copyTask: Task<Void, Never>?
    private var pasteboardTask: Task<Void, Never>?

    /// How long a revealed value stays on screen.
    static let revealLifetime: Duration = .seconds(20)
    /// How long the Copy button reads "Copied".
    static let copyConfirmation: Duration = .milliseconds(1800)

    // MARK: - Lifecycle

    init(server: URL = ServerSetting.resolve(), session: URLSession = .shared) {
        self.server = server
        client = SetecClient(server: server, session: session)
    }

    /// A store with a fixed list and no network, for previews and tests.
    static func preview(_ secrets: [Secret] = Secret.samples) -> SecretStore {
        let store = SecretStore(server: ServerSetting.fallback)
        store.adopt(secrets)
        store.loading = .loaded
        store.lastSynced = .now
        store.identity = TailnetIdentity(loginName: "you@example.com", nodeName: "mac.example.ts.net")
        return store
    }

    /// Points the client at a different server and reloads. The Settings field
    /// writes through here, so a server change does not need a relaunch.
    func use(server url: URL) {
        guard url != server else { return }
        server = url
        client = SetecClient(server: url, session: client.session)
        secrets = []
        selectedName = nil
        loading = .idle
        cancelReuseScan()
        reuseScan = nil
        Task { await refresh() }
    }

    /// How many values the scan fetches at once. setec answers one request per
    /// value and there are hundreds of them; eight keeps the scan short
    /// without making the server's audit log look like a sweep.
    private static let reuseConcurrency = 8

    /// Fetches every secret's active value, hashes it, and keeps only the
    /// digest. This is the only operation in the app that reads values the
    /// operator did not point at, which is why it never starts on its own.
    func scanForReuse() async {
        guard reuseTask == nil else { return }
        let names = secrets.map(\.name)
        guard !names.isEmpty else { return }
        reuseProgress = ReuseProgress(done: 0, total: names.count)
        lastCall = "POST /api/get × \(names.count)"

        let task = Task { [client] in
            var digests: [String: String] = [:]
            var failures: [String: String] = [:]
            var index = 0
            await withTaskGroup(of: (String, Result<String, Error>).self) { group in
                func addNext() {
                    guard index < names.count else { return }
                    let name = names[index]
                    index += 1
                    group.addTask {
                        do {
                            // The plaintext lives exactly as long as this
                            // expression: it is hashed here and not returned.
                            let value = try await client.get(name: name).value
                            return (name, .success(ReuseScan.digest(of: value)))
                        } catch {
                            return (name, .failure(error))
                        }
                    }
                }
                for _ in 0 ..< min(Self.reuseConcurrency, names.count) {
                    addNext()
                }
                while let (name, result) = await group.next() {
                    switch result {
                    case let .success(digest): digests[name] = digest
                    case let .failure(error):
                        failures[name] = (error as? LocalizedError)?.errorDescription
                            ?? error.localizedDescription
                    }
                    await MainActor.run {
                        self.reuseProgress = ReuseProgress(done: digests.count + failures.count, total: names.count)
                    }
                    if Task.isCancelled {
                        break
                    }
                    addNext()
                }
            }
            let scan = ReuseScan(
                digests: digests,
                failures: failures,
                finished: .now,
                attempted: names.count
            )
            await MainActor.run {
                if !Task.isCancelled {
                    self.reuseScan = scan
                }
                self.reuseProgress = nil
                self.reuseTask = nil
                Log.app.notice("reuse scan: \(scan.digests.count) read, \(scan.failures.count) failed")
            }
        }
        reuseTask = task
        await task.value
    }

    func cancelReuseScan() {
        reuseTask?.cancel()
        reuseTask = nil
        reuseProgress = nil
    }

    var reusedNames: Set<String> {
        reuseScan?.reusedNames ?? []
    }

    func loadIdentity() async {
        identity = await TailnetIdentity.current()
    }

    // MARK: - Reading

    func refresh() async {
        if case .loading = loading {
            return
        }
        loading = .loading
        lastCall = "POST /api/list"
        do {
            let infos = try await client.list()
            adopt(infos.map(Secret.init))
            loading = .loaded
            lastSynced = .now
            problem = nil
            Log.app.notice("list returned \(infos.count) secrets")
        } catch {
            loading = .failed(message(for: error))
            Log.app.error("list failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func adopt(_ list: [Secret]) {
        secrets = list.sorted { $0.name < $1.name }
        if let selectedName, !secrets.contains(where: { $0.name == selectedName }) {
            self.selectedName = nil
        }
    }

    // MARK: - Reveal and copy

    /// Fetches the active value and shows it. The value is not fetched to
    /// render a row, only here and in `copyActiveValue`.
    func reveal() async {
        guard let secret = selected, revealed == nil, !isFetchingValue else { return }
        isFetchingValue = true
        defer { isFetchingValue = false }
        lastCall = "POST /api/get {\"Name\":\"\(secret.name)\"}"
        do {
            let value = try await client.get(name: secret.name)
            revealed = Revealed(name: secret.name, version: value.version, value: value.value)
            problem = nil
            scheduleHide()
        } catch {
            problem = message(for: error)
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        revealed = nil
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: SecretStore.revealLifetime)
            guard !Task.isCancelled else { return }
            self?.revealed = nil
        }
    }

    /// The remaining lifetime of the revealed value is not counted down in the
    /// UI; the footer states the rule instead, which is what the design shows.
    func copyActiveValue() async {
        guard let secret = selected, !isFetchingValue else { return }
        isFetchingValue = true
        defer { isFetchingValue = false }
        lastCall = "POST /api/get {\"Name\":\"\(secret.name)\"}"
        do {
            let value = try await client.get(name: secret.name)
            let change = SecretPasteboard.copy(value.value)
            problem = nil
            confirmCopy()
            schedulePasteboardClear(change)
            Log.app.notice("copied a value to the pasteboard")
        } catch {
            problem = message(for: error)
        }
    }

    /// Loads the active value so the New version sheet can start from it.
    func currentValue() async -> String? {
        guard let secret = selected else { return nil }
        lastCall = "POST /api/get {\"Name\":\"\(secret.name)\"}"
        do {
            return try await client.get(name: secret.name).value
        } catch {
            problem = message(for: error)
            return nil
        }
    }

    private func confirmCopy() {
        copyConfirmed = true
        copyTask?.cancel()
        copyTask = Task { [weak self] in
            try? await Task.sleep(for: SecretStore.copyConfirmation)
            guard !Task.isCancelled else { return }
            self?.copyConfirmed = false
        }
    }

    private func schedulePasteboardClear(_ change: Int) {
        pasteboardTask?.cancel()
        pasteboardTask = Task {
            try? await Task.sleep(for: SecretPasteboard.lifetime)
            guard !Task.isCancelled else { return }
            SecretPasteboard.clear(ifChangeCountIs: change)
        }
    }

    // MARK: - Writing

    /// `put` appends a version; `activate` makes it the one consumers fetch.
    /// The two are separate calls, which is what the sheet's API preview says.
    func createSecret(name: String, value: String, activate: Bool) async -> Bool {
        await write(describing: activate ? "POST /api/put → POST /api/activate" : "POST /api/put") {
            let version = try await self.client.put(name: name, value: value)
            if activate {
                try await self.client.activate(name: name, version: version)
            }
            await self.refresh()
            self.selectedName = name
        }
    }

    func createVersion(name: String, value: String, activate: Bool) async -> Bool {
        await createSecret(name: name, value: value, activate: activate)
    }

    func activate(name: String, version: Int) async -> Bool {
        await write(describing: "POST /api/activate {\"Name\":\"\(name)\",\"Version\":\(version)}") {
            try await self.client.activate(name: name, version: version)
            await self.refresh()
        }
    }

    func deleteSecret(name: String) async -> Bool {
        await write(describing: "POST /api/delete {\"Name\":\"\(name)\"}") {
            try await self.client.delete(name: name)
            if self.selectedName == name {
                self.selectedName = nil
            }
            await self.refresh()
        }
    }

    func deleteVersion(name: String, version: Int) async -> Bool {
        await write(describing: "POST /api/delete-version {\"Name\":\"\(name)\",\"Version\":\(version)}") {
            try await self.client.deleteVersion(name: name, version: version)
            await self.refresh()
        }
    }

    private func write(describing call: String, _ body: () async throws -> Void) async -> Bool {
        busy = call
        lastCall = call
        defer { busy = nil }
        do {
            try await body()
            // The body reloads the list, which sets `lastCall` to that reload.
            // The status bar names what the user asked for, so the write is
            // restored as the last call.
            lastCall = call
            problem = nil
            return true
        } catch {
            problem = message(for: error)
            Log.app.error("\(call, privacy: .public) failed")
            return false
        }
    }

    // MARK: - Transitions

    func dismissProblem() {
        problem = nil
    }

    private func selectionChanged() {
        hide()
        copyTask?.cancel()
        copyConfirmed = false
        lastCall = selectedName.map { "Selected \($0)" } ?? "No request yet"
    }

    private func scopeChanged() {
        query = ""
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    // MARK: - Debug endpoint

    /// What `make eval CMD=state` returns. Names and version numbers only —
    /// no value ever reaches this dictionary.
    func snapshot() -> [String: Any] {
        [
            "server": server.absoluteString,
            "count": secrets.count,
            "visible": visible.count,
            "scope": scope.title,
            "query": query,
            "selected": selectedName ?? NSNull(),
            "revealed": revealed != nil,
            "loading": String(describing: loading),
            "identity": identity?.loginName ?? NSNull(),
            "lastCall": lastCall,
            "problem": problem ?? NSNull(),
            "sort": sort.rawValue,
            "reuseScanned": reuseScan?.digests.count ?? NSNull(),
            "reusedNames": reuseScan?.reusedNames.count ?? NSNull(),
            "sheet": sheet?.id ?? NSNull(),
        ]
    }
}

extension Secret {
    /// Shapes the previews and the UI tests render: a group with several
    /// versions, one with a newer inactive version, one without a rollback,
    /// and an ungrouped name.
    static let samples: [Secret] = [
        Secret(name: "docker/immich/api-key", versions: [1, 2, 3], activeVersion: 3),
        Secret(name: "docker/immich/db-password", versions: [1], activeVersion: 1),
        Secret(name: "homelab/forgejo-api-token", versions: [1, 2], activeVersion: 1),
        Secret(name: "homelab/hetzner-api-token", versions: [1, 2, 3], activeVersion: 3),
        Secret(name: "juno/grafana-admin", versions: [1], activeVersion: 1),
        Secret(name: "standalone-token", versions: [1, 2], activeVersion: 2),
    ]
}
