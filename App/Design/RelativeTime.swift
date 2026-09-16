import Foundation

/// The compact form the sidebar footer shows: "Synced 40s ago". `Text`'s
/// relative style spells the unit out ("40 seconds ago"), which does not fit
/// the 11px footer the design specifies.
enum RelativeTime {
    static func compact(since date: Date, now: Date = .now) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<2: return "just now"
        case ..<60: return "\(seconds)s ago"
        case ..<3600: return "\(seconds / 60)m ago"
        case ..<86400: return "\(seconds / 3600)h ago"
        default: return "\(seconds / 86400)d ago"
        }
    }
}
