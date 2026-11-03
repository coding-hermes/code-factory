#!/usr/bin/env bash
# Regenerate docs/audits/cf092-install-check-arms.txt (CF-092).
# Runs the README Status row 1 command in two arms and records what each one prints.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd) || exit 2
cd "$ROOT" || exit 2

TREE=$(git rev-parse HEAD)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
PY_SHELL=$(python3 -V 2>&1)
PY_ARM=$(env -i PATH=/usr/local/bin:/usr/bin:/bin python3 -V 2>&1)
PATH_ARM=/usr/local/bin:/usr/bin:/bin
OUT=${1:-docs/audits/cf092-install-check-arms.txt}
HOME1=$(mktemp -d)

gate_rows() { printf '%s\n' "$1" | grep -E '^  (PASS|FAIL|WARN) '; }

run_arm() {
  # $1 = label, $2 = 0|1 (set HERMES_PYTHON_BIN)
  local label=$1 use_bin=$2 cmd out rc rows
  if [ "$use_bin" = "1" ]; then
    cmd="env -i HOME=\"\$home\" PATH=$PATH_ARM HERMES_PYTHON_BIN=python3.12 bash scripts/harness/install-hermes.sh --check"
    out=$(env -i HOME="$HOME1" PATH=$PATH_ARM HERMES_PYTHON_BIN=python3.12 bash scripts/harness/install-hermes.sh --check 2>&1)
    rc=$?
  else
    cmd="env -i HOME=\"\$home\" PATH=$PATH_ARM bash scripts/harness/install-hermes.sh --check"
    out=$(env -i HOME="$HOME1" PATH=$PATH_ARM bash scripts/harness/install-hermes.sh --check 2>&1)
    rc=$?
  fi
  rows=$(gate_rows "$out")
  {
    echo "## $label"
    echo "\$ $cmd"
    printf '%s\n' "$out"
    echo "EXIT: $rc"
    echo "gate rows printed: $(printf '%s\n' "$rows" | grep -c .)"
    echo "gate rows naming binary: $(printf '%s\n' "$rows" | grep -c 'binary')"
    echo "gate rows naming port: $(printf '%s\n' "$rows" | grep -c ' port')"
    echo
  } >> "$OUT.part"
}

: > "$OUT.part"
{
  echo "# CF-092 probe transcript — regenerate with: bash docs/audits/cf092-arms.sh"
  echo "# tree: $TREE (branch $BRANCH)"
  echo "# host: $(uname -sr) $(uname -m)"
  echo "# python3 as the authoring shell sees it: ${PY_SHELL#Python }"
  echo "# python3 as the graded arms see it (PATH=$PATH_ARM): ${PY_ARM#Python }"
  echo "# command under test: README Status row 1 re-run cell, scripts/harness/install-hermes.sh --check"
  echo
} >> "$OUT.part"

run_arm "arm 1 — the host's default python3 (outside the pin's range)" 0
run_arm "arm 2 — an interpreter inside the pin's range (HERMES_PYTHON_BIN=python3.12)" 1
{
  echo "# read: arm 1 prints ONE gate row (python) and never reaches the binary or port arms."
  echo "# arm 2 prints FOUR gate rows, including binary and port. The README row 1 re-run cell"
  echo "# names the qualified form and states the precondition; the state cell no longer claims"
  echo "# binary/port gates for the unqualified command (CF-092)."
} >> "$OUT.part"

mv "$OUT.part" "$OUT"
echo "wrote $OUT"
