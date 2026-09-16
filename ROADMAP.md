# Roadmap

**This file contains open work only.** Every row carries the status token
`[open]`. Closed work is not struck through here — it is removed and lives in
[`DECISIONS.md`](DECISIONS.md) (decisions, with their reasoning) or
[`INCIDENTS.md`](INCIDENTS.md) (postmortems).

Columns: **Status** is always `[open]`. **Where** names the artifact the work
touches. **Trigger** carries the condition for items that are deliberately
deferred, and is empty for items that are simply pending. **Notes** carries the
reasoning.

Before closing an item, check its entry for residual work, dates or triggers —
each becomes its own `[open]` row before the entry is moved out.

## Build

The order is the one the design handoff prescribes: each step is verifiable on
its own, and the autocomplete field in the New secret sheet is the piece most
likely to be rewritten, so it comes last.

| Status | Item | Where | Trigger | Notes |
|---|---|---|---|---|
| [open] | **Prove the app reaches setec under the Mac's tailnet identity** | `Services/`, `design/api.md` | — do it first, before any UI | setec authenticates the caller by its tailnet identity, so a plain HTTPS request from the app should carry the node's identity the way a `setec` CLI call does. That is the assumption the whole design rests on and it is unverified: MagicDNS resolution of `setec.coydog-fence.ts.net` from a non-sandboxed app bundle, and whether the server's WhoIs sees the same principal as the CLI. A `list` that returns the same names as `setec list` on the same Mac is the evidence. If it does not, every later step changes. |
| [open] | **API client for the seven operations** | `Services/` | | Typed wrappers for `list`, `get`, `get-version`, `put`, `activate`, `delete`, `delete-version`, per `design/api.md`. Values are base64 in transit: decode at the boundary and keep plaintext in memory only. |
| [open] | **Store: the secret list, the selection, and the derived state** | `App/` | | One observable object. `list` is fetched on launch, on Refresh and on window focus; nothing else is fetched to render. Derived rather than stored: the group tree and its counts, the autocomplete candidates, filter membership, the next version number, name validity, duplicate-value detection, the API preview string. `design/handoff.md` § *State Management* is the full list. |
| [open] | **Main window: sidebar, list, detail** | `App/` | | Three columns, 232 / 316 / rest, matching the prototype at 1280×800. Values are never fetched for rendering — only on Reveal, Copy and Start from current. |
| [open] | **The three sheets** | `App/` | | In order: New secret, New version, Delete secret. The autocomplete field in New secret is the most involved piece; the delete sheet's type-the-name confirmation is what replaces the CLI's `confirm-token`. |
| [open] | **The access matrix, read from the Tailscale control API** | `Services/`, `App/` | | The grants come from `GET /api/v2/tailnet/-/acl`, authenticated with the read-only OAuth client `homelab/ts-oauth-client-{id,secret}` read from setec — homelab `SECRETS.md` § *Tailscale control API* has the exchange. Display-only: the app gates no action on a grant. |

## Undesigned, undecided, and deferred

| Status | Item | Where | Trigger | Notes |
|---|---|---|---|---|
| [open] | **Per-version author and timestamp have no source** | `design/handoff.md` § *The setec data model*, the version table in the detail view | — decide before the version table is built | `list` returns version numbers only. Two ways out: drop the two columns, or carry the metadata elsewhere — a convention in the value envelope, or a sidecar store. A third, showing placeholder values, is excluded: a plausible-looking author who did not publish the version is worse than a missing column. Undecided as of 2026-09-16. |
| [open] | **A throwaway prefix would separate exploration from production secrets** | setec, `Services/` | — decide before the first `put` from a Debug build | Development runs against the production store under an identity with grants on every prefix. A prefix reserved for the app's own testing would make an accidental write harmless, at the cost of a name in the store that homelab `SECRETS.md` would have to list. The alternative is discipline alone, which is what this row exists to question. |
| [open] | **Loading, empty and error states are not designed** | `design/handoff.md` § *Not yet designed* | | First launch with no secrets, an unreachable server, a `get` that fails on permission, a `put` that races another writer. Implement them in the established visual language and flag them for design review; none of them is in the prototype. |
| [open] | **A delete-version confirmation is missing** | the version table, `design/handoff.md` § *Not yet designed* | | The prototype's row button deletes directly. The whole-secret delete is behind a typed name; a single version is not, and the two destructive paths should not differ by accident. |
| [open] | **Dark mode** | `design/handoff.md` § *Design Tokens* | — after the light-mode build matches the prototype | The palette is light-mode only. A native app that ignores the system appearance is conspicuous; interpolating the tokens is not a substitute for designing the second palette. |
| [open] | **Multi-server management** | — | — when a second setec server exists | The app is pointed at one server. The design names a management screen and does not draw it. |
