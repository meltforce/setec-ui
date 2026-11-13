# Incidents

Postmortems for things that broke. One section per incident, newest first.

Add an entry after fixing something that was not obvious — the kind of failure
where the useful question six months later is "have I seen this before?". Skip
routine config changes, dependency bumps, and one-line typos.

Structure per entry: **symptoms** (what was visible), **root cause** (concrete:
component, version, why), **fix** (what changed), **lesson** (one line,
actionable).

---

## 2026-11-02 — every UI test failed after the built-in server was removed

**Symptoms.** `make verify` reported 10 of 10 UI tests failed, each with
`No matches found for … "secrets.list" IN identifiers`. `make install` and a
release gate on `make verify`, so neither could run green.

**Root cause.** Commit `9704db7` (2026-09-21) removed the built-in server. An
app launched by XCUITest gets neither the shell's `SETEC_SERVER` — xcodebuild
forwards a variable to the test runner only as `TEST_RUNNER_<name>` — nor a
stored server, so the list column read "No server yet" and rendered no list.
That commit ran `make check`, which does not include the UI bundle.

**Fix.** `make test` runs the unit bundle first, then the UI bundle with
`TEST_RUNNER_SETEC_SERVER`; `SmokeUITests.launch()` hands the value to the app
and fails with a named cause when it is missing. The unit bundle stays without
the variable, because it is hosted in the app process and
`ServerSettingTests` assert the behaviour with no server configured.

**Lesson.** A change to how the app finds its server runs `make verify`, not
`make check`.

