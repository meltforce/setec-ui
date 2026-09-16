import SwiftUI

/// The 38-point bar that opens every one of the three columns, so their
/// contents start on one line. The list column carries the scope and the sort
/// control, the sidebar the secret count, the detail column the group and the
/// actions on the selected secret.
struct ColumnHeader<Content: View>: View {
    var background: Color = Palette.listSurface
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 8) {
            content()
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .background(background)
        .hairline(.bottom, color: Palette.rule)
    }
}
