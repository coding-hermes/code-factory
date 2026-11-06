#!/usr/bin/env bash
# land-node-branch.sh — control host: land a node's result branch on main, then prove it.
#
#   ./land-node-branch.sh --workdir ~/repos/foo --branch node/crier/<dispatch_id> \
#                         --commit <sha> [--remote origin] [--main main] \
#                         [--gate-cmd 'go test ./...'] [--no-ff] [--dry-run]
#
# The result envelope (specs/ENVELOPE.md) names `branch` and `commit`; no step in this repo
# merges them, so a finished node task has no path into origin/main. This is that path.
#
# Refuses, naming the measured value, before it merges anything:
#   - the workdir is not a git worktree, is not checked out on <main>, or is dirty
#   - <commit> is not a commit in this clone, or is not reachable from <branch>
#   - <branch> is not a descendant of <remote>/<main> (rebase it, do not merge it)
#   - --ff-only (the default) and <main> is not an ancestor of <commit>
#   - --no-ff and the local <main> is not <remote>/<main>: the merge commit's first parent is
#     that local tip, so pushing it would publish commits the node never made — row
#     `no_ff_local` names how many, which, and the remedy; nothing is merged or pushed
#   - the project gate exits nonzero on the node's own tree
#   - the merge itself fails (a conflict aborts the merge and names the reason)
# On success: fetch both refs, merge, capture the merge's tip as `merge_sha`, push
# `<merge_sha>:refs/heads/<main>` — an explicit object, never `HEAD` — re-fetch, and PROVE
# `git merge-base --is-ancestor <sha> origin/<main>`. The PASS row belongs to that proof, never
# to the merge: a push that did not land the commit prints FAIL and exits nonzero. The `push`
# row and the closing LANDED line both name the sha this run pushed, so the claim and the
# object cannot drift apart.
#
# Idempotent: a commit already contained in <remote>/<main> is reported as landed, with no
# merge and no push — the gate still runs on that path, so "already landed" is reported only
# after the node's own tree has been measured. --dry-run runs every read-only check, prints the
# exact commands it would run — including the explicit-sha push, which on --no-ff can only be
# named after the merge creates it — and changes nothing (no fetch, no gate worktree, no merge,
# no push).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

WORKDIR="" BRANCH="" COMMIT="" REMOTE=origin MAIN=main GATE="" FF_ONLY=1 DRY=0
GATE_WT="" TOP=""

# Print the leading comment block only: a hard-coded line range leaks code when the header grows.
usage() { awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit "${1:-2}"; }

first_line() { printf '%s\n' "$1" | head -1 | cut -c1-200 | sed 's/[[:space:]]*$//'; }

# The most specific line of a gate/merge log: a conflict or a fatal beats "Auto-merging x".
last_reason() {
  local line
  line=$(grep -E 'CONFLICT|fatal:|error:' "$1" 2>/dev/null | tail -1 | cut -c1-160 | sed 's/[[:space:]]*$//')
  [ -n "$line" ] || line=$(tail -1 "$1" 2>/dev/null | cut -c1-160 | sed 's/[[:space:]]*$//')
  printf '%s' "$line"
}

# Stop at the first refusal: nothing has been merged yet, so there is nothing to undo.
refuse() {  # refuse <row> <reason>
  bad "$1" "$2"
  say ""
  say "LAND: REFUSED — $2"
  exit 1
}

# The gate runs in its own detached worktree so it measures the node's tree, not main's.
cleanup() {
  [ -n "${GATE_WT:-}" ] || return 0
  git -C "${TOP:-.}" worktree remove --force "$GATE_WT" >/dev/null 2>&1 || true
  rm -rf "$GATE_WT" "$(dirname "$GATE_WT")"
  GATE_WT=""
}
trap cleanup EXIT

# --- gate: measure the node's tree, not main's --------------------------------------------
# Every path that reports success runs this, including the already-landed path: being an
# ancestor of <remote>/<main> proves ancestry, not that the node's own tree is green.
run_gate() {
  [ -n "$GATE" ] || return 0
  if [ "$DRY" -eq 1 ]; then
    note "dry-run: would run gate '$GATE' in a detached worktree at ${commit_sha:0:12}"
    return 0
  fi
  local wtbase gate_wt gate_rc gate_last
  wtbase=$(mktemp -d)
  gate_wt="$wtbase/gate"
  if ! git -C "$TOP" worktree add --quiet --detach "$gate_wt" "$commit_sha" >/dev/null 2>&1; then
    rm -rf "$wtbase"
    refuse gate "cannot create a detached worktree at $commit_sha in $TOP to run '$GATE'"
  fi
  GATE_WT="$gate_wt"
  ( cd "$gate_wt" && bash -c "$GATE" ) >"$wtbase/gate.log" 2>&1
  gate_rc=$?
  if [ "$gate_rc" -eq 0 ]; then
    ok gate "'$GATE' exited 0 at ${commit_sha:0:12} (detached worktree)"
    cleanup
  else
    gate_last=$(last_reason "$wtbase/gate.log")
    tail -5 "$wtbase/gate.log" 2>/dev/null | sed 's/^/  ..    /'
    refuse gate "'$GATE' exited $gate_rc at ${commit_sha:0:12} — ${gate_last:-no output}"
  fi
  return 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --workdir) [ $# -ge 2 ] || { say "refusing: --workdir needs a value"; exit 2; }; WORKDIR="$2"; shift 2 ;;
    --branch)  [ $# -ge 2 ] || { say "refusing: --branch needs a value"; exit 2; }; BRANCH="$2"; shift 2 ;;
    --commit)  [ $# -ge 2 ] || { say "refusing: --commit needs a value"; exit 2; }; COMMIT="$2"; shift 2 ;;
    --remote)  [ $# -ge 2 ] || { say "refusing: --remote needs a value"; exit 2; }; REMOTE="$2"; shift 2 ;;
    --main)    [ $# -ge 2 ] || { say "refusing: --main needs a value"; exit 2; }; MAIN="$2"; shift 2 ;;
    --gate-cmd) [ $# -ge 2 ] || { say "refusing: --gate-cmd needs a value"; exit 2; }; GATE="$2"; shift 2 ;;
    --ff-only) FF_ONLY=1; shift ;;
    --no-ff)   FF_ONLY=0; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage 0 ;;
    *) say "unknown argument: $1"; usage 2 ;;
  esac
done

[ -n "$WORKDIR" ] && [ -n "$BRANCH" ] && [ -n "$COMMIT" ] \
  || { say "usage: $0 --workdir DIR --branch BRANCH --commit SHA [--remote R] [--main M] [--gate-cmd CMD] [--no-ff] [--dry-run]"; exit 2; }

say "land-node-branch — workdir=$WORKDIR branch=$BRANCH commit=$COMMIT $REMOTE/$MAIN"

# --- preconditions ------------------------------------------------------------------------
if ! TOP=$(git -C "$WORKDIR" rev-parse --show-toplevel 2>/dev/null); then
  refuse workdir "not a git worktree: $WORKDIR"
fi

porcelain=$(git -C "$TOP" status --porcelain 2>/dev/null) \
  || refuse workdir_clean "git status failed in $TOP"
if [ -n "$porcelain" ]; then
  n=$(printf '%s\n' "$porcelain" | wc -l | tr -d ' ')
  refuse workdir_clean "$n uncommitted path(s) in $TOP (first: $(printf '%s\n' "$porcelain" | head -1)) — commit or stash them first"
fi
ok workdir_clean "clean worktree at $TOP"

cur=$(git -C "$TOP" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
[ -n "$cur" ] || refuse on_main "detached HEAD in $TOP — check out $MAIN before landing"
[ "$cur" = "$MAIN" ] \
  || refuse on_main "workdir is on '$cur', not '$MAIN' — a landing merges into $MAIN"
ok on_main "$MAIN is checked out in $TOP"

MAIN_REF="refs/remotes/$REMOTE/$MAIN"
BRANCH_REF="refs/remotes/$REMOTE/$BRANCH"
if [ "$DRY" -eq 1 ]; then
  note "dry-run: no fetch — every verdict below uses the refs as they stand now"
else
  if ! err=$(git -C "$TOP" fetch --quiet "$REMOTE" "+refs/heads/$MAIN:$MAIN_REF" 2>&1); then
    refuse fetch "git fetch $REMOTE $MAIN failed — $(first_line "$err")"
  fi
  ok fetch "$MAIN_REF refreshed from $REMOTE"
  # The node pushes its own branch; without this the envelope's commit can be present on the
  # remote and still be judged unreachable from a stale tracking ref.
  if err=$(git -C "$TOP" fetch --quiet "$REMOTE" "+refs/heads/$BRANCH:$BRANCH_REF" 2>&1); then
    ok fetch_branch "$BRANCH_REF refreshed from $REMOTE"
  else
    note "no refs/heads/$BRANCH on $REMOTE — falling back to a local branch"
  fi
fi

main_sha=$(git -C "$TOP" rev-parse --verify --quiet "$MAIN_REF^{commit}" 2>/dev/null || true)
[ -n "$main_sha" ] || refuse main_tip "cannot resolve $MAIN_REF in $TOP"

if ! commit_sha=$(git -C "$TOP" rev-parse --verify --quiet "$COMMIT^{commit}" 2>/dev/null); then
  refuse commit "$COMMIT is not a commit in $TOP — fetch the node branch before landing it"
fi
ok commit "resolved $COMMIT to $commit_sha"

# The node pushes its branch; a control-host branch of the same name is the fallback.
branch_ref="" branch_sha=""
for cand in "$BRANCH_REF" "refs/heads/$BRANCH"; do
  if cand_sha=$(git -C "$TOP" rev-parse --verify --quiet "$cand^{commit}" 2>/dev/null); then
    branch_ref="$cand"; branch_sha="$cand_sha"; break
  fi
done
[ -n "$branch_ref" ] || refuse branch "no branch $BRANCH in $TOP or on $REMOTE"
ok branch "$branch_ref at ${branch_sha:0:12}"

if git -C "$TOP" merge-base --is-ancestor "$commit_sha" "$branch_sha"; then
  ok commit_on_branch "$commit_sha is reachable from $branch_ref (tip ${branch_sha:0:12})"
else
  refuse commit_on_branch "$commit_sha is not reachable from $branch_ref (tip ${branch_sha:0:12})"
fi

# Idempotence: the same command twice must change nothing and exit 0 — and the gate still runs,
# because "already in <remote>/<main>" is a claim about ancestry, not about the node's tree.
if git -C "$TOP" merge-base --is-ancestor "$commit_sha" "$MAIN_REF"; then
  ok landed "$commit_sha is an ancestor of $REMOTE/$MAIN (${main_sha:0:12}) — already landed"
  say ""
  if [ "$DRY" -eq 1 ]; then
    [ -n "$GATE" ] && note gate "dry-run: not run — a gate worktree would be created at ${commit_sha:0:12}"
    say "LAND: DRY-RUN — nothing to do, $commit_sha is already in $REMOTE/$MAIN"
  else
    run_gate
    say "LANDED (already): $BRANCH @ $commit_sha in $REMOTE/$MAIN"
  fi
  exit 0
fi

if git -C "$TOP" merge-base --is-ancestor "$main_sha" "$branch_sha"; then
  ok descendant "$branch_ref is a descendant of $REMOTE/$MAIN (${main_sha:0:12})"
else
  behind=$(git -C "$TOP" rev-list --count "$branch_sha..$main_sha" 2>/dev/null || printf '?')
  refuse descendant "$branch_ref ${branch_sha:0:12} is not a descendant of $REMOTE/$MAIN ${main_sha:0:12} — $behind commit(s) on $REMOTE/$MAIN are not in the branch; rebase the branch onto $REMOTE/$MAIN"
fi

# --- gate: measure the node's tree, not main's --------------------------------------------
run_gate

head_sha=$(git -C "$TOP" rev-parse --verify HEAD)
if [ "$FF_ONLY" -eq 1 ] && ! git -C "$TOP" merge-base --is-ancestor "$head_sha" "$commit_sha"; then
  ahead=$(git -C "$TOP" rev-list --count "$commit_sha..$head_sha" 2>/dev/null || printf '?')
  refuse ff_only "$MAIN at ${head_sha:0:12} is not an ancestor of $commit_sha ($ahead local commit(s) on $MAIN are not in the branch) — not fast-forwardable; push or reset $MAIN, or pass --no-ff"
fi

# --no-ff exists to record a merge, not to widen what is published: the merge commit's first
# parent is this local tip, so every commit that sits on the control clone's $MAIN but not on
# $REMOTE/$MAIN rides into remote history on the push below. `--ff-only` refuses that case; this
# is the same refusal for the other door, taken before anything is merged or pushed.
if [ "$FF_ONLY" -eq 0 ] && [ "$head_sha" != "$main_sha" ]; then
  strays=$(git -C "$TOP" rev-list "$main_sha..$head_sha" 2>/dev/null || true)
  n=0
  [ -n "$strays" ] && n=$(printf '%s\n' "$strays" | wc -l | tr -d ' ')
  if [ "$n" -eq 0 ]; then
    refuse no_ff_local "$MAIN at ${head_sha:0:12} has not caught up with $REMOTE/$MAIN ${main_sha:0:12} — 0 local commit(s) on $MAIN are missing from $REMOTE/$MAIN, but a --no-ff merge would start from a stale $MAIN and the push could not fast-forward the remote; fast-forward or reset $MAIN onto $REMOTE/$MAIN first"
  fi
  shorts=$(printf '%s\n' "$strays" | awk 'NR<=5 {printf "%s%s", sep, substr($0,1,12); sep=", "}')
  more=""; [ "$n" -gt 5 ] && more=" (+$((n-5)) more)"
  refuse no_ff_local "$MAIN at ${head_sha:0:12} is ahead of $REMOTE/$MAIN ${main_sha:0:12} — $n local commit(s) on $MAIN are not on $REMOTE/$MAIN (${shorts}${more}) and a --no-ff merge would publish them on its push; push or reset $MAIN, or land those commits first"
fi

if [ "$DRY" -eq 1 ]; then
  say ""
  say "dry-run: would run:"
  if [ "$FF_ONLY" -eq 1 ]; then
    say "  git -C $TOP merge --ff-only $commit_sha"
    say "  git -C $TOP push $REMOTE $commit_sha:refs/heads/$MAIN   # an explicit object, never HEAD"
  else
    say "  git -C $TOP merge --no-ff -m 'merge: land $BRANCH at ${commit_sha:0:12} — the result envelope named this commit' $commit_sha"
    say "  merge_sha=\$(git -C $TOP rev-parse --verify HEAD)   # the merge commit --no-ff just created"
    say "  git -C $TOP push $REMOTE \$merge_sha:refs/heads/$MAIN   # an explicit object, never HEAD"
  fi
  say "  git -C $TOP fetch $REMOTE +refs/heads/$MAIN:$MAIN_REF"
  say "  git -C $TOP merge-base --is-ancestor $commit_sha $MAIN_REF"
  say ""
  say "LAND: DRY-RUN — 0 commands run, nothing merged or pushed, no ref moved"
  exit 0
fi

# --- merge ---------------------------------------------------------------------------------
mergelog=$(mktemp)
if [ "$FF_ONLY" -eq 1 ]; then
  if git -C "$TOP" merge --ff-only "$commit_sha" >"$mergelog" 2>&1; then
    ok merge "fast-forwarded $MAIN to $(git -C "$TOP" rev-parse --short HEAD)"
  else
    git -C "$TOP" merge --abort >/dev/null 2>&1 || true
    refuse merge "git merge --ff-only $commit_sha failed — $(last_reason "$mergelog")"
  fi
else
  if git -C "$TOP" merge --no-ff -m "merge: land $BRANCH at ${commit_sha:0:12} — the result envelope named this commit" "$commit_sha" >"$mergelog" 2>&1; then
    ok merge "merge commit $(git -C "$TOP" rev-parse --short HEAD) records $BRANCH"
  else
    git -C "$TOP" merge --abort >/dev/null 2>&1 || true
    refuse merge "git merge --no-ff $commit_sha failed — $(last_reason "$mergelog")"
  fi
fi
rm -f "$mergelog"

# The object this run publishes. It is read back from the merge that just ran here, so the push
# below names it explicitly instead of trusting whatever HEAD happens to be when the push starts.
merge_sha=$(git -C "$TOP" rev-parse --verify HEAD 2>/dev/null || true)
[ -n "$merge_sha" ] || refuse merge "cannot resolve HEAD in $TOP after the merge — nothing was pushed"
if [ "$FF_ONLY" -eq 1 ] && [ "$merge_sha" != "$commit_sha" ]; then
  refuse merge "the fast-forward left $MAIN at ${merge_sha:0:12}, not the envelope's $commit_sha — refusing to push a commit this run did not validate"
fi

# --- push ----------------------------------------------------------------------------------
# `<sha>:refs/heads/<main>` — never `HEAD`: a refspec of HEAD publishes whatever the checkout
# points at, which is how a --no-ff landing used to carry local-only commits to the remote.
if ! push_out=$(git -C "$TOP" push --quiet "$REMOTE" "$merge_sha:refs/heads/$MAIN" 2>&1); then
  bad push "git push $REMOTE $merge_sha:refs/heads/$MAIN failed — $(first_line "$push_out"); local $MAIN is now ${merge_sha:0:12} and $REMOTE/$MAIN was not updated"
  say ""
  say "LAND: FAIL ($FAILED) — merged locally, NOT landed"
  exit 1
fi
ok push "$REMOTE refs/heads/$MAIN accepted $merge_sha (this run's merge tip)"

# --- prove it ------------------------------------------------------------------------------
# The push is a claim; the ancestry test against the re-fetched remote is the evidence.
if ! err=$(git -C "$TOP" fetch --quiet "$REMOTE" "+refs/heads/$MAIN:$MAIN_REF" 2>&1); then
  note "post-push fetch failed: $(first_line "$err") — verifying against the tracking ref as it stands"
fi
remote_tip=$(git -C "$TOP" rev-parse --verify --quiet "$MAIN_REF^{commit}" 2>/dev/null || true)
if git -C "$TOP" merge-base --is-ancestor "$commit_sha" "$MAIN_REF"; then
  ok landed "$commit_sha is an ancestor of $REMOTE/$MAIN (${remote_tip:0:12})"
else
  bad landed "$commit_sha is NOT an ancestor of $REMOTE/$MAIN (${remote_tip:0:12}) — the push did not land this commit"
fi
wire=$(git -C "$TOP" ls-remote --heads "$REMOTE" "refs/heads/$MAIN" 2>/dev/null | awk '{print $1; exit}')
if [ -n "$wire" ] && [ "$wire" != "$remote_tip" ]; then
  warn landed_remote "$REMOTE reports ${wire:0:12}, the tracking ref is ${remote_tip:0:12} — the branch moved during this run"
fi

say ""
if [ "$FAILED" -eq 0 ]; then
  say "LANDED: $BRANCH @ $commit_sha in $REMOTE/$MAIN (pushed $merge_sha, tip ${remote_tip:-unresolved})"
  exit 0
fi
say "LAND: FAIL ($FAILED)"
exit 1
