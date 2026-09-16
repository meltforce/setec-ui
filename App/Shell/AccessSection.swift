import SwiftUI

/// Which tailnet principals hold which capability on this secret's group. The
/// matrix is display-only — the app gates no action on a grant, because the
/// user is assumed to hold every capability. It is here because the grants of
/// *other* principals are information only the policy has.
struct AccessSection: View {
    @Environment(AccessStore.self) private var access
    let secret: Secret

    private var scope: AccessScope {
        secret.group.map(AccessScope.group) ?? .name(secret.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Access in \(scope.title)") {
                Text(verbatim: sourceLabel)
                    .font(Typeface.meta)
                    .foregroundStyle(Palette.textQuaternary)
                    .accessibilityIdentifier("access.source")
            }
            content
        }
    }

    private var sourceLabel: String {
        switch access.state {
        case .idle, .loading: return "Reading the tailnet policy"
        case .failed: return "The tailnet policy is unavailable"
        case .loaded:
            let count = access.ruleCount(in: scope)
            return count == 1 ? "1 rule from the tailnet policy" : "\(count) rules from the tailnet policy"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch access.state {
        case .idle, .loading:
            placeholder { ProgressView().controlSize(.small) }
        case let .failed(message):
            placeholder {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No grants to show")
                        .font(Typeface.control)
                        .foregroundStyle(Palette.textBody)
                    Text(verbatim: "\(message). The grants live in the tailnet policy file, not in setec.")
                        .font(Typeface.meta)
                        .foregroundStyle(Palette.textQuaternary)
                }
            }
        case .loaded:
            let rows = access.rows(in: scope)
            if rows.isEmpty {
                placeholder {
                    Text(verbatim: "No rule in the tailnet policy names \(scope.title).")
                        .font(Typeface.meta)
                        .foregroundStyle(Palette.textQuaternary)
                }
            } else {
                matrix(rows)
            }
        }
    }

    private func placeholder(@ViewBuilder _ content: () -> some View) -> some View {
        HStack {
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .panelSurface()
        .accessibilityIdentifier("access.placeholder")
    }

    private func matrix(_ rows: [PrincipalAccess]) -> some View {
        VStack(spacing: 0) {
            headerRow
            ForEach(rows) { row in
                Rectangle().fill(Palette.tableRow).frame(height: 0.5)
                bodyRow(row)
            }
        }
        .panelSurface()
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("Principal")
                .sectionHeaderStyle()
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(SecretCapability.allCases) { capability in
                Text(verbatim: capability.columnTitle)
                    .font(Typeface.mono(10.5))
                    .foregroundStyle(Palette.textQuaternary)
                    .frame(width: 74)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Palette.insetPanel)
    }

    private func bodyRow(_ row: PrincipalAccess) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(verbatim: row.principal)
                    .font(Typeface.monoPrincipal)
                    .foregroundStyle(Palette.textControl)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(verbatim: row.isSelf ? "you" : row.note)
                    .font(Typeface.meta)
                    .foregroundStyle(Palette.textQuaternary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(SecretCapability.allCases) { capability in
                let granted = row.capabilities.contains(capability)
                Text(verbatim: granted ? "●" : "–")
                    .font(Typeface.ui(granted ? 11 : 12))
                    .foregroundStyle(granted ? Palette.granted : Palette.inputRing)
                    .frame(width: 74)
                    .accessibilityLabel(
                        Text("\(row.principal) \(capability.rawValue) \(granted ? "granted" : "not granted")")
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(row.isSelf ? Palette.activeTableRow : .clear)
        .accessibilityIdentifier("access.row.\(row.principal)")
    }
}
