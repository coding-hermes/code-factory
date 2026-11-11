# Sync lane verification addendum — 2026-11-04T08:52Z (tick `code-factory-sync-2026-11-04-08-24-10`, third execution)

Third execution of this tick id. The first fire landed `docs/audits/code-factory-sync-2026-11-04-0824.md`
(pass `0e44db9`, superseded record `7383edf7`), the second fire landed
`docs/audits/code-factory-sync-2026-11-04-0842-refire.md` (pass `d1342ac`, verdict `3ddc4abd`). Neither
receipt is edited here. Per the resumed-tick rule this pass implemented nothing for the work those two
fires closed and minted no second task for it.

All measurements below are from a scratch clone of the published tip, because `~/code-factory`
is 19 commits behind and carries a live sibling writer (see "Barrier"):

```sh
git clone ~/code-factory land && cd land
git remote add gh git@github.com:coding-hermes/code-factory.git
git fetch gh main && git checkout -B main gh/main    # 7232954, porcelain 0
```

## Prior-receipt claims re-verified at the current published tip `7232954`

| Claim (from the 08:24 / 08:42 receipts) | Re-measured here | Verdict |
|---|---|---|
| board parses line by line | `jq -c .` rc 0 on `tasks.jsonl` **and** `events.jsonl` | holds |
| row count equals the committed copy | 158 tree = 158 `git show HEAD:…`; 300 events = 300 | holds (numbers moved with 2 sibling rows) |
| no duplicate ids | `uniq -d` count 0 for tasks and events | holds |
| schema gate | `bash scripts/boardctl validate` → `RESULT: OK (3 warning(s))`, `158/158` canon keys | holds |
| every `complete` row carries a resolving `commit_hash` | 51/51 resolve via `git cat-file -e <sha>^{commit}`; 0 empty | holds |
| every artifact named by the newest evidence entry exists | 32 distinct artifacts, `missing=0` | holds |
| completion-event coverage | 49/51 carry `task_completed`; `CF-034`, `CF-041` still do not (owned by **CF-130**) | unchanged |
| verdict binding sweep | `cf181-verdict-binding-sweep.py` → `complete_rows=51`, `verdict_artifacts_checked=23`, `orphan_count=1` = `CF-077` → `1dfb58b8` | unchanged; already **CF-181** (pending) |
| standing gate still runs | `bash tests/selftest.sh` rc 0, `SELFTEST: PASS`, 119 `PASS`, 19 intentional-fixture `FAIL`, 36 numbered sections + `4b`/`7b` (38 arms) | holds |
| PRD/plan drift probe | `cf099-prd-drift-probe.sh` → `OK: milestone, plan snapshot and layer arms agree at 7232954`, rc 0 | holds |
| board-drift instrument | `board_drift.py check --workdir . --ref main` → `RESULT: OK` (initial run inside the clone self-fetched from the registered checkout; re-run clean) | holds |
| CI surface | `gh run list --repo coding-hermes/code-factory --limit 3` → `[]` — the repo ships no GitHub Actions, so the gate is the selftest plus the gitreins guard; an empty list is not a green CI | holds |

## Drift found and fixed (this commit)

`docs/BOARD.md` §"Current measured state" carried the 08:42Z `202fb61` snapshot under a heading that
asserted it described **"the tree this commit lands"** — 156 rows / 295 events / 50 `complete` /
98 `pending` / `PASS 156/156 rows parse`. Two sibling rows (`CF-183`, `CF-184`) landed after that
receipt and moved the published tip to `7232954`, so the block no longer described any current tree.
Measured drift at `7232954`: **+2 rows, +5 events, +1 `complete`, +1 `pending`, `PASS 158/158 rows
parse`**.

Fix applied, one file, additive:

- the heading no longer claims currency by construction — it says the newest snapshot names the tip it
  was measured at;
- a new snapshot pinned to `7232954` (158 / 300 / 51 / 8 / 99, validate `158/158`, selftest `PASS
  158/158 rows parse`) sits above it;
- the `202fb61` bullet is retained verbatim and re-labelled an **earlier snapshot (historical, not
  current)** — no prior snapshot line was deleted or rewritten;
- the structural owners are named in the block: **CF-081** (hand-typed counts → committed check),
  **CF-154** (warning count), **CF-155** (plan section count).

No other docs drift exists in this tree. `docs/ACCEPTANCE-PLAN.md`'s current-state line is pinned to
`8b81369` and reproduces there (`cf099` probe rc 0), so a moved tip is not drift for it. No per-task
status table exists in `docs/`, so the "row complete but the table says pending" class does not occur;
the one place it could occur — the PRD milestone's open-defect list — is guarded by the `cf099` probe
and passes.

## Gates at the landing tree

```
bash tests/selftest.sh                     -> SELFTEST: PASS (exit 0; 119 PASS / 19 fixture FAIL; 158/158 rows parse)
bash scripts/boardctl validate             -> RESULT: OK (3 warning(s)) (exit 0; 158/158 canon keys)
bash docs/audits/cf099-prd-drift-probe.sh  -> OK at 7232954 (exit 0)
python3 docs/audits/cf181-verdict-binding-sweep.py . .coding-hermes/board/tasks.jsonl main
                                           -> verdict_artifacts_checked=23, orphan_count=1 (CF-077 -> CF-181)
python3 scripts/board_drift.py check --workdir . --ref main -> RESULT: OK
gh run list --repo coding-hermes/code-factory --limit 3      -> [] (no workflows shipped)
```

## Barrier and residue (disclosed, not cleaned)

- `~/code-factory` was **not** written, fetched into, reset, or cleaned. It is 19 commits
  behind `origin/main` (`git rev-list --left-right --count origin/main...HEAD` = `19 0`), its board
  bytes differ from the published board for that reason, and it carries three modified tracked files —
  `docs/ACCEPTANCE-PLAN.md`, `docs/audits/cf099-prd-drift-probe.sh`, `tests/selftest.sh` — belonging to
  a sibling docs lane's in-flight CF-155 worker.
- `scripts/checkout-writer-census.sh ~/code-factory` reported `CENSUS_COUNT=8`, including
  `comm=hermes` (pid 573391, started 03:34:46) with cwd at the checkout root. A live writer holds it, so
  the fast-forward route was refused and the pass ran from a clone.
- 56+ untracked `.gitreins/history/` judge bundles remain in the registered checkout; not read, not
  published, not adopted.
- No board row was filed, closed, or rewritten by this pass; no board event was appended; the two
  regression rows it re-verified (`CF-181`, `CF-130`) were already pending and are named, not re-filed.
