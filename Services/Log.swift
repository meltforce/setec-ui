import Foundation
import OSLog

/// One subsystem per app (the bundle identifier), one category per area.
/// `make logs` streams the subsystem; add a category here when a new area
/// needs its own filter.
///
/// Levels: `notice` for milestones the agent reads back with `log show`
/// (launch, listener up, save done); `info` and `debug` stay in memory and
/// appear only in `log stream`; `error` and `fault` persist and flush the
/// in-memory `info` lines around them.
enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "org.meltforce.app"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let net = Logger(subsystem: subsystem, category: "net")
    static let debugServer = Logger(subsystem: subsystem, category: "debug-server")
}
