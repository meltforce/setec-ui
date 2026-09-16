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

## Pending

| Status | Item | Where | Trigger | Notes |
|---|---|---|---|---|
| [open] | **Loading, empty and error states need a design review** | `App/Shell/SecretListView.swift`, `App/Shell/RootView.swift`, `App/Shell/AccessSection.swift` | | They are built, because the app cannot ship without them, but `design/handoff.md` § *Not yet designed* still holds: none of them came from design. What exists now: a `ProgressView` while the first `list` runs, `ContentUnavailableView` for an unreachable server (with Try Again), for an empty scope (with New secret) and for a search without results, a red strip below the toolbar for a failed call, and a panel in the access section naming the tailnet policy as the source when it could not be read. A `put` that races another writer is *not* handled beyond the generic strip — setec has no compare-and-set, so the second writer's version simply wins. |
| [open] | **Multi-server management** | — | — when a second setec server exists | The app is pointed at one server, chosen by `SETEC_SERVER`, the Settings field or the built-in default ([`DECISIONS.md`](DECISIONS.md)). The toolbar pill shows that one server and opens Settings. The design names a management screen and does not draw it. |
| [open] | **The identity is read by running the `tailscale` CLI** | `Services/TailnetIdentity.swift` | — if the CLI stops being installed on a seat Mac, or the toolbar has to show more than the login name | One `Process` per launch, for one display string. It degrades to "Identity unknown" when no CLI is found, so nothing depends on it. The alternative is the local `tailscaled` API, which needs the client authorization token from `/Library/Tailscale` — a credential read for a label, which is why it was not taken ([`DECISIONS.md`](DECISIONS.md)). |
