import AppKit
import SwiftUI

/// The token list from `design/handoff.md` § *Design Tokens*, one property per
/// token, named for its role rather than its hex value.
///
/// The handoff specifies light mode only and says so. The dark values are the
/// second pass it calls for: the neutral ramp is inverted, the surfaces sit
/// between `#17181c` and `#2a2c32`, and every accent is lifted until it holds
/// its contrast on a dark surface — a blue that reads as an action on white is
/// too dark to read as one on `#1c1d21`.
enum Palette {
    // MARK: - Neutrals

    static let textPrimary = color(light: 0x16171A, dark: 0xF2F3F5)
    static let textLeaf = color(light: 0x1D1E22, dark: 0xE8E9EC)
    static let textControl = color(light: 0x26272B, dark: 0xDCDDE1)
    static let textField = color(light: 0x3A3B40, dark: 0xC9CAD0)
    static let textBody = color(light: 0x4A4B51, dark: 0xB7B8BF)
    static let textSecondary = color(light: 0x5D6068, dark: 0x9FA1A9)
    static let textTertiary = color(light: 0x8A8B91, dark: 0x85878F)
    static let textQuaternary = color(light: 0x9A9BA0, dark: 0x787A82)
    static let textMeta = color(light: 0xA3A4AA, dark: 0x6E7078)
    static let maskedValue = color(light: 0xB8B9BE, dark: 0x55575F)
    static let ghostText = color(light: 0xB9BBC1, dark: 0x5B5D65)

    // MARK: - Surfaces

    static let panel = color(light: 0xFFFFFF, dark: 0x1C1D21)
    static let listSurface = color(light: 0xFBFBFC, dark: 0x191A1E)
    static let insetPanel = color(light: 0xFAFBFC, dark: 0x212328)
    static let fill = color(light: 0xF4F6F9, dark: 0x2A2C32)
    static let sidebar = color(light: 0xF3F4F7, dark: 0x17181C)
    static let toolbar = color(light: 0xECEEF1, dark: 0x1F2025)

    // MARK: - Lines

    static let rule = color(light: 0xEBEDF0, dark: 0x2A2C31)
    static let tableRow = color(light: 0xEDEFF2, dark: 0x26282D)
    static let sectionBorder = color(light: 0xEAECEF, dark: 0x2C2E34)
    static let panelRing = color(light: 0xE3E5EA, dark: 0x34363D)
    static let subtleRing = color(light: 0xE8EAEE, dark: 0x2E3036)
    static let chromeBorder = color(light: 0xDCDEE3, dark: 0x313339)
    static let inputRing = color(light: 0xD7DAE0, dark: 0x3A3C43)
    static let switchOff = color(light: 0xD2D4DA, dark: 0x44464E)

    // MARK: - Blue

    static let accent = color(light: 0x3C6DF0, dark: 0x4F7DF5)
    static let accentHover = color(light: 0x3462DD, dark: 0x6A91F7)
    static let linkHover = color(light: 0x2A55C9, dark: 0x8AA8F9)
    static let apiText = color(light: 0x2F56B5, dark: 0x93B0FB)
    static let activeBadgeText = color(light: 0x1F5BD6, dark: 0x9DBCFF)
    static let apiMeta = color(light: 0x6F83B8, dark: 0x7D8FC0)
    static let selectionRing = color(light: 0xC2D4FB, dark: 0x35508F)
    static let selectedRow = color(light: 0xEAF0FE, dark: 0x1E2942)
    static let badgeFill = color(light: 0xE5EDFD, dark: 0x1B2740)
    static let apiPanel = color(light: 0xF5F8FF, dark: 0x161D2C)
    static let apiPanelRing = color(light: 0xDCE6FB, dark: 0x2A3757)
    static let activeTableRow = color(light: 0xF7F9FE, dark: 0x1A2033)
    static let disabledPrimary = color(light: 0xB9C8EF, dark: 0x34456E)

    // MARK: - Green

    static let granted = color(light: 0x3FAE63, dark: 0x4CBB75)
    static let availableName = color(light: 0x3D8F5C, dark: 0x64C489)

    // MARK: - Amber

    static let filterDot = color(light: 0xD69016, dark: 0xE0A53A)
    static let rotationDue = color(light: 0xC08A2E, dark: 0xD9A441)
    static let warningText = color(light: 0x8A5A12, dark: 0xE3BD76)
    static let warningFill = color(light: 0xFDF6E7, dark: 0x2C2415)
    static let warningRing = color(light: 0xF0E0B8, dark: 0x4A3C1D)

    // MARK: - Red

    static let destructive = color(light: 0xC0392B, dark: 0xD0453A)
    static let destructiveLabel = color(light: 0xB4342A, dark: 0xE2695E)
    static let matchConfirmed = color(light: 0xA8362B, dark: 0xE2695E)
    static let apiRed = color(light: 0x98463A, dark: 0xE08278)
    static let redTitle = color(light: 0x8E2C21, dark: 0xF0A49A)
    static let redSubtitle = color(light: 0x96635C, dark: 0xC08D86)
    static let redMeta = color(light: 0xAB7A72, dark: 0xA87A73)
    static let redBullet = color(light: 0xC9A09A, dark: 0x7A4F49)
    static let redInputRing = color(light: 0xE0A9A2, dark: 0x8C4B43)
    static let collisionRing = color(light: 0xE8B3AD, dark: 0x8C4B43)
    static let disabledDestructive = color(light: 0xE3B6B0, dark: 0x5A332E)
    static let redHeaderFill = color(light: 0xFDF7F6, dark: 0x2A1A18)
    static let redApiPanel = color(light: 0xFBF6F5, dark: 0x241816)
    static let redRing = color(light: 0xF3E6E4, dark: 0x3D2825)

    // MARK: - Construction

    /// One `NSColor` with a dynamic provider per token, so the whole palette
    /// follows the system appearance without a second set of view code.
    static func color(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(rgb: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(
            srgbRed: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
