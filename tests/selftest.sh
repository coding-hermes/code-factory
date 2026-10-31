#!/usr/bin/env bash
# selftest.sh — prove the checks in this repo can FAIL. A green that cannot go red is decoration.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
. "$HERE/scripts/lib.sh"
fails=0
t() { if eval "$2" >/dev/null 2>&1; then say "  PASS  $1"; else say "  FAIL  $1"; fails=$((fails+1)); fi; }

say "1. every script parses"
for f in "$HERE"/scripts/*.sh "$HERE"/scripts/harness/*.sh "$HERE"/tests/*.sh; do
  bash -n "$f" && say "  PASS  bash -n $(basename "$f")" || { say "  FAIL  bash -n $f"; fails=$((fails+1)); }
done

say "2. the node checker FAILS on an empty PATH"
out=$(env -i PATH=/nonexistent HOME="$HOME" NODE_PROJECT=t /bin/bash "$HERE/scripts/project-node.sh" --check 2>&1); rc=$?
[ "$rc" -ne 0 ] && say "  PASS  empty PATH -> exit $rc" || { say "  FAIL  empty PATH reported success"; fails=$((fails+1)); }
printf '%s' "$out" | grep -q 'FAIL' && say "  PASS  report contains FAIL rows" || { say "  FAIL  no FAIL rows"; fails=$((fails+1)); }

say "3. fetch_verified refuses a wrong digest"
tmpd=$(mktemp -d); echo hello > "$tmpd/src"
want=$(sha256sum "$tmpd/src" | cut -d' ' -f1)
fetch_verified "file://$tmpd/src" "$tmpd/out" "$want" && say "  PASS  correct digest accepted" || { say "  FAIL  correct digest refused"; fails=$((fails+1)); }
fetch_verified "file://$tmpd/src" "$tmpd/out2" "0000000000000000000000000000000000000000000000000000000000000000" \
  && { say "  FAIL  wrong digest accepted"; fails=$((fails+1)); } || say "  PASS  wrong digest refused"
rm -rf "$tmpd"

say "4. no literal credential assignments"
if grep -rnE '^[A-Z_]*(API_KEY|TOKEN|SECRET)=[^$"[:space:]]' "$HERE"/scripts "$HERE"/specs "$HERE"/docs 2>/dev/null | grep -v 'example' | head -3 | grep -q .; then
  say "  FAIL  a literal credential assignment is in the tree"; fails=$((fails+1))
else
  say "  PASS  none found"
fi

say "5. the board is valid JSONL"
b="$HERE/.coding-hermes/board/tasks.jsonl"
if [ -f "$b" ]; then
  n=$(wc -l < "$b"); good=0
  while IFS= read -r line; do printf '%s' "$line" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null && good=$((good+1)); done < "$b"
  [ "$good" = "$n" ] && say "  PASS  $good/$n rows parse" || { say "  FAIL  $good of $n rows parse"; fails=$((fails+1)); }
else
  say "  FAIL  board missing"; fails=$((fails+1))
fi

say "6. project board entrypoint is real and fails closed without dependency"
bash -n "$HERE/scripts/boardctl" && say "  PASS  bash -n scripts/boardctl" || { say "  FAIL  bash syntax"; fails=$((fails+1)); }
"$HERE/scripts/boardctl" --help >/dev/null 2>&1 && say "  PASS  local help" || { say "  FAIL  help"; fails=$((fails+1)); }
missing=$(env -i PATH=/usr/bin:/bin HOME="$HOME" /bin/bash "$HERE/scripts/boardctl" list 2>&1); rc=$?
if [ "$rc" -eq 127 ] && printf '%s' "$missing" | grep -q 'FAIL boardctl'; then
  say "  PASS  missing boardctl -> explicit FAIL, exit 127"
else
  say "  FAIL  missing dependency was not surfaced"; fails=$((fails+1))
fi

say "7. every prompt file the README relies on exists"
# The README's lane section names prompts/<name>.md files and the loaders copy them into the
# scheduler. A rename that misses one side leaves a lane loading a prompt that is not shipped.
prompt_refs_missing() {  # $1=README $2=repo root -> prints each absent prompt, returns 1 if any
  local readme="$1" root="$2" rc=0 p
  for p in $(grep -oE 'prompts/[a-z0-9-]+\.md' "$readme" | sort -u); do
    [ -f "$root/$p" ] || { echo "absent: $p"; rc=1; }
  done
  return $rc
}
if prompt_refs_missing "$HERE/README.md" "$HERE" >/dev/null; then
  say "  PASS  every prompts/*.md named by README.md exists"
else
  say "  FAIL  README names a prompt file that is not shipped: $(prompt_refs_missing "$HERE/README.md" "$HERE" | tr '\n' ' ')"
  fails=$((fails+1))
fi
# negative fixture: a README that names a prompt nobody ships must be refused
tmpd=$(mktemp -d)
sed 's#prompts/qa\.md#prompts/ghost-lane.md#' "$HERE/README.md" > "$tmpd/README.md"
if prompt_refs_missing "$tmpd/README.md" "$HERE" >/dev/null; then
  say "  FAIL  a README naming an absent prompt was accepted"; fails=$((fails+1))
else
  say "  PASS  absent prompt refused ($(prompt_refs_missing "$tmpd/README.md" "$HERE" | head -1))"
fi
rm -rf "$tmpd"

say "8. layer 40 remains a clone-only contract"
# Layer 40 is generic across arbitrary repositories. A build/cache claim needs a project-specific
# protocol and measured artifact, so the spec must name only the pinned clone until one exists.
layer_40_clone_only() {  # $1=NODE.md -> returns 0 only for the measured clone-only contract
  grep -qFx '| 40 repo | the repo cloned at a pinned ref | base |' "$1" && \
    ! grep -qE '^\| 40 repo \|.*build cache' "$1"
}
if layer_40_clone_only "$HERE/specs/NODE.md"; then
  say "  PASS  layer 40 names only the pinned repo clone"
else
  say "  FAIL  layer 40 claims an unmeasured build cache or differs from the clone contract"; fails=$((fails+1))
fi
# negative fixture: restore the old cache claim and prove the contract checker refuses it.
tmpd=$(mktemp -d)
sed 's#the repo cloned at a pinned ref | base#the repo cloned at a pinned ref, build cache present | base#' \
  "$HERE/specs/NODE.md" > "$tmpd/NODE.md"
if layer_40_clone_only "$tmpd/NODE.md"; then
  say "  FAIL  layer 40 build-cache claim was accepted"; fails=$((fails+1))
else
  say "  PASS  layer 40 build-cache claim refused"
fi
rm -rf "$tmpd"

say ""
[ "$fails" -eq 0 ] && { say "SELFTEST: PASS"; exit 0; } || { say "SELFTEST: FAIL ($fails)"; exit 1; }
