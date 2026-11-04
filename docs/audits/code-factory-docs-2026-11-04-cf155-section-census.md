# CF-155 section census correction and gate

Tick: `code-factory-docs-2026-11-04-08-12-52`
Row: CF-155
Claim corrected: current acceptance-plan selftest section count; add a regression gate for section drift.

## Before / after

| Location | Before | After |
|---|---|---|
| `docs/ACCEPTANCE-PLAN.md:5` | Current state was pinned to `bc68e59`: 35 numbered sections, 37 arms, 109 PASS rows, 19 fixture FAIL rows, 148 board rows, 273 events. | Re-measured at `8b81369`: 36 numbered sections plus §4b/§7b/§7c = 39 arms; 121 PASS rows and 19 intentional fixture FAIL rows; loadavg 7.43; 154 task-file lines and 291 event-file lines. §36 landed in 8b81369 for CF-159, falsifying the 35-section line. The filed 29-vs-30 premise moved to 35-vs-36; this closes the current drift. |
| `docs/ACCEPTANCE-PLAN.md:60-61` | 37 arms, 25 unnamed arms, enumeration ended at §35 and omitted §7c. | 39 total arms; 12 named and 27 unnamed; enumeration includes §7c and §36. |
| `docs/ACCEPTANCE-PLAN.md:65` | Governing-row map ended at §35 / CF-153. | Adds §36 / CF-159 and §7c / CF-155. |
| `docs/ACCEPTANCE-PLAN.md:97` | Current tree claimed 35 numbered + two lettered = 37 arms. | Corrected to 36 numbered + three lettered = 39; historical 31-arm d02916e count unchanged. |

Historical snapshots explicitly pinned to old tips were preserved, including the d02916e 29-section snapshot and the `Previous snapshots` list.

## Implementation and proof paths

- `docs/audits/cf099-prd-drift-probe.sh:2-6` documents default and `--sections-only` scope plus fixture overrides; lines 10-17 implement the isolated section census and measured output; default mode remains below that block and checks milestone, tip-pinned snapshot and PRD layer arms.
- `tests/selftest.sh:270-290` contains lettered arm §7c. It runs the real-tree green direction and a fixture pair with exactly one additional numbered `say` section; each direction emits one named PASS row, and the red assertion requires the full `DRIFT:` line (not a bare `FAIL` substring).
- The full mode reads the first Current state line for its pinned tip, row/event counts and section count; it does not pin mutable board counts as selftest fixtures.

## Evidence transcripts

Before the fix, `bash docs/audits/cf099-prd-drift-probe.sh` produced:

```text
DRIFT: plan says 35 sections, tests/selftest.sh has 36
measured: tip=bc68e59 rows=148 events=273 sections=36 open_blockers=CF-001 CF-002 CF-004 CF-080 CF-110 CF-112 CF-131 CF-132 CF-133 CF-136 CF-137 CF-138 CF-139 CF-150
probe_rc=1
```

After the fix, green section-only run:

```text
measured: plan_sections=36 selftest_sections=36 plan=docs/ACCEPTANCE-PLAN.md selftest=tests/selftest.sh
sections_rc=0
```

Red one-extra-section fixture run (fixture directory `/var/tmp/cf155-fixture.fxN9q5`):

```text
DRIFT: plan says 36 sections, tests/selftest.sh has 37
measured: plan_sections=36 selftest_sections=37 plan=/var/tmp/cf155-fixture.fxN9q5/plan.md selftest=/var/tmp/cf155-fixture.fxN9q5/selftest.sh
fixture_path=/var/tmp/cf155-fixture.fxN9q5
fixture_rc=1
```

Full probe at HEAD:

```text
measured: tip=8b81369 rows=154 events=291 sections=36 open_blockers=CF-001 CF-002 CF-004 CF-080 CF-110 CF-112 CF-131 CF-132 CF-133 CF-136 CF-137 CF-138 CF-139 CF-150
OK: milestone, plan snapshot and layer arms agree at 8b81369
full_rc=0
```

`bash tests/selftest.sh` completed with exit 0 and these final lines:

```text
  PASS  cf159 node-create repo payload is data, not code
  PASS  cf159 node-create ref payload is data, not code
  PASS  cf159 node-create crier payload is data, not code
  PASS  cf159 verify-node artifact payload is data, not code; digest intact
  PASS  cf159 bunker_exec trusted command text preserves quoted values and literal pipelines
  PASS  cf159-escaping all remote-command sites

SELFTEST: PASS
```

The run's complete transcript had 121 lines matching `grep -c '^  PASS'` and 19 matching `grep -c '^  FAIL'`; those FAIL rows are intentional negative-fixture output. The measured per-arm outputs were:

```text
PASS  cf155 sections census green at this tree
PASS  cf155 sections census red on a fixture with one extra numbered section
```

Required command tails:

```text
$ bash -n docs/audits/cf099-prd-drift-probe.sh
(exit 0; no output)
$ bash docs/audits/cf099-prd-drift-probe.sh --sections-only
measured: plan_sections=36 selftest_sections=36 plan=docs/ACCEPTANCE-PLAN.md selftest=tests/selftest.sh
(exit 0)
$ bash docs/audits/cf099-prd-drift-probe.sh
measured: tip=8b81369 rows=154 events=291 sections=36 open_blockers=CF-001 CF-002 CF-004 CF-080 CF-110 CF-112 CF-131 CF-132 CF-133 CF-136 CF-137 CF-138 CF-139 CF-150
OK: milestone, plan snapshot and layer arms agree at 8b81369
(exit 0)
$ bash scripts/boardctl validate
RESULT: OK (3 warning(s))
(exit 0)
```

`bash -n docs/audits/cf099-prd-drift-probe.sh` passed. `bash scripts/boardctl validate` warnings are CF-034's two free-form values and the headerless board.

## Re-derived measurements

All tree counts below refer to the named tip `8b81369` (confirmed before edits). Commands and values:

- `git rev-parse --short HEAD` → `8b81369`; `git rev-list --left-right --count origin/main...HEAD` → `0 0`.
- `grep -cE '^say "[0-9]+\.' tests/selftest.sh` → 36 numbered sections.
- `grep -cE '^say "§?[0-9]+[a-z]\.' tests/selftest.sh` → 3 lettered arms (§4b, §7b, §7c).
- Derived arms: 36 + 3 = 39.
- `git show 8b81369:.coding-hermes/board/tasks.jsonl | wc -l` → 154; `git show 8b81369:.coding-hermes/board/events.jsonl | wc -l` → 291.
- `grep -c '^  PASS' /tmp/cf155-final-selftest.txt` → 121; `grep -c '^  FAIL' /tmp/cf155-final-selftest.txt` → 19. Transcript produced by `bash tests/selftest.sh`.
- `grep -oE '§[0-9]+[a-z]?' docs/PRD-code-factory.md | sort -u` → 14 unique ids.
- `/proc/loadavg` first field after the selftest run → 7.43 (host load context only).
- Falsifier: commit `8b81369` (`fix(node-scripts): escape every value interpolated into remote bash -lc`), which added §36 and addresses CF-159.

## Claims I could not verify

- not measured — no live/remote node provisioning or deployment was requested; the scope is local docs, audit and selftest only.
- not measured — the exact load average at the instant the selftest process started; 7.43 was sampled after the successful run.

## Trace and status

ch:trace row=CF-155 spec=docs/ACCEPTANCE-PLAN.md wave=none:serial test=tests/selftest.sh::7c doc=docs/ACCEPTANCE-PLAN.md evidence=docs/audits/code-factory-docs-2026-11-04-cf155-section-census.md witness=cmd:cf099-sections-only-green-and-fixture-red verdict=none:pending-tier2 commit=self memory=none:foreman-writes-receipt

STATUS: implemented and locally verified
TIER: Tier 1 checks passed
EVIDENCE: local probe, red fixture, selftest and board validation; commit pending
