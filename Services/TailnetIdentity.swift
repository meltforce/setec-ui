import Foundation

/// Who the local machine is on the tailnet. setec authenticates the caller by
/// its tailnet identity, so the app asks for no credential; this type exists
/// only to name the identity in the toolbar and to mark the caller's own row
/// in the access matrix.
///
/// The source is `tailscale status --json`. The daemon's LocalAPI would avoid
/// the subprocess, but reaching it means reading the client-authentication
/// token out of `/Library/Tailscale`, which is a credential read for a display
/// string. The CLI is the documented interface and needs no token.
struct TailnetIdentity: Sendable, Hashable {
    /// The login name of the user the node is signed in as, `linus@example.com`.
    var loginName: String
    /// The node's MagicDNS name without the trailing dot, `blackbook.example.ts.net`.
    var nodeName: String

    /// The short form the toolbar shows: `linus@example`.
    var shortLogin: String {
        guard let at = loginName.firstIndex(of: "@") else { return loginName }
        let domain = loginName[loginName.index(after: at)...]
        let label = domain.split(separator: ".").first.map(String.init) ?? String(domain)
        return "\(loginName[..<at])@\(label)"
    }

    /// The candidate locations of the CLI: the Homebrew and standalone
    /// installs, then the binary inside the GUI app bundle.
    private static let binaries = [
        "/usr/local/bin/tailscale",
        "/opt/homebrew/bin/tailscale",
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
    ]

    /// Reads the identity, or returns nil when no CLI is installed, the daemon
    /// is not running, or the output does not parse. Every caller renders a
    /// neutral placeholder in that case; nothing else depends on it.
    static func current() async -> TailnetIdentity? {
        guard let binary = binaries.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            Log.app.notice("no tailscale CLI found; identity stays unknown")
            return nil
        }
        guard let data = await run(binary, arguments: ["status", "--json"]) else { return nil }
        return parse(data)
    }

    static func parse(_ data: Data) -> TailnetIdentity? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let node = root["Self"] as? [String: Any],
              let userID = node["UserID"] as? Int64,
              let users = root["User"] as? [String: Any],
              let user = users[String(userID)] as? [String: Any],
              let login = user["LoginName"] as? String
        else {
            return nil
        }
        let dns = (node["DNSName"] as? String) ?? ""
        return TailnetIdentity(
            loginName: login,
            nodeName: dns.hasSuffix(".") ? String(dns.dropLast()) : dns
        )
    }

    private static func run(_ binary: String, arguments: [String]) async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(filePath: binary)
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                } catch {
                    Log.app.error("\(binary, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: nil)
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus == 0 ? data : nil)
            }
        }
    }
}
