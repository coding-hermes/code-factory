#!/usr/bin/env bash
# CF-094 probe — does the Tier-1 lint arm skip silently when no linter is on PATH?
#
# Both arms stage the SAME file, which `ruff format --check .` rejects.
#   arm 1: PATH contains ruff  -> the lint arm must FAIL
#   arm 2: PATH has no ruff    -> the lint arm reports "unknown" and the guard PASSES
#
# Run from the repository root of a checkout that has .gitreins/ installed.
# Regenerate this transcript with: bash docs/audits/cf094-lint-skip-arms.sh

set -u
REPO=${1:-.}
cd "$REPO" || { echo "FATAL: cannot cd $REPO"; exit 2; }
GUARD=${GITREINS_BIN:-$HOME/.local/bin/gitreins}
TMP=$(mktemp -d)
FIXTURE=scripts/qa_cf094_ruff_violation.py

cleanup() { rm -f "$FIXTURE"; rm -rf "$TMP"; }
trap cleanup EXIT

echo "# CF-094 probe transcript — regenerate with: bash docs/audits/cf094-lint-skip-arms.sh"
echo "# tree: $(git rev-parse HEAD)"
echo "# host: $(uname -srm)"
echo "# gitreins: $($GUARD --version 2>&1 | head -1)"
echo "# fixture: $FIXTURE — a Python file ruff format rejects (spaced args, dict padding, extra blanks)"
echo

cat > "$FIXTURE" <<'PY'
"""Fixture: deliberately unformatted, so `ruff format --check .` fails while it is present."""


def badly_formatted( x,y ):
    result = {  "a":x,"b":y }

    return   result
PY

# A third state matters: is the fixture actually a violation? Measure it directly.
fmt_out=$(ruff format --check "$FIXTURE" 2>&1); fmt_rc=$?
echo "## control — the fixture really is a violation"
echo "\$ ruff format --check $FIXTURE"
echo "$fmt_out"
echo "EXIT: $fmt_rc"
echo

git add "$FIXTURE" 2>/dev/null
echo "## arm 1 — ruff present on PATH"
echo "\$ gitreins guard --full --json     # with \$(command -v ruff) on PATH"
env "PATH=$PATH" "$GUARD" guard --full --json > "$TMP/arm1.json" 2>&1
echo "GUARD_EXIT: $?"
jq -r '.checks[] | select(.id=="lint") | "lint.outcome: \(.outcome)", "lint.passed: \(.passed)", "lint.summary: \(.summary)"' "$TMP/arm1.json" 2>&1
jq -r '"guard.passed: \(.passed)", "guard.outcome: \(.outcome)"' "$TMP/arm1.json" 2>&1
echo

git reset -q 2>/dev/null; git add "$FIXTURE" 2>/dev/null
echo "## arm 2 — same staged fixture, PATH without ruff"
echo "\$ PATH=/usr/local/bin:/usr/bin:/bin gitreins guard --full --json"
env PATH=/usr/local/bin:/usr/bin:/bin "$GUARD" guard --full --json > "$TMP/arm2.json" 2>&1
echo "GUARD_EXIT: $?"
jq -r '.checks[] | select(.id=="lint") | "lint.outcome: \(.outcome)", "lint.passed: \(.passed)", "lint.summary: \(.summary)"' "$TMP/arm2.json" 2>&1
jq -r '"guard.passed: \(.passed)", "guard.outcome: \(.outcome)"' "$TMP/arm2.json" 2>&1
echo
echo "## config declares allow_skips (read from the tree under test)"
grep -n 'allow_skips' .gitreins/config.yaml 2>&1
echo
echo "# read: arm 1 fails the lint check with a named reformat instruction, so the arm CAN fail."
echo "# arm 2 reports lint outcome 'unknown' ('skipped — no linter on PATH') and the guard still"
echo "# returns PASS with the same violating file staged, so on any host without ruff the"
echo "# tree-wide lint arm degrades to a silent skip (CF-094)."
