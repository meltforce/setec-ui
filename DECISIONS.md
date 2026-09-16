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

## 2026-09-16 — the access matrix reads the Tailscale control API

**Decided:** 2026-09-16

**Decision.** The grant matrix is populated from the tailnet policy file,
fetched with `GET https://api.tailscale.com/api/v2/tailnet/-/acl`. The
credential is the read-only OAuth client `homelab/ts-oauth-client-{id,secret}`,
read from setec itself and exchanged for a bearer token. The matrix stays
display-only: the app gates no action on a grant.

**Reasoning.** setec exposes no policy-read endpoint, so the grants of other
principals cannot come from the same server as the secrets. The tailnet policy
is where they are actually defined. The OAuth client already exists for exactly
this purpose and carries `policy_file:read` among its scopes; homelab
`SECRETS.md` § *Tailscale control API* documents the exchange and notes that
OAuth clients do not expire while API keys are capped at 90 days, which is what
makes this the durable path.

**Alternative considered.** Reading a local copy of the policy file, which
removes the network dependency and introduces a copy that drifts from the
tailnet without either side reporting it. Also rejected: showing invented
grants, or an empty matrix labelled as complete.

**Trigger to re-open.** setec gaining a policy-read endpoint, or the read-only
OAuth client losing `policy_file:read`.

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
