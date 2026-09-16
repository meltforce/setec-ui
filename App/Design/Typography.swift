import SwiftUI

/// The type scale from `design/handoff.md`. System UI font for chrome,
/// monospaced for every secret name, value, version number, principal and API
/// string — the distinction is what makes a name readable as data.
enum Typeface {
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// 10.5, uppercase, 600, letter-spacing .06em.
    static let sectionHeader = ui(10.5, .semibold)
    static let sectionHeaderTracking: CGFloat = 10.5 * 0.06

    static let badge = ui(11, .regular)
    static let meta = ui(11.5, .regular)
    static let label = ui(12, .regular)
    static let control = ui(12.5, .regular)
    static let controlEmphasis = ui(12.5, .medium)
    static let sheetTitle = ui(16, .semibold)

    static let monoLeaf = mono(13, .semibold)
    static let monoPrefix = mono(12, .regular)
    static let monoInput = mono(13, .regular)
    static let monoValue = mono(13.5, .regular)
    static let monoVersion = mono(13, .semibold)
    static let monoPrincipal = mono(12.5, .regular)
    static let monoApi = mono(11.5, .regular)
    static let detailTitle = mono(21, .bold)
    static let detailTitleTracking: CGFloat = -0.21
}

extension View {
    /// The uppercase section label the detail view and the sheets repeat.
    func sectionHeaderStyle() -> some View {
        font(Typeface.sectionHeader)
            .tracking(Typeface.sectionHeaderTracking)
            .textCase(.uppercase)
            .foregroundStyle(Palette.textQuaternary)
    }

    /// Digits that do not jump when a count changes.
    func tabularDigits() -> some View {
        monospacedDigit()
    }
}
