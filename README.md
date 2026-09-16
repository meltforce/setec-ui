# setec-ui

A native macOS app for [setec](https://github.com/tailscale/setec), Tailscale's
secrets service, which today is driven only by the `setec` CLI. It covers the
read-and-rotate workflow: find a secret by group, filter or search, reveal and
copy its value, publish a new version, roll back by activating an older one,
delete a version or a whole secret, and see which tailnet principals hold which
grant.

The app talks to the homelab setec server over the tailnet. Identity comes from
the local `tailscaled`, so there is no login screen and no token to enter.

## Layout

| Path | Holds |
|---|---|
| `design/` | The design handoff this app is built from: `handoff.md` is the specification, `api.md` the upstream API reference, `Setec Mac App.dc.html` plus `support.js` the interactive HTML prototype. A reference for look and behaviour, not code to port. |
| `App/Design/` | The handoff's token list as Swift: palette (light and dark), type scale, button styles, section header, API preview panel. |
| `App/Features/` | `SecretStore` with the list, the selection and everything derived from them; the name rules and the value generator; the access models. |
| `App/Shell/` | The window: toolbar, sidebar, list, detail with its three sections, status bar. |
| `App/Sheets/` | New secret, New version, Delete secret, Delete version — all four in the same chrome. |
| `Services/` | The setec client, the tailnet policy client, the tailnet identity, the pasteboard, the logger, `DebugServer` (DEBUG builds only). |
| `Resources/` | `Info.plist` and `App.entitlements` are generated from `project.yml` by `make project` and are gitignored. |
| `project.yml` | The project definition. `*.xcodeproj` is generated from it and never committed. |
| `tools/` | `check-docs.sh`, which guards the document contract and the language rule. |

## What runs outside this checkout

- The setec server `https://setec.coydog-fence.ts.net`, and the Tailscale
  control API at `api.tailscale.com`. Both are read over the tailnet; neither is
  configured from here. `SETEC_SERVER` and the Settings field point the app at a
  different server.
- The `tailscale` CLI, which the app runs once per launch to read the identity
  it shows in the toolbar. Without it the toolbar says "Identity unknown" and
  nothing else changes.
- `make install` copies the Release build to `/Applications/Setec UI.app`.
- The skills `mac-app-run`, `mac-app-verify` and `mac-ui-patterns` are symlinks
  in `~/.claude/skills/` pointing into `meltforce.net/mac-app-template`, and
  `~/bin/axdump` and `~/bin/winid` are built from its `tools/`. Both are
  installed by `make install-tools install-skills` in that checkout, not here.
- The build tools `xcodegen`, `swiftformat`, `swiftlint` and `xcbeautify` come
  from the homelab `dev-tools` role. Xcode comes from the App Store.

## Getting started

```bash
make run        # build Debug, launch, wait for the window
make verify     # lint, build, unit and UI tests
```

## Documents

| File | Holds |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Conventions and gotchas for working in this repo. |
| [`ROADMAP.md`](ROADMAP.md) | Open work. |
| [`DECISIONS.md`](DECISIONS.md) | Decisions taken, with reasoning. |
| [`INCIDENTS.md`](INCIDENTS.md) | Postmortems. |
