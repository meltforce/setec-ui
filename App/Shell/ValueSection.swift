import SwiftUI

/// The value of the active version. Masked until Reveal is pressed, and the
/// masked state is not the real value behind a cover: nothing is fetched
/// until Reveal or Copy asks for it, and the panel below holds bullets of a
/// fixed length so the mask does not leak the value's size either.
struct ValueSection: View {
    @Environment(SecretStore.self) private var store
    let secret: Secret

    private static let maskLength = 40

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Value of active version") {
                Button(revealed == nil ? "Reveal" : "Hide") {
                    if revealed == nil {
                        Task { await store.reveal() }
                    } else {
                        store.hide()
                    }
                }
                .buttonStyle(LinkButtonStyle())
                .disabled(store.isFetchingValue)
                .accessibilityIdentifier("value.reveal")
            }
            panel
            footer
        }
    }

    private var revealed: SecretStore.Revealed? {
        guard let value = store.revealed, value.name == secret.name else { return nil }
        return value
    }

    private var panel: some View {
        HStack {
            Group {
                if let revealed {
                    Text(verbatim: revealed.value)
                        .foregroundStyle(Palette.textPrimary)
                        .textSelection(.enabled)
                } else if store.isFetchingValue {
                    Text("Fetching …")
                        .foregroundStyle(Palette.textQuaternary)
                } else {
                    Text(verbatim: String(repeating: "•", count: Self.maskLength))
                        .foregroundStyle(Palette.maskedValue)
                }
            }
            .font(Typeface.monoValue)
            .lineSpacing(6)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            // On the value itself, not on the panel around it: an identifier
            // on the container would replace the copy button's own.
            .accessibilityIdentifier("value.panel")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .panelSurface()
        .overlay(alignment: .topTrailing) { copyButton }
        .onHover { hovering = $0 }
    }

    /// Copying belongs to the value, not to the window's action bar. The
    /// button appears on rollover, and SwiftUI takes a fully transparent view
    /// out of the accessibility tree — so `make click` and the UI tests hover
    /// the panel first, the same way a person does.
    private var copyButton: some View {
        Button(store.copyConfirmed ? "Copied ✓" : "Copy") {
            Task { await store.copyActiveValue() }
        }
        .buttonStyle(.glass)
        .controlSize(.small)
        .disabled(store.isFetchingValue)
        .padding(8)
        .opacity(hovering || store.copyConfirmed ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .animation(.easeOut(duration: 0.12), value: store.copyConfirmed)
        .accessibilityIdentifier("value.copy")
    }

    private var footer: some View {
        HStack {
            Text(verbatim: leftFooter)
            Spacer(minLength: 12)
            Text(verbatim: revealed == nil ? "Revealing performs a get request" : "Hides again in 20s")
        }
        .font(Typeface.meta)
        .foregroundStyle(Palette.textQuaternary)
        .accessibilityIdentifier("value.footer")
    }

    private var leftFooter: String {
        guard let revealed else {
            return "v\(secret.activeVersion) · base64 in transit"
        }
        let count = revealed.value.count
        return "v\(revealed.version) · \(count) character\(count == 1 ? "" : "s") · base64 in transit"
    }
}
