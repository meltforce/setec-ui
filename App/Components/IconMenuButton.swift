import AppKit
import SwiftUI

/// A round icon button that opens a menu.
///
/// SwiftUI's `Menu` will not take the round shape: with `.menuStyle(.button)`,
/// `.buttonStyle(.glass)` and `.buttonBorderShape(.circle)` its background
/// disappears entirely, while the same three modifiers on a plain `Button`
/// with a square label draw the circle the system uses for an icon-only glass
/// button. Measured 2026-09-16 by rendering the variants side by side; Notes'
/// overflow button is the shape being matched.
///
/// So the control is a real `Button` — which is what `make click`, the UI
/// tests and VoiceOver need — and the menu is the `NSMenu` SwiftUI would have
/// built underneath anyway.
struct IconMenuButton: View {
    struct Item: Identifiable {
        var title: String
        var isDestructive = false
        var isSeparator = false
        var action: () -> Void = {}

        var id: String {
            isSeparator ? "-\(title)" : title
        }

        static func separator(_ id: String) -> Item {
            Item(title: id, isSeparator: true)
        }
    }

    let systemImage: String
    let items: [Item]
    var size: CGFloat = 16

    @State private var anchor = MenuAnchor()

    var body: some View {
        Button {
            anchor.present(items)
        } label: {
            Image(systemName: systemImage)
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .background(MenuAnchorView(anchor: anchor))
    }
}

/// Holds the `NSView` the menu is positioned against.
@MainActor
private final class MenuAnchor {
    weak var view: NSView?

    func present(_ items: [IconMenuButton.Item]) {
        guard let view else { return }
        let menu = NSMenu()
        for item in items {
            if item.isSeparator {
                menu.addItem(.separator())
                continue
            }
            let entry = NSMenuItem(title: item.title, action: #selector(Invoker.run), keyEquivalent: "")
            let invoker = Invoker(item.action)
            entry.target = invoker
            entry.representedObject = invoker
            if item.isDestructive {
                entry.attributedTitle = NSAttributedString(
                    string: item.title,
                    attributes: [.foregroundColor: NSColor.systemRed]
                )
            }
            menu.addItem(entry)
        }
        // Below the button's leading edge, which is where a menu opened from a
        // toolbar-style control belongs.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height + 4), in: view)
    }

    /// `NSMenuItem` keeps an unowned target, so the closure's owner is held by
    /// the item itself through `representedObject`.
    @MainActor
    private final class Invoker: NSObject {
        private let action: () -> Void

        init(_ action: @escaping () -> Void) {
            self.action = action
        }

        @objc func run() {
            action()
        }
    }
}

private struct MenuAnchorView: NSViewRepresentable {
    let anchor: MenuAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        anchor.view = view
    }
}
