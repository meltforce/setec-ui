import SwiftUI

/// The shape all three sheets share: a header, a body of sections, and a
/// footer with a hint on the left and the two buttons on the right. The
/// presentation animation and the scrim come from the native sheet.
struct SheetChrome<Header: View, Body: View, Footer: View>: View {
    var width: CGFloat = 620
    var headerBackground: Color = .clear
    var headerBorder: Color = Palette.sectionBorder
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Body
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            header()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .background(headerBackground)
                .hairline(.bottom, color: headerBorder)
            VStack(alignment: .leading, spacing: 20) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            footer()
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Palette.listSurface)
                .hairline(.top, color: Palette.sectionBorder)
        }
        .frame(width: width)
        .background(Palette.panel)
    }
}

/// Hint on the left, Cancel and the primary action on the right. The primary
/// button carries ⌘↩ and stays visible but inert while the form is invalid.
struct SheetFooter: View {
    let hint: String
    let primaryTitle: String
    let enabled: Bool
    var destructive = false
    var identifier: String
    let cancel: () -> Void
    let submit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: hint)
                .font(Typeface.meta)
                .foregroundStyle(Palette.textQuaternary)
            Spacer(minLength: 12)
            Button("Cancel", action: cancel)
                .buttonStyle(SecondaryButtonStyle(height: 30))
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("\(identifier).cancel")
            Button(primaryTitle) {
                guard enabled else { return }
                submit()
            }
            .buttonStyle(
                destructive
                    ? AnyButtonStyle(DestructiveButtonStyle(height: 30, enabled: enabled))
                    : AnyButtonStyle(PrimaryButtonStyle(height: 30, enabled: enabled))
            )
            .keyboardShortcut(.return, modifiers: .command)
            // The style already draws the inert state; `disabled` is what
            // stops ⌘↩ and what a UI test and VoiceOver read.
            .disabled(!enabled)
            .accessibilityIdentifier("\(identifier).submit")
        }
    }
}

/// `ButtonStyle` is not existential-friendly; this wrapper lets one button
/// carry either of two styles without duplicating the button itself.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    init(_ style: some ButtonStyle) {
        make = { configuration in AnyView(style.makeBody(configuration: configuration)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}

/// The value editor both creation sheets use: a monospaced text area that
/// renders bullets while hidden, with the character count in its footer.
struct SecretValueEditor: View {
    @Binding var text: String
    @Binding var revealed: Bool
    var identifier: String

    var body: some View {
        VStack(spacing: 0) {
            if revealed {
                TextEditor(text: $text)
                    .font(Typeface.monoInput)
                    .scrollContentBackground(.hidden)
                    .frame(height: 66)
                    .accessibilityIdentifier(identifier)
            } else {
                // A `SecureField` is single-line; the hidden state of a
                // multi-line value is rendered instead, and typing goes to the
                // same binding through an invisible field above it.
                ZStack(alignment: .topLeading) {
                    Text(verbatim: String(repeating: "•", count: min(text.count, 512)))
                        .font(Typeface.monoInput)
                        .foregroundStyle(Palette.maskedValue)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    TextEditor(text: $text)
                        .font(Typeface.monoInput)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(.clear)
                        .tint(Palette.accent)
                        .accessibilityIdentifier(identifier)
                }
                .frame(height: 66)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .panelSurface(radius: 8, fill: Palette.panel, ring: Palette.inputRing)
    }
}
