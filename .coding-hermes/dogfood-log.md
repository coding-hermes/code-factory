# Dogfood log — code-factory

One entry per dogfood tick: what was walked, what it cost, what broke, what was filed.
Newest last. Run ids are the tick ids, so `grep -n '<tick-id>'` finds the record.

## 2026-11-17 — run `code-factory-dogfood-2026-11-17-10-10-24`

- **Verdict**: 🟡 PROMISING-BUT-ROUGH. Every documented control-host command runs and refuses
  by name with the missing value; two of the outputs misstate their own measurement.
- **Tip walked**: `0014b76ac0b5a33081068d743e52754b928b4e0c` (origin/main, parity 0/0, clean tree).
- **Promise tested**: "a stranger on a fresh host runs the three Quick start commands and each one
  either works or fails naming the value to supply."
- **Time to first success**: `bunker-server-install.sh --check` → `RESULT: PASS` in **0.92 s** once
  `BUNKER_SERVER` names a configured server (0.00 s / 0.03 s on the two refusal arms).
  `project-node.sh --check` → `NODE: FAIL (5)` in **38.16 s** (cost owned by CF-387).
- **Top findings**:
  1. `CF-483` — the `residue` row is a substring match on the word "orphan", so it WARNs on a host
     the server reports as *0 orphan homes, 0 orphan keys* and can never report a real leak.
  2. `CF-484` — README Quick start step 2 says "the same check with an explicit interpreter
     passes"; measured `NODE: FAIL (7)` (two MORE failures than the default arm's 5).
  3. `CF-057` annotated — `--json` is parsed into a variable nothing reads: the documented
     machine-readable surface does not exist.
- **Not filed**: the `node-create.sh` spawn row already owns its message quality (`CF-469`); the
  README's `bunker-provision --check` transcript is `CF-467`; step-2 cost is `CF-387`.
- **Unverified this fire**: a live node create (would spawn a real agent on `bunker-las-03`, which
  reported 0/8 agents); one probe arm was refused by the unattended command gate and is recorded as
  UNVERIFIED in the report, not retried in another form.
- **Artifacts**: `docs/dogfood/2026-11-17-dogfood-path.md`,
  `.coding-hermes/evidence/code-factory-dogfood-2026-11-17-10-10-24/`.

### 2026-11-17 — re-fire receipt for `code-factory-dogfood-2026-11-17-10-10-24` (delivery 2)

Duplicate delivery of the tick above: no re-walk, no new product measurements, zero rows filed.

- **Tip unchanged**: `f2127dd9` = `origin/main` at parity 0/0 (the record commit itself).
- **Verified from `origin/main`, not the working copy**: `CF-483` + `CF-484` `pending` with non-empty
  `reasoning`/`acceptance_criteria` (2327/1258 and 2907/1074 chars) and one paired `task_created`
  event each (ids 887/888) · `CF-057`'s `foreman_note` quotes `--json` (1738 chars) · three artifacts
  non-empty (7607/2082/3888 bytes) · `step2.out` ends `NODE: FAIL (5)`, `b1.out` `NODE: FAIL (7)`,
  both `.err` carrying `non-zero status 1` · gitreins `CF-DOGFOOD-20261117` complete, verdict at
  `.gitreins/history/2026-11-17/ed488866` (tier1 PASS, tier2 PASS, COMPLETE).
- **No residue**: the evidence INDEX names no `agent=` id — the node-create leg was never run, so
  there is no agent to destroy.
- **Stood down, no blocked receipt**: `docs/audits/cf-PERF-021-cold-cache-attribution.md` and
  `docs/handbook/chapters/VIII-5-tests.md` are staged but are NOT unowned residue — live worker pid
  2491440 (PERF-021 brief, started 05:06:25) owns them, and its dirty-path set matches its brief
  exactly. Left untouched; no second dispatch into this checkout.
- **CI**: last 5 runs on `coding-hermes/code-factory` all `success`; nothing filed.

#### Addendum — the tip moved while this receipt was being written

The `f2127dd9` claim above is scoped to the moment it was measured; two commits landed after it, and
this receipt was rebased onto them by the fleet harvester (its local pre-rebase sha was `e986d45c`):

- `1fc9c17e` — the live PERF-021 worker's own commit: `docs/audits/cf-PERF-021-cold-cache-attribution.md`
  (+370) and `docs/handbook/chapters/VIII-5-tests.md` (+11). The two paths this receipt "left untouched"
  are therefore now landed by their owner, not residue.
- `82972156` — this receipt itself, `name-only` = `.coding-hermes/dogfood-log.md` alone.

**Guard coverage, re-measured:** the pathspec commit (`git commit -F msg -- <path>`) presented the guard
an EMPTY staged set — `Tier 1: DEGRADED PASS (skips: lint=no staged files, tests=no staged files)`,
guard log `.gitreins/logs/guard-20261117T110029.965517Z.log`. That class is already owned by **CF-474**
("the commit-time guard treats `git commit --only <path>` from a clean index as an empty…"), so no
sibling row was minted; this is a second, independent measurement of the same defect at a new tip.
A separate FAIL on the first attempt (`publish paths — baseline 0, current 1`,
`docs/audits/cf-PERF-021-…`) was the worker's own mid-edit `/home/…` leak in the shared index, gone by
the retry — a shared-checkout snapshot, not a repo defect, and not filed.
