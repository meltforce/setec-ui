import AppKit
import SwiftUI

/// A tooltip that works on any view.
///
/// SwiftUI's `.help` reaches controls — a `Button`, a `Toggle` — but produces
/// nothing on a plain `Text`, with or without a `contentShape`: measured
/// 2026-09-16 on macOS 27.0 by hovering the access matrix's column headings
/// for three seconds and finding no tooltip window in `CGWindowListCopyWindowInfo`.
/// This overlays an `NSView` whose `toolTip` AppKit itself manages, so the
/// delay, the placement and the dismissal are the system's.
private struct TooltipView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.toolTip = text
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        view.toolTip = text
    }
}

extension View {
    /// Attaches a system tooltip. Use instead of `.help` on anything that is
    /// not a control.
    func tooltip(_ text: String) -> some View {
        overlay(TooltipView(text: text))
    }
}
