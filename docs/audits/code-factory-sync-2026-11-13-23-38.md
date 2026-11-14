# code-factory sync lane — 2026-11-13 (tick `code-factory-sync-2026-11-13-23-38-27`)

Lane: sync (board ⇄ repo consistency, plus the memory duty absorbed from the retired
`code-factory-duckbrain` row). Workdir `/home/kara/code-factory`.

Board source: **`origin/main`** (`git show origin/main:.coding-hermes/board/tasks.jsonl`), not the
worktree copy. Published tip at read time: `6c9cd553`.

Re-fire note: a sibling executor of the *same* tick id published a receipt (`d741f258`) and the
canonical marker (`f104357f`) at 23:47–23:48Z describing a **read-only** pass with no board or code
mutation. That pass did not run the CF-099 PRD-drift probe; the probe was RED at the tip it read.
This segment measured the gates, fixed the drift it found, and corrects the marker (see Memory).

## 1. Board parse and row count

| Check | Measured | Verdict |
|---|---|---|
| task rows on `origin/main` | 506 | — |
| rows parsing as JSON objects | 506 / 506 | OK |
| distinct task ids | 506 | no duplicate ids |
| `scripts/boardctl validate` | `OK` (89 warnings, 0 errors) | OK |
| events | 759 lines; one legacy event without `id`; duplicate `id` 336 (present twice) | known legacy, not rewritten |

Row status distribution: `pending` 340, `complete` 150, `in_progress` 14, `blocked` 2.

## 2. Evidence on `complete` rows (every complete row must name a re-runnable command)

| Measurement | Value |
|---|---|
| `complete` rows | 150 |
| rows carrying `commit_hash` | 148 |
| distinct `commit_hash` values | 140 |
| hashes that resolve to a commit in the published history | **140 / 140** (0 unresolvable) |
| rows with no `commit_hash` | 2 — `CF-245`, `P5G-34` |
| rows whose evidence text names no command | 2 by regex — `CF-032`, `CF-054` |

Both "gap" classes were checked by reading the rows, not by trusting the regex:

* `CF-245`, `P5G-34` are verification closeouts whose fix landed in **another** repo (scheduler /
  gitreins); their `foreman_note` names the commit and path in that repo and states explicitly that
  no code changed here. No `commit_hash` is correct for them.
* `CF-032`, `CF-054` do name their commit and the documents they narrowed; they simply do not spell
  a shell command. Their closures are dated 2026-11-03/04 (pre-receipt-discipline rows).

Net: **0 `complete` rows lack evidence that names where the proof lives.** No row was filed, because
filing "row has prose evidence instead of a command" against four historical rows would be noise.
The regex count is reported here so a later tick can re-derive it and see why it is not a defect.

## 3. Docs ⇄ board reconciliation — one real drift, found and fixed

`docs/` carries no per-row status table (the historical drift class this lane fixes), so the drift
surface is the acceptance-plan snapshot instead.

| Gate | Before | After |
|---|---|---|
| `docs/audits/cf099-prd-drift-probe.sh` | **RED** — plan snapshot claimed 67 numbered sections / 70 arms, `tests/selftest.sh` carries 68 / 72 | `OK: milestone, plan snapshot and layer arms agree at 6c9cd553` |
| `docs/audits/cf198-section-mapping.sh` | (not the failing surface) | `arms_plan=72 arms_tree=72`, `RESULT: OK` |

Root cause: commit `3e9f2302` (2026-11-13 13:21 -05) added selftest section 68 and its §68 mapping
row but left the "Current state" paragraph in `docs/ACCEPTANCE-PLAN.md` counting 67 sections and 70
arms; `§32a` was likewise absent from that sentence. Fixed in the paragraph only — the mapping table
and every section body are untouched.

## 4. Local gate (the change is docs-only, but the suite is the arbiter)

`bash tests/selftest.sh` → `SELFTEST: PASS`, `EXIT=0` (552 `PASS` lines; the 61 `FAIL` lines are
expected-rejection arms driving fixture boards that must not parse — the suite's own fail counter
stayed 0, which is why it printed PASS).

## 5. CI health

`gh run list --repo coding-hermes/code-factory --limit 3` → `[]`, and `.github/workflows/` is absent.
This repo has **no CI configured**: nothing green, nothing red, nothing to file. Gates for this repo
are the local ones above (`boardctl validate`, `board_drift.py`, `board_evidence_check.py`, the two
audit probes, `tests/selftest.sh`). Reported rather than silently omitted.

## 6. Residuals / open, stated so a later tick can pick them up

* `cf181-verdict-binding-sweep.py` at the published tip reports `verdict_artifacts_checked=0`,
  `rows_without_verdict=150`, status `UNRESOLVED`: GitReins verdict artifacts are not published into
  git (`.gitreins/` is untracked), so verdict binding cannot be measured from a fresh clone. If
  verdict binding is meant to be auditable, the verdicts have to be published or the sweep has to
  run where the artifacts live.
* `board_evidence_check.py` reports 57 unresolved local evidence pointers against an accepted
  baseline of 57 (`expected_unresolved=57`) — a shallow-clone artifact, unchanged this tick.
* `boardctl validate` emits 89 warnings; they are pre-existing and were not rewritten.

## Memory duty (decisions captured this tick)

Written to DuckBrain namespace `code-factory` as an append-only addendum plus a corrected canonical
marker naming the superseded UUID, because the earlier marker for this same tick id asserted a
read-only pass and the probe disagreed with it. Each claim above is measured; the one inference is
labelled: the 67→68 drift was introduced by `3e9f2302` (measured by diffing that commit), while "the
sibling pass did not run the probe" is **inferred** from its receipt text (it names cf198 and
boardctl but never cf099) — the observable fact is that the probe was RED at `6c9cd553`.
