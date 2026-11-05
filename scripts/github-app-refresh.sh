#!/usr/bin/env bash
# github-app-refresh.sh — keep a GitHub App installation token fresh, so a long-lived node
# never silently loses push rights one hour after it was provisioned.
#
#   github-app-refresh.sh --local                        # refresh this host's own token file
#   github-app-refresh.sh --node cf-node --server b-01   # mint here, install into the node
#   github-app-refresh.sh --node cf-node --server b-01 --min-age 2400 --quiet
#
# Two modes, one rule: the App PRIVATE KEY never leaves the control host. The node only ever
# holds a token that dies within the hour, so a node compromise costs at most one hour of
# write access to one installation — not a permanent App credential.
#
# Why a timer at all: an installation token is valid for exactly one hour (GitHub, not us).
# A node provisioned today and pushing tomorrow has a dead credential unless something
# re-mints it. Run this from a user systemd timer (see the doc block in
# skills/code-factory-bunker/SKILL.md) every 20 minutes with --min-age 2400: a token is
# re-minted once it is 40 minutes old, leaving a 20-minute margin against expiry.
#
# Never prints the token, the JWT or the key. Only the file it wrote and the seconds left.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

ENV_FILE="${GITHUB_APP_ENV_FILE:-$HOME/.config/code-factory/github-app.env}"
TOKEN_FILE=""
NODE=""
SERVER=""
MIN_AGE=2400
GIT_CREDENTIALS="$HOME/.git-credentials"
LOCAL=0
DRY=0
QUIET=0
API_BASE="${GITHUB_API_BASE:-}"

usage() { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-2}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --env-file) ENV_FILE="${2:-}"; shift 2 ;;
    --token-file) TOKEN_FILE="${2:-}"; shift 2 ;;
    --node) NODE="${2:-}"; shift 2 ;;
    --server) SERVER="${2:-}"; shift 2 ;;
    --min-age) MIN_AGE="${2:-}"; shift 2 ;;
    --git-credentials) GIT_CREDENTIALS="${2:-}"; shift 2 ;;
    --api-base) API_BASE="${2:-}"; shift 2 ;;
    --local) LOCAL=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage 0 ;;
    *) say "unknown argument: $1"; usage 2 ;;
  esac
done
case "$MIN_AGE" in ''|*[!0-9]*) say "--min-age must be a number of seconds"; exit 2 ;; esac

say_q() { [ "$QUIET" -eq 1 ] || say "$@"; }

[ -f "$ENV_FILE" ] || { bad "env_file" "$ENV_FILE absent — run scripts/github-app-setup.sh --apply once"; exit 1; }
TOKEN_FILE="${TOKEN_FILE:-$HOME/.config/code-factory/github.token}"
PY="$(command -v python3 || true)"
[ -n "$PY" ] || { bad "python3" "python3 is required to sign the App JWT"; exit 1; }
[ -r "$HERE/github-app-token.py" ] || { bad "minter" "$HERE/github-app-token.py is missing"; exit 1; }

if [ "$NODE" != "" ] && [ "$SERVER" = "" ]; then
  bad "server" "--node needs --server (which bunker host the agent lives on)"; exit 2
fi

PHP_ARGS=(token --env-file "$ENV_FILE" --if-older "$MIN_AGE")
[ -n "$API_BASE" ] && PHP_ARGS+=(--api-base "$API_BASE")

# Seconds of life left in a token file, from its mtime: an installation token lives 3600s and
# the minter writes the file the moment the token is created.
life_left() {
  local f="$1" age
  age=$(python3 -c 'import os,sys,time; print(int(max(0,time.time()-os.path.getmtime(sys.argv[1]))))' "$f" 2>/dev/null || echo 0)
  printf '%s' "$((3600 - age))"
}

# mint_local <dest> — fills MINT_ROWS (the minter's own named rows, which carry no secret) and
# MINT_SKIPPED, so the caller can tell "a fresh token was written" from "the token was still
# valid": a refresh that reports work it did not do is the same lie as a vacuous PASS.
MINT_ROWS=""
MINT_SKIPPED=0
mint_local() {
  local dest="$1" out rc
  out=$("$PY" "$HERE/github-app-token.py" "${PHP_ARGS[@]}" --out "$dest" 2>&1); rc=$?
  MINT_ROWS="$out"
  case "$out" in *"GITHUB APP TOKEN: SKIP"*) MINT_SKIPPED=1 ;; *) MINT_SKIPPED=0 ;; esac
  printf '%s\n' "$out" | sed 's/^/  /'
  return "$rc"
}

if [ "$LOCAL" -eq 1 ] || [ "$NODE" = "" ]; then
  say_q "github-app-refresh — local: $TOKEN_FILE (min-age ${MIN_AGE}s)"
  if [ "$DRY" -eq 1 ]; then note "dry run: no mint, no write"; exit 0; fi
  mint_local "$TOKEN_FILE" || { bad "refresh" "could not mint into $TOKEN_FILE — the existing token keeps its remaining life"; exit 1; }
  if [ "$MINT_SKIPPED" -eq 1 ]; then
    left=$(life_left "$TOKEN_FILE")
    ok "refresh" "(no-op) $TOKEN_FILE is still valid, ~${left}s left; nothing rewritten"
    exit 0
  fi
  mode=$(stat -c %a "$TOKEN_FILE" 2>/dev/null || echo '?')
  [ "$mode" = "600" ] || bad "mode" "$TOKEN_FILE is mode $mode, expected 600"
  # A store-based credential helper reads ~/.git-credentials: rewrite it only when it exists,
  # so this script never creates a second credential store on a host that does not use one.
  if [ -f "$GIT_CREDENTIALS" ] && [ -s "$TOKEN_FILE" ]; then
    tmp=$(mktemp); chmod 600 "$tmp"
    printf 'https://x-access-token:%s@github.com\n' "$(tr -d '\r\n' < "$TOKEN_FILE")" > "$tmp"
    mv "$tmp" "$GIT_CREDENTIALS"; chmod 600 "$GIT_CREDENTIALS"
    note "refreshed $GIT_CREDENTIALS (mode 600)"
  fi
  left=$(life_left "$TOKEN_FILE")
  ok "refresh" "$TOKEN_FILE refreshed, ~${left}s of life left (a fresh token is valid 3600s)"
  exit 0
fi

# --- node mode: mint on this host, install on the node, delete the local copy ---------------
say_q "github-app-refresh — node: $NODE on $SERVER (min-age ${MIN_AGE}s)"
b=$(have bunker)
[ -n "$b" ] || { bad "bunker_cli" "the bunker client is not on PATH"; exit 1; }
if ! "$b" info "$NODE" --server "$SERVER" >/dev/null 2>&1; then
  bad "agent" "$NODE not found on $SERVER (bunker info failed)"; exit 1
fi

tmp=$(mktemp); chmod 600 "$tmp"; rm -f "$tmp"
if [ "$DRY" -eq 1 ]; then note "dry run: would mint and install into $NODE:$HOME/.node/auth/github.token"; exit 0; fi
mint_local "$tmp" || { bad "refresh" "could not mint — the node keeps its current token"; rm -f "$tmp"; exit 1; }

if "$b" cp "$tmp" "$NODE:cf-github.token" --server "$SERVER" >/dev/null 2>&1 &&
   "$b" exec --server "$SERVER" "$NODE" -- bash -lc '
     set -e
     mkdir -p "$HOME/.node/auth"; chmod 700 "$HOME/.node" "$HOME/.node/auth" 2>/dev/null || true
     umask 077
     mv "$HOME/cf-github.token" "$HOME/.node/auth/github.token"
     chmod 600 "$HOME/.node/auth/github.token"
     printf "https://x-access-token:%s@github.com\n" "$(cat "$HOME/.node/auth/github.token")" > "$HOME/.git-credentials"
     chmod 600 "$HOME/.git-credentials"
     git config --global credential.helper "store --file=$HOME/.git-credentials"
     printf "token mode %s\n" "$(stat -c %a "$HOME/.node/auth/github.token")"
   ' 2>&1 | sed 's/^/  ..    /'; then
  ok "refresh" "$NODE:$HOME/.node/auth/github.token replaced (mode 600), git credential store repointed"
else
  bad "refresh" "could not install the token into $NODE — its current token keeps its remaining life"
  rm -f "$tmp"; exit 1
fi
rm -f "$tmp"
exit 0
