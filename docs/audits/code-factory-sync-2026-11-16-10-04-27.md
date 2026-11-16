# Code Factory sync tick — 2026-11-16T10:04Z scheduled, measured at 14:45Z

Lane: `code-factory` / sync. Branch `main` in the repo checkout — the checkout's absolute path is
deliberately not written here, because item 61 of the self-test (CF-050) refuses any published tree
that adds an absolute host-home path, and this file is part of that tree.
Board source: `python3 scripts/board_read.py --next 10` → **`origin/main`**, tip `74c973af`.
Every number below is an output value from a command in the *Reproduce* section, not a hand count.

## 1. Board census

| measure | value | command |
| --- | --- | --- |
| tip | `74c973af` | `git rev-parse --short=8 HEAD` |
| task rows | 528 | `wc -l .coding-hermes/board/tasks.jsonl` |
| event rows | 817 (max id 816) | `wc -l` + `jq -r 'select(.id)|.id' \| sort -n \| tail -1` |
| ids parse as JSON objects | 528 / 528 | item-count vs row-count, no torn lines |
| duplicate task ids | 0 | `scripts/boardctl validate` |
| key uniformity | 526 / 528 | `acceptance`/`chapter`/`created`/`model` on 2 rows — **CF-154** territory, 0 fixable by `--normalize` |
| `boardctl validate` | `RESULT: OK (89 warning(s))` | warning count is not a function of the board bytes |
| drift vs canonical | `RESULT: OK` — 528 vs 528, 0 divergent ids | `scripts/board_drift.py check --workdir . --ref origin/main` |
| status split | 167 complete, 15 in_progress, 344 pending, 2 blocked | `jq -r '.status' \| sort \| uniq -c` |
| complete rows binding an ancestor commit | 165 / 167 | `git merge-base --is-ancestor <hash> origin/main` per row |
| complete rows with no hash | 2 — **CF-245**, **P5G-34** | same loop, `no_hash` bucket |
| closure evidence | `checked 167 complete rows, 57 unresolved`, `expected_unresolved=57` | `scripts/board_evidence_check.py` |

The heads of both board files are byte-identical to `origin/main`, so this census describes the
canonical board rather than a cache some worker dirtied. Nothing needed reconciling: no complete row
pointed at a commit outside `origin/main`, and the evidence checker's orphan count matches the count
it derives from the board.

## 2. CI census — and the attribution CF-450 called impossible

`gh run list --limit 200` returns **49 runs: 31 success, 17 failure, 1 cancelled**. The order matters
and a 10-run window hides it:

| phase | window | runs |
| --- | --- | --- |
| green (gate arrives) | 2026-11-15T01:15Z `e51daff3` → 2026-11-15T22:26Z `176378c1` | 30 consecutive `success` |
| red (handbook review text lands) | 2026-11-16T01:34Z `228b7896` → 2026-11-16T14:31Z `7d1dac3e` | 17 consecutive `failure` + 1 `cancelled` |
| green again (fix) | 2026-11-16T14:33Z `74c973af` | `success`, both jobs |

Every red run died on the same arm. Exact row from run `43886556997` (job `selftest`, step
`Repo self-test gate`):

```
61. the published tree does not add absolute host-home paths (CF-050)
  FAIL  publish paths — baseline 0, current 2; paths: docs/handbook/PASS7-PLAN.md docs/handbook/conformance/manifest.json
SELFTEST: FAIL (1)
```

**CF-450 recorded that the log could not say which arm failed:** "the log cannot say WHICH arm failed
… no item-level FAIL marker," with attribution left to an Actions re-run. That was a parsing error,
and it is worth writing down because the next reader will make it too. Two greps both mislead:

- `grep '^[0-9]\+\. '` matches nothing. Every Actions log line is
  `<job>\t<step>\t<ISO-8601 timestamp> <message>`, so the item header never starts the line.
- `grep FAIL` matches 64 rows in a *passing* run. They are negative-control fixtures — arms whose job
  is to prove a gate can refuse — so a FAIL row is not a verdict.

The verdict is the pair `PASS`/`FAIL` on a stable label, and the item that broke is the label whose
verdict differs between a red run and a green one. `docs/audits/cf450-ci-attribution.sh` does exactly
that join and nothing else:

```
$ bash docs/audits/cf450-ci-attribution.sh 43886556997 43887027423
--- verdict rows: red=574 green=574 (unique labels) ---
ATTRIBUTED  publish paths  (red=FAIL green=PASS)
ATTRIBUTED: 1 label(s) flipped FAIL in the red run.
$ bash docs/audits/cf450-ci-attribution.sh 43887027423 43887027423
--- verdict rows: red=574 green=574 (unique labels) ---
NO DIVERGENCE: red and green agree on every shared label.
(exit 2)
```

574 verdict labels in each run — **562 shared** after the inner join, one divergence — and the
instrument exits 2 rather than inventing an attribution when the runs agree. The 12 one-sided labels
are excluded because they embed volatile data (tmp paths, short commit ids); that is a real limit, not
a cosmetic one: a regression confined to such a label would be invisible here (filed as **CF-454**).
**CF-450 is satisfied by re-runnable commands**: which workflow/job
(`selftest` / `Repo self-test gate`), exact failure output (above), a reproducible command (the script
plus a local `bash tests/selftest.sh`), and a green run on the corrected head (`43887027423` at
`74c973af`).

The fix itself is `74c973af`, 2 files, 2 insertions, 2 deletions — one absolute host path in
`docs/handbook/PASS7-PLAN.md` and one in `docs/handbook/conformance/manifest.json`, each spelled
`$HOME`. Nothing else was committed to make CI green, and `176378c1` — the last green before the red —
is the same commit the leaked review note names as its base.

## 3. Local reproduction (does the evidence still run?)

`bash tests/selftest.sh` at `74c973af`, full suite: **70 numbered items, 571 `PASS` rows, 64 `FAIL`
rows (all fixtures), `SELFTEST: PASS`, `EXIT=0`**. The lane's second duty — "the evidence still runs" —
is met by a fresh run at the published tip, not by citing the CI badge.

## 4. Drift found and fixed

| # | drift | disposition |
| --- | --- | --- |
| 1 | `docs/BOARD.md` current-state block still described the 2026-11-14 tip `70519fcc` and still asserted "the repo has no CI at all — no `.github` directory at `origin/main`" | re-measured block added at `74c973af` (528 rows / 817 events); the no-CI sentence is kept as dated history and explicitly marked superseded by `e51daff3` |
| 2 | **CF-450** `pending` while its own acceptance criteria were fully demonstrated | closed with the run ids, the exact FAIL row, and the attribution tool as evidence |
| 3 | an attribution tool did not exist, so each tick re-derived the same parse by hand | `docs/audits/cf450-ci-attribution.sh` added — falsifiable (exit 2 on agreement) and public-safe (no paths, no secrets, repo arg only) |

## 5. Still open (filed, not fixed here)

- **CF-451** — `ruff format` drift: 18 tracked Python files would be reformatted at `303e7515`, so any
  commit staging one of them is refused by the tier-1 lint lane. Not touched: this tick stages only
  Markdown and shell, and reformatting 18 files inside a sync tick would hide the change behind noise.
- **CF-154** — `boardctl validate` reports 89 warnings that do not move with the board bytes; the
  count is not derived, so it cannot presently fail.
- **CF-245**, **P5G-34** — complete with no `commit_hash`. Both have known reasons (fix landed in the
  scheduler repo; acceptance was a measurement) and neither is a sync-lane fix.
- The 2 off-canon key rows still carry `acceptance`/`chapter`/`created`/`model` and are not fixable
  by `boardctl update <id> --normalize`.

## 6. Reproduce

```sh
git fetch origin --prune && git rev-parse --short=8 HEAD
wc -l .coding-hermes/board/tasks.jsonl .coding-hermes/board/events.jsonl
python3 scripts/boardctl validate
python3 scripts/board_drift.py check --workdir . --ref origin/main
python3 scripts/board_evidence_check.py
gh run list --repo coding-hermes/code-factory --limit 200 --json conclusion \
  -q '[.[].conclusion] | group_by(.) | map("\(.[0])=\(length)") | join(" ")'
bash docs/audits/cf450-ci-attribution.sh 43886556997 43887027423   # exit 0, 1 attribution
bash docs/audits/cf450-ci-attribution.sh 43887027423 43887027423   # exit 2, NO DIVERGENCE
bash tests/selftest.sh                                             # SELFTEST: PASS, EXIT=0
```
