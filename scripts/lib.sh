#!/usr/bin/env bash
# lib.sh — shared helpers for every script in this repo.
# Sourced, never executed. Requires bash.

say()  { printf '%s\n' "$*"; }
ok()   { printf '  PASS  %s — %s\n' "$1" "$2"; }
bad()  { printf '  FAIL  %s — %s\n' "$1" "$2"; FAILED=$((FAILED+1)); }
warn() { printf '  WARN  %s — %s\n' "$1" "$2"; WARNED=$((WARNED+1)); }
note() { printf '  ..    %s\n' "$*"; }

FAILED=${FAILED:-0}
# A WARN row is a measured absence, so it is counted. Reading only $FAILED let an adapter print
# `PASS` beside its own WARN rows (CF-141).
WARNED=${WARNED:-0}

# The verdict line every adapter ends with. The vocabulary and the row-count rule are
# specs/HARNESS.md "The verdict line"; there is one implementation so six adapters cannot drift:
#   FAIL (n)    at least one FAIL row            -> exit 1
#   UNVERIFIED  at least one WARN row, no FAIL   -> exit 3
#   PASS        no FAIL and no WARN row          -> exit 0
# Exit 3 (not 0) because nothing was certified: an adapter whose install ladder is unmeasured
# must not exit like a green one. Usage/contract refusals are a different case — nothing was
# measured at all — and keep their own named line and exit 2.
# `action` is for the modes that DO something (--apply/--turn/--app-server): their WARN rows are
# advice about a run that already happened (a PATH hint, an experimental subcommand) and do not
# unmake it, so only FAIL rows decide. Certification (`--check`) is the mode that may only answer
# PASS when every row passed — that is the claim callers act on.
verdict() {  # verdict <LABEL> [action] — prints the line, returns the status the caller exits with
  local label="$1" mode="${2:-check}"
  if [ "${FAILED:-0}" -gt 0 ]; then say "$label: FAIL ($FAILED)"; return 1; fi
  if [ "$mode" != "action" ] && [ "${WARNED:-0}" -gt 0 ]; then say "$label: UNVERIFIED"; return 3; fi
  say "$label: PASS"
  return 0
}

# have <cmd> — prints the resolved path and exits 0 when <cmd> is on PATH; prints NOTHING on stdout
# and exits non-zero when it is not. Absence must be observable by STATUS: the trailing `|| true`
# this used to end in made the status constant 0, so every `b=$(have x) || { … }` guard in this tree
# was dead code and `have x && …` was always true (CF-281). Never write an error here — callers
# execute the result as a path (`"$b" cp …`), so the only thing on stdout is the path itself.
have() {
  local p
  p=$(command -v "${1:-}" 2>/dev/null) || return 1
  printf '%s\n' "$p"
}

# A pinned download that refuses a digest mismatch (CF-105). Never pipes to a shell.
# CF-280: fails closed. Every step that can fail while putting the artifact in place is checked
# explicitly — no `set -e` (this file is sourced by many scripts) and no trailing `|| true` deciding
# the status. The function's exit code now describes the INSTALL, not the best-effort chmod.
fetch_verified() {
  local url="$1" dest="$2" want="$3"
  local tmp; tmp="$(mktemp)"
  curl -fsSL --max-time 120 -o "$tmp" "$url" || { rm -f "$tmp"; return 1; }
  local got; got=$(sha256sum "$tmp" | cut -d' ' -f1)
  if [ "$got" != "$want" ]; then
    rm -f "$tmp"
    printf 'digest mismatch for %s: want %s got %s\n' "$url" "$want" "$got" >&2
    return 1
  fi
  local dir; dir="$(dirname "$dest")"
  if ! mkdir -p "$dir"; then
    rm -f "$tmp"
    printf 'cannot create destination directory %s for %s\n' "$dir" "$url" >&2
    return 1
  fi
  if ! mv "$tmp" "$dest"; then
    rm -f "$tmp"
    printf 'cannot move verified download into place at %s for %s\n' "$dest" "$url" >&2
    return 1
  fi
  chmod +x "$dest" 2>/dev/null || true
  return 0
}

# Free space in GB at a path.
free_gb() { df -Pk "$1" | awk 'NR==2{printf "%.1f", $4/1048576}'; }

# Refuse below the floor, naming the number (CF-109 / N-5).
require_disk() {
  local path="$1" floor="$2" free
  free=$(free_gb "$path")
  if awk -v f="$free" -v m="$floor" 'BEGIN{exit !(f>=m)}'; then
    ok "disk" "${free} GB free (floor ${floor} GB)"
  else
    bad "disk" "${free} GB free < floor ${floor} GB at ${path}"
    return 1
  fi
}

# An idempotent action: run only if the sentinel is absent.
once() {
  local sentinel="$1"; shift
  if [ -e "$sentinel" ]; then note "already done: $(basename "$sentinel")"; return 0; fi
  "$@" && mkdir -p "$(dirname "$sentinel")" && date -u +%FT%TZ > "$sentinel"
}

# Quote one data value for a remote shell, including empty strings and apostrophes.
shq() {
  local value="${1//\'/\'\\\'\'}"
  printf "'%s'" "$value"
}

# Accept trusted shell command text, not an argv array: remaining arguments are joined
# with spaces for bash -lc. Callers must pass every interpolated data value through
# shq before composing that text; literal shell commands retain their semantics.
bunker_exec() {  # bunker_exec <server> <agent> <cmd...>
  local server="$1" agent="$2"; shift 2
  bunker exec --server "$server" "$agent" -- bash -lc "$*"
}
