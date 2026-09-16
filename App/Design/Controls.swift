import SwiftUI

/// The button shapes the design names: a filled primary, a white secondary
/// pill, a red destructive, and a text link. Each one is a `ButtonStyle`, so
/// the control stays a `Button` — a rounded rectangle with a label is not one,
/// and neither `make click` nor a UI test can press it.
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 28
    var enabled = true

    func makeBody(configuration: Configuration) -> some View {
        HoverBox { hovering in
            configuration.label
                .font(Typeface.controlEmphasis)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: height)
                .background(background(hovering: hovering, pressed: configuration.isPressed))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: Palette.accent.opacity(enabled ? 0.35 : 0), radius: 1, y: 1)
        }
    }

    private func background(hovering: Bool, pressed: Bool) -> Color {
        guard enabled else { return Palette.disabledPrimary }
        if pressed {
            return Palette.linkHover
        }
        return hovering ? Palette.accentHover : Palette.accent
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 28
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        HoverBox { hovering in
            configuration.label
                .font(Typeface.controlEmphasis)
                .foregroundStyle(destructive ? Palette.destructiveLabel : Palette.textControl)
                .padding(.horizontal, 10)
                .frame(height: height)
                .background(hovering || configuration.isPressed ? Palette.fill : Palette.panel)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Palette.inputRing, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.04), radius: 0.5, y: 1)
        }
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    var height: CGFloat = 30
    var enabled = true

    func makeBody(configuration: Configuration) -> some View {
        HoverBox { hovering in
            configuration.label
                .font(Typeface.controlEmphasis)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: height)
                .background(fill(hovering: hovering, pressed: configuration.isPressed))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    private func fill(hovering: Bool, pressed: Bool) -> Color {
        guard enabled else { return Palette.disabledDestructive }
        return hovering || pressed ? Palette.redTitle : Palette.destructive
    }
}

/// The inline text actions: Reveal, Generate, Start from current.
struct LinkButtonStyle: ButtonStyle {
    var size: CGFloat = 12
    var tint: Color = Palette.accent

    func makeBody(configuration: Configuration) -> some View {
        HoverBox { hovering in
            configuration.label
                .font(Typeface.ui(size, .medium))
                .foregroundStyle(hovering || configuration.isPressed ? Palette.linkHover : tint)
        }
    }
}

/// `ButtonStyle` cannot hold state, so the hover flag lives in this wrapper.
private struct HoverBox<Content: View>: View {
    @State private var hovering = false
    @ViewBuilder var content: (Bool) -> Content

    var body: some View {
        content(hovering)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}

// MARK: - Surfaces

extension View {
    /// The inset panel the value section and the options block use.
    func panelSurface(
        radius: CGFloat = 10,
        fill: Color = Palette.insetPanel,
        ring: Color = Palette.panelRing
    ) -> some View {
        background(fill)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(ring, lineWidth: 0.5)
            )
    }

    /// A 0.5px hairline in the given colour, on one edge.
    func hairline(_ edge: Edge, color: Color = Palette.sectionBorder) -> some View {
        overlay(alignment: alignment(for: edge)) {
            Rectangle()
                .fill(color)
                .frame(
                    width: edge == .leading || edge == .trailing ? 0.5 : nil,
                    height: edge == .top || edge == .bottom ? 0.5 : nil
                )
        }
    }

    private func alignment(for edge: Edge) -> Alignment {
        switch edge {
        case .top: .top
        case .bottom: .bottom
        case .leading: .leading
        case .trailing: .trailing
        }
    }
}

/// The section header row: an uppercase label, a hairline filling the middle,
/// and a control on the right.
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Text(title).sectionHeaderStyle()
            Rectangle()
                .fill(Palette.rule)
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)
            trailing()
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// `v12` — the version chip on a list card and in the sheet header.
struct VersionChip: View {
    let version: Int
    var emphasis = false

    var body: some View {
        Text(verbatim: "v\(version)")
            .font(Typeface.ui(11, emphasis ? .semibold : .regular))
            .tabularDigits()
            .foregroundStyle(emphasis ? Palette.apiText : Palette.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(emphasis ? Palette.selectedRow : Palette.fill)
            .clipShape(RoundedRectangle(cornerRadius: emphasis ? 5 : 4, style: .continuous))
    }
}

/// The blue panel that spells out the calls a sheet will make. It is what
/// makes the "activate immediately" switch's consequence legible.
struct APIPreview: View {
    let lines: [String]
    var destructive = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(lines, id: \.self) { line in
                    Text(verbatim: line)
                        .font(Typeface.monoApi)
                        .foregroundStyle(destructive ? Palette.apiRed : Palette.apiText)
                }
            }
            Spacer(minLength: 0)
            Text(verbatim: lines.count == 1 ? "1 request" : "\(lines.count) requests")
                .font(Typeface.monoApi)
                .foregroundStyle(destructive ? Palette.redMeta : Palette.apiMeta)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .panelSurface(
            radius: 8,
            fill: destructive ? Palette.redApiPanel : Palette.apiPanel,
            ring: destructive ? Palette.redRing : Palette.apiPanelRing
        )
        .accessibilityIdentifier("sheet.apiPreview")
    }
}
