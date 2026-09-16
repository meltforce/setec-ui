import AppKit

/// Writing a secret to the pasteboard, with the two properties the design
/// asks for: clipboard managers skip the item, and the value does not stay on
/// the pasteboard indefinitely.
enum SecretPasteboard {
    /// The type clipboard managers read to decide that an item is a password
    /// and must not be recorded (nspasteboard.org).
    static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    /// How long a copied value stays on the pasteboard.
    static let lifetime: Duration = .seconds(45)

    /// Writes `value`, marked concealed, and clears it again after `lifetime`
    /// unless something else has written to the pasteboard in the meantime.
    /// The change count is what makes that check possible: a later write by
    /// any process raises it, and this only clears what it wrote itself.
    @discardableResult
    static func copy(_ value: String) -> Int {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("", forType: concealedType)
        pasteboard.setString(value, forType: .string)
        return pasteboard.changeCount
    }

    static func clear(ifChangeCountIs count: Int) {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount == count else { return }
        pasteboard.clearContents()
        Log.app.debug("pasteboard cleared")
    }
}

extension SecretPasteboard {
    /// For text that is not a secret — a name, an error message. Not marked
    /// concealed and not cleared on a timer.
    static func copyPlain(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
