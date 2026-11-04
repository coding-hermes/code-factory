# Sync lane evidence — 2026-11-04T08:29Z (tick `code-factory-sync-2026-11-04-08-24-10`)

Board/repo consistency pass for code-factory. The registered checkout passed the identity gate but
was **8 commits behind the published tip and carried one sibling lane's unpublished commit**, so this
pass ran from a scratch clone of `origin/main` and left `/home/kara/code-factory` untouched.

Lane: sync (board/repo drift reconciliation). Namespace: `code-factory`.

## Identity and barrier

| Check | Measured |
|---|---|
| `realpath /home/kara/code-factory` vs `git -C … rev-parse --show-toplevel` | equal (`/home/kara/code-factory`) |
| registered `workdir` / `repo_url` (scheduler project row `code-factory-sync`) | `/home/kara/code-factory` / `local:/home/kara/code-factory` — matches the locator |
| `origin` / `worker` | both `git@github.com:coding-hermes/code-factory.git` |
| branch | `main`, attached |
| `HEAD` / published tip (`git ls-remote`-equivalent after `fetch`) | `8f03159` / `a5be9c9` — `git rev-list --left-right --count origin/main...HEAD` = `8 1` |
| the one local-ahead commit | `8f03159 fix(node-scripts): escape every value interpolated into remote bash -lc … Addresses CF-159.`, committed 2026-11-04 03:24:20 — ten seconds after this tick spawned; touches `scripts/lib.sh`, `scripts/node-create.sh`, `scripts/verify-node.sh`, `tests/selftest.sh`. Another lane's in-flight work: **not pushed, not rebased, not touched** |
| board bytes, worktree vs `HEAD` | identical (`3ab5babbd748` / `4bed93b53d3e` truncations match) — the tree carries no uncommitted board edit |
| board bytes vs published board | differ, because the checkout is 8 commits behind (three of those commits are board/verdict commits) |
| bare `REBASE_HEAD` | present, content `cdb0cc8a…`, mtime `2026-11-04 03:12:09`. Classified **stale** on all four signals: (1) the mtime and second match `pull --rebase origin main (start)` at 03:12:09 in `git reflog --date=iso`; (2) later normal operations exist — `rebase (continue)` and `rebase (finish)` at 03:12:24, then `merge origin/main: Fast-forward` at 03:13:02; (3) no `rebase-merge` / `rebase-apply` / `MERGE_HEAD` / `CHERRY_PICK_HEAD` under `git rev-parse --absolute-git-dir`; (4) `scripts/checkout-writer-census.sh` reports `CENSUS_COUNT=1` for a single `comm=tail` hit started at `03:25:07` — this tick's own pipeline stage, not an owner |
| `board/.lock` | 0 bytes, mtime `2026-11-03 07:40:02`. `fuser -v` → no holder; `grep -rn 'flock\|fcntl' scripts/boardctl*` → no hits. Writer residue, recorded and **not deleted** |
| untracked residue | 56 paths, every one under `.gitreins/history/2026-11-03/` or `/2026-11-04/` (unpublished judge bundles). Not read, not cleaned, not adopted |
| per-tick receipt | `GET /api/memories/key//code-factory/sync/2026-11-04-08-24-10?namespace=code-factory` → `404 NOT_FOUND`: fresh tick, not a resumed one |
| sibling lane | `code-factory-releng-qa-2026-11-04-08-24-10` shares this batch's `spawned_at`; the writer census, not its `running` row, decided that nothing is writing |
| transport | `git clone /home/kara/code-factory` into tick scratch, `git remote add gh git@github.com:coding-hermes/code-factory.git`, `git fetch gh main`, `git checkout -B main gh/main` → `a5be9c9`, porcelain 0 |
| host load | loadavg 7.36 / 12.82 / 19.53 at the gate run |

## Deliverable 1 — the board parses and the row count matches the commit

All figures measured at tip `a5be9c9` unless a different tip is named.

| Check | Command | Result |
|---|---|---|
| per-line JSON | `jq -c . .coding-hermes/board/tasks.jsonl > /dev/null` | parses, rc 0 |
| task rows | `wc -l < .coding-hermes/board/tasks.jsonl` | 154 |
| rows that re-emit | `jq -c . … \| wc -l` | 154 — no torn line |
| rows in the committed copy | `git show gh/main:… \| wc -l` | 154 — matches the last commit |
| duplicate task ids | `jq -r .id … \| sort \| uniq -d` | none |
| event rows | `wc -l < .coding-hermes/board/events.jsonl` | 286 (87 `audit`, 123 `task_created`, 62 `task_completed`, 11 `task_updated`, 3 `task_evidence`) |
| duplicate event ids | `jq -r .id … \| sort \| uniq -d` | none |
| status census | `jq -r .status … \| sort \| uniq -c` | 49 `complete`, 97 `pending`, 8 `in_progress` |
| schema gate | `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))`, rc 0 — `key uniformity: 154/154 rows carry only canon keys (0 drift)`; warnings are CF-034's free-form `guard_result`/`ci_result` and the headerless board |

Field names were read before set arithmetic: events carry `event_type`, not `type`. A coverage check
keyed on `.type` reports 100% missing on this board.

## Deliverable 2 — every `complete` row's evidence resolves, and a new instrument found one orphan

The seven-class census (`board-evidence-census.sh <repo> .coding-hermes/board/tasks.jsonl gh/main`)
judges each row's `commit_hash` and its **newest** evidence entry's artifacts:

```
ref=gh/main complete_rows=49 finding_lines=0
  NO_SHA=0  NO_OBJECT=0  NOT_ON_REF=0  NO_EVIDENCE=0
  NO_ARTIFACT_LATEST=0  ABSOLUTE_PATH=0  NOT_IN_TREE=0
```

That census does not read inside the verdict artifact, so this tick added a second sweep
(`docs/audits/cf181-verdict-binding-sweep.py`, filed with the row it justifies): every complete
row's verdict JSON is parsed in the tree at the ref and its envelope `commit` is tested for ancestry.

```
ref=gh/main complete_rows=49
verdict_artifacts_checked=21
=== ORPHANED ===
CF-077 run=410022a2 artifact=.gitreins/history/2026-11-03/410022a2/verdict.json commit=1dfb58b8aa passed=True
orphan_count=1
```

Both arms were run, not assumed. `docs/audits/fixtures/cf181-board-clean.jsonl` (verdict bound to an
on-ref commit) prints `orphan_count=0`; `cf181-board-orphan.jsonl` (verdict bound to 40 zeros) prints
exactly one ORPHANED line naming `CF-009` and `orphan_count=1`.

`CF-077` is `complete` with `commit_hash 1232f7a0` — an ancestor of `gh/main`. Its cited verdict binds
`1dfb58b8`, the pre-rewrite copy of the same subject (`fix: fail closed when the auth probe cannot
prove the gateway is closed. Addresses CF-077.`, 11:29:50 vs the landed 11:42:32), which no branch
contains. The Tier-2 PASS therefore certifies a tree that is not the published one. Filed as
**CF-181** with the reproduction tool and both fixture arms; not a split closure of CF-067 (evidence
digests resolving to no object) or CF-144 (which instrument grades `tree_fp`).

Completion-event coverage: 47 of 49 `complete` rows carry a `task_completed` event. `CF-034` and
`CF-041` do not — already measured by the `01:21` tick (event 168) and owned by **CF-130**; not
re-filed, and no completion transition was minted for either id.

`in_progress` staleness: 8 rows (`CF-001`, `CF-002`, `CF-005`, `CF-053`, `CF-079`, `CF-137`,
`CF-138`, `CF-139`). Each is a judgement or an external dependency rather than bookkeeping; no row
status was changed by this pass.

## Deliverable 3 — docs against the board

- `docs/audits/cf099-prd-drift-probe.sh` → `OK: milestone, plan snapshot and layer arms agree at
  a5be9c9` (rc 0). It measures `tip=bc68e59 rows=148 events=273 sections=35` and every open-defect
  id it lists is still not `complete`.
- `docs/ACCEPTANCE-PLAN.md` gained one dated delta line naming tip `a5be9c9`; no earlier snapshot was
  rewritten, and no number was carried forward that this tick did not measure. The plan's own
  snapshot figures stay pinned to the tips they name — a moving tip is not drift.
- `docs/BOARD.md`'s hand-typed "Current measured state" block is owned by **CF-081** (pending); this
  tick corrected no figure there and filed nothing for the class.

## Gates at the landing tree

| Gate | Command | Result |
|---|---|---|
| repo selftest | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc 0 — 109 `PASS` rows, 19 `FAIL` rows (every one an intentional negative fixture), 35 numbered sections plus §4b/§7b = 37 arms, loadavg 7.36 (1 min) |
| board schema | `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))`, rc 0 |
| docs drift probe | `bash docs/audits/cf099-prd-drift-probe.sh` | rc 0, `OK: … agree at a5be9c9` |
| row probe (staged, run from the repo root) | `bash <probe>.sh` | rc 0, prints `verdict_artifacts_checked=21`, the `CF-077` ORPHANED line, `orphan_count=1` |
| CI surface | `gh run list --repo coding-hermes/code-factory` | `[]` — this repo ships no GitHub Actions; the CI-equivalent gate is `tests/selftest.sh` plus the gitreins guard, and an empty run list is not evidence of health |

## Rebase at landing

The published tip moved six commits while this pass ran (`a5be9c9` → `a9453d9`: five events and the
CF-176 closure). The landing was rebased rather than force-pushed: the upstream `events.jsonl` was
taken whole (291 events, max id 291) and this tick's own `task_created` line re-appended as event
**292** — its pre-rebase id 287 was already taken by a sibling's verification addendum. `tasks.jsonl`
merged insert-only (`CF-181` present once, 155 rows, no duplicate ids) and every line re-parses in
both files. Figures above stay pinned to the tip they were measured at; the board at the landing
commit carries 155 rows and 292 events.

## Second rebase and the section-count drift it exposed

The tip moved once more before the push (`a9453d9` → `8b81369`: CF-159's escaping fix). That rebase
was clean (`scripts/`, `tests/` versus this tick's board/docs), but it landed **§36**, and the CF-099
probe compares the acceptance plan's section count against the working tree, so the probe went red:
`DRIFT: plan says 35 sections, tests/selftest.sh has 36`. That red is the sibling commit's landing,
not this diff — the probe was green on this tick's first tree. Reconciled by re-measuring the plan's
current-state line at `8b81369` (36 sections, 38 arms counting §4b/§7b, 119 `PASS` rows, 19 fixture
`FAIL` rows, board 154 rows / 291 events) and naming §36 with its board row, rather than trimming the
tree back to 35 sections. The suite was measured on a tree whose `tests/selftest.sh` is byte-identical
to `8b81369`'s (`git diff 8b81369 HEAD -- tests/selftest.sh` = 0 lines).

## Candidate state at close

`/home/kara/code-factory` was **not** fetched into, fast-forwarded, written, or cleaned. It remains
8 behind / 1 ahead of the published tip with the same 56 untracked judge bundles and the same
0-byte `board/.lock`; the in-flight `8f03159` is still its owner's to publish. Per the sync-lane
rule, a candidate that is behind **and** carries an unpublished sibling commit is the clone case, not
the fast-forward case.
