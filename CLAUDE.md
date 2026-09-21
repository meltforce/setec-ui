# setec-ui — a native macOS client for the homelab setec server

A SwiftUI app that manages secrets in [setec](https://github.com/tailscale/setec)
over the tailnet: list, reveal, copy, publish a version, activate, delete. It is
a client and nothing else — it stores no secret, holds no policy, and runs no
server.

## Gotchas

- **Never persist a secret value.** No disk cache, no `UserDefaults`, no log
  line, no crash report. A revealed value auto-hides after 20 s; a copied value
  is cleared from the pasteboard on a timer and the item is marked
  `org.nspasteboard.ConcealedType`. Values are fetched only on Reveal, Copy and
  Start from current — never to render a row.
- **Development runs against the production store.** `SETEC_SERVER` in the
  operator's profile names it, the operator's identity holds grants on every
  prefix, and the app has no read-only mode. A `put`, `activate` or
  `delete` issued from a Debug build changes a real secret that real services
  read. Prefer a name under a throwaway prefix for anything exploratory.
- **Namespaces are not objects.** `prod/db/password` is a flat string that only
  looks like a path. The sidebar tree and the autocomplete list are derived by
  splitting names on `/`; a group exists exactly as long as a secret carries its
  prefix. Do not add a create-namespace affordance or a model type for it.
- **Rollback is `activate`.** There is no rollback operation in the API and
  there must not be one in the app.
- **The access matrix is display-only.** The user is assumed to hold every
  capability, so the UI gates no action on a grant. The matrix exists because
  the grants of *other* principals are information only the policy has.
- **The grants come from the Tailscale control API, not from setec** — setec has
  no policy-read endpoint. The credential is a read-only OAuth client held in
  two setec entries, named in Settings › Access matrix, read from setec and
  exchanged for a bearer token. A Tailscale auth key is not a substitute: it
  registers a node and answers 401 here. The fleet's own entry names and the
  exchange are in homelab `SECRETS.md` § *Tailscale control API*.
- **`confirm-token` is not part of the API.** The CLI calls it a request digest
  and says explicitly that it is not a security feature. The delete sheet's
  type-the-name confirmation replaces it; do not surface a token.
- **The handoff is light-mode only; the dark palette is this repo's own.**
  `design/handoff.md` carries no dark values. The ones in
  `App/Design/Palette.swift` were chosen here and are recorded as a decision, so
  a palette arriving from design replaces them rather than being merged into
  them. The prototype also draws its own window chrome, which the real window
  provides.
- **`design/` is a specification, not a source tree.** The inline styles are the
  intended sizes, colors and hierarchy; the controls are rebuilt with native
  ones. Do not port the HTML.

## Standards

The app runs on the seat Macs, so homelab governs how it is built and installed.
Cited rather than restated, because a copy drifts from its source and neither
side reports it:

| Question | Document |
|---|---|
| Bundle identifier, signing team, `make install` target, where the build tools come from | homelab `configuration/macs/README.md` § *Self-built Mac apps* |
| The setec server, the prefix grants, what each prefix means | homelab `SECRETS.md` § *setec* |
| Reading the Tailscale control API, and which credential does it | homelab `SECRETS.md` § *Tailscale control API* |
| Where a published repo is mirrored, and that nothing may originate on GitHub | homelab `STANDARDS.md` § *Git & repos* |
| The Developer ID certificate and the notarization credentials | homelab `SECRETS.md` § *Apple code signing* |
## Repo documents

These documents carry state over time. The axis is where a thing *is*, not what
it is about.

| File | Holds |
|---|---|
| `ROADMAP.md` | Open work only. Status token `[open]`. |
| `DECISIONS.md` | Decisions taken, including decisions not to do something — those are the ones most likely to be re-derived from scratch otherwise. |
| `INCIDENTS.md` | Postmortems for things that broke. Newest first. |

**The movement rule.** When an item closes it is *removed* from `ROADMAP.md`,
and its reasoning moves to whichever document above holds that kind of thing.
Nothing is struck through — a struck-through row is a row that should have been
moved. Status tokens are exactly `[open]`, `[done YYYY-MM-DD]`,
`[dropped YYYY-MM-DD]`; emoji never carry status.

**Before closing an item, read its entry for residual work, dates, or
triggers.** Each of those becomes its own `[open]` row before the entry leaves
the roadmap. This is the step that gets skipped, and skipping it is how
finished-looking work quietly loses its tail.


**No new top-level documents** unless the concern is genuinely orthogonal to the
ones above. Everything else lives inside a project directory.

**Operational exceptions never live in documentation.** Excluding a host from a
run, skipping a check for one case — those belong in configuration, in a
condition, in the inventory. Documentation may reference them; it may not
replace them.

Every rule written here carries a one-line **why**, so it can be revisited when
the context that produced it changes.

## Language

English is the only language used inside this repo. This is not a style
preference — German prose describing English identifiers forces a translation
layer ("Rolle" in the text, `role` in the YAML) and breaks keyword search
between an explanation and the code it explains.

Applies to every document, every code comment and docstring in every language
present, log messages, error strings, user-facing CLI output, identifiers
(variables, functions, roles, tags, unit names, secret paths), and commit
messages.

Number and date formats follow the English convention: `1.82 GB` (decimal
point), `217,226` (comma as thousands separator), `2026-08-04` (ISO 8601, never
`04.08.2026`).

The only exception is a verbatim quote of external output — an upstream error
message, vendor documentation — which keeps its original wording.

The copy a GUI app shows its users is a product decision, not a repo-language
question: the base language in the string catalog is English, and every other
language is a localization of it. A German label therefore lives in the
localization table, never as the source string in code.

Conversation language is independent of this and follows the operator.

## Git workflow

Single developer. **`main` is the only long-lived branch** — commit straight to
`main`, never open a PR for this repo. This overrides the harness default of
branching before committing.

**Commit and push autonomously** once a coherent change is complete and
verified. No approval needed per commit.

**Stage explicitly, never `git add -A`.** Parallel sessions run in this same
checkout; a blanket add sweeps up their work in progress and commits it under
your message. Name the paths you touched.

### Parallel sessions

Isolate concurrent sessions with worktrees:

```bash
claude --worktree <name>          # .claude/worktrees/<name>, branch worktree-<name>
```

A worktree branch is **ephemeral plumbing, not a feature branch**. Never push it
as a branch, never open a PR from it. Land the work on `main`:

```bash
git fetch origin
git rebase origin/main
git push origin HEAD:main          # a rejection means another session landed first
```

Rebase and push again rather than forcing.

Do **not** start background sessions for work that edits this repo — a
background session commits, pushes its own branch and opens a draft PR without
asking, and is hard-wired never to push to `main`. Background sessions are fine
for read-only investigation.

**If a harness rule conflicts with this, this file wins.** `main` *is* the review
surface here and `git revert` is the undo. Say plainly which rule you are
setting aside, then land the work. Do not stop at "the commit is ready, please
push it yourself" — that hands back a half-finished task.

## Skills

A skill lives in exactly one home, decided by *what it touches* — not by where
you were when you wrote it.

| Home | For |
|---|---|
| `.claude/skills/<name>/` in this repo | Skills that depend on this project: its scripts, its services, its MCP servers. Committed here. |
| `~/.claude/skills/<name>/` | Skills that work anywhere and carry no project dependency. |

Decide the home before writing. If the skill would fail outside this project, it
belongs here.

**Those two paths are the only places Claude Code looks**, plus a plugin's own
`skills/` directory. A `skills/` directory at the repo root is not a discovery
location — a skill placed there is invisible until something links it into
`.claude/skills/`, and a link that is not committed exists on one machine only.

`.gitignore` therefore has to let the directory through. `.claude/*` with
`!.claude/skills/` keeps session state out while committing the skills:

```
.claude/*
!.claude/skills/
!.claude/settings.json
!.claude/project-standards.json
.claude/settings.local.json
```

A `description` carries the literal trigger phrases that should invoke the
skill, in the languages they are spoken in, plus the cases that should *not*
invoke it. The description is the only part loaded into every session, so it
does the whole job of routing.

An entry under `.claude/skills/` may be a symlink to a directory elsewhere on
disk — Claude Code follows it and reads `SKILL.md` from the target. That is
worth using when a skill genuinely has to live somewhere else; it is not worth
using to keep the source outside `.claude/`, because the link then has to be
recreated on every checkout.

## Claude settings

`.claude/settings.json` is committed; `.claude/settings.local.json` is not.
Project scope belongs in the repo, session and machine state does not.

**`allow` and `deny` are both required.** An allow list on its own describes what
is permitted and says nothing about what is refused, which reads as a complete
policy and is not one.

**Deferred tool schemas.** With several MCP servers attached, set
`env.ENABLE_TOOL_SEARCH: "auto"` — tool names load into every session, schemas
are fetched on demand. Measure before and after with `/context` rather than
assuming: the saving is large when the catalog is large and negative when it is
small, which is why the value is `auto` and not `true`.

Settings that belong to this project live here rather than in a host-level
configuration role: they deploy with a `git pull`, need no privileged run, and
appear in a diff. The cost is that they cover only sessions whose working
directory is this repo — anything spawned from elsewhere does not get them.

## Mac app

This is a native SwiftUI app scaffolded from `mac-app-template`. `project.yml`
is the project; `*.xcodeproj` is generated by `make project` and gitignored.

| Command | Does |
|---|---|
| `make run` | Kills the previous instance, builds Debug, launches, waits for the window, prints the last log lines |
| `make check` | `swiftformat --lint`, `swiftlint`, build, unit tests — the gate after a change |
| `make verify` | `check` plus the UI tests — the gate before `make install`, which now runs it |
| `make screenshot` | Asks the running DEBUG build to render its key window to `.agent/screenshot.png` |
| `make inspect` | Accessibility tree of the running app (`axdump`); `make click ID=…`, `make type TEXT=…`, `make key KEY=return` |
| `make eval CMD=state` | Talks to the DEBUG build's `DebugServer`: `state`, `action <name> <json>` |
| `make logs` | Streams this app's unified log by subsystem |
| `make install` | Copies the Release build to `/Applications` |

Skills: `mac-app-run` before building or launching, `mac-ui-patterns` before
writing a view, `mac-app-verify` before claiming a task done.

- **A green build proves valid code, not a finished feature.** Every task that
  changes app code ends with `make check`, `make run`, and the evidence the
  task calls for — a screenshot, a `state` dump, an `axdump` click. Say which
  requested behaviour was not exercised.
- **Menu shortcuts are focus problems, not menu problems.** A `Commands` entry
  reaches its handler through `@FocusedValue`. A shortcut that does nothing
  while a text field is focused is a missing focused value or a first responder
  that consumes the key, never a wrong `keyboardShortcut`.
- **Give every control the agent must find an `.accessibilityIdentifier`** in
  `feature.element` form (`items.list`, `inspector.title`). `axdump --click`
  and the UI tests address controls by that identifier; a control without one
  is invisible to both.
- **Register state and actions with `DebugServer`** in `AppDelegate` for
  anything the agent may need to verify without a screenshot. DEBUG builds
  only; the Release build compiles the calls away.
- **TCC grants are keyed to team ID plus bundle ID.** Both are fixed in
  `project.yml`; changing either means granting Accessibility and Screen
  Recording again, and a process running at grant time sees the grant only
  after a restart.
- Inspection has a budget: at most five `inspect`/`click`/`eval`/`screenshot`
  calls per build, at most three build-and-inspect cycles per task. Past that,
  state what remains unverified.
- **Quit with `make stop`, never `pkill`.** A forced quit leaves AppKit's
  window restoration state with no windows, and the next launch shows none:
  `make run` reports "no window after 15 s" while `make eval CMD=windows`
  returns an empty list. Bisecting code against that costs an afternoon
  (`mac-app-template/INCIDENTS.md`, 2026-09-15).
- **`Text("… \(anInt)")` groups the digits by locale** — document 3711 reads
  "3.711" on a German Mac, because the interpolation goes through
  `LocalizedStringKey`. An id, a port or a build number is not a quantity:
  `Text(verbatim:)`, or build the string in Swift first.
- **A `URLProtocol` stub must not touch a `@MainActor` test class.** Its
  handler runs on a URLSession thread; the symptom is `Executed 0 tests` with
  every test started and none finished. Record what the stub sees in a
  separate `@unchecked Sendable` object behind a lock.
- **A tap gesture is not a press.** `make click` and the UI tests activate
  controls through accessibility, which `.onTapGesture` does not answer.
  Anything the agent or a test has to activate — a scrim, a chip, a row
  action — is a `Button`.
- **An `.accessibilityIdentifier` on a container replaces the identifiers of
  every child inside it.** Measured three times on 2026-09-16 in this repo: an
  identifier on the sheet body, on the detail column and on the version table
  made every text field, static text and button beneath them report the
  container's identifier, and `make click` and the UI tests stopped finding
  them. Identifiers go on leaves. The rule is in
  `mac-ui-patterns/references/type-ahead.md`; it is repeated here because it
  costs a build cycle to rediscover.
- **Nothing in this app uses a tooltip, because none works here.** `.help` on
  a plain `Text` shows none, with or without a `contentShape`, and an `NSView`
  overlay carrying a `toolTip` shows none either (measured 2026-09-16 on macOS
  27.0; no tooltip window in `CGWindowListCopyWindowInfo` after a three-second
  hover). An explanation goes inline — the access matrix's legend is the
  worked example.
- **`.buttonBorderShape(.circle)` needs a label with an explicit square
  frame.** With a label of the glyph's own width the shape reverts to a
  capsule, and with `.circle` set it draws no background at all. SwiftUI's
  `Menu` will not take the round shape under any combination: an icon-only
  menu button is a `Button` with an `NSMenu` — `App/Components/IconMenuButton.swift`.
- **The app carries no built-in server.** `SETEC_SERVER` or the Settings field
  names one; with neither, the list column reads "No server yet" and no request
  is made (`SecretStore.Loading.unconfigured`). A client that shipped with one
  tailnet's host in it would point every other installation at that host
  ([`DECISIONS.md`](DECISIONS.md), 2026-09-21).
- **`make run` hands the app the shell's `SETEC_SERVER`; a launch from the
  Dock does not.** The operator's profile exports it, so an app started from
  the terminal inherits it and the environment wins over the Settings field —
  which then appears to do nothing, although the field is disabled and says so.
  The installed app started from Spotlight or the Dock has no such variable and
  the field applies. To test a different server from here, launch without it:
  `env -u SETEC_SERVER open -n ".build/Build/Products/Debug/Setec UI.app"`.
  Measured 2026-09-18 with `ps eww` on the running process.
- **A write is confirmed by re-reading, never by the status code.** `delete`
  and `delete-version` re-list and check that the name or the version is
  actually gone; a 200 with nothing removed is reported as a failure
  (`SecretStore.Unconfirmed`). The rule comes from a measured case in the
  fleet's backup tooling on 2026-09-18: `pvesm free` exits 0 when PBS refuses
  the deletion, and the loop reported "forgotten: 21, failed: 0" with two
  snapshots still present.
- **A setec outage reads as a credential problem in everything that depends on
  it.** setec runs on one host (homelab `architecture/OVERVIEW.md` § *Secrets
  and identity*), so a reboot of that host takes it down; the git credential
  helper that reads from setec then answers `could not read Username for
  https://git…`, which names the credential and not the cause. The access
  matrix keeps the two apart — `TailnetPolicyClient.Failure.unreachable` says
  setec is unreachable, `.credential` says the entry could not be read.
- **A synthesized `CGEvent` mouse move does not reach SwiftUI's `.onHover`.**
  Rollover behaviour cannot be shown with `screencapture` from here; assert it
  in a UI test, where `XCUIElement.hover()` works, and assert the geometry
  (`frame.midY`, `frame.height`) rather than trying to photograph it.
- **A release is a tag on Forgejo, and the DMG is built on GitHub.** The fleet
  has no macOS runner, so `.github/workflows/release.yml` is the one pipeline
  that runs outside the tailnet. It is edited here and arrives on the mirror
  with the next sync; a commit made on GitHub is removed by the next
  `git push --mirror`, which is why nothing in that workflow writes back to the
  repository. `README.md` § *Releases* has the tag form.
- **A version is a date and has three components at most.**
  `CFBundleShortVersionString` takes three period-separated integers, so
  `YYYY.MM.DD` fills it exactly and a second release on the same day carries
  its counter as the build number (`scripts/package.sh`). A four-component
  version string in the bundle is what `altool` and the App Store reject; the
  notary service accepts it, so nothing here would report it.
- **A `confirmationDialog` is an `_NSAlertPanel`, which the agent cannot
  drive.** Its buttons report `missing value` for their name, `osascript` does
  not reach them and a synthesized Return does not either. A destructive
  confirmation is a sheet — see `App/Sheets/DeleteVersionSheet.swift` and
  [`DECISIONS.md`](DECISIONS.md).

### Working rhythm

- **Before the first tool call, write the task brief:** `Explicit: … |
  Inferred: … | Unresolved: …`. Ask only when `Unresolved` holds a mutually
  exclusive product or architecture choice; decide implementation details
  yourself.
- **An independent request starts a fresh session**; a correction or a
  problem report stays in the running one. `README.md`, `CLAUDE.md` §
  Gotchas, `DECISIONS.md` and `git log` are what the fresh session reads, so
  `mac-app-verify` keeps them current.
- **A reported defect goes to a read-only planner first:** an `Explore` agent
  that returns Diagnosis, Evidence, Fix plan, Verification contract, Risks.
  Implement from that, reproduce the failure before the fix, show the after.
- **A pointed-at element** (`make at X=… Y=…`, or an identifier the operator
  names) is edited surgically: that element, nothing around it, one to three
  sentences of reply.

## Verification

A task that changed app code ends with the `mac-app-verify` skill. The contract
and its commands live there, not here — they are needed rarely and are long.

The gate is split: `make check` after a change, `make verify` before an
install. The skill carries which is which and the measurement behind the split;
`mac-app-template/DECISIONS.md` carries the reasoning. This repo is where the
numbers were taken — 49 unit and 7 UI tests, 4.9 s against 84 s on 2026-09-16.
