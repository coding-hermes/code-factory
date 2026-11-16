#!/usr/bin/env bash
# cf450-ci-attribution.sh — name the selftest item that failed in a red run.
#
# Why this exists (CF-450): a selftest log contains many `  FAIL  ` rows even
# when the run is green — they are negative-control fixtures proving a gate CAN
# fail. So grepping for `FAIL` finds fixtures, and grepping for `^[0-9]+\. `
# finds nothing, because every Actions log line is
#     <job>\t<step>\t<ISO-8601 timestamp> <message>
# i.e. the item header never starts the line. This tool compares a red run with
# a green baseline run by *label*, and reports the labels whose verdict differs.
# A difference is the failing item; no difference means the run genuinely cannot
# be attributed from its own log (exit 2), which is a real finding, not a bug.
#
# Usage: cf450-ci-attribution.sh <red-run-id> <green-run-id> [owner/repo]
# Exit:  0 attributed, 1 usage/gh error, 2 no divergence found.

set -uo pipefail

red="${1:-}"; green="${2:-}"; repo="${3:-coding-hermes/code-factory}"
if [[ -z "$red" || -z "$green" ]]; then
  printf 'usage: %s <red-run-id> <green-run-id> [owner/repo]\n' "$0" >&2
  exit 1
fi

tmp="${TMPDIR:-/tmp}/cf450-attrib"
mkdir -p "$tmp"

fetch() { # $1=run id -> path of stripped log
  local run="$1"
  local raw="$tmp/raw-$run.log"
  local out="$tmp/msg-$run.log"
  if [[ ! -s "$raw" ]]; then
    gh run view "$run" --repo "$repo" --log > "$raw" 2>"$tmp/err-$run.log" || {
      printf 'gh could not read run %s: %s\n' "$run" "$(head -2 "$tmp/err-$run.log")" >&2
      return 1
    }
  fi
  # keep only the message field, timestamp stripped
  awk -F'\t' '{ m=$NF; sub(/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z[ ]?/, "", m); print m }' \
    "$raw" > "$out"
  printf '%s' "$out"
}

red_log="$(fetch "$red")" || exit 1
green_log="$(fetch "$green")" || exit 1

printf 'repo=%s\nred=%s\ngreen=%s\n' "$repo" "$red" "$green"
printf -- '--- job conclusions ---\n'
for run in "$red" "$green"; do
  printf 'run %s: ' "$run"
  gh run view "$run" --repo "$repo" --json jobs \
    -q '[.jobs[] | "\(.name)=\(.conclusion)"] | join(" ")' 2>/dev/null || printf 'unavailable'
  printf '\n'
done

# label -> verdict, per run (last row wins; labels are unique per item)
verdicts() { # $1=stripped log  $2=outfile
  awk '
    /^  (PASS|FAIL)  / {
      v = substr($0, 3, 4)                       # PASS | FAIL
      body = substr($0, 9)                       # label + measured tail
      i = index(body, "\342\200\224")             # em dash separating label
      lbl = (i ? substr(body, 1, i - 1) : body)
      sub(/[ \t]+$/, "", lbl)
      if (lbl != "") seen[lbl] = v
    }
    END { for (l in seen) printf "%s\t%s\n", l, seen[l] }' "$1" | LC_ALL=C sort > "$2"
}

verdicts "$red_log" "$tmp/v-red.tsv"
verdicts "$green_log" "$tmp/v-green.tsv"

printf -- '--- verdict rows: red=%s green=%s (unique labels) ---\n' \
  "$(wc -l < "$tmp/v-red.tsv")" "$(wc -l < "$tmp/v-green.tsv")"

# inner join on the label; report labels that are FAIL in red but PASS in green
LC_ALL=C join -t $'\t' -1 1 -2 1 "$tmp/v-red.tsv" "$tmp/v-green.tsv" > "$tmp/join.tsv"
awk -F'\t' '
  $2=="FAIL" && $3=="PASS" { print "ATTRIBUTED  " $1 "  (red=FAIL green=PASS)"; n++ }
  $2!=$3 && !($2=="FAIL" && $3=="PASS") { print "DIFFERS     " $1 "  (red=" $2 " green=" $3 ")" }
  END { exit (n>0 ? 0 : 2) }' "$tmp/join.tsv" > "$tmp/attribution.txt"
rc=$?
cat "$tmp/attribution.txt"

if [[ $rc -ne 0 ]]; then
  printf '\nNO DIVERGENCE: red and green agree on every shared label.\n'
  printf 'The failing item is not named by this pair; compare against the parent\n'
  printf 'commit'"'"'s run or inspect newer runs before filing attribution.\n'
  exit 2
fi

printf '\nATTRIBUTED: %s label(s) flipped FAIL in the red run.\n' \
  "$(grep -c '^ATTRIBUTED' "$tmp/attribution.txt")"
