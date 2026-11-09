# code-factory sync lane — 2026-11-09T16:46Z

Lane: `code-factory-sync-2026-11-09-16-46-28`. Tick ran from the registered checkout,
which was clean and level with `origin/main`
(`cd1a3f6a5c43ef150176270e4cd394d829873f60`, `git rev-list --count origin/main..HEAD` = 0) when the
tick opened. Board source named in every figure below is the **committed** board at `origin/main`,
read with `board_read.py` / `git show`, not the worktree cache.

## 1. Board parses, and the row count is the last commit's

| Check | Command | Measured |
|---|---|---|
| on-disk parse | `git show origin/main:.coding-hermes/board/tasks.jsonl` line-by-line `json.loads` | 438 rows, **0 unparseable** |
| worktree vs committed | same parser over the working copy | 438 rows, identical status split — cache not dirty |
| duplicate ids | `Counter(row["id"])` | **0** duplicates |
| status split | — | complete 117 · in_progress 14 · pending 307 |
| events | `git show origin/main:.coding-hermes/board/events.jsonl` | 634 events, 0 unparseable, `max_id=634` |
| duplicate event ids | `Counter(event["id"])` | **336** only — the documented legacy pair, unchanged |
| shape gate | `bash scripts/boardctl validate` | `RESULT: OK (85 warning(s))` |

The 85 warnings are dominated by one pre-existing class (`branches is not an array (null)` on the
`P3B-*` rows) plus the free-form `guard`/`ci` fields (CF-034), the headerless board, and the
title-priority drift (CF-150/CF-192). No warning was created by this tick.

Rows closed in the last window (both carry evidence): **CF-299** `2026-11-09T13:07:53Z` (event 633)
and **CF-399** `2026-11-09T14:53:02Z` (event 634, verdict `5a127f1b`).

## 2. Every `complete` row names evidence that still runs

Two instruments, because one of them is vacuous here and the honest thing is to say which.

**a. Verdict-artifact sweep** — `python3 docs/audits/cf181-verdict-binding-sweep.py . .coding-hermes/board/tasks.jsonl origin/main`
prints `complete_rows=117`, `verdict_artifacts_checked=0`, `orphan_count=0`.

`checked=0` is **not** the deleted-bundles defect. The denominator is real:
`git ls-tree -r --name-only origin/main | grep -c '^\.gitreins/history/'` = **8** files, and both
run-ids among them (`65bf5725`, `9ccb5dfd`) are cited by **CF-006, which is `pending`**. So no
`complete` row has a tracked verdict bundle to check — the sweep is vacuous by subject matter, not
by blindness.

**b. Evidence census over the LATEST `detail.evidence` entry of every `complete` row**, resolving
each artifact against the tree at `origin/main` (`path`, or `path::anchor` with the anchor grep'd,
or an absolute path tested for existence):

| Bucket | Rows | Meaning |
|---|---|---|
| bound-resolvable | **36** | artifact path/anchor resolves at `origin/main` |
| bound-missing | **66** | entry names an artifact that does not resolve at `origin/main` |
| unbound | **15** | entry carries `run_id`/`ts` but no artifact list at all |
| no-evidence-entry | **0** | every complete row has at least one evidence entry |
| total | 117 | |

Unbound: `CF-087 CF-150 CF-211 CF-266 CF-278 CF-281 CF-288 CF-290 CF-292 CF-299 CF-307 CF-384
CF-388 CF-396 CF-399`. `CF-299` and `CF-399` are the two rows this window closed — closures keep
minting unbound entries, which is exactly why the class needs an owner that runs, not a sweep.

No delta is claimed against the previously recorded triple `36 / 66 / 4`: that triple sums to 106,
today's buckets sum to 117, so the earlier census ran a narrower classifier over a different
denominator. Re-measured is re-measured; the old number does not describe this tree.

`commit_hash`: 0 complete rows cite a commit that is not an ancestor of `origin/main`; 2 rows cite
no commit at all (`CF-245`, `CF-384`).

**The class is already owned** — `CF-398` (pending) exists to make evidence-pointer resolvability a
check that can fail in-repo, `python3 scripts/board_evidence_check.py`, pinned to 46 unresolved rows
at `4b7e0aa`. This tick adds instances under that row and files no duplicate.

## 3. Docs status tables vs the board

`bash docs/audits/cf198-section-mapping.sh` → `arms_plan=68 arms_tree=68`, `RESULT: OK`.
`bash docs/audits/cf099-prd-drift-probe.sh` → **DRIFT**:

```
DRIFT: plan says 64 sections, tests/selftest.sh has 65
measured: tip=2f07051 rows=350 events=489 sections=65 open_blockers=CF-001 CF-002 …
```

The drift is one stale sentence, not a stale tree: `docs/ACCEPTANCE-PLAN.md` line 114 already
carried the `§65` mapping row (landed by `6f04f57`, CF-299), while the **current-state** line still
said 64 numbered sections / 67 arms. A `§NN` arm can land without the current-state prose following
it; `cf099` is the falsifier.

**Fixed** in this tick, in `docs/ACCEPTANCE-PLAN.md`: the current-state line now reads 65 numbered
sections (1–65), 68 arms, `arms_plan=68 arms_tree=68`, and its census chain names the `§65` landing
(`6f04f57`, the CF-299 resolver/ladder role-table parity arm).

Red→green on the same instrument:

- before: `DRIFT: plan says 64 sections, tests/selftest.sh has 65`, exit 1
- after: `OK: milestone, plan snapshot and layer arms agree at cd1a3f6`, exit 0

Named as **documented-real, not drift**: `docs/RUMSFELD.md` line 13 still says
`arms_plan=61 arms_tree=61`, and line 7–16 says outright that the register was not re-run at the
current HEAD and that "re-measuring this register at HEAD is a separate piece of work, not a property
this page claims". The figure is pinned to `c068e87` and reproduces there. Left alone on purpose.

`CF-199` (pending) is adjacent but distinct — it wants `cf099` to prove the *pinned tip is
published*, not to keep the section count current. No row was filed for this drift: it was fixed
here, which is the lane's job.

## 4. Ownership / unblock

`python3 scripts/ownership.py status` at tick open reported `state=clean` — `untracked=0`, `lock=null`,
workdir the registered checkout — nothing to dispose, nothing to attribute.

## 5. Memory duty — decisions this tick records

- **Ownership beats re-instrumentation.** The evidence-resolvability class stays with `CF-398`
  (in-repo checker, strict mode, fixture proving it can fail); the sync lane reports instances under
  it instead of minting a parallel instrument that would drift.
- **A vacuous instrument must report its denominator.** `cf181` printing `checked=0` was resolved by
  naming the 8 tracked artifacts and the pending row that cites them, not by declaring the sweep
  green.
- **One stale sentence, one fix.** `cf099` red → edit → green, no board row, because the lane's job
  is reconciliation, and the plan's own mapping row already agreed with the tree.

Open and unowned by this tick, stated so a later tick can pick it up: 66 `bound-missing` and 15
`unbound` evidence entries remain (CF-398's subject); `CF-245` and `CF-384` still cite no commit.
