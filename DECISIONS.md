# Decisions

Decisions taken about the setec macOS client, with the reasoning that led to
them. One section per decision, newest first.

A decision belongs here once it has been made — including decisions to *not* do
something, which are the ones most likely to be re-derived from scratch
otherwise. Open work lives in [`ROADMAP.md`](ROADMAP.md); postmortems live in
[`INCIDENTS.md`](INCIDENTS.md).

Structure per entry: **decision**, **reasoning**, **trigger to re-open**, and a
**revisions** log when the decision has changed. A revised decision is edited in
place with the old form recorded under revisions — the entry is not duplicated.

---

## 2026-09-21 — the app is published from a GitHub mirror, and versions are dates

**Decided:** 2026-09-21

**Decision.** `meltforce.net/setec-ui` on Forgejo stays canonical and
`github.com/meltforce/setec-ui` becomes a push mirror, which is where the
downloads live. One workflow runs on GitHub, `.github/workflows/release.yml`:
a `v*` tag builds a universal Release build, signs it with the Developer ID of
team R43S29F4G5, notarizes and staples it, packages a DMG and publishes a
release page with the SHA-256. The workflow and `make dmg` / `make notarize`
both call `scripts/package.sh`, so there is one set of steps rather than two.

**Versions are dates**, `YYYY.MM.DD`, with a fourth component for a second
release on the same day that becomes the build number rather than part of the
version string.

**Reasoning.** The mirror shape is the fleet's (homelab `STANDARDS.md` § *Git
& repos*) and is not re-argued here. What this repo adds is the one case that
shape does not cover: the release artifact is a signed macOS app, no runner in
the fleet is a Mac, and a seat Mac is a workstation rather than a build host.
GitHub's macOS runners are the only build host available, so the release
pipeline is the single thing that runs there — the precedent is
`github.com/meltforce/MBOMail`, whose release workflow this one is derived
from.

Two properties of the mirror decide the shape of the workflow. It is
`git push --mirror`, force and prune, so anything the workflow committed back
to the repository would be removed at the next sync — MBOMail's workflow
commits its appcast and its website to `main`, and that step cannot come along.
GitHub Releases are not git refs and survive. And the workflow file itself is
edited on Forgejo, never on GitHub.

Versions are dates because this app has no external API and no compatibility
contract to express: a consumer of a release wants to know how old it is, which
is the one question a semantic version does not answer. `CFBundleShortVersionString`
accepts three period-separated integers, which `YYYY.MM.DD` fills exactly —
hence the same-day counter goes to `CFBundleVersion`, where a build number
belongs anyway.

**Not chosen: Sparkle in-app updates and a Homebrew cask.** Both are MBOMail's
and both would work here, and neither is in this repo. Sparkle needs the
appcast to be reachable at a stable URL, and the route MBOMail takes to that —
committing `appcast.xml` to `main` from CI — is the one route the mirror
forbids. A cask needs a second repository (`homebrew-setec-ui`) that is not a
mirror of anything, which is a second publication channel to keep correct for
an app whose audience is currently one fleet. The trigger to revisit both is
the same: someone outside the fleet installing the app.

**Not chosen: archive and `xcodebuild -exportArchive`.** The app has no
embedded frameworks and no entitlement that needs a provisioning profile, so a
Release build product is already the shippable bundle; signing it during the
build with `CODE_SIGN_STYLE=Manual` is fewer moving parts than an archive, an
`ExportOptions.plist` and an export step that re-signs.

**What that costs, and what pays for it.** An archive strips
`com.apple.security.get-task-allow`; a `build` injects it so a debugger can
attach, for the Release configuration as well, and the notary service refuses
the submission for it — `status: Invalid`, "Archive contains critical
validation errors", once per architecture. Measured on 2026-09-21 in the first
run with credentials. `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` is what an
archive does here, and `scripts/package.sh` asserts the result rather than
trusting the setting. It asserts the other three properties a submission is
rejected for as well — wrong authority, no hardened runtime, no secure
timestamp — because each costs an upload and a wait to learn from the service,
and a second to check against `codesign` locally.

**Trigger to re-open.** An audience outside the fleet (then: cask, and
in-app updates with the appcast as a release asset rather than a commit); a
second signed artifact from this repo, for example a helper tool, which would
make the single-product assumptions in `scripts/package.sh` wrong; Apple
retiring the Developer ID certificate that team R43S29F4G5 holds.

---

## 2026-09-16 — reuse detection is a report, not a smart filter

**Decided:** 2026-09-16

**Decision.** The sidebar's smart filters answer from `/api/list` alone. Reuse
detection is not one of them: it becomes a report the operator calls explicitly,
in the shape 1Password's Watchtower has, and it is open work
([`ROADMAP.md`](ROADMAP.md)).

**Reasoning.** Two secrets hold the same value or they do not, and setec cannot
answer that without handing over both values: `/api/list` carries no digest and
there is no compare endpoint. Hashing makes the comparison safe to hold — it
does not make the reading free. Every value read is a `get` the server can
audit, and reading them is the one thing the rest of the app never does.

A sidebar row is the wrong place for that. The four filters next to it cost
nothing and are always true; a fifth that is empty until several hundred
audited reads have run does not belong in the same list, and a row that reads
"–" until pressed teaches the wrong thing about what the sidebar is. A report
is called deliberately, can state its cost before it runs, and can show its
result in the form the result actually has — groups of secrets that share a
value, rather than a flat list in which the pairing is invisible.

**Alternative considered.** Keeping it as a filter with the scan behind a
button in the list column, which is what was built and measured first. Rejected
on the operator's reading: the affordance promised a filter and delivered an
audit.

**What the measurement showed**, because it decides how big the report is: a
scan of the production store on 2026-09-16 read 288 values in under four
seconds at eight requests in parallel and found 29 secrets sharing a value with
at least one other — among them one registry token stored twice under two
prefixes, and an object store's access key and secret key holding one value.

**Trigger to re-open.** setec exposing a digest in `/api/list` or `/api/info`,
which makes the comparison free and puts the question back in reach of a filter.

**Revisions.** 2026-09-16, same day: first decided as a fifth smart filter
*Reused value*, with the scan behind a button in the list column and digests
held in memory. Withdrawn before it was used. The working implementation —
`ReuseScan`, `SecretStore.scanForReuse`, the progress and prompt states and
their tests — is commit `282a7b6` and is what the report starts from.

---

## 2026-09-16 — no keyboard shortcut carries Shift, and copying sits on the value

**Decided:** 2026-09-16

**Decision.** The shortcuts are ⌘N New Secret, ⌘⌥N New Version, ⌘⌥C Copy
Value, ⌘E Reveal or Hide Value, ⌘R Refresh, ⌘⌫ Delete Secret and ⌘F Find,
which focuses the toolbar's search field through `searchFocused`. None carries
Shift.

Copying the value is no longer a button in the detail column's action bar. It
is a control on the value panel itself, shown on rollover.

**Reasoning.** The operator asked for the Shift variants to be dropped. Two of
them cannot simply lose it: ⌘N already creates a secret, so a version takes
⌘⌥N; and ⌘C belongs to the text selection in the value panel and in every sheet
field — a `Commands` entry on ⌘C competes with the Edit menu's Copy for the
same key and makes copying a name out of a field ambiguous. Measured after the
change with `AXMenuItemCmdModifiers`: every entry reports 0 or 2, which is ⌘ and
⌘⌥; the only Shift in the menu bar is the system's own Redo.

Copying belongs next to the value because that is the object being copied, and
the action bar is about the secret as a whole.

**Alternative considered.** Giving Reveal ⌘R and moving Refresh to ⌘⌥R.
Rejected: ⌘R means reload across macOS, and Refresh is the window-wide action.

**Trigger to re-open.** A second action that wants ⌘E or ⌘⌥C.

---

## 2026-09-16 — the access matrix explains its columns inline, not in a tooltip

**Decided:** 2026-09-16

**Decision.** The matrix's section header carries a "What these mean" link that
discloses a legend: the six column headings with one line each on what the
action permits. No tooltip is used anywhere in the app, and
`App/Components/Tooltip.swift` is deleted.

**Reasoning.** Two mechanisms were tried and neither produced a tooltip in this
window. `.help` on a plain `Text` shows nothing, with or without a
`contentShape`. An `NSView` overlay carrying a `toolTip` — the mechanism AppKit
itself uses — shows nothing either; the operator reported both, and no tooltip
window appeared in `CGWindowListCopyWindowInfo` during a three-second hover.

Beyond the mechanism: the question that started this was "what does `c-ver`
mean", asked of an abbreviation the reader had no way to expand. An answer that
only exists while the pointer rests on the heading is a poor place for a
definition — it is invisible to a keyboard, absent from a screenshot, and
cannot be read while looking at the row it explains. The legend is visible,
reachable by keyboard, and sits directly above the matrix.

**Alternative considered.** Drawing a tooltip in SwiftUI with `onHover` and an
overlay. Rejected: it reimplements the delay, the placement and the dismissal
of a system affordance, and it would have been the third mechanism tried for
something that does not need to be a tooltip.

**Trigger to re-open.** A SwiftUI release in which `.help` works on a `Text`,
which would make a tooltip a reasonable *addition* to the legend.

**Revisions.** 2026-09-16, same day: first replaced `.help` with an AppKit
`toolTip` overlay in `App/Components/Tooltip.swift`, which did not work either.
Withdrawn in favour of the legend.

---

## 2026-09-16 — the toolbar carries the search field and two buttons, and nothing else

**Decided:** 2026-09-16

**Decision.** The window toolbar holds Refresh, New Secret and the search
field. The server pill and the tailnet identity are gone from it; both are read
in Settings › Server, alongside the node name and whether the server answered.
Refresh and New Secret are plain `Button`s in the system's styles —
`.borderedProminent` for New Secret — not the app's own `ButtonStyle`s.

Each of the three columns opens with a 38-point `ColumnHeader`, so their
contents begin on one line: the secret count in the sidebar, the scope and the
sort control in the list, the group and the actions on the selected secret in
the detail column. The secret's name moved out of that bar into the top of the
scrollable body, where it is the heading of what is shown beneath it.

**Reasoning.** macOS draws a toolbar item's own background, and a custom
`ButtonStyle` paints a second one inside it: the operator reported the two
buttons as "a bit like liquid glass, but not properly, with a white frame
behind them that does not fit", which is exactly that double background. The
server and the identity are one value each and neither changes while the window
is open, so a permanent strip for them spends toolbar width on a fact that is
read once — the width goes to the search field, which is used repeatedly and
searches every secret regardless of the selected group, so it belongs to the
window rather than to the column that chooses a group.

**Alternative considered.** Keeping the design's hand-drawn toolbar by
suppressing the system's item background. Rejected: `design/handoff.md` already
names the window chrome as the one thing that comes from the real window and is
not to be rebuilt, and the toolbar is part of it.

**Trigger to re-open.** A second setec server, which turns the server from a
displayed fact into a choice that belongs in the window.

---

## 2026-09-16 — the access matrix keeps `create-version` and names the actions it has no column for

**Decided:** 2026-09-16

**Decision.** The six columns stay as `design/handoff.md` specifies them, with
`c-ver` written out as `create` and every header carrying a tooltip with the
action's full name and what it permits. An action a rule grants that has no
column — `list`, in this tailnet — is named in a line below the matrix instead
of being discarded during parsing.

**Reasoning.** `create-version` is empty in every row because no rule in
`infrastructure/tailnet-policy/policy.hujson` grants it and this app never
calls it, which the operator read as a column without a purpose. Dropping it
would make the matrix silent about the grant the moment someone adds one, and a
matrix that cannot show a grant is worse than one with an empty column. The
same argument runs the other way for `list`: it *is* granted, `design/api.md`
does not list it among the per-secret actions, and until now the parser dropped
it — so the matrix was already silent about a real grant.

**Alternative considered.** A seventh column for `list`. Rejected because it is
not a per-secret action: it authorizes `/api/list`, which returns everything
the caller may see, so a per-group column for it would imply a scoping it does
not have.

**Trigger to re-open.** setec documenting `list` as a per-secret action, or a
rule in this tailnet granting `create-version`.

---

## 2026-09-16 — the app icon is a brass key on a labelled tag

**Decided:** 2026-09-16

**Decision.** `Resources/Assets.xcassets/AppIcon.appiconset` holds the first of
three `icongen` variants: a brass key lying on a dark labelled tag, on a deep
navy ground. The subject paragraph handed to the generator described setec in
everyday terms — a private company vault holding passwords and server keys,
with a history of older copies per key — and proposed a key on a paper tag, a
rack of numbered key tags, or a strongbox with a key on it.

**Reasoning.** The three variants were a key on a tag, a combination safe and a
vault door. The key on the tag has the strongest silhouette and the only
saturated colour, so it stays legible at 32 and 16 points; the safe loses its
dial markings at that size and the vault door is a grey disc that names no part
of what the app does. The tag also carries the app's actual subject — a key
that has a *name* — which neither of the others does.

**Alternative considered.** Drawing something from the window itself, such as
the version list or the grant matrix. Rejected: an icon of a table is an icon
of a spreadsheet.

**Trigger to re-open.** A request for a different subject, or a macOS release
that changes the icon shape the generator masks for.

---

## 2026-09-16 — a delete-version confirmation is a sheet, not a system alert

**Decided:** 2026-09-16

**Decision.** Deleting a single version opens `DeleteVersionSheet`, built from
the same `SheetChrome` as the delete-secret sheet: red header, the consequence
lines, the red API preview, `Delete version` as the primary button. It does not
ask for the name to be typed — that guard stays on the whole-secret delete.
`confirmationDialog`, which is what the first implementation used, is gone.

**Reasoning.** Two properties, both measured on 2026-09-16. The first is
consistency: every other modal in the app is a sheet in the app's own palette,
and a `confirmationDialog` renders as an `_NSAlertPanel` in the system's. The
second is reachability: that panel is a separate window that neither
`axdump --click` nor `osascript` addresses — its buttons report `missing value`
for their name, and a synthesized Return does not reach it, so the confirm path
had no way to be exercised from a test or from the agent. A destructive path
that cannot be tested is the one that should be.

**Alternative considered.** Keeping the alert and testing only the store method
behind it. Rejected because the untested part is exactly the step between the
button and the call.

**Trigger to re-open.** A macOS release in which `confirmationDialog` presents
as a sheet of the presenting window rather than as an alert panel.

---

## 2026-09-16 — the dark palette is designed, not interpolated

**Decided:** 2026-09-16

**Decision.** `App/Design/Palette.swift` carries both appearances. Every token
from `design/handoff.md` § *Design Tokens* has a light value taken from the
handoff and a dark value chosen here: the neutral ramp is inverted, the surfaces
sit between `#17181c` and `#2a2c32`, and each accent is lifted until it holds
its contrast on a dark surface. Sidebar row text and counts are the exception —
they use `.secondary`, because the sidebar style inverts the foreground of the
selected row and a fixed grey stays grey on the selection fill.

**Reasoning.** The operator asked for dark mode in the build. The handoff states
the palette is light-mode only and that a native build needs a second pass, so
the dark values are a design decision made here and are marked as such rather
than presented as part of the handoff.

**Alternative considered.** Deriving the dark values mechanically by inverting
lightness. Rejected: it produces a washed-out blue for the primary action and a
red that reads brown, both visible in the first pass before the accents were
lifted by hand.

**Trigger to re-open.** A dark palette arriving from design, which replaces
these values rather than being merged with them.

---

## 2026-09-16 — writes from a Debug build go to `setec-ui-dev/`

**Decided:** 2026-09-16

**Decision.** Exploratory `put`, `activate`, `delete` and `delete-version` calls
from a development build use names under `setec-ui-dev/`. The prefix is recorded
in homelab `SECRETS.md` § *setec*. It normally holds nothing: a group exists
exactly as long as a secret carries its prefix, so the prefix disappears from
`setec list` when the last test name is deleted.

**Reasoning.** Development runs against the production store under an identity
holding every capability on `*` (`infrastructure/tailnet-policy/policy.hujson`),
so a misdirected write changes a secret a real service reads. A reserved prefix
makes a misdirected write harmless. The cost is a name in the store that
`SECRETS.md` has to explain, which is smaller than the cost of the write it
prevents.

**Alternative considered.** Discipline alone, with no reserved prefix. Rejected
because the whole write path has to be exercised against the real server at
least once, and "be careful" is not a place for that to land.

**Trigger to re-open.** A second setec server that development could point at
instead.

---

## 2026-09-16 — the server URL comes from the Settings field and `SETEC_SERVER`

**Decided:** 2026-09-16 · **Revised:** 2026-09-21

**Decision.** `ServerSetting.resolve()` reads, in order: `SETEC_SERVER` from the
environment, then the value the Settings window stored in `UserDefaults`. There
is no third source: it returns `nil` when neither names a server, and the app
reports that state rather than contacting anything
(`SecretStore.Loading.unconfigured`). The Settings field writes through
`SecretStore.use(server:)`, so a server change takes effect without a relaunch;
while `SETEC_SERVER` is set the field is disabled and says so.

**Reasoning.** The environment variable is what the `setec` CLI reads, so a
shell that is already pointed at a server points the app at the same one. The
Settings field is what a person without that shell uses. Building both now costs
one resolution function; adding the field later would mean reworking a store that was
constructed once at launch.

**Alternative considered.** A constant alone. Rejected because the design draws
a server picker in the toolbar, and a picker over a value that cannot change is
a control that lies.

**Trigger to re-open.** A second setec server, which turns the picker from a
display of one value into a choice and moves the setting out of a single field.

**Revisions.** 2026-09-21: the third source, a built-in constant holding the
fleet's own server, was removed when the repository was published. A client that
ships with one tailnet's host in it points every installation that is not that
fleet's at a host its user cannot reach, and it states that host to anyone who
reads the binary — `strings` is enough. What replaced it is a fourth loading
state: with no server named, the list column reads "No server yet" and offers
Settings, the sidebar footer reads "No server", and no request is made. The cost
is one step on a fresh installation, including the operator's own: an installed
app started from the Dock inherits no `SETEC_SERVER` (see the gotcha in
[`CLAUDE.md`](CLAUDE.md)), so the field is filled once per Mac.

---

## 2026-09-16 — the version table drops author and timestamp, and two smart filters are replaced

**Decided:** 2026-09-16

**Decision.** The version table shows the version number, the `active` and
`latest` badges and the row actions. The design's "date · author" column and the
6-character digest are not built, and the list cards carry no relative age. The
sidebar's smart filters are *Latest is not active* (a newer version exists than
the one in use) and *Multiple versions*.

**Reasoning.** `/api/list` returns `Name`, `Versions` and `ActiveVersion` and
nothing else — confirmed against the production server on 2026-09-16, 286
secrets, and matching `design/api.md`. The design's *Rotation over 90 days* and
*Changed this week* both need a timestamp that has no source. The three filters
built instead are each answerable from the list response, so the sidebar keeps
its shape and every count in it is true.

**Alternative considered.** A local sidecar store recording what this app
writes. Rejected: it would describe only the changes made through this app on
this machine, so the column would be empty for every secret that existed before
and would disagree between two Macs. Also rejected, as the handoff already says:
placeholder values, because a plausible-looking author who did not publish the
version is worse than a missing column. The value envelope is ruled out by its
cost — a wrapped value is no longer the value, and every `setec get` in a
`run.sh` and every `setec.Store` consumer would read JSON where it expects the
secret.

**Trigger to re-open.** setec carrying per-version metadata in its API, which
restores the columns and the two time-based filters together.

**Revisions.** 2026-09-16: a third filter, *No rollback version*, was dropped.
It selected every secret with exactly one version — 268 of 288 in the
production store, so it named 93% of the sidebar's own contents — and it is the
exact complement of *Multiple versions*, which names the 20 that are worth
looking at. Two rows that partition the store between them are one row and its
negation, and the useful half is the smaller one.

---

## 2026-09-16 — the app reaches setec with a plain `URLSession`

**Decided:** 2026-09-16

**Decision.** The client is a plain `URLSession` against whatever server is
configured, with `Sec-X-Tailscale-No-Browsers: setec` on every call and no
credential of any kind. No Tailscale library is linked.
The tailnet identity shown in the toolbar is read separately, by running
`tailscale status --json`.

**Reasoning.** setec authorizes the caller by the tailnet identity of the source
address, so a request from a non-sandboxed app on a node that is signed in
carries the same principal as a `setec` CLI call from the same Mac. Measured on
2026-09-16: a Debug build listed the same 286 secrets that `setec list` returns
on the same Mac, MagicDNS resolved the name from inside the app bundle, and the
whole write path — put, activate, delete-version, delete — ran against
`setec-ui-dev/smoke` and left the store as it found it. This is the assumption
the rest of the design rests on, which is why it was the first thing built.

**Alternative considered.** Reading the identity from the local `tailscaled`
API instead of the CLI. Rejected: reaching it means reading the client
authorization token out of `/Library/Tailscale`, which is a credential read for
a display string.

**Trigger to re-open.** The app being sandboxed, or a setec deployment that
authenticates by something other than the peer identity.

---

## 2026-09-16 — the access matrix reads the Tailscale control API

**Decided:** 2026-09-16

**Decision.** The grant matrix is populated from the tailnet policy file,
fetched with `GET https://api.tailscale.com/api/v2/tailnet/-/acl`. The
credential is a read-only OAuth client held in two setec entries, read from
setec itself and exchanged for a bearer token. The matrix stays
display-only: the app gates no action on a grant.

**Reasoning.** setec exposes no policy-read endpoint, so the grants of other
principals cannot come from the same server as the secrets. The tailnet policy
is where they are actually defined. Such a client carries `policy_file:read`
among its scopes; homelab `SECRETS.md` § *Tailscale control API* names the
fleet's own client, documents the exchange and notes that
OAuth clients do not expire while API keys are capped at 90 days, which is what
makes this the durable path.

**Alternative considered.** Reading a local copy of the policy file, which
removes the network dependency and introduces a copy that drifts from the
tailnet without either side reporting it. Also rejected: showing invented
grants, or an empty matrix labelled as complete.

**Trigger to re-open.** setec gaining a policy-read endpoint, or the read-only
OAuth client losing `policy_file:read`.

**Revisions.** 2026-09-16: the two entry names moved from constants in
`TailnetPolicyClient` into a setting (`AccessSetting`, Settings › Access
matrix), and the defaults became the app's own `setec-ui/ts-client-{id,secret}`
rather than the fleet's own entry names. A name that
belongs to one fleet does not belong in an app's source, and an app pointed at
a different setec server has no reason to carry it; its own prefix is a name
the app can state without assuming whose store it is talking to. Leaving either blank switches the matrix off — a store with no policy
credential is an ordinary configuration, and the section now says "switched
off" rather than reporting an error. A wrong name reports the failure in the
matrix and names both entries; the secret list, the versions and every action
are untouched, which `AccessStoreTests` asserts and which was measured against
the production server in all three states: a name that does not exist, both
names blank, and the defaults restored.

2026-09-16, later the same day: the dialog states the rights the client needs
and shows the ones it has. The app calls exactly one endpoint,
`GET /api/v2/tailnet/-/acl`, so `policy_file:read` is the whole requirement —
no device, DNS or route scope. The token response carries the granted scope
list, so the dialog shows it and marks the one that is used; a client without
`policy_file:read` is reported as a missing scope rather than as a bare 403.
Measured 2026-09-16 against the fleet's shared read-only client, which returns
`devices:core:read devices:posture_attributes:read devices:routes:read
policy_file:read dns:read services:read` — five scopes wider than this app
needs, which is the argument for giving it a client of its own.

---

## 2026-09-16 — the app is not sandboxed

**Decided:** 2026-09-16

**Decision.** `com.apple.security.app-sandbox` stays `false` and
`com.apple.security.network.client` stays `true` in `project.yml`. Distribution
is `make install` to `/Applications`, not the App Store.

**Reasoning.** The app is for the fleet's seat Macs and is installed from a
local Release build, so the sandbox buys nothing it would otherwise be required
for. The scaffold from `mac-app-template` already ships both entitlements in
this shape; the decision is recorded because an unsandboxed app looks like an
omission to a reader who does not know it was chosen.

**Alternative considered.** Sandboxing anyway, as defence in depth. Rejected for
now because the app's whole function is to reach a host on the tailnet and hold
plaintext secrets in memory, and no sandbox entitlement changes either.

**Trigger to re-open.** A decision to distribute the app outside the fleet.

---

## 2026-09-16 — the design handoff is committed, the implementation prompt is not

**Decided:** 2026-09-16

**Decision.** `design/` holds the handoff specification, the API reference and
the HTML prototype. The `PROMPT.md` that accompanied them is not committed: its
build order and scope became rows in [`ROADMAP.md`](ROADMAP.md), its constraints
became the Gotchas in [`CLAUDE.md`](CLAUDE.md), and its two open questions
became rows here and in the roadmap.

**Reasoning.** The handoff is a fidelity reference that outlives the build and
is read again whenever a view is questioned. The prompt is a plan, and a plan
committed next to the roadmap is a second place where the scope is written; the
two drift and neither reports it.

**Alternative considered.** Committing `PROMPT.md` verbatim as provenance.
Rejected because `git log` and this entry already record where the scope came
from.

**Trigger to re-open.** A revised handoff arriving from design, which replaces
the contents of `design/` rather than being merged into it.
