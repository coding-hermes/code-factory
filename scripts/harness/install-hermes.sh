#!/usr/bin/env bash
# install-hermes.sh — the MEASURED Hermes adapter.
#
# Measured 2026-10-29 on a test node: python 3.12.3, hermes-agent 0.19.0, 32 s install,
# 248 MB venv, no node/npm (the backend runs with --skip-build).
#
#   install-hermes.sh --check
#   install-hermes.sh --apply
#
# A public bind ALWAYS requires auth (since the June 2026 hardening; --insecure is a no-op),
# so --apply refuses to start a gateway without dashboard.basic_auth configured.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"

PORT="${NODE_GATEWAY_PORT:-10800}"
PIN="${HERMES_PIN:-0.19.0}"
VENV="$HOME/hermes-venv"
PYTHON_BIN="${HERMES_PYTHON_BIN:-python3}"
PYTHON_MIN_MAJOR=3
PYTHON_MIN_MINOR=11
PYTHON_MAX_MAJOR=3
PYTHON_MAX_MINOR=14
MODE="${1:---check}"

hb() { [ -x "$VENV/bin/hermes" ] && echo "$VENV/bin/hermes" || have hermes; }

check_python_compatibility() {
  local raw version py_major py_minor
  raw=$("$PYTHON_BIN" --version 2>&1) || {
    bad "python" "unable to run $PYTHON_BIN --version"
    return 1
  }
  version=$(printf '%s\n' "$raw" | sed -nE 's/.*Python ([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/p' | head -1)
  if [ -z "$version" ]; then
    bad "python" "unable to determine interpreter version from: $raw"
    return 1
  fi
  IFS=. read -r py_major py_minor _ <<< "$version"
  if ! [[ "$py_major" =~ ^[0-9]+$ && "$py_minor" =~ ^[0-9]+$ ]]; then
    bad "python" "unable to parse interpreter version: $version"
    return 1
  fi
  if (( py_major < PYTHON_MIN_MAJOR ||
        (py_major == PYTHON_MIN_MAJOR && py_minor < PYTHON_MIN_MINOR) ||
        py_major > PYTHON_MAX_MAJOR ||
        (py_major == PYTHON_MAX_MAJOR && py_minor >= PYTHON_MAX_MINOR) )); then
    bad "python" "hermes-agent $PIN requires python >=3.11,<3.14; found $version"
    return 1
  fi
  ok "python" "$version (hermes-agent $PIN requires >=3.11,<3.14)"
}

say "harness: hermes (pin $PIN, port $PORT)"
check_python_compatibility || exit 1

h=$(hb)
if [ -n "$h" ]; then
  ok "binary" "$h"
  ok "version" "$("$h" --version 2>/dev/null | head -1)"
else
  bad "binary" "absent — run --apply"
fi

# gateway
if (command -v ss >/dev/null && ss -tln 2>/dev/null | grep -q ":$PORT ") 2>/dev/null; then
  ok "port" "listening on :$PORT"
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$PORT/api/status" 2>/dev/null || echo 000)
  # NOTE: `hermes serve` has no /health (302 to login); /api/status is the probe.
  [ "$code" = 200 ] && ok "status_probe" "/api/status -> 200" || bad "status_probe" "/api/status -> $code"
else
  bad "port" "nothing on :$PORT"
fi

# inference provider — the one thing install cannot supply
if [ -f "$HOME/.hermes/.env" ] && grep -qE '^[A-Z_]+_API_KEY=' "$HOME/.hermes/.env" 2>/dev/null; then
  ok "inference_key" "a provider key is present in ~/.hermes/.env (value not read)"
else
  bad "inference_key" "no provider key — a turn dies at 'No inference provider configured'"
fi

if [ "$MODE" = "--apply" ]; then
  say "apply"
  if [ -z "$h" ]; then
    "$PYTHON_BIN" -m venv "$VENV" || { bad "venv" "creation failed"; exit 1; }
    "$VENV/bin/python" -m pip install --no-cache-dir "hermes-agent==$PIN" >/tmp/hermes-install.log 2>&1 \
      && ok "install" "$("$VENV/bin/hermes" --version 2>/dev/null | head -1)" \
      || { bad "install" "pip failed — /tmp/hermes-install.log"; exit 1; }
  else
    note "already installed: $("$h" --version 2>/dev/null | head -1)"
  fi

  if ! (command -v ss >/dev/null && ss -tln 2>/dev/null | grep -q ":$PORT ") 2>/dev/null; then
    if grep -q 'basic_auth' "$HOME/.hermes/config.yaml" 2>/dev/null; then
      nohup "$VENV/bin/hermes" serve --host 0.0.0.0 --port "$PORT" --skip-build >"$HOME/.node-serve-$PORT.log" 2>&1 &
      sleep 6
      code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$PORT/api/status" 2>/dev/null || echo 000)
      [ "$code" = 200 ] && ok "gateway_start" "/api/status -> 200" || bad "gateway_start" "-> $code (see ~/.node-serve-$PORT.log)"
    else
      bad "gateway_start" "refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml"
    fi
  fi
fi

say ""
[ "$FAILED" -eq 0 ] && { say "HERMES: PASS"; exit 0; } || { say "HERMES: FAIL ($FAILED)"; exit 1; }
