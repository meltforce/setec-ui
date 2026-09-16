# Handoff: setec secrets manager — native macOS app

## Overview
A desktop GUI for [setec](https://github.com/tailscale/setec), Tailscale's secrets service. setec exposes a small
HTTP API over a tailnet; today it is driven by the `setec` CLI. This design covers the read-and-rotate workflow a
small team needs day to day: find a secret, copy its value, publish a new version, roll back, delete, and see who
else in the tailnet can do the same.

Target platform: native macOS window app (SwiftUI/AppKit). The prototype is HTML, rendered as a mock macOS window.

## About the Design Files
The files in this bundle are **design references created in HTML** — a prototype showing intended look and
behavior, not production code to copy. The task is to **recreate these designs in the target environment**
(SwiftUI is the natural fit for a native Mac app; AppKit or Catalyst also work) using that platform's
established controls and idioms. Where a native control does the same job as a hand-built element in the
prototype (`NSTableView` / `List` for the secret list, `NSSwitch` / `Toggle` for the switches, a real sheet
for the dialogs), prefer the native control and keep the visual result as close to the mock as the platform allows.

Do not port the inline styles literally. Read them as the intended specification: sizes, colors, and hierarchy.

## Fidelity
**High-fidelity.** Colors, type sizes, spacing, and copy are final and intentional. Recreate them precisely.
The one deliberate abstraction: the prototype draws its own window chrome (traffic lights, toolbar) — that comes
free from the real window and should not be rebuilt.

## The setec data model (read this first)
Everything in the UI follows from four facts about the API:

1. A secret has a **name** and a list of **versions**. Exactly one version is **active**.
2. Names are **flat strings**. `prod/db/password` only looks like a path. There is no namespace object:
   a group appears when the first secret with that prefix is created and disappears when the last one is deleted.
   The UI derives the sidebar tree and the autocomplete list by splitting names on `/`.
3. Operations: `list` (metadata only), `get`, `get-version`, `put` (append a version), `create-version`
   (append with a caller-chosen number), `activate`, `delete` (whole secret), `delete-version`.
   Values are base64 in transit.
4. Permissions are granted per action and per secret pattern in the tailnet policy
   (`tailscale.com/cap/secrets` grants). The app's own user is assumed to be an admin holding all capabilities,
   so the UI never gates its actions — but it **displays** the grants of everyone else, because that is
   information only the policy has and the user cannot otherwise see.

Two things the design shows that the API does **not** provide, and which need a decision before implementation:
- **Per-version author and timestamp.** `list` returns version numbers only. Either drop these columns, or
  carry the metadata elsewhere (a convention in the value envelope, or a sidecar store).
- **The grant matrix.** setec has no policy-read endpoint. This must come from the tailnet ACL
  (Tailscale API `/api/v2/tailnet/<t>/acl`) or a local copy of the policy file. If neither is available,
  cut the section rather than faking it.

The CLI's `confirm-token` for destructive commands is **not** part of the API — the source calls it a request
digest, explicitly not a security feature. The delete dialog's type-the-name confirmation replaces it.

## Screens / Views

### 1. Main window
**Purpose:** browse and act on secrets.
**Layout:** 1280×800 window, vertical stack: 52px toolbar, then a three-column split filling the rest.
Columns: 232px sidebar (fixed), 316px list (fixed), detail (flexible, min 0). 0.5px dividers between all three.

**Toolbar** (height 52, padding 0 16, background `#eceef1`, bottom border 0.5px `#d3d5da`, items gap 14):
- Traffic lights: three 12px circles, gap 8, `#ec6a5e` / `#f4bf4f` / `#61c554`. Native window provides these.
- 1px × 20px separator `#d8dade`.
- **Server picker**: white pill, radius 6, padding 4/10/4/8, shadow `0 0 0 .5px rgba(0,0,0,.12), 0 1px 1px rgba(0,0,0,.04)`.
  Contains a 7px green dot `#3fae63` (reachable), the tailnet hostname at 12.5px/500 `#26272b`, and a `▾`.
  Hover `#f7f8fa`. Opens a list of configured setec servers.
- **Identity**: "Signed in as dana@tail9a2f", 12px `#8a8b91` with the address in `#5d5e64`. From the local
  tailscaled identity — the app does not ask for credentials.
- Spacer, then **Refresh** (secondary button) and **+ New secret** (primary, `#3c6df0`, white 12.5px/500,
  radius 6, height 28, shadow `0 1px 2px rgba(60,109,240,.35)`, hover `#3462dd`; leading `+` at 14px).

**Sidebar** (background `#f3f4f7`):
- Search field: height 28, radius 7, white, inset shadow `0 0 0 .5px rgba(0,0,0,.1)`, 11px circle outline
  `#a9aab0` as the magnifier, placeholder "Search secrets" 12.5px. Filters across all secrets by substring,
  ignoring the selected group.
- Section header "Namespaces": 10.5px, uppercase, letter-spacing .06em, 600, `#9a9ba0`, padding 8/8/6.
- Group rows: 14px `▸` glyph column, label `name/` at 12.5px, right-aligned count in tabular numerals `#a3a4aa`.
  Row: padding 5/8, radius 6, gap 8. Selected: background `#3c6df0`, text white, weight 550. Sorted alphabetically.
- Section header "Smart filters", then three rows in the same shape with a colored `●` instead of the glyph:
  "Rotation over 90 days" `#d69016`, "No rollback version" `#b0b1b7`, "Changed this week" `#3fae63`.
  Selecting a filter clears the group selection and vice versa; clicking an active filter clears it.
- Footer: top border 0.5px `#dcdee3`, padding 10/14, 11px `#9a9ba0`, secret count left, "Synced 40s ago" right.

**List column** (background `#fbfbfc`):
- Header: height 38, bottom border 0.5px `#e9ebee`, current scope title 12.5px/600 left, sort control "Name ▾"
  11.5px `#9a9ba0` right.
- Cards: padding 9/11, radius 8, 2px vertical gap. Line 1 — group prefix in mono 12px `#9a9ba0` followed by the
  leaf in mono 13px/600 `#1d1e22`. Line 2 (margin-top 5, gap 8) — version chip `v12` (11px, padding 1/6,
  radius 4, background `#eef1f6`, color `#5d6068`, tabular numerals), relative age 11.5px `#9a9ba0`, spacer,
  then either "rotation due" `#c08a2e` or "N versions" `#a3a4aa`.
  Selected card: background `#eaf0fe`, ring `0 0 0 1px #c2d4fb`.

**Detail column** (white):
- Header (padding 20/26/16, bottom border 0.5px `#eaecef`): group prefix mono 12px `#9a9ba0`; secret leaf name
  mono 21px/650 `#16171a`, letter-spacing -.01em; meta row (margin-top 8, 12px `#8a8b91`, `·` separators):
  "Active: v12" with the version in `#3c6df0`/600, version count, "updated 3 days ago by ci-runner".
  Right-aligned actions, height 30, radius 7, gap 8: **Copy value** (primary; becomes "Copied ✓" for 1.8s),
  **New version …** (secondary), **···** (secondary, 30×30 — opens the destructive menu; in this design it goes
  straight to Delete).
- Body: scrollable, padding 20/26/28, sections stacked with 22px gap. Every section header is a row:
  11px uppercase 600 `#9a9ba0` label, a 0.5px `#ebedf0` rule filling the middle, and a right-side control.

  **Value of active version** — right control is a Reveal/Hide link (12px `#3c6df0`, hover `#2a55c9`).
  Panel: radius 10, background `#fafbfc`, inset ring `0 0 0 .5px #e3e5ea`, padding 14/16.
  Value in mono 13.5px, line-height 1.5, `word-break: break-all`; masked state is bullets in `#b8b9be`,
  revealed is `#16171a`. Footer row 11.5px `#9a9ba0`: "v12 · 29 characters · base64 in transit" left;
  right side "Revealing performs a get request" → "Hides again in 20s" once revealed.
  **The masked state must not be the real value under a CSS mask** — do not fetch until Reveal or Copy is used.

  **Versions** — right control is the static hint "Roll back by activating".
  Table: radius 10, ring `0 0 0 .5px #e3e5ea`, rows separated by 0.5px `#edeff2`, row padding 10/14, gap 12.
  Columns: 52px version number (mono 13px/600, tabular), 78px badge slot, flexible "date · author" 12.5px
  `#5d6068`, right-aligned 6-char digest in mono 12px `#9a9ba0`, 150px action slot.
  Badges: "active" `#1f5bd6` on `#e5edfd`; "latest" `#5d6068` on `#eef0f3` (only when the newest row is not
  the active one). Active row background `#f7f9fe` and the action slot reads "in use" 11.5px `#a3a4aa`.
  Other rows: **Activate** and **Delete** (24px secondary buttons; Delete label `#b4342a`).
  Activate is the rollback mechanism — there is no separate rollback command.

  **Access in <group>/*** — right control names the source: "N rules from the tailnet policy".
  Matrix: radius 10, ring `0 0 0 .5px #e3e5ea`. Header row (padding 8/14, background `#fafbfc`, bottom border
  0.5px `#e9ebee`): "PRINCIPAL" 11px uppercase 600 `#9a9ba0` in the flexible column, then six 74px centered
  capability columns in mono 10.5px: info, get, put, c-ver, activ, del.
  Body rows: principal in mono 12.5px `#26272b` plus a note in 11.5px `#9a9ba0` ("4 members", "2 devices",
  "you"); cells are `●` 11px `#3fae63` when granted, `–` 12px `#d3d4d9` when not. The row for the current
  user has background `#f7f9fe`. Principals include `group:`, `tag:`, and user identities.
- Status bar: height 30, padding 0 26, top border 0.5px `#eaecef`, background `#fbfbfc`, 11.5px `#9a9ba0`.
  Left: the last API call made for this secret. Right: "Values are never cached on disk".

### 2. Sheet — New secret
Modal sheet over the window: 620px wide, 54px from the top, radius 12, shadow
`0 24px 60px rgba(18,20,28,.34), 0 0 0 .5px rgba(0,0,0,.14)`. Scrim `rgba(28,30,38,.28)` with a 1.5px blur;
clicking it cancels. In the native app this is an NSWindow sheet.

- Header (padding 20/24/16, bottom border 0.5px `#eef0f3`): "New secret" 16px/650 `#16171a`;
  subtitle 12.5px `#8a8b91` naming the target server.
- Body padding 20/24, sections gap 20.
- **Name** — one field for the whole name, no separate namespace control, because a namespace is not a thing.
  Field: height 32, radius 7, ring `0 0 0 1px` (`#d7dae0` empty → `#c2d4fb` typing → `#e8b3ad` on collision),
  input in mono 13px, placeholder `prod/service/key-name`.
  **Autocomplete:** the candidate set is every prefix that exists in any secret name, one entry per path level
  (`prod/`, `prod/db/`, `prod/stripe/`, …), each with the number of secrets beneath it. Candidates are those
  that start with the typed text case-insensitively and are longer than it.
  The best candidate is shown as ghost text in the field: a non-interactive overlay that repeats the typed
  characters in `transparent` and continues in `#b9bbc1`, so the completion lines up under the real caret.
  Tab or → accepts it; a small "tab" chip (10.5px `#8a8b91` on `#f1f2f5`) appears at the field's trailing edge
  while a completion is available. Up to five candidates also list below the field in a popover
  (radius 8, shadow `0 10px 24px rgba(20,22,30,.16), 0 0 0 .5px rgba(0,0,0,.12)`, rows padding 6/11,
  hover `#f4f6f9`) with their counts; clicking one fills the field.
  Below: a hint line and the static note "Slashes group secrets in the sidebar", then a "Groups:" row of
  top-level prefix chips (mono 11.5px, padding 2/8, radius 5) as a shortcut; the chip matching the typed
  prefix is highlighted `#2f56b5` on `#eaf0fe`.
  Hint states: default "Grouping is just part of the name — a new prefix creates a new group";
  new prefix → "Creates new group foo/" `#2f56b5`; existing name → "Already exists — use New version instead"
  `#b4342a`; bad characters → "Lowercase, digits, . _ - and / only" `#b4342a`; otherwise
  "Name is available" `#3d8f5c`.
  Validation: `/^[a-z0-9][a-z0-9._\-\/]*[a-z0-9]$/`, leading slashes stripped, must not collide.
- **Value** — header row with Generate and Reveal/Hide links. Generate produces 32 characters from
  `crypto.getRandomValues` over the alphabet `a-z A-Z 2-9 - _` minus look-alikes (no l, I, 1, o, O, 0).
  Field: radius 8, ring `0 0 0 1px #d7dae0`, padding 10/11, textarea 66px tall, mono 13px, no resize.
  Hidden state renders bullets. Footer 11.5px `#9a9ba0`: character count left,
  "Encoded as base64 in transit · not written to disk" right.
- **Options panel** (radius 10, background `#fafbfc`, ring `0 0 0 .5px #e8eaee`, padding 14/16):
  one switch, **Activate immediately**, default on. Switch: 32×19 track, radius 10, padding 2,
  `#3c6df0` on / `#d2d4da` off, 15px white knob with `0 1px 2px rgba(0,0,0,.2)`.
  Label 12.5px/550, explanation 11.5px `#8a8b91` that changes with the state:
  on → "Consumers pick up this value on their next fetch."; off → "Stored as an inactive version until you activate it."
- **API preview** (radius 8, background `#f5f8ff`, ring `0 0 0 .5px #dce6fb`, padding 10/13):
  the exact calls in mono 11.5px `#2f56b5` — `POST /api/put` plus `→ POST /api/activate` when the switch is on —
  and the request count right-aligned in `#6f83b8`. This is what makes the switch's consequence legible.
- Footer (padding 14/24, top border 0.5px `#eef0f3`, background `#fbfbfc`): hint left
  ("Add a value" → "Enter a valid name" → "⌘↩ to create"), then Cancel and **Create secret**.
  The primary button is `#3c6df0` when valid and `#b9c8ef` when not — visible but visibly inert.

### 3. Sheet — New version
Same geometry and section grammar as New secret. Differences:
- Header carries the target version as a badge next to the title: "v13" 12px/600 `#2f56b5` on `#eaf0fe`,
  radius 5, then the secret's full name in mono 12.5px, then
  "Current active version is v12, set 3 days ago by ci-runner."
- No name field — the secret is fixed.
- Value header offers three links: **Generate** (length follows the current value, minimum 32),
  **Start from current** (loads the existing value for editing — a get request), **Reveal/Hide**.
  Footer compares: "44 characters · was 29", or when empty "Empty · current value is 29 characters".
- **Duplicate warning**, shown only when the typed value equals the current one: padding 9/13, radius 8,
  background `#fdf6e7`, ring `0 0 0 .5px #f0e0b8`, 11px `#c08a2e` dot, text 11.5px `#8a5a12`:
  "Identical to v12 — this would create a duplicate version".
- One switch, **Activate on create**, default on. On → "v13 becomes active — consumers pick it up on their next
  fetch."; off → "Stored alongside v12, which stays active until you switch."
- Footer hint: "Previous version stays available for rollback" / "Activate later from the version list" /
  "Add a value". Primary button label follows the switch: **Create and activate** / **Create version**.

### 4. Sheet — Delete secret
560px wide, 76px from the top. The only red surface in the app.
- Header: padding 20/24/16, background `#fdf7f6`, bottom border 0.5px `#f3e6e4`.
  Title "Delete secret" 16px/650 `#8e2c21`; subtitle 12.5px `#96635c`
  "This cannot be undone. setec keeps no backup of deleted values."
- **This removes** — three consequence lines (9px `#c9a09a` bullet, text 12.5px `#4a4b51`, line-height 1.5):
  the version count including the active one; "Any client still fetching this name starts failing immediately";
  "The name becomes free again — deleted values cannot be restored". The first line is generated from the secret.
- **Confirmation** — "To confirm, type the secret name" 12px/600.
  Copy source above the input: padding 9/11, radius 8, background `#f4f6f9`, ring `0 0 0 .5px #e4e6ea`,
  name in mono 13px with `user-select: all` (triple-click selects the whole name), and a small **Copy** button
  that reads "Copied" for 1.6s.
  Input: height 34, radius 8, mono 13px, ring `#d7dae0` empty → `#e6e8ec` while wrong → `#e0a9a2` on match.
  Hint below: "Type the full name to enable deletion" → "Does not match yet" → "Name matches" `#a8362b`.
  Comparison is exact after trimming whitespace.
- API preview in the red key: background `#fbf6f5`, ring `0 0 0 .5px #f0dfdc`,
  `POST /api/delete` in `#98463a`, "1 request" in `#ab7a72`.
- Footer: "To remove a single version instead, use the version list" left; Cancel; **Delete secret**
  `#c0392b` when the name matches, `#e3b6b0` when not.

## Interactions & Behavior
- **Selection**: clicking a sidebar group filters the list and clears any smart filter; clicking a smart filter
  clears the group. Typing in search overrides both and searches all secrets. Selecting a secret resets the
  reveal and copy states.
- **Reveal**: hidden by default, per selection. Revealing issues a `get`; the value auto-hides after 20s.
  Switching secrets hides again.
- **Copy**: copies the active version's value, button confirms for 1.8s. Consider clearing the pasteboard
  after a timeout and marking the item `org.nspasteboard.ConcealedType` so clipboard managers skip it.
- **Activate** on a non-active version performs the rollback and re-renders the badges immediately.
- **Sheets**: only one at a time. Cancel, scrim click, and Esc all dismiss. ⌘↩ submits when valid.
  Dismissing discards the typed value.
- **Animation**: scrim fades in over 140ms; the sheet runs `opacity 0→1` with
  `translateY(-12px) scale(.985) → none` over 180ms, `cubic-bezier(.2,.8,.3,1)`. Native sheets have their own
  presentation animation — use it rather than reimplementing this.
- **Hover**: every secondary button lightens to `#f7f8fa`; the primary to `#3462dd`; links to `#2a55c9`;
  autocomplete and matrix rows to `#f4f6f9`.

### Not yet designed
Loading, empty, and error states are absent from the prototype and need design before shipping:
first launch with no secrets, an unreachable server, a `get` that fails on permission, and a `put` that
races another writer. Also missing: a delete-version confirmation (currently the row button acts directly),
a multi-server management screen, and the "···" menu's other entries.

## State Management
Prototype state, which maps closely to what the real app needs:
- `selection: String` — the selected secret's name
- `scope: String?` — selected sidebar group; mutually exclusive with `filter`
- `filter: enum?` — `stale` | `single` | `recent`
- `query: String` — search text; when non-empty it overrides scope and filter
- `revealed: Bool`, `copied: Bool` — transient, reset on selection change
- `activeOverride: [String: Int]` — prototype stand-in for the server's active version after Activate
- `sheet: enum?` — `new` | `version` | `delete`
- New secret: `newPath`, `newValue`, `newRevealed`, `activateNow`
- New version: `verValue`, `verRevealed`, `verActivate`
- Delete: `confirmName`, `confirmCopied`

Derived, not stored: the group tree and counts, the autocomplete candidates, filter membership,
the next version number (max + 1), name validity, duplicate-value detection, and the API preview string.

Data fetching: `list` on launch and on Refresh gives every name and its versions — that is enough to render
the sidebar, the list, and the version table. Values are fetched only on Reveal, Copy, and Start from current,
and are never persisted. Watch mode (`setec.Store`) is not needed for a manual GUI, but a poll on window
focus keeps the list honest.

## Design Tokens
**Neutrals** — `#16171a` primary text · `#1d1e22` list leaf · `#26272b` control label · `#3a3b40` field label ·
`#4a4b51` body · `#5d6068` secondary · `#8a8b91` tertiary · `#9a9ba0` quaternary/placeholder ·
`#a3a4aa` meta · `#b8b9be` masked value · `#b9bbc1` ghost text

**Surfaces** — `#ffffff` panels · `#fbfbfc` list + footers · `#fafbfc` inset panels · `#f4f6f9` fills ·
`#f3f4f7` sidebar · `#eceef1` toolbar · window backdrop `radial-gradient(120% 120% at 20% 0%, #eceef3, #cfd1d8)`

**Lines** — `#ebedf0` rules · `#edeff2` table rows · `#eaecef` / `#e9ebee` / `#eef0f3` section borders ·
`#e3e5ea` panel rings · `#e4e6ea` / `#e8eaee` subtle rings · `#dcdee3` / `#d3d5da` chrome borders ·
`#d7dae0` input ring · `#d2d4da` switch off

**Blue (primary)** — `#3c6df0` action · `#3462dd` hover · `#2a55c9` link hover · `#2f56b5` API text ·
`#1f5bd6` active badge · `#6f83b8` API meta · `#c2d4fb` selection ring · `#eaf0fe` selected row ·
`#e5edfd` badge fill · `#f5f8ff` API panel · `#dce6fb` API panel ring · `#f7f9fe` active table row ·
`#b9c8ef` disabled primary

**Green** — `#3fae63` granted / online · `#3d8f5c` available name
**Amber** — `#d69016` filter dot · `#c08a2e` rotation due · `#8a5a12` warning text · `#fdf6e7` warning fill · `#f0e0b8` warning ring
**Red** — `#c0392b` destructive button · `#b4342a` destructive label · `#a8362b` match confirmed ·
`#98463a` API text · `#8e2c21` title · `#96635c` subtitle · `#ab7a72` meta · `#c9a09a` bullet ·
`#e0a9a2` / `#e8b3ad` input ring · `#e3b6b0` disabled destructive · `#fdf7f6` header fill ·
`#fbf6f5` API panel · `#f3e6e4` / `#f0dfdc` rings
**Traffic lights** — `#ec6a5e` `#f4bf4f` `#61c554`

**Type** — system UI font (`-apple-system`) for chrome, monospace (`ui-monospace`, SF Mono) for every secret
name, value, version number, digest, principal, and API string. Scale: 10.5 section header (uppercase, .06em) ·
11 badge/chip · 11.5 meta · 12 label · 12.5 control · 13 input/mono body · 13.5 secret value · 16 sheet title ·
21 detail title (-.01em). Weights 450 / 500 / 550 / 600 / 650.

**Spacing** — 2 · 5 · 6 · 7 · 8 · 9 · 10 · 11 · 12 · 14 · 16 · 18 · 20 · 22 · 24 · 26.
Fixed widths: sidebar 232, list 316, sheets 620 / 560, matrix capability column 74, version columns 52 / 78 / 150.
Control heights: 24 inline · 28 toolbar · 30 action · 32 field · 34 confirm input · 38 list header · 52 toolbar · 30 status bar.

**Radii** — 4 chip · 5 small chip · 6 toolbar button · 7 button/field · 8 input/panel · 10 section panel · 12 window & sheet
**Shadows** — hairline `0 0 0 .5px rgba(0,0,0,.12)` · button `+ 0 1px 1px rgba(0,0,0,.04)` ·
primary `0 1px 2px rgba(60,109,240,.35)` · switch knob `0 1px 2px rgba(0,0,0,.2)` ·
popover `0 10px 24px rgba(20,22,30,.16)` · sheet `0 24px 60px rgba(18,20,28,.34)` · window `0 30px 70px rgba(20,22,30,.35)`

Dark mode is not designed. The palette is light-mode only; a native build needs a second pass for it.

## Assets
None. No images, no icon fonts. The few glyphs are text characters: `▸ ▾ ● – ··· + ✓ ⌘↩`.
Replace them with SF Symbols in the native build (`chevron.right`, `chevron.down`, `circle.fill`,
`ellipsis`, `plus`, `checkmark`, `magnifyingglass`).

## Files
- `Setec Mac App.dc.html` — the full prototype: main window plus all three sheets. Open it directly in a browser.
  The sheet shown on load is controlled by the `sheet` field in the component's initial state
  (`"new"`, `"version"`, `"delete"`, or `null` for just the main window); all three are also reachable
  by clicking "+ New secret", "New version …", and "···".
- `support.js` — runtime for the prototype format. Not part of the design; it must sit next to the HTML file.
- `api.md` — the setec HTTP API reference, copied from the upstream repository for convenience.

Upstream source: https://github.com/tailscale/setec
