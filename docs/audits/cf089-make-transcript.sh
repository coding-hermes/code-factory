#!/usr/bin/env bash
# Produce the CF-089 transcript: the README census recipe re-run verbatim against a
# stand-in scheduler whose page at offset=500 answers 502 while two matching rows
# exist across that page boundary. Re-runnable from the repo root:
#   bash docs/audits/cf089-census-standin.py &      # port 18999, binds fail loudly if taken
#   bash docs/audits/cf089-make-transcript.sh
set -uo pipefail
REPO=~/code-factory
OUT="$REPO/docs/audits/code-factory-qa-2026-11-03-cf089.probe.txt"
BASE=http://127.0.0.1:18999

{
  echo "# CF-089 probe — README census recipe vs a failed page"
  echo "# tree: $(git -C "$REPO" rev-parse --short HEAD) branch=$(git -C "$REPO" rev-parse --abbrev-ref HEAD)"
  echo "# date: $(date -Iseconds)"
  echo "# recipe: README.md 'The lanes' block, verbatim, \$BASE parameterised only"
  echo
  echo '$ bash tests/selftest.sh | tail -1'
  ( cd "$REPO" && bash tests/selftest.sh 2>&1 | tail -1 )
  echo
  echo '$ bash docs/audits/cf089-census-standin.py &   # total=866; page offset=0 -> 500 rows; page offset=500 -> 502'
  echo
  echo '$ curl -s "$BASE/api/v1/projects?limit=500&offset=0" | jq -r ".total as \$t | \"total=\(\$t) page0=\(.projects|length)\""'
  curl -s "$BASE/api/v1/projects?limit=500&offset=0" | jq -r '.total as $t | "total=\($t) page0=\(.projects|length)"'
  echo
  echo '$ curl -s -o /dev/null -w "http=%{http_code}\n" "$BASE/api/v1/projects?limit=500&offset=500"'
  curl -s -o /dev/null -w 'http=%{http_code}\n' "$BASE/api/v1/projects?limit=500&offset=500"
  echo
  echo '# ground truth: the stand-in holds exactly TWO code-factory rows, at index 0 and 600.'
  echo '# row 600 is reachable only through the page that answers 502.'
  echo
  echo '$ BASE=http://127.0.0.1:18999 bash docs/audits/cf089-census-recipe.sh   # README recipe, verbatim'
  BASE="$BASE" bash "$REPO/docs/audits/cf089-census-recipe.sh" 2>&1
  echo "RC=$?"
  echo
  echo '# => one row printed, RC=0: the census under-counts (2 -> 1) and reports success.'
  echo '#    The only signal is a jq stderr line, which changes neither the count nor the exit code.'
  echo
  echo '$ BASE=http://127.0.0.1:18999/nototal bash docs/audits/cf089-census-recipe.sh   # CF-065 control'
  BASE="$BASE/nototal" bash "$REPO/docs/audits/cf089-census-recipe.sh" 2>&1
  echo "RC=$?"
  echo
  echo '# => the no-total control CF-065 shipped does fail loudly. The per-page failure does not.'
} > "$OUT" 2>&1
echo "wrote $OUT"
cat "$OUT"
