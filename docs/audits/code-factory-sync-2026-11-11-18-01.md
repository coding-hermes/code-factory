# code-factory sync census — 2026-11-11 18:01 UTC-05

Lane: `code-factory-sync-2026-11-11-18-01-01`. Board source for every number below:
`git show origin/main:.coding-hermes/board/tasks.jsonl` (the git-side canonical copy). The
working copy was byte-identical to it at the start of the tick, and `HEAD` equalled
`origin/main` at `49916f1e`.

This file is the durable record of one sync tick: what parsed, what drifted, what was fixed,
and what is still open. Nothing here is a claim about a row's correctness — only about the
state of the two stores the lane owns (the board and the docs that quote it).

## 1. Board integrity

| Measure | Value | Instrument |
|---|---|---|
| rows parsed | 491 before this tick, 492 after (CF-420 filed) | `wc -l`, `jq` per line |
| status split (before) | 137 complete · 14 in_progress · 340 pending · 0 blocked | `jq -r .status \| sort \| uniq -c` |
| line-by-line parse | every line is one JSON object; no torn line | `jq -c . tasks.jsonl \| wc -l` |
| validator | `RESULT: OK (97 warning(s))` | `bash scripts/boardctl validate` |
| drift vs origin/main | `PASS` — 0 divergent, 0 missing, 0 extra, byte parity identical | `python3 scripts/board_drift.py check --workdir . --ref origin/main` |
| events store | 489+ rows, parses; one duplicate event id and one legacy row without `id` (tolerated, pre-existing) | `boardctl validate` |

The 97 warnings are standing, not new, and they are classified rather than dismissed:

| Class | Count |
|---|---|
| `branches is not an array (null)` — tolerated by validator | 74 |
| deferred row carries no `defer_reason` | 10 |
| title/priority both carry "PN"; priority wins | 3 |
| `created_at` absent (excluded from time buckets) | 3 |
| keys outside declared canon (`acceptance`, `chapter`, `created`, `model`) | 2 |
| free-form `guard_result` / `ci_result` values | 2 |
| headerless board; legacy event without id; duplicate event id | 3 |

A warning count is not a clean-close proof. Two of the classes are actionable and are named in
§4; the rest are representation choices the validator already tolerates.

## 2. Evidence coverage on complete rows

| Measure | Value |
|---|---|
| complete rows checked | 137 |
| evidence resolved | 80 |
| evidence unresolved | 57 (`expected_unresolved=57`, derived from the board itself) |
| local verdict history | 81 run dirs across 5 dates: 2026-11-06 … 2026-11-11 |
| history tracked in git? | no — `.gitignore:12` ignores `.gitreins/history/` |

Instrument: `python3 scripts/board_evidence_check.py`.

Reading this honestly matters. The 57 unresolved rows are **not** 57 sloppy closes. Every one
of them cites a run id from before 2026-11-06, and no verdict artifact for those dates exists
anywhere — the history directory holds five days and git never carried the rest. So the
population is *unavailable*, not *failed*. The repo cannot answer "was this row really judged"
for anything closed before 2026-11-06, and no amount of re-running the checker changes that.

The related sweep at a git ref makes the same point from the other side:
`python3 docs/audits/cf181-verdict-binding-sweep.py` prints `verdict_artifacts_checked=0` when
run against `origin/main`, because the artifacts are not in the tree. A zero denominator is an
unavailable population, not proof that no orphaned verdict exists.

This class already has an owner — `CF-181`, pending — so this tick files nothing for it.

## 3. Docs versus board

The lane's third duty is to reconcile `docs/` status tables against the board. Findings:

- **No per-row board-status table exists in `docs/`.** Greps for table rows carrying
  `pending`/`complete`/`in_progress`/`blocked` cells return nothing, and no doc maps a `CF-nnn`
  id to a board status. There is therefore no per-row table that can contradict the board.
- **The count claims that do exist are dated snapshots**, and each names its own tip:
  `docs/ACCEPTANCE-PLAN.md:6` (re-read 2026-11-06 at `2f07051`), `:13` ("historical board
  snapshot at tip `2f07051` … the current tree's census is re-measured by the command below"),
  `:16` (evidence snapshot 2026-11-04T02:35Z at `d02916e`), `:55` (archived delta list).
  Under this lane's own classification rule a dated census block is a historical artifact, not
  drift, and rewriting one would destroy the record it exists to keep.
- **The live instrument agrees with the tree:** `bash docs/audits/cf099-prd-drift-probe.sh`
  prints `OK: milestone, plan snapshot and layer arms agree at 49916f1e`, exit 0.

Drift found in docs this tick: none. Drift repaired: none — with the reason stated, so a later
reader does not mistake "nothing to fix" for "nothing checked".

## 4. Fix applied

One row filed — `CF-420`, P3, chapter III.M4.S1:

> ten rows carry `deferred:true` with no recorded deferral, and six of them are also
> `in_progress`.

The ten are `CF-001 CF-049 CF-131 CF-132 CF-136 CF-137 CF-138 CF-139 CF-204 CF-248`. All were
stamped 2026-11-05T13:02–13:04Z (five share the identical stamp `13:02:43Z`, i.e. one bulk
write), and `events.jsonl` carries `task_created`/`task_updated` for them but no defer event and
no reason text. The board status machine in `docs/handbook/chapters/M4-board.md:346-372` treats
`deferred` as a *status* with a required `deferral` record (reason, review-by, return
condition), and forbids that record otherwise (`:354`).

The tick does not guess the reason. Removing a deferral flag on a row nobody explained is how a
parked epic silently becomes dispatchable, so the disagreement is filed with its evidence and
left for a foreman to settle row by row.

## 5. CI health

`gh run list --repo coding-hermes/code-factory --limit 3` returns `[]`, and `.github/workflows`
does not exist. CI on this repository is *unconfigured* — neither green nor red. The gate that
does exist is `tests/selftest.sh` plus the gitreins guard, and neither runs on a push. No CI
failure row was filed because there is no CI to fail.

## 6. Open items

1. `CF-420` — the deferral disagreement above (this tick's only filing).
2. `CF-181` (pending, pre-existing) — durable verdict binding. 57 complete rows cannot be
   re-verified from the repo for the structural reason in §2; the fix is to make verdict
   artifacts durable, not to re-run the checker.
3. Standing validator warnings that nobody owns: 74 null `branches`, 3 rows with `created_at`
   absent, 2 rows carrying off-canon keys. These are cheap to normalize and were deliberately
   left alone, because a bulk rewrite of 79 rows for warnings the validator already tolerates
   is a bigger risk than the warnings themselves.
