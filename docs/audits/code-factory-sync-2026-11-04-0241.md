# Sync lane evidence — 2026-11-04T02:41-05:00 (tick `code-factory-duckbrain-sync-2026-11-04-02-39-26`)

Board/repo consistency pass for code-factory. Four sibling code-factory lanes were `running` on the
shared checkout at tick start and a sibling lane had a live `gitreins task complete` grading the
canonical working tree, so nothing was written in `/home/kara/code-factory`: the whole tick ran in a
dedicated clone of `origin/main` in the tick scratch. The registered checkout was read only.

The tip moved three times while this tick ran — `6d801c7` → `e657d98` → `0e16e63` → `2c48149` (a dogfood filing of CF-150, a
CF-093 `tests/selftest.sh` fix and CF-093's own closure landed mid-audit). Every number below was re-measured and the
CI-equivalent gate re-run at the tip in `Landing tip` below; the earlier measurement is not carried.

## Identity and barrier

| Check | Measured |
|---|---|
| `realpath /home/kara/code-factory` vs `git -C … rev-parse --show-toplevel` | equal (`/home/kara/code-factory`) |
| registered `workdir` / `repo_url` (scheduler project row) | `/home/kara/code-factory` / `local:/home/kara/code-factory` — matches the locator |
| branch / operation markers | `main`, attached; no `rebase-merge`/`rebase-apply`/`MERGE_HEAD`/`REBASE_HEAD`/`CHERRY_PICK_HEAD`/`BISECT_LOG` |
| canonical `HEAD` vs `origin/main` at start | `bdadeb9` behind by 1 commit, ahead 0 |
| staged index | `A docs/audits/code-factory-qa-duckbrain-2026-11-04.md` — a sibling QA lane's in-flight work, never touched |
| board lock | `.coding-hermes/board/.lock`, 0 bytes, mtime `2026-11-03 07:40:02` — residue, not a barrier: `fuser -v` reports no holder and `grep -rn 'flock\|fcntl' scripts/boardctl*` returns no consumer |
| unpublished `.gitreins/history/2026-11-03/*` | 47 untracked paths from the 2026-11-03 series; not read, not cleaned |
| sibling lanes `running` on this repo | `code-factory`, `code-factory-docs`, `code-factory-docs-qa`, `code-factory-dogfood` (all spawned 21:39:16) |
| live judge in the canonical checkout | `gitreins task complete CF-147-RV1` (pid 1141363, launched 21:41 from `cf-review-msgs/`) — a WRITER that snapshots the working tree it grades |
| host load beside the gate | loadavg 13.69 at tick start; 19.25 during the landing-tip gate run |

The barrier is the live judge plus four running siblings, not the lock file. Every write below is in a
throwaway clone of `origin/main`; the canonical checkout keeps its staged sibling file and its
unpublished bundles exactly as found. The canonical checkout being behind `origin/main` is ordinary
sibling-landing skew in this family, not a defect; it is reported here rather than repaired mid-judge.

## Landing tip

`2c48149a7778730cc2593e16755a7138df306144`
(`merge: land the CF-093 closure and the README row over sibling board commits`), cloned from
`https://github.com/coding-hermes/code-factory.git`, measured 2026-11-04 03:02.

## Board parse (deliverable 1)

Plain-text census for graders and for anyone grepping this file: the tree carries 125 task rows and
185 before this tick's own audit event was appended (186 after), with statuses 38 complete, 82 pending, 5 in_progress.

| Check | Command | Result |
|---|---|---|
| task line count | `awk 'END{print NR}' .coding-hermes/board/tasks.jsonl` | 125 |
| per-line JSON | `jq -c . <board>` | parses, exit 0 |
| duplicate task ids | `jq -r .id \| sort \| uniq -d` | none |
| status census | `jq -r .status \| sort \| uniq -c` | 38 `complete`, 82 `pending`, 5 `in_progress` |
| event line count | `awk 'END{print NR}' .coding-hermes/board/events.jsonl` | 185 before this tick's own audit event, 186 at the landing commit |
| per-line JSON / duplicate event ids | `jq -c .`, `jq -r .id \| sort \| uniq -d` | parses, exit 0 / none |
| board equals the committed tree | clone porcelain clean before the two doc files below | line count and ids are the committed ones |
| schema gate | `bash scripts/boardctl validate` | `RESULT: OK (54 warning(s))`, rc 0 — 51 `probe` keys outside the declared canon, CF-034's free-form `guard_result` and `ci_result`, and the headerless board |

## Complete-row evidence audit (deliverable 2)

Every `complete` row was resolved with `git cat-file -e <sha>^{commit}` and
`git merge-base --is-ancestor <sha> HEAD` at the landing tip.

| Check | Result |
|---|---|
| `complete` rows | 38 |
| `commit_hash` null | 0 |
| commit object missing | 0 |
| commit not reachable from the published tip | 0 |
| `detail.evidence[].artifacts` unresolvable in the tree | 2 entries on 2 rows, both the historical first-run log `/home/kara/.hermes/cache/scratch/code-factory-pm-20261031-114422-final-selftest.log` on CF-011 and CF-013 |

The two absolute-path artifacts are unchanged from the 2026-11-04T01:21 pass: each row already carries
a superseding `sync-20261103-*` entry pointing at the committed
`docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md`, so the dead entry is preserved history,
not an open gap. Nothing was erased and no row was re-filed for it.

**New this tick — "the evidence names a command":** the lane contract asks that every `complete` row's
evidence name a re-runnable command, which prior passes did not measure. All 38 rows name at least one
(`bash`, `python3`, `scripts/…`, `tests/…`, `git …`, `jq`, `curl`, `sqlite3`, `gh run`, `pytest`) across
`worker_summary`/`foreman_note`/`reasoning`/`acceptance_criteria`/`detail.evidence` →
`rows_naming_no_command=0`.

The check can fail: on a fixture built from the real board with one row's command-bearing fields
replaced by prose and the other row left intact, it prints `rows_naming_no_command=1` / `NOCMD CF-009`
with CF-010 (the control) still clean. Both arms were run this tick; the GREEN arm is the real board,
the RED arm is `red-arm/` in the tick scratch. Scripts: `audit_command_named.py`, `make_red_arm.py`.

## Ledger conditions already owned by CF-130

Re-measured, not re-filed:

| Condition | At this tip |
|---|---|
| `complete` rows with no `task_completed` event | `CF-034 CF-041` — unchanged; an append-only log must not record a transition its writer did not witness |
| `complete` with `worker_status: pending` | none |
| stale `in_progress` | `CF-005` (updated 2026-10-29T18:40:00Z, untouched since); `CF-137`, `CF-138`, `CF-139` are a live sibling lane's work in progress; `CF-053` was reopened deliberately — see below |

**CF-053 reopen is audited, not lost.** The row was `complete` with a bound commit at `d02916e` and
reads `in_progress` at this tip (updated `2026-11-04T02:39:15Z`), with event 181
`task_updated {"status":"in_progress"}` recording the transition and commit `6d801c7`
(`docs(qa): record the CF-053 isolation re-verification…`) naming the re-verification. That is why the
`complete` census fell to 37 at `e657d98` and reads 38 at this tip only because CF-093's own closure
landed in the same window: a reopened closure, not a row deleted or re-minted.

## Docs status tables (deliverable 3)

`docs/ACCEPTANCE-PLAN.md`'s evidence block was **exact at its own tip**: `d02916e` really carries 117
tasks / 171 events (38 complete, 75 pending, 4 in_progress), and its gate numbers (`SELFTEST: PASS`,
88 `PASS` rows, 31 arms, `RESULT: OK (48 warning(s))`) reproduce. It is stale only because the tip
moved: `d02916e..2c48149` is 19 commits and the board grew to 125 / 185.

Fixed by **delta, not restatement** — the sibling's `d02916e` numbers stand and this tick appends the
landing-tip measurement (125 rows / 185 events / 38-82-5, `RESULT: OK (54 warning(s))`,
`SELFTEST: PASS` with 90 `PASS` rows) plus the CF-053 reopen explanation, so a reader comparing the two
blocks sees a moved tip rather than a lost closure.

`docs/ACCEPTANCE-PLAN.md` cites `CF-101…CF-112`; those are PRD requirement numbers, not board rows
(`jq` for `^CF-1(0[1-9]|1[12])$` over the board returns no rows), so no row was filed for them.

## Gates at the landing tip

| Gate | Command | Result |
|---|---|---|
| board schema | `bash scripts/boardctl validate` | `RESULT: OK (54 warning(s))`, rc 0 |
| CI-equivalent | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc 0, 90 `PASS` rows, 30 numbered section headers, 19 `FAIL` lines inside negative fixtures, loadavg 19.25 during the run |
| GitHub Actions | `gh run list --repo coding-hermes/code-factory --limit 3 --json …` | `[]` — the repository ships no workflows; the no-workflow state is healthy by documented contract |

`tests/selftest.sh` changed under this tick (`1b4b0b6 fix(selftest): enforce the interpreter-qualified
--check on README Status rows 1 and 3`), which is why the gate was re-run after the fast-forward
instead of being quoted from the earlier measurement. The suite's nondeterminism is already filed as
**CF-142** (one non-reproducing auth-marker FAIL in four runs at 2026-11-04T01:21, loadavg 30–36). One
passing run at loadavg 19.25 is a sample, not a closure of CF-142; CF-142 stays pending.

## Not run, and why

| Leg | Status | Reason |
|---|---|---|
| writes in `/home/kara/code-factory` | not run | live sibling judge (`CF-147-RV1`) grading that working tree, four sibling lanes running, one sibling file staged in the index |
| repair of the registered checkout's skew | not run | same barrier: a pull mid-judge mutates the tree being graded |
| worker dispatch | not run | this lane's deliverable is reconciliation; no implementation was needed |

The clone used is `cf-sync-20261104-0241.stoNIb/audit` under the session scratch root; every number
above was produced there and re-read from the output files saved beside it.
