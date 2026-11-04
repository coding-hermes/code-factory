# Sync lane evidence — 2026-11-04T06:26Z (tick `code-factory-duckbrain-sync-2026-11-04-06-11-13`)

Board/repo consistency pass for code-factory, run **in the registered checkout**
`/home/kara/code-factory`: the ownership gate came back clean (attached `main`, no operation
markers, zero tracked edits, tip in parity with `origin/main`, board bytes identical to the
published board), so no clone transport was needed.

Lane: sync (board/repo drift reconciliation). Namespace: `code-factory`.

## Identity and barrier

| Check | Measured |
|---|---|
| `realpath /home/kara/code-factory` vs `git -C … rev-parse --show-toplevel` | equal (`/home/kara/code-factory`) |
| registered `workdir` / `repo_url` (scheduler project row `code-factory-duckbrain`) | `/home/kara/code-factory` / `local:/home/kara/code-factory` — matches the locator |
| `origin` / `worker` | both `git@github.com:coding-hermes/code-factory.git` |
| branch / operation markers | `main`, attached; no `MERGE_HEAD` / `REBASE_HEAD` / `CHERRY_PICK_HEAD` / `REVERT_HEAD` / `rebase-merge` / `rebase-apply` |
| `HEAD` / `origin/main` / `git ls-remote` | `1aeb0c7` / `1aeb0c7` / `1aeb0c7fb05dff56c12aaae97f8b39f02e32b441` — parity `0 0` |
| tracked index and worktree | empty — zero staged and zero unstaged tracked edits |
| untracked residue | 53 paths, every one under `.gitreins/history/2026-11-03/` (unpublished judge bundles). Not read, not cleaned, not adopted |
| live writer census (`scripts/checkout-writer-census.sh`) | `CENSUS_EMPTY=1`, `CENSUS_COUNT=0` — no process with cwd at or under the checkout |
| host load | loadavg 9.70 / 13.29 / 16.87 during the gate run |
| per-tick receipt for this tick id | `GET /api/memories/key//code-factory/sync/2026-11-04-061113?namespace=code-factory` → `404 NOT_FOUND`: no prior execution, so this is a fresh tick, not a resumed one |

## Deliverable 1 — board parses, and the row count matches the last commit

| Check | Command | Result |
|---|---|---|
| per-line JSON | `jq -c . .coding-hermes/board/tasks.jsonl > /dev/null` | parses, rc 0 |
| task rows | `jq -s length .coding-hermes/board/tasks.jsonl` | 137 |
| rows in the committed copy | `git show HEAD:.coding-hermes/board/tasks.jsonl \| jq -s length` | 137 |
| board bytes vs committed copy | `sha256sum` on both | identical, `ba93be84c405b4ed913e09e6efa7c1519feaf0e088243461e25055c3037e0ec0` |
| duplicate task ids | `jq -r .id … \| sort \| uniq -d` | none |
| status census | `jq -r .status … \| sort \| uniq -c` | 45 `complete`, 8 `in_progress`, 84 `pending` |
| event rows | `wc -l < .coding-hermes/board/events.jsonl` | 233 before this tick's own audit event |
| schema gate | `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))`, rc 0 — CF-034's free-form `guard_result`/`ci_result` plus the headerless board; `key uniformity: 137/137 rows carry only canon keys (0 drift)` |

Completion-event coverage: the 45 `complete` rows are covered by 45 distinct `task_completed`
event `task_id`s, except `CF-034` and `CF-041`, which are `complete` with **no** completion event.
That gap was already measured and recorded by the `01:21` sync tick (event 168) — it is not new
here, and this lane did not mint events for transitions it did not witness.

## Deliverable 2 — complete-row evidence still binds and still runs

`scripts/board-evidence-census.sh /home/kara/code-factory .coding-hermes/board/tasks.jsonl origin/main`:

```
ref=origin/main complete_rows=45 finding_lines=0
  NO_SHA=0  NO_OBJECT=0  NOT_ON_REF=0  NO_EVIDENCE=0
  NO_ARTIFACT_LATEST=0  ABSOLUTE_PATH=0  NOT_IN_TREE=0
```

Every `complete` row carries a `commit_hash` that exists and is an ancestor of `origin/main`, and
its **newest** evidence entry names an artifact that resolves in the published tree. The
`NO_ARTIFACT_LATEST=1` finding the `04:08` tick reported on `CF-032` is gone: that tick's
superseding evidence run (`run_id=CF-SYNC-20261104-0408`, artifact
`docs/audits/code-factory-duckbrain-sync-2026-11-04-0408.md`) is in the published tree, and the
historical entries on the row were left standing.

"Still runs", re-executed at this head rather than quoted from history:

| Command | Result at `1aeb0c7` |
|---|---|
| `bash tests/selftest.sh` | `SELFTEST: PASS`, rc 0 (log kept at `$TICK_SCRATCH/selftest.log`; the `FAIL` lines in it are the suite's intentional negative fixtures) |
| `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))`, rc 0 |
| `scripts/board-evidence-census.sh …` | `finding_lines=0`, rc 0 |

## Deliverable 3 — docs status tables vs the board

One status drift, in `docs/ACCEPTANCE-PLAN.md`'s `Current acceptance summary` bullet
**End-to-end first milestone**. Its `04:14` correction stated that `CF-002` "still stands
(`status: pending`)" and the bullet itself listed `CF-001` among the "never-exercised" legs. The
board and the tree disagree at this tip:

| Frozen claim (as found at `1aeb0c7`, quoted before the edit) | Board / commit at `1aeb0c7` |
|---|---|
| `CF-001` is among the "never-exercised" legs (line 185) | `CF-001` = `in_progress` since `2026-11-04T05:54:41Z`; `1aeb0c7` records the first scheduler-originated remote dispatch accepted by the relay at `00:53:34` (message `7f4bc40b`), after 82 consecutive `403` refusals, AC6/AC7 still open |
| "The `CF-002` clause still stands (`status: pending`)" (lines 193–194) | `CF-002` = `in_progress` since `2026-11-04T05:35:55Z`; `3c78dd1` records a live node-token probe (allowed `200`, other model `403`, no model `400`, unknown token `401`, revoked sub-token `401` with no restart) and a completing turn (`hermes chat` → `AC1-NODE-OK`) |
| "`CF-002` … so the commit leg is unreachable" (lines 186–187) | superseded as a *blocker* by `3c78dd1`; the end-to-end commit leg is still not demonstrated, and this pass does not claim it |

**Fix applied (append-only, snapshot preserved):** one dated correction bullet added after the
milestone bullet. The `d02916e` snapshot and both earlier corrections are left standing so the move
reads as a moved tip, not a lost closure. Diff is `12 insertions(+), 0 deletions(-)` on
`docs/ACCEPTANCE-PLAN.md`.

Every other row-status claim in the docs was re-verified against the board and found consistent:
`CF-075`/`CF-077` complete (claimed closed), `CF-126` complete (as corrected at `04:14`), `CF-113`
pending (claimed pending), `CF-137`/`CF-138`/`CF-139` `in_progress` (PRD block claim), `CF-004`,
`CF-080`, `CF-083` pending. Identifiers `CF-101`–`CF-112` in the plan are PRD requirement numbers,
not board rows — read as ids they would manufacture a phantom "12 missing rows", so no row was
filed for them. `docs/BOARD.md` is an operation contract carrying no row statuses, and
`docs/SECURITY-TRIAGE.md` cites `CF-119` as prose; neither can drift the way a status table does,
so both were left untouched. `README.md`'s status table states capability status with its own
evidence commands and does not assert a board row status; its `CF-001`/`CF-002`/`CF-004` mentions
remain accurate as "not armed / not yet" until those rows close, so it was left untouched.

No task row was filed: the pass found no new gap that survives verification, and both drift items
were corrections of a document to match the board, which the lane fixes in place.

## Board writes

One append: an `audit` event recording this pass (counts, gate results, the drift found and the
correction applied, the completion-event gap re-measured). No row `status` field was rewritten.

## Not run, and why

| Leg | Status | Reason |
|---|---|---|
| publishing the 53 untracked `.gitreins/history/2026-11-03/*` bundles | not run | no board row points at them (every referenced artifact resolves), so publication is not required for evidence binding; left exactly as found and disclosed |
| deletion of `.coding-hermes/board/.lock` | not run | writer residue is recorded, never deleted, by lane contract |
| re-executing every one of the 45 complete rows' acceptance commands | not run | out of this tick's budget; each row's newest named artifact is proven to resolve at `origin/main` and the repo-wide gates were re-run instead |
| worker dispatch | not run | the lane's deliverable is reconciliation; no implementation was needed |

## Gates and publication

| Leg | Value |
|---|---|
| GitReins task | `CF-SYNC-20261104-0611` — created and started before any edit; verdict recorded by the follow-up board event |
| CI-equivalent gate | `bash tests/selftest.sh` → `SELFTEST: PASS`, rc 0 |
| board schema | `bash scripts/boardctl validate` → `RESULT: OK (3 warning(s))`, rc 0 |
| GitHub Actions | `gh run list --repo coding-hermes/code-factory --limit 3` — queried this tick; the repository ships no workflows, so the selftest above is the gate |

This file is the pass commit's evidence artifact. It is falsifiable from the published tip:

```
bash /home/kara/.hermes/skills/devops/sync-lane-tick-operations/scripts/board-evidence-census.sh \
  <clone-of-origin/main> .coding-hermes/board/tasks.jsonl origin/main   # finding_lines=0
git cat-file -e origin/main:docs/audits/code-factory-sync-2026-11-04-0611.md
jq -r 'select(.id=="CF-001" or .id=="CF-002")|[.id,.status]|@tsv' .coding-hermes/board/tasks.jsonl
```

## Disclosure — a second writer appeared in this checkout mid-tick

The ownership gate was clean when this tick started (`CENSUS_EMPTY=1`, zero tracked edits). At
`2026-11-04T06:14:42Z` a foreign write appeared in the tree: `docs/PRD-code-factory.md` was rewritten
with a `Status 2026-11-04T06:20Z (board re-measured at 1aeb0c7)` block, and at `06:14:47Z`
`docs/ACCEPTANCE-PLAN.md` line 6 was rewritten with a `Current state (re-measured
2026-11-04T06:15Z at tip 1aeb0c7)` header. A re-run of `scripts/checkout-writer-census.sh` then
reported `CENSUS_COUNT=4` (`bash`+`tail`+`sleep`, started `01:15:16`/`01:15:36` local) — a sibling
lane's launcher, live in the shared checkout.

Consequences, stated rather than papered over:

- This pass commit publishes **only** the three paths it authored: this file, the appended
  correction bullet in `docs/ACCEPTANCE-PLAN.md`, and the single appended audit event. `git commit`
  was scoped by pathspec, so `docs/PRD-code-factory.md` was **not** staged and remains the sibling's
  in-flight work, untouched and uncommitted by this tick.
- The sibling's header line rides inside the same file this tick edited and therefore lands in this
  commit as well. It is disclosed here rather than silently claimed: its two numbers (137 task rows,
  233 events at `1aeb0c7`) were independently reproduced by this tick's own census, so they are
  verified; its `loadavg 8.56` sample is **not** measured here and is carried on the sibling's
  authority.
- No board row, event id or evidence entry of the sibling's was adopted, renumbered or rewritten.

