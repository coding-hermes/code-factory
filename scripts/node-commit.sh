#!/usr/bin/env bash
# node-commit.sh — node side: commit with the run it belongs to written into the commit itself.
#
#   ./node-commit.sh [--workdir DIR] (--message TEXT | --message-file FILE) \
#                    [--run-id <run_id>] [--dry-run] [-- <git commit args>]
#
# specs/TRACE.md:64 names the hop this script owns: "node → git | commit trailer
# `Run-Id: <run_id>`". Without it a commit that breaks main cannot be named back to the attempt
# that produced it, and §6 statement 4 (`git log --grep` finds the trailer) cannot pass. The
# trailer is written HERE, at commit time, by the side that knows the run: a control host that
# invents attribution at merge time attributes nothing.
#
# The run id is `--run-id VALUE` when given, else `$CF_RUN_ID` — the node variable the harness
# already exports (`specs/HARNESS-MATRIX.md:127`). It is admitted only as a bare identifier
# (`^[A-Za-z0-9][A-Za-z0-9._-]*$`, max 128 chars), the same rule `install-codex.sh` applies to
# CF_RUN_ID: the id is echoed into a message that becomes permanent git history, and a value
# carrying a newline or a separator could forge a second trailer line.
#
# Refuses, naming the measured value, before it commits anything:
#   - no run id at all: row `run_id` — a commit with no attribution is the defect, not the default
#   - a run id that fails the bare-identifier rule: row `run_id`, value truncated to 64 chars
#   - neither `--message` nor `--message-file`, both at once, an unreadable file, or a body that
#     is empty after trailing blank lines: row `message`
#   - a body that already carries a DIFFERENT `Run-Id:` line: row `run_trailer`, both values named
#     (two run ids on one commit makes the join ambiguous, which is worse than none)
# A body that already carries the SAME trailer is committed as-is: the trailer is never duplicated.
#
# The message is assembled in a temp file and passed with `git commit -F`, never through a shell
# string, so a subject containing quotes, backticks or `$` reaches git byte-exact. Every argument
# this script does not recognise is handed to `git commit` unchanged — stage the work yourself
# (`git add`), exactly as `git commit` requires. Passthrough pathspecs resolve relative to the
# worktree root, because the commit runs with `-C <worktree>`.
#
# After the commit, HEAD is re-read (never assumed) and the trailer is read back out of the commit
# itself: the `run_trailer` row reports what the commit carries, not what this script intended.
# --dry-run prints the exact command and the exact message and creates no commit.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

WORKDIR="." RUN_ID="" MSG_FILE="" MSG_TEXT="" MSG_SET=0 DRY=0
PASS_ARGS=()
FINAL="" BODY="" LOG=""

# Print the leading comment block only: a hard-coded line range leaks code when the header grows.
usage() { awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit "${1:-2}"; }

cleanup() { rm -f "${FINAL:-}" "${BODY:-}" "${LOG:-}"; }
trap cleanup EXIT

# Stop at the first refusal: nothing has been committed yet, so there is nothing to undo.
refuse() {  # refuse <row> <reason>
  bad "$1" "$2"
  say ""
  say "COMMIT: REFUSED — $2"
  exit 1
}

last_reason() {
  local line
  line=$(grep -E 'fatal:|error:|Aborting' "$1" 2>/dev/null | tail -1 | cut -c1-200 | sed 's/[[:space:]]*$//')
  [ -n "$line" ] || line=$(tail -1 "$1" 2>/dev/null | cut -c1-200 | sed 's/[[:space:]]*$//')
  printf '%s' "$line"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --workdir)      [ $# -ge 2 ] || { say "refusing: --workdir needs a value"; exit 2; }; WORKDIR="$2"; shift 2 ;;
    --run-id)       [ $# -ge 2 ] || { say "refusing: --run-id needs a value"; exit 2; }; RUN_ID="$2"; shift 2 ;;
    --message-file) [ $# -ge 2 ] || { say "refusing: --message-file needs a value"; exit 2; }; MSG_FILE="$2"; MSG_SET=$((MSG_SET+1)); shift 2 ;;
    --message)      [ $# -ge 2 ] || { say "refusing: --message needs a value"; exit 2; }; MSG_TEXT="$2"; MSG_SET=$((MSG_SET+1)); shift 2 ;;
    --dry-run)      DRY=1; shift ;;
    -h|--help)      usage 0 ;;
    --)             shift; while [ $# -gt 0 ]; do PASS_ARGS+=("$1"); shift; done ;;
    *)              PASS_ARGS+=("$1"); shift ;;
  esac
done

[ "$MSG_SET" -le 1 ] \
  || { say "refusing: --message and --message-file name the same body twice"; exit 2; }

# --- run id -------------------------------------------------------------------------------
# `--run-id` wins over the ambient `CF_RUN_ID`; absent from both is a refusal, never a silent
# untrailed commit — the whole point of the row is that an unattributed commit is not produced.
run_id="${RUN_ID:-${CF_RUN_ID:-}}"
if [ -z "$run_id" ]; then
  refuse run_id "the run id is required — specs/TRACE.md §3 requires the node → git hop to name it; pass --run-id <id> or set CF_RUN_ID"
fi
if [ "${#run_id}" -gt 128 ] || [[ ! "$run_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  refuse run_id "the run id must be a bare identifier (^[A-Za-z0-9][A-Za-z0-9._-]*\$, max 128 chars); got '$(printf '%.64s' "$run_id")' (${#run_id} chars)"
fi

# --- workdir ------------------------------------------------------------------------------
if ! TOP=$(git -C "$WORKDIR" rev-parse --show-toplevel 2>/dev/null); then
  refuse workdir "not a git worktree: $WORKDIR"
fi

# --- message body -------------------------------------------------------------------------
if [ "$MSG_SET" -eq 0 ]; then
  refuse message "a commit message body is required — pass --message TEXT or --message-file FILE (the trailer alone does not name what the commit does)"
fi
BODY=$(mktemp)
FINAL=$(mktemp)
if [ -n "$MSG_FILE" ]; then
  [ -r "$MSG_FILE" ] || refuse message "cannot read the message file: $MSG_FILE"
  cp "$MSG_FILE" "$BODY" || refuse message "cannot copy the message file: $MSG_FILE"
else
  printf '%s\n' "$MSG_TEXT" > "$BODY"
fi

# Trailing blank lines are dropped so the separator below is exactly one blank line; interior
# blank lines are preserved (a body with paragraphs stays a body with paragraphs).
awk '{ line[NR] = $0 }
     END { last = 0
           for (i = 1; i <= NR; i++) if (line[i] !~ /^[[:space:]]*$/) last = i
           for (i = 1; i <= last; i++) print line[i] }' "$BODY" > "$FINAL" \
  || refuse message "cannot assemble the commit message from $MSG_FILE"
[ -s "$FINAL" ] || refuse message "the commit message body is empty — the trailer alone does not name what the commit does"

# Last occurrence wins: a body that ends with a stale trailer is the case this guard exists for.
existing_line=$(grep -E '^Run-Id:' "$FINAL" | tail -1 || true)
if [ -n "$existing_line" ]; then
  existing_val=$(printf '%s' "$existing_line" | sed -E 's/^Run-Id:[[:space:]]*//; s/[[:space:]]+$//')
  if [ "$existing_val" = "$run_id" ]; then
    note "run_trailer" "the body already carries Run-Id: $run_id — not duplicated"
  else
    refuse run_trailer "the body already carries 'Run-Id: ${existing_val:-<empty>}' but this commit is attributed to '$run_id' — one commit cannot carry two run ids; drop the stale trailer or pass --run-id ${existing_val:-<empty>}"
  fi
else
  printf '\nRun-Id: %s\n' "$run_id" >> "$FINAL" || refuse message "cannot append the Run-Id trailer to $FINAL"
fi

# --- dry run ------------------------------------------------------------------------------
if [ "$DRY" -eq 1 ]; then
  say "dry-run: would run:"
  say "  git -C $TOP commit -F $FINAL${PASS_ARGS[*]:+ ${PASS_ARGS[*]}}"
  say "dry-run: the exact message it would write:"
  sed 's/^/  | /' "$FINAL"
  say ""
  say "COMMIT: DRY-RUN — no commit created, no ref moved, nothing written to the repository"
  exit 0
fi

# --- commit -------------------------------------------------------------------------------
LOG=$(mktemp)
if ! git -C "$TOP" commit -F "$FINAL" "${PASS_ARGS[@]}" >"$LOG" 2>&1; then
  reason=$(last_reason "$LOG")
  tail -5 "$LOG" 2>/dev/null | sed 's/^/  ..    /'
  bad commit "git commit -F $FINAL${PASS_ARGS[*]:+ ${PASS_ARGS[*]}} failed — ${reason:-no output}"
  say ""
  say "COMMIT: FAIL ($FAILED)"
  exit 1
fi

# --- prove it -----------------------------------------------------------------------------
# The commit is a claim; re-reading HEAD and the trailer out of the commit is the evidence.
sha=$(git -C "$TOP" rev-parse --verify --quiet HEAD 2>/dev/null || true)
[ -n "$sha" ] || refuse commit "cannot resolve HEAD in $TOP after the commit"
landed_val=$(git -C "$TOP" log -1 --format=%B "$sha" 2>/dev/null \
  | grep -E '^Run-Id:' | tail -1 | sed -E 's/^Run-Id:[[:space:]]*//; s/[[:space:]]+$//' || true)
if [ "$landed_val" != "$run_id" ]; then
  bad run_trailer "commit ${sha:0:12} carries 'Run-Id: ${landed_val:-none}', not '$run_id' — the trailer did not reach the commit"
  say ""
  say "COMMIT: FAIL ($FAILED)"
  exit 1
fi
ok run_trailer "Run-Id: $run_id written on $sha"

say ""
say "COMMITTED: $sha (Run-Id: $run_id)"
exit 0
