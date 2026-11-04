# Sync lane audit — code-factory-duckbrain, tick `code-factory-duckbrain-2026-11-04-01-21-33`

Lane: sync (board/repo drift reconciliation). Namespace: `code-factory`.
Measured at published tip `f49d85b98aa90fcb3346a3edc40fe398a50a5d95` on 2026-11-04T01:36Z.

## Root and ownership

The scheduler locator `~/code-factory` resolves to itself and to its own Git top level, is on an
attached `main`, carries no rebase/merge/cherry-pick/revert marker, and is level with
`origin/main` (`git rev-list --left-right --count origin/main...HEAD` = `0 0`).

The checkout was nevertheless not written to this tick. Two sibling lanes of the same family
were live at dispatch time (`code-factory-pm` and `code-factory-sync`, both `status=running`,
ticks `…-2026-11-04-01-21-15`), which is a family-wide stand-down barrier for the shared
checkout. The work was done in a fresh `git clone` of `git@github.com:coding-hermes/code-factory.git`
at `f49d85b` (parity `0 0` against `origin/main`), and the locator was left untouched.

`.coding-hermes/board/.lock` exists in the locator: 0 bytes, mtime 2026-11-03T07:40:02-05:00,
`fuser -v` reports no holder, and `grep -rn 'flock\|fcntl' scripts/boardctl scripts/*.py` returns
no consumer. Recorded as residue, not a held lock, and not deleted.

## Census

| check | result |
|---|---|
| `tasks.jsonl` lines / parsed rows | 114 / 114 (`jq -c .` exit 0) |
| `events.jsonl` lines / parsed rows | 162 / 162 (`jq -c .` exit 0) |
| duplicate task ids | none |
| working file vs `git show HEAD:` sha256 | identical (`f6e782c0…`) |
| status histogram | 38 complete, 4 in_progress, 72 pending |

## Complete rows: evidence binding

38 rows are `complete`.

- `commit_hash` missing or unresolvable: **1** — `CF-053` (`commit_hash: null`, config-only
  change in another repository). Already tracked by CF-130.
- commit not an ancestor of `origin/main`: **0**.
- evidence artifacts that do not resolve in the committed tree: **2 entries on 2 rows**, both the
  historical entry of `CF-011` and `CF-013` citing an absolute scratch log outside the tree. Both
  rows carry a later superseding entry pointing at
  `docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md`, which exists in the tree. History
  preserved by design; no action.
- `complete` rows with no `task_completed` event: **2** — `CF-034`, `CF-041`. Already tracked by
  CF-130; not re-filed and not minted, because neither closure was witnessed by this tick.
- Completion-event duplicates: 9 task ids carry two `task_completed` events. This is the board's
  established minimal+rich closure shape (the writer's own minimal event plus the lane's rich
  `--detail` event), not drift.

Field-name note for later ticks: events carry `event_type` (never `type`); the first pass of this
audit keyed on `type`, read 162 nulls, and produced a false "9 completion events with no row".
Re-running with `event_type` in a private scratch path showed the true set. `detail` is an object
on 83 rows, a string on 3, and null on 28 — normalize per row before traversing it.

## Docs drift found and fixed

`docs/BOARD.md` carried a hand-typed `Current measured state` block pinned to tip `21d3265`:

- frozen pre-fix pair — 104 task rows, 148 events, `RESULT: OK (45 warning(s))`,
  `PASS 104/104 rows parse`;
- measured at `f49d85b` — 114 task rows, 162 events, `RESULT: OK (46 warning(s))`,
  `PASS 114/114 rows parse`.

The block was restated at the measured tip with measured values only, and it now names CF-081 as
the structural fix (a committed check that derives the counts and fails on a mismatch). CF-081 stays
pending: this tick corrects the numbers, it does not build the guard. The pre-fix pair is frozen
above so CF-081's red arm still has a reproducible fixture.

## Gates run at `f49d85b`

```
bash scripts/boardctl validate
  RESULT: OK (46 warning(s))                     rc=0
bash tests/selftest.sh
  PASS  114/114 rows parse
  SELFTEST: PASS                                  rc=0
```

The 46 validator warnings are pre-existing vocabulary/graph warnings: 43 rows carrying a free-form
`probe` key, CF-034's `guard_result`/`ci_result` prose, and the headerless board.

## Open, not touched

CF-130 (completion-transition gaps, CF-053 stale closure, CF-005 stale `in_progress`), CF-081
(hand-typed measured-state block), CF-086 (absolute host paths in board rows) remain pending and are
the owning lanes' work. This repo runs no GitHub Actions; the CI-equivalent gate is the selftest
above.

## Verification addendum — 2026-11-04T02:05Z–02:20Z (same tick id, second session)

The prior session of this tick id (`code-factory-duckbrain-2026-11-04-01-21-33`) completed its
work and died before reporting; the scheduler record reads `failed` (a spawn artifact — the
`latest_tick.id` for this lane is still this tick id, so no second instance exists). Its durable
claims verify: `ceff295`, `82d8819` and `d59f87b` are on `origin/main`, and the DuckBrain record
`/code-factory/sync/2026-11-04-duckbrain-tick` reads back `200` with the content quoted in event
164. The work was NOT re-executed.

### What changed after that record (measured here)

| Fact | Value |
|---|---|
| published tip | `2a3d357` (was `f49d85b` when the record was measured) |
| commits after the record | `df0c8fc` PM re-anchor + CF-141, `2a3d357` verdict bundle |
| census at `2a3d357` | 115 task rows, 165 events, 0 duplicate ids (38 complete / 4 in_progress / 73 pending) |
| `bash scripts/boardctl validate` | `RESULT: OK (47 warning(s))`, rc=0 |
| `bash tests/selftest.sh` | `PASS 115/115 rows parse`, `SELFTEST: PASS`, rc=0 |
| parity | `git rev-list --left-right --count origin/main...HEAD` = `0 0`, tracked porcelain empty |

### Barrier, seen and lifted inside this session

At 20:51:29 -05 the canonical root entered an interactive rebase (`refs/heads/main` onto
`d59f87b`, msgnum 1/1). At 20:53:57 HEAD was detached with `.git/rebase-merge` present and
`UU .coding-hermes/board/events.jsonl` staged, so the operation gate failed. At 20:55 the marker
was gone, `main` was attached at `df0c8fc`, the tracked tree was clean and parity was `0 0`. The
resolution was performed by the rebase's owner, not by this tick, and no owner authorization for
it is recorded on CF-049 — which names this class and its earlier lift (06:57 the same morning).
The 01-21-15 slot fired eight sibling `code-factory*` lanes; all read `failed` afterwards.

### Finding filed

`df0c8fc` rewrote 35 pre-existing lines of `.coding-hermes/board/events.jsonl`
(`git show --numstat df0c8fc -- .coding-hermes/board/events.jsonl` = 36 insertions / 35
deletions) while resolving the rebase. The content is intact: normalising both sides with `jq -c`
and sorting shows old ⊂ new, additions only (event ids 163–165), zero events lost. What changed is
the raw bytes of historical lines — the legacy `"id": 1` separator style became compact — so an
append-only ledger was rewritten in place and no gate notices. Filed as **CF-143** with this
re-runnable detector as acceptance criterion 0:

```
git log --format='commit %h' --numstat -- .coding-hermes/board/events.jsonl | awk '/^commit /{c=$2; next} NF==3 && $2+0>0 {print c": "$0}'
```

It prints exactly one line today (`df0c8fc: 36	35	.coding-hermes/board/events.jsonl`). No claim is
made about which resolution step produced the rewrite; the commit shape cannot distinguish a
line-wise merge from a slurp/dump resolver.

### Memory written this session (namespace `code-factory`, content-equality readback)

| key | record id |
|---|---|
| `/code-factory/decisions/2026-11-04-pm-milestone-reanchor` | `8915336e-ef5a-4edc-a0a1-4f0a4daabf27` |
| `/code-factory/findings/2026-11-04-append-only-reserialization` | `6194c660-a32c-49ad-ba80-c25c6bc135c3` |
| `/code-factory/findings/2026-11-04-checkout-barrier-recurrence` | `d8473191-099f-4aca-94c3-31a1c8c38d9d` |
| `/code-factory/findings/2026-11-04-append-only-reserialization-correction` | `4dcf1418-08b2-4dbd-9809-9cc9ac855e50` |

### Verdicts on this filing

The row was drafted `CF-142` and filed `CF-143`: a board read taken minutes before the append
still said `CF-142` free, and the sync lane consumed it at `b5cf33a` for an unrelated flake
finding. A draft id is not a reservation.

| task | history dir | passed | commit | mode |
|---|---|---|---|---|
| `CF-142-DUCK1` | `.gitreins/history/2026-11-04/11b28235` | no | `4b24e84` | instrument: tier-2 output truncated at char 2500, `items: []`, no criterion graded |
| `CF-143-DUCK2` | `.gitreins/history/2026-11-04/2b57ca8b` | yes | `4b24e84` | tier1 PASS, tier2 PASS (printed run id `d747ab6b`) |

The truncated run is preserved, not deleted. Its cause was the criterion's own length: the
criterion is echoed verbatim into the judge's JSON response, and the ~1000-character five-part
version pushed that response past the parser's window. The same commit re-judged with a
~390-character criterion passed cleanly, so the lesson is to keep filing criteria short and let
the board row carry the detail.

## Verification addendum — re-fire of tick `code-factory-duckbrain-sync-2026-11-04-02-39-26`

Measured 2026-11-04T03:01Z at tip `dae4e7a0e59f489cf1b90f57ce9bbe5ee71b243a`.

A prior execution of this same tick id left `docs/audits/code-factory-sync-2026-11-04-0241.md`
(measured at `2c48149`) and reported. This session is a re-fire: the earlier file's durable claims
were re-verified against the tree instead of re-executed, and the tip had moved four commits
(`2c48149` → `dae4e7a`) in the meantime, so every number below was measured again.

### Barrier

The canonical checkout `/home/kara/code-factory` was read only. At tick start the family lanes
`code-factory` (tick `code-factory-2026-11-04-02-39-16`, same 02-39 slot) and `code-factory-releng`
(`…-02-59-07`) were `running` on the shared repo, and `code-factory-dogfood` had just completed. Root
equality held (`realpath` = `git rev-parse --show-toplevel` = `/home/kara/code-factory`), remote
`coding-hermes/code-factory` matched the registered `repo_url`, `main` was attached, no operation
marker was present, and tracked-tree porcelain was empty; only `.coding-hermes/board/.lock`
(0 bytes, mtime 2026-11-03 07:40, no `flock`/`fcntl` consumer in `scripts/boardctl*`) and 50
untracked `.gitreins/history/2026-11-0{3,4}/*` paths were present. All writes below ran in a fresh
clone of `origin/main` in this tick's scratch, not in the canonical checkout.

### Re-verified deliverable 1 — board parses, row count matches the committed tree

| Check | Result at `dae4e7a` |
|---|---|
| task line count | 127 |
| per-line JSON (`jq -c .`) | parses, exit 0 |
| duplicate task ids | none |
| status census | 40 `complete`, 5 `in_progress`, 82 `pending` |
| event line count | 193, parses, no duplicate ids |
| working board vs committed tree | byte-identical (`sha256 f86611f2…` both sides) |
| publish-drift census (`scripts/board_drift.py check --workdir . --ref origin/main`) | `RESULT: OK` — 127 vs 127 rows, 0 divergent ids, HEAD ancestry exit 0 |

### Re-verified deliverable 2 — every `complete` row's evidence

| Check | Result |
|---|---|
| `complete` rows | 40 |
| `commit_hash` null or unresolvable | 0 — every sha passes `git cat-file -e <sha>^{commit}` |
| commit not reachable from `origin/main` | 0 |
| `detail.evidence[].artifacts` unresolvable in the committed tree | 2 entries on 2 rows: the historical first-run log `/home/…/code-factory-pm-20261031-114422-final-selftest.log` on CF-011 and CF-013 |
| `complete` rows with no `task_completed` event | 2 — `CF-034`, `CF-041`; both commit-bound, already tracked by CF-130. No event was minted, because the append-only log must not record a transition its writer did not witness |
| `task_completed` event with no `complete` row | 1 — `CF-053`, the audited reopen (event records `in_progress`; commit `6d801c7` names the QA isolation re-verification) |

The two absolute-path artifacts are preserved history, not an open gap: each row already carries a
later superseding entry whose artifact `docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md`
resolves in the committed tree. Nothing was erased and no row was re-filed.

### Deliverable 3 — docs status tables, drift found and fixed

Both docs blocks were stale by count, not by status (no row is described as pending while the board
says complete, or the reverse):

- `docs/BOARD.md`'s measured block still read 116 rows / 168 events / `RESULT: OK (47 warning(s))`
  from 01:58Z.
- `docs/ACCEPTANCE-PLAN.md`'s newest delta read 125 rows / 185 events / `RESULT: OK (54 warning(s))`
  at `2c48149`.

Both received an appended measured delta instead of a rewrite, so the earlier snapshots stand as
history: 127 rows / 193 events (40-5-82), `RESULT: OK (3 warning(s))`, `SELFTEST: PASS`. The warning
count fell from 54 to 3 because CF-129 relanded canon keys (key uniformity 127/127); the three
remaining warnings are CF-034's two free-form fields and the headerless board.

### Gates at the landing tip

| Gate | Command | Result |
|---|---|---|
| board schema | `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))`, rc 0 |
| CI-equivalent | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc 0, `PASS 127/127 rows parse`, 92 `PASS` rows, 30 numbered sections plus `4b`/`7b`, 19 `FAIL` lines inside negative fixtures; loadavg 15.60 during the run |
| GitHub Actions | `gh run list --repo coding-hermes/code-factory --limit 3` | `[]` — the repository ships no workflows; healthy by documented contract |

### Not run, and why

| Leg | Status | Reason |
|---|---|---|
| writes in `/home/kara/code-factory` | not run | sibling lanes `running` on the shared checkout in the same slot; all writes went to a fresh clone |
| worker dispatch | not run | this lane's deliverable is reconciliation; no implementation was needed |

### Landing-tip delta — the board moved during this tick's rebase

The rebase onto `origin/main` picked up four sibling commits (`dae4e7a` → `e9f3085`) that filed CF-154,
CF-155, reopened CF-079 and recorded a DuckBrain receipt. Measured again at `e9f3085`:

| Check | At `e9f3085` |
|---|---|
| tasks.jsonl | 129 rows parse, no duplicate ids — 39 `complete`, 6 `in_progress`, 84 `pending` |
| events.jsonl | 197 rows parse |
| `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))` — unchanged: CF-034's two free-form fields plus the headerless board |
| `bash tests/selftest.sh` | `SELFTEST: PASS`, `PASS 129/129 rows parse`, 92 `PASS` rows, 30 numbered sections, loadavg 9.49 |

Two consequences, both recorded rather than chased:

- The measured deltas appended to `docs/BOARD.md` and `docs/ACCEPTANCE-PLAN.md` are labelled at
  `dae4e7a` (127 rows / 193 events) and are stale by two folded rows at the landed tip. That is the
  documented moving-target class, not a defect this lane closes by typing a third number.
- **CF-154** ("the census block's warning count does not follow from the board") and **CF-155**
  ("plan stale by one selftest section") own the structural fix. This tick named both inside the
  corrected docs text and filed nothing for the same class.
