# Sync lane audit — code-factory-duckbrain, tick `code-factory-duckbrain-sync-2026-11-04-04-08-27`

Lane: sync (board/repo drift reconciliation). Namespace: `code-factory`.
Measured at published tip `c2a6a45b28f142635e9cb53d9d18f94c4d7d4208` on 2026-11-04T04:14Z.

## Identity and ownership

| Check | Measured |
|---|---|
| scheduler locator vs `git -C … rev-parse --show-toplevel` | `realpath /home/kara/code-factory` = `/home/kara/code-factory` — equal |
| registered mapping (scheduler project row `code-factory-duckbrain`) | `repo_url` `local:/home/kara/code-factory`, `workdir` `/home/kara/code-factory` — matches the locator |
| `origin` / `worker` | both `git@github.com:coding-hermes/code-factory.git` |
| branch / operation markers | `main`, attached; no `MERGE_HEAD` / `REBASE_HEAD` / `CHERRY_PICK_HEAD` / `rebase-merge` / `rebase-apply` |
| tracked porcelain in the locator | empty; 53 untracked paths, all `.gitreins/history/2026-11-03/*` |
| board lock | `.coding-hermes/board/.lock`, 0 bytes, mtime 2026-11-03T07:40 — writer residue, not a barrier (`fuser` reports no holder and commits landed through it) |
| `core.hooksPath` | unset in the locator; a fresh clone ships no `pre-commit`, so no guard runs at commit time and guard evidence comes from the explicit `gitreins task complete` |
| live writer census (`scripts/checkout-writer-census.sh`) | `CENSUS_COUNT=4` — two `bash`+`sleep` wrapper pairs started 23:07:48 and 23:08:19, i.e. a sibling lane's launcher, not this tick |
| sibling lanes (single-project GETs) | `code-factory-sync` tick `…-2026-11-04-04-00-08` **running**; `code-factory-dogfood` tick `…-03-58-57` completed; `code-factory`, `-pm`, `-qa`, `-releng`, `-docs`, `-perf`, `-review` all `failed` |

Because a sibling lane of the same family was live on the shared checkout, **every write in this
tick ran in a fresh clone** of `git@github.com:coding-hermes/code-factory.git` under
`$TMPDIR/cfdb-sync-20261104/clone1` (cloned at `702a3e5`, fast-forwarded to `c2a6a45`, parity
`0 0`). The registered checkout was read only.

## Board census (deliverable 1)

| Check | Command | Result |
|---|---|---|
| task line count | `jq -s length .coding-hermes/board/tasks.jsonl` | 135 |
| per-line JSON | `jq -c . .coding-hermes/board/tasks.jsonl > /dev/null` | parses, rc 0 |
| duplicate task ids | `jq -r .id … \| sort \| uniq -d` | none |
| status census | `jq -r .status … \| sort \| uniq -c` | 45 `complete`, 6 `in_progress`, 84 `pending` |
| event line count at census time | `jq -s length .coding-hermes/board/events.jsonl` | 222 |
| row count matches the last commit | working board vs `git show HEAD:` sha256 | identical, `890b584b…` both sides |
| schema gate | `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))`, rc 0 — CF-034's free-form `guard_result`/`ci_result` plus the headerless board; `key uniformity: 135/135 rows carry only canon keys` |

## Complete-row evidence census (deliverable 2)

**The instrument had a defect, and it is fixed at source.** `board-evidence-census.sh` read its
per-row table with `IFS=$'\t' read`; because tab is IFS *whitespace*, an **empty** artifacts field
collapses and `run_id` shifts into `arts`, so a row whose newest evidence names no artifacts was
reported as `NOT_IN_TREE <id> <run-id>`. First run this tick produced exactly that phantom
(`NOT_IN_TREE CF-032 0576a54e`). The script now emits a `-` sentinel for an empty artifact list and
`sync-lane-tick-operations/scripts/board-evidence-census.sh` reports the true class. Corrected run
at `c2a6a45`:

| Class | Count |
|---|---|
| `NO_SHA` | 0 |
| `NO_OBJECT` | 0 |
| `NOT_ON_REF` | 0 |
| `NO_EVIDENCE` | 0 |
| `ABSOLUTE_PATH` | 0 |
| `NOT_IN_TREE` | 0 |
| **`NO_ARTIFACT_LATEST`** | **1 — `CF-032` (`run_id=0576a54e`)** |

One artifact shape that looks like a failure and is not: `CF-034`'s newest artifact is the trace
token `tests/selftest.sh::clone-error-classification`, not a file by that name. The lane's rule is
that an artifact may carry a `path::section` suffix, and the census strips the suffix before
resolving, so `tests/selftest.sh` resolves — `git cat-file -e origin/main:tests/selftest.sh::clone-error-classification`
fails only because that exact string is not a path. The row's legacy shape is recorded history and
the validator still warns about its `guard_result`/`ci_result`, not about this.

`CF-032`'s newest evidence entry (`run_id 0576a54e`, hand-appended 2026-11-03T08:42:20Z) named no
artifacts, so its closure had nothing resolvable at `origin/main`. Its closure content is in the
tree — `specs/NODE.md:30` reads `| 40 repo | the repo cloned at a pinned ref | base |`, the
narrowing is recorded at `specs/NODE.md:57` for `6f75e28` (CF-032), and `README.md:74` states "Layer
40 clones only; no build step is shipped" — and its bound commit `6f75e28` is an ancestor of
`origin/main`.

Repair, per lane contract (*append a superseding evidence run, erase nothing*): an entry
`run_id=CF-SYNC-20261104-0408`, `tree_fp=4ae2713e…` (the 64-hex `git ls-tree -r c2a6a45 | sha256sum`
— the tree the census was taken on, not this commit's tree: the board write that stores the entry
changes the tree, so a fingerprint can never equal the commit that carries it),
`artifacts=[this file]` was appended with `scripts/boardctl update CF-032 --evidence-run-id … --evidence-fingerprint … --evidence-artifact …`.
The row now carries three evidence entries; the two historical ones are untouched. The
field-vocabulary question (what `run_id`/`tree_fp` must be) stays with pending row **CF-047**, which
already owns it and cites CF-032 as its demonstration row — no second row was filed for that class.

## Docs status tables (deliverable 3)

One status drift, in `docs/ACCEPTANCE-PLAN.md`:

- The `Current acceptance summary` block (explicitly dated `d02916e`, 02:35) named `CF-126` as an
  open defect that makes the bus leg unreachable ("a README-created node fails layer 00 on
  `CRIER_URL`"). The board says otherwise: `CF-126` is `complete` since `2026-11-04T02:56:26Z` on
  `23c1c6d` (closure recorded by `85f852b` on verdict `dd7f64bc`; `git merge-base --is-ancestor
  23c1c6d origin/main` exits 0).
  **Fixed by a dated correction appended inside that bullet**, which keeps the `d02916e` snapshot
  standing and states that end-to-end exercise of the bus leg was not measured here. `CF-002` in the
  same sentence still stands (`status: pending`).

Every other row-status claim in the docs re-verified against the board and found consistent:
`CF-075`/`CF-077` complete (claimed closed), `CF-113` pending (claimed pending), `CF-137`/`CF-138`
`in_progress` (PRD block claim), `CF-001`/`CF-002`/`CF-004`/`CF-080`/`CF-083` pending. Identifiers
`CF-101`–`CF-112` in the plan are PRD requirement numbers, not board rows — read as ids they would
manufacture a phantom "12 missing rows".

## Gates

Measured on this commit's board and scripts immediately before this file was added — adding a
markdown file cannot change either result. The PASS-line count is deliberately not quoted: it moved
between runs of the same tree (103 vs 104) as fixtures print verdicts, so it is not a stable
evidence number; `SELFTEST: PASS` and the rows-parse line are.

| Gate | Command | Result |
|---|---|---|
| board schema | `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))`, rc 0 |
| CI-equivalent | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc 0, `PASS 135/135 rows parse` |
| GitHub Actions | `gh run list --repo coding-hermes/code-factory --limit 3` | `[]` — the repository ships no workflows; the selftest above is the gate |

## Not run, and why

| Leg | Status | Reason |
|---|---|---|
| writes in `/home/kara/code-factory` | not run | sibling lane `code-factory-sync` running on the shared checkout; all writes went to the clone |
| re-executing every one of the 45 complete rows' acceptance commands | not run | the lane re-runs the repo-wide gates; per-row probes that clone repos or touch docker are out of this tick's budget, and each row's named artifact is checked to resolve instead |
| further count deltas in `docs/BOARD.md` / `docs/ACCEPTANCE-PLAN.md` | not run | older ticks appended one, and it is stale within one merge. The counted snapshots are owned by CF-081 / CF-154 / CF-155, which the existing text already names |
| worker dispatch | not run | the lane's deliverable is reconciliation; no implementation was needed |

## Publication and how this file's own claims are falsifiable

This commit is the pass commit. Re-run at the published tip, not at a local head:

```
bash /home/kara/.hermes/skills/devops/sync-lane-tick-operations/scripts/board-evidence-census.sh \
  <clone-of-origin/main> .coding-hermes/board/tasks.jsonl origin/main
git cat-file -e origin/main:docs/audits/code-factory-duckbrain-sync-2026-11-04-0408.md
```

The first must print `finding_lines=0` and the second must exit 0. Before publication both fail by
construction — the CF-032 repair entry names *this* file, so it cannot resolve until this file is on
`origin/main`; a census taken against a local head proves the local head, not the published state.

The GitReins verdict and the DuckBrain receipt for this tick are bound by the board `audit` event
appended in the publication step, which names the verdict record id, the verdict-bundle commit and
the DuckBrain record id; the commit message's `ch:trace` line says
`verdict=none:recorded-after-push` / `memory=none:recorded-after-push` on purpose, because a commit
cannot name an artifact minted after it.
