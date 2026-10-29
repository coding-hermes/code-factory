#!/usr/bin/env bash
# lib.sh — shared helpers for every script in this repo.
# Sourced, never executed. Requires bash.

say()  { printf '%s\n' "$*"; }
ok()   { printf '  PASS  %s — %s\n' "$1" "$2"; }
bad()  { printf '  FAIL  %s — %s\n' "$1" "$2"; FAILED=$((FAILED+1)); }
warn() { printf '  WARN  %s — %s\n' "$1" "$2"; }
note() { printf '  ..    %s\n' "$*"; }

FAILED=${FAILED:-0}

have() { command -v "$1" >/dev/null 2>&1 && command -v "$1" || true; }

# A pinned download that refuses a digest mismatch (CF-105). Never pipes to a shell.
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
  mkdir -p "$(dirname "$dest")"
  mv "$tmp" "$dest"
  chmod +x "$dest" 2>/dev/null || true
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

bunker_exec() {  # bunker_exec <server> <agent> <cmd...>
  local server="$1" agent="$2"; shift 2
  bunker exec --server "$server" "$agent" -- bash -lc "$*"
}
