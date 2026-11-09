#!/usr/bin/env bash
# node-create-staged-set.sh — CF-087: the staged-set validator's bounded behavioural probe.
#
#   bash tests/node-create-staged-set.sh <spellings|members|derive|all>
#
# The validator in scripts/node-create.sh answers one question: does the staging manifest carry
# every file the runtime will reach for? It used to answer it from a single spelling of one
# variable in two files ("\$HERE/"), so `${HERE}/x` passed and a reference in lib.sh was never
# read at all. This probe mutates a PRIVATE COPY of scripts/ in a fresh temporary directory and
# runs THE COPY's node-create.sh --staged-files. It never writes to the working tree, never needs
# the network and never installs anything: it measures the verdict, not a node.
#
#   spellings  the same unstaged reference in four spellings, in the entry point
#   members    one arm per staged member (lib.sh and two others), so no member is silently skipped
#   derive     the printed set is the derived closure: a needed member dropped from the declared
#              list, or a declared member nothing references, is a named staged_set row, and every
#              reference a printed member holds resolves back into the printed set
#   all        every arm; prints STAGED_SET: PASS only when each one passed
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
ARM="${1:-all}"
failures=0

work="$(mktemp -d "${TMPDIR:-/tmp}/cf087-staged-set.XXXXXX")" || {
  printf 'cannot create a scratch directory\n' >&2
  exit 2
}
# Only ever remove the directory this run created.
trap 'case "$work" in /*cf087-staged-set.*) rm -rf "$work" ;; esac' EXIT

pass_arm() { printf '  PASS  %s\n' "$*"; }
fail_arm() {
  printf '  FAIL  %s\n' "$*"
  failures=$((failures+1))
}

# new_copy <name> — a private copy of scripts/ the arm is allowed to break.
new_copy() {
  local d
  d="$(mktemp -d "$work/$1.XXXXXX")" || return 1
  cp -R "$HERE/scripts" "$d/scripts" || return 1
  printf '%s\n' "$d"
}

# run_manifest <copy> — sets $out (stdout+stderr) and $rc from that copy's --staged-files.
run_manifest() {
  out="$(bash "$1/scripts/node-create.sh" --staged-files 2>&1)"
  rc=$?
}

# expect_unstaged <label> <member> <line to append to the member>
# The mutated copy must exit nonzero AND print the named row, not just any failure.
expect_unstaged() {
  local label="$1" member="$2" line="$3" d
  d="$(new_copy "spell-$label")" || { fail_arm "$label $member — cannot copy scripts/"; return; }
  printf '%s\n' "$line" >> "$d/scripts/$member"
  run_manifest "$d"
  if [ "$rc" -ne 0 ] \
    && printf '%s\n' "$out" | grep -Eq '^  FAIL  staged_set — .*references unstaged unstaged\.py$'; then
    pass_arm "$label $member — staged_set names unstaged.py (exit $rc)"
  else
    fail_arm "$label $member — exit $rc, no staged_set row naming unstaged.py"
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
}

arm_spellings() {
  # Same defect, four spellings: braced, bare (unquoted), and inside each quote style. The
  # reference is a single missing file, so only the matcher can explain a green run.
  expect_unstaged braced          project-node.sh 'X="${HERE}/unstaged.py"'
  expect_unstaged bare            project-node.sh 'echo $HERE/unstaged.py >/dev/null'
  expect_unstaged quoted-double   project-node.sh 'X="$HERE/unstaged.py"'
  expect_unstaged quoted-single   project-node.sh "X='\$HERE/unstaged.py'"
}

arm_members() {
  # Every staged member is a source of references. lib.sh is sourced first by the entry point, a
  # .py member is not shell at all, and install-node.sh runs only on layer 10 — all three can
  # hold a reference the runtime follows, so none of them may be skipped.
  expect_unstaged member-lib-sh        lib.sh         'X="$HERE/unstaged.py"'
  expect_unstaged member-disk-floor-py disk_floor.py 'X="$HERE/unstaged.py"'
  expect_unstaged member-install-node  install-node.sh 'X="$HERE/unstaged.py"'
}

# derive_omit — drop a needed member from the DECLARED list only: the file is on disk and the
# entry point still references it, so the set the validator derives cannot lose it.
derive_omit() {
  local d
  d="$(new_copy derive-omit)" || { fail_arm "derive-omit — cannot copy scripts/"; return; }
  if ! grep -q 'lib.sh disk_floor.py' "$d/scripts/node-create.sh"; then
    fail_arm "derive-omit — cannot derive the mutation: the declared list no longer reads 'lib.sh disk_floor.py'"
    return
  fi
  sed 's/lib.sh disk_floor.py/lib.sh/' "$d/scripts/node-create.sh" > "$d/scripts/node-create.pre"
  mv "$d/scripts/node-create.pre" "$d/scripts/node-create.sh"
  run_manifest "$d"
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -Eq '^  FAIL  staged_set — .*disk_floor\.py'; then
    pass_arm "derive-omit disk_floor.py — staged_set row names disk_floor.py (exit $rc)"
  else
    fail_arm "derive-omit disk_floor.py — exit $rc, the declared set no longer equals the derived closure and nothing said so"
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
}

# derive_stray — the other direction: a declared member that no staged member references must not
# ride along in the manifest (a list nobody checks drifts in both directions).
derive_stray() {
  local d
  d="$(new_copy derive-stray)" || { fail_arm "derive-stray — cannot copy scripts/"; return; }
  if ! grep -q 'gomodcache.py deploy_key.py' "$d/scripts/node-create.sh"; then
    fail_arm "derive-stray — cannot derive the mutation: the declared list no longer reads 'gomodcache.py deploy_key.py'"
    return
  fi
  sed 's/gomodcache.py deploy_key.py/gomodcache.py deploy_key.py verify-patch.sh/' \
    "$d/scripts/node-create.sh" > "$d/scripts/node-create.pre"
  mv "$d/scripts/node-create.pre" "$d/scripts/node-create.sh"
  run_manifest "$d"
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -Eq '^  FAIL  staged_set — .*carries verify-patch\.sh'; then
    pass_arm "derive-stray verify-patch.sh — staged_set row names the unreferenced member (exit $rc)"
  else
    fail_arm "derive-stray verify-patch.sh — exit $rc, an unreferenced member rode along in the manifest"
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
}

# derive_closed — the printed set equals the set the validator derived: every HERE reference held
# by a printed member must resolve, through the filesystem, into the printed set. This is an
# independent oracle (cd/pwd, not the validator's own string walk), so a set that stops following
# a transitive reference shows up here even when every other arm is green.
derive_closed() {
  local d member ref cand dir target manifest missing=""
  d="$(new_copy derive-closed)" || { fail_arm "derive-closed — cannot copy scripts/"; return; }
  run_manifest "$d"
  if [ "$rc" -ne 0 ]; then
    fail_arm "derive-closed — this tree's own manifest exited $rc"
    printf '%s\n' "$out" | sed 's/^/    | /'
    return
  fi
  manifest="$out"
  while IFS= read -r member; do
    [ -n "$member" ] || continue
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      ref="${ref#\$HERE/}"
      ref="${ref#\$\{HERE\}/}"
      ref="${ref//\$\{HARNESS\}/hermes}"
      ref="${ref//\$HARNESS/hermes}"
      case "$ref" in *'$'*) continue ;; esac
      if [ "$(dirname "$member")" = . ]; then cand="$ref"; else cand="$(dirname "$member")/$ref"; fi
      dir="$(cd "$d/scripts/$(dirname "$cand")" 2>/dev/null && pwd)" || continue
      case "$dir" in
        "$d/scripts") target="$(basename "$cand")" ;;
        "$d/scripts"/*) target="${dir#"$d/scripts"/}/$(basename "$cand")" ;;
        *) continue ;;
      esac
      [ -f "$d/scripts/$target" ] || continue
      printf '%s\n' "$manifest" | grep -Fxq "$target" || missing="$missing $target"
    done < <(grep -oE '(\$HERE|\$\{HERE\})/[A-Za-z0-9_./${}-]+' "$d/scripts/$member")
  done <<< "$manifest"
  if [ -z "$missing" ]; then
    pass_arm "derive-closed — staged_set prints exactly the derived closure"
  else
    fail_arm "derive-closed — the printed set is not closed under its own references:$missing"
  fi
}

arm_derive() {
  derive_omit
  derive_stray
  derive_closed
}

case "$ARM" in
  spellings) arm_spellings ;;
  members) arm_members ;;
  derive) arm_derive ;;
  all) arm_spellings; arm_members; arm_derive ;;
  *) printf 'usage: %s <spellings|members|derive|all>\n' "$0" >&2; exit 2 ;;
esac

if [ "$ARM" = all ]; then
  if [ "$failures" -eq 0 ]; then
    printf 'STAGED_SET: PASS\n'
    exit 0
  fi
  printf 'STAGED_SET: FAIL (%s)\n' "$failures"
  exit 1
fi
[ "$failures" -eq 0 ] || exit 1
exit 0
