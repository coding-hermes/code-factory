# 20. scripts/land-node-branch.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/land-node-branch.sh` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: A finished node task has no path into `origin/main`; the source says: `The result envelope (specs/ENVELOPE.md) names `branch` and `commit`; no step in this repo merges them, so a finished node task has no path into origin/main. This is that path.`
- What breaks if it lies: It would report a commit as landed when `origin/<main>` does not contain it. The script itself distinguishes: `The push is a claim; the ancestry test against the re-fetched remote is the evidence.` A push that did not land the commit should print `LAND: FAIL` and exit nonzero.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | UNKNOWN | `#!/usr/bin/env bash` (`$PATH`) | UNKNOWN |
| `git` | UNKNOWN | `$PATH`; invoked as `git -C ...` | UNKNOWN |
| `lib.sh` | UNKNOWN | `$HERE/lib.sh`, sourced via `. "$HERE/lib.sh"` | UNKNOWN |
| `awk`, `head`, `cut`, `sed`, `grep`, `tail`, `wc`, `tr`, `mktemp`, `rm`, `dirname` | UNKNOWN | `$PATH` | UNKNOWN |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `. "$HERE/lib.sh"` | `lib.sh` in same directory as script | Functions `say`, `note`, `ok`, `bad`, `warn` and variable `FAILED` are used but not defined in this source | UNKNOWN |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| **UNKNOWN** | — | — | — | **RED** |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| — | **no check exists** | — | — | **RED** |

## 4. Metrics emitted

**NONE FOUND** — the source contains no metrics/telemetry; it only prints textual status lines via `say`, `note`, `ok`, `bad`, and `warn`.

## 5. Log lines it can generate

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| unknown | `land-node-branch — workdir=$WORKDIR branch=$BRANCH commit=$COMMIT $REMOTE/$MAIN` | After argument parsing completes | startup |
| unknown | `LAND: REFUSED — $2` | Any refusal path, via `refuse` | failure |
| unknown | `LANDED (already): $BRANCH @ $commit_sha in $REMOTE/$MAIN` | Idempotent already-landed path, non-dry-run | success |
| unknown | `LAND: DRY-RUN — nothing to do, $commit_sha is already in $REMOTE/$MAIN` | Already-landed path under `--dry-run` | dry-run |
| unknown | `LAND: DRY-RUN — 0 commands run, nothing merged or pushed, no ref moved` | `--dry-run` completes all read-only checks | dry-run |
| unknown | `LANDED: $BRANCH @ $commit_sha in $REMOTE/$MAIN (tip $(git -C "$TOP" rev-parse --short "$MAIN_REF"))` | Success after final ancestry proof passes | success |
| unknown | `LAND: FAIL ($FAILED)` | Push failed or final proof failed | failure |

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Not a git worktree | `LAND: REFUSED — not a git worktree: $WORKDIR` (row `workdir`, exit 1) | Row `workdir` | Use a valid git worktree |
| Dirty worktree | `LAND: REFUSED — <n> uncommitted path(s) in $TOP (...)` (row `workdir_clean`, exit 1) | Row `workdir_clean` | Commit or stash, per message |
| Not on `$MAIN` or detached HEAD | `LAND: REFUSED — workdir is on '$cur', not '$MAIN' ...` or `detached HEAD ...` (row `on_main`, exit 1) | Row `on_main` | Check out `$MAIN` before landing |
| Fetch failure for remote main ref | `LAND: REFUSED — git fetch ...` (row `fetch`, exit 1) | Row `fetch` | Resolve remote/fetch issue |
| Cannot resolve remote main ref | `LAND: REFUSED — cannot resolve $MAIN_REF in $TOP` (row `main_tip`, exit 1) | Row `main_tip` | Fetch the remote main ref |
| `$COMMIT` not in clone | `LAND: REFUSED — $COMMIT is not a commit in $TOP ...` (row `commit`, exit 1) | Row `commit` | Fetch the node branch before landing |
| Branch not found | `LAND: REFUSED — no branch $BRANCH in $TOP or on $REMOTE` (row `branch`, exit 1) | Row `branch` | Push/fetch the branch |
| Commit not reachable from branch | `LAND: REFUSED — $commit_sha is not reachable from $branch_ref ...` (row `commit_on_branch`, exit 1) | Row `commit_on_branch` | Use the correct branch/commit pair |
| Branch is not descendant of remote main | `LAND: REFUSED — $branch_ref ... is not a descendant of $REMOTE/$MAIN ...` (row `descendant`, exit 1) | Row `descendant` | Rebase the branch onto `$REMOTE/$MAIN` |
| Gate worktree creation fails | `LAND: REFUSED — cannot create a detached worktree at $commit_sha ...` (row `gate`, exit 1) | Row `gate` | Fix worktree/disk/permission issue |
| Gate command exits nonzero | `LAND: REFUSED — '$GATE' exited $gate_rc at ${commit_sha:0:12} — ...` (row `gate`, exit 1) | Row `gate` | Fix the failing gate/project tests |
| Not fast-forwardable under `--ff-only` default | `LAND: REFUSED — $MAIN at ... is not an ancestor of $commit_sha ... — not fast-forwardable; push or reset $MAIN, or pass --no-ff` (row `ff_only`, exit 1) | Row `ff_only` | Push/reset `$MAIN`, or pass `--no-ff` |
| Merge failure/conflict | `LAND: REFUSED — git merge --ff-only $commit_sha failed — ...` or `git merge --no-ff ... failed` (row `merge`, exit 1) | Row `merge`; merge is aborted first | Resolve conflict/rebase, then rerun |
| Push rejected or fails | `git push $REMOTE HEAD:refs/heads/$MAIN failed — ...; local $MAIN is now ... and $REMOTE/$MAIN was not updated` (row `push`), then `LAND: FAIL ($FAILED)` | Row `push` plus `LAND: FAIL` | Resolve remote push issue; merged locally but not landed |
| Post-push proof fails | `$commit_sha is NOT an ancestor of $REMOTE/$MAIN (...)` (row `landed`), then `LAND: FAIL` | Row `landed` plus `LAND: FAIL` | Investigate push; script exits nonzero |

## 7. Environment and settings it reads

- CLI arguments parsed in the `while [ $# -gt 0 ]` block:
  - Required: `--workdir`, `--branch`, `--commit`
  - Optional: `--remote` (default `origin`), `--main` (default `main`), `--gate-cmd` (default empty), `--ff-only` (default enabled), `--no-ff`, `--dry-run`, `-h|--help`
- Defaults assigned at the top: `WORKDIR="" BRANCH="" COMMIT="" REMOTE=origin MAIN=main GATE="" FF_ONLY=1 DRY=0`
- No environment variables are read in this source.

## 8. Evidence of record

- none yet
