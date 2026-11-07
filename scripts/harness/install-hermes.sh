#!/usr/bin/env bash
# install-hermes.sh — the MEASURED Hermes adapter.
#
# Measured 2026-10-29 on a test node: python 3.12.3, hermes-agent 0.19.0, 32 s install,
# 248 MB venv, no node/npm (the backend runs with --skip-build).
#
#   install-hermes.sh --check
#   install-hermes.sh --apply
#   install-hermes.sh --contract
#   install-hermes.sh --help
#
# The §5 input contract is one implementation, scripts/harness/harness-vars.sh: every declared
# variable is accepted as a flag and as a CF_* environment variable, a credential is a PATH (never
# a value, never ambient), and every accepted name is recorded (CF-229).
#
# A public bind ALWAYS requires auth (since the June 2026 hardening; --insecure is a no-op),
# so --apply refuses to start a gateway without dashboard.basic_auth configured — and the same gate
# is evaluated when a listener ALREADY owns the port, because a port this adapter did not start is
# still a public bind (CF-192).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"
. "$HERE/harness-vars.sh"

PORT="${NODE_GATEWAY_PORT:-10800}"
PIN="${HERMES_PIN:-0.19.0}"
VENV="$HOME/hermes-venv"
PYTHON_BIN="${HERMES_PYTHON_BIN:-python3}"
PYTHON_MIN_MAJOR=3
PYTHON_MIN_MINOR=11
PYTHON_MAX_MAJOR=3
PYTHON_MAX_MINOR=14
MODE="--check"

usage() {
  cat <<'HERMES_USAGE'
install-hermes.sh — the MEASURED Hermes adapter (pin, venv, gateway probe).

USAGE
  install-hermes.sh [--check | --apply | --contract] [CF_* options]

MODES
  --check      (default) Read-only. python compatibility, the venv binary and its measured
               version against the pin, the gateway port and /api/status, and whether a provider
               key exists (existence only — the value is never read). Exit 0 only when every row
               PASSes.
  --apply      Install hermes-agent at the pin into $HOME/hermes-venv and start the gateway with
               --skip-build, which refuses without dashboard.basic_auth. Re-running it changes
               nothing: an installed pin is a no-op and a listening port is left alone.
  --contract   Validate the §5 set below and exit 0, or exit 2 with a named refusal. Installs
               nothing, starts nothing, needs no credential: this is the acceptance check the
               conformance battery calls.

  --help, -h   This text.

HERMES_USAGE
  cfv_help_block
  cat <<'HERMES_TAIL'
REFUSALS (each one names the rule, not just "invalid")
  * a credential value in CF_API_KEY_FILE or as --api-key, and CF_API_KEY set at all (not in the
    contract) — a key travels as a mode-600 PATH, never as a value (AGENTS.md r8);
  * OPENAI_API_KEY / ANTHROPIC_API_KEY exported into the ambient environment — the directive is
    the only source, so two lanes on one node cannot contaminate each other (matrix §5);
  * CF_WORKDIR that does not exist, or that resolves outside $HOME;
  * CF_MAX_TURNS / CF_TIMEOUT_S that are not integers, or outside 1..1000 / 1..86400;
  * CF_BASE_URL that is not http(s), or that carries userinfo (a credential in a URL).

WHAT THIS ADAPTER DOES WITH THE SET
  --check/--apply record every accepted name and act on the ones the install ladder needs
  (CF_WORKDIR, CF_BASE_URL, CF_API_KEY_FILE, the budget). Model, provider, namespace, run id,
  lane, skills root and the options bag belong to the RUN, which this installer does not perform:
  they are recorded here and passed to the harness by the node at invocation time (§5).
HERMES_TAIL
}

cfv_load_env
cfv_parse_args "$@"
[ "$CFV_HELP" -eq 0 ] || { usage; exit 0; }
MODE="--$CFV_MODE"

hb() { [ -x "$VENV/bin/hermes" ] && echo "$VENV/bin/hermes" || have hermes; }
hv() {
  local raw
  raw=$("$1" --version 2>/dev/null) || return 1
  raw=${raw%%$'\n'*}
  if [[ "$raw" =~ (^|[[:space:]])v?([0-9]+\.[0-9]+\.[0-9]+[^[:space:]]*) ]]; then
    printf '%s\n' "${BASH_REMATCH[2]}"
  else
    printf '%s\n' "$raw"
    return 1
  fi
}

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

# Read only the configured credentials; never echo values or YAML parser diagnostics.
check_public_bind_auth() {
  local config_python="$PYTHON_BIN"
  [ ! -x "$VENV/bin/python" ] || config_python="$VENV/bin/python"
  "$config_python" - "$HOME/.hermes/config.yaml" 2>/dev/null <<'PY'
import json
import re
import sys
from pathlib import Path


def refuse(reason):
    print(reason)
    sys.exit(1)


# Deliberately accept a strict YAML subset, identically with or without PyYAML.
# Unsupported syntax (aliases, tags, flow collections, multiline scalars) refuses.
# No parser dependency may turn a valid block into an unavailable-parser refusal.


def content(line):
    quote = None
    i = 0
    while i < len(line):
        char = line[i]
        if quote == '"' and char == "\\":
            i += 2
            continue
        if quote == "'" and line[i:i + 2] == "''":
            i += 2
            continue
        if quote:
            if char == quote:
                quote = None
        elif char == "#" and (i == 0 or line[i - 1].isspace()):
            return line[:i].rstrip()
        elif char in "\"'" and (i == 0 or line[i - 1].isspace()):
            quote = char
        i += 1
    if quote:
        raise ValueError
    return line.rstrip()


def scalar(value):
    if value.startswith('"'):
        result = json.loads(value)
        if not isinstance(result, str):
            raise ValueError
        return result
    if value.startswith("'"):
        if not re.fullmatch(r"'(?:[^']|'')*'", value):
            raise ValueError
        return value[1:-1].replace("''", "'")
    if value == "{}":
        return {}
    if (value[0] in "[]{}&*!|>@`%"
            or re.match(r"[-?:](?:\s|$)", value)
            or re.search(r":(?:\s|$)", value)):
        raise ValueError
    # Plain YAML booleans, nulls, numbers and timestamps are not string scalars.
    if value.lower() in {"null", "~", "true", "false", "yes", "no", "on", "off"}:
        return None
    if re.fullmatch(
        r"[-+]?(?:[0-9][0-9_]*(?:\.[0-9_]*)?(?:[eE][-+]?[0-9]+)?"
        r"|\.[0-9_]+(?:[eE][-+]?[0-9]+)?|0[xX][0-9a-fA-F_]+"
        r"|0[bBoO][0-9_]+|[0-9_]+(?::[0-9_]+)+(?:\.[0-9_]*)?"
        r"|\.(?:inf|Inf|INF|nan|NaN|NAN))", value
    ) or re.match(r"[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}(?:$|[Tt\s])", value):
        return None
    return value


def mapping(lines, index, indent):
    result = {}
    while index < len(lines):
        depth, line = lines[index]
        if depth < indent:
            break
        match = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_.-]*):(?:\s+(.*))?", line)
        if depth != indent or not match or match[1] in result:
            raise ValueError
        key, value = match[1], match[2]
        index += 1
        if index < len(lines) and lines[index][0] > indent:
            if value:
                raise ValueError
            child = lines[index][0]
            if lines[index][1].startswith("- ") or lines[index][1] == "-":
                result[key] = []
                while index < len(lines) and lines[index][0] >= child:
                    index += 1
            else:
                result[key], index = mapping(lines, index, child)
        elif (index < len(lines) and lines[index][0] == indent
              and (lines[index][1].startswith("- ") or lines[index][1] == "-")):
            # A block sequence written at the SAME indent as its key, which is what the node's
            # own config does:
            #   custom_providers:
            #   - name: cf-proxy
            # Its content cannot authorize anything here, but refusing to parse it made every
            # node carrying a list report "block absent (invalid YAML)" and never start a
            # gateway (measured on cf-node 2026-11-05 against a valid 310-byte config).
            if value:
                raise ValueError
            result[key] = []
            while index < len(lines):
                depth, item = lines[index]
                if depth < indent:
                    break
                if depth == indent and not (item.startswith("- ") or item == "-"):
                    break
                index += 1
        else:
            result[key] = scalar(value) if value else None
    return result, index


try:
    text = Path(sys.argv[1]).read_text(encoding="utf-8")
except (OSError, UnicodeError):
    refuse("block absent (config unreadable)")
try:
    lines = []
    for raw in text.splitlines():
        if "\t" in raw or any(ord(char) < 32 for char in raw):
            raise ValueError
        line = content(raw)
        if line.strip():
            lines.append((len(line) - len(line.lstrip(" ")), line.lstrip(" ")))
    config, end = mapping(lines, 0, 0)
    if end != len(lines):
        raise ValueError
except (ValueError, RecursionError):
    refuse("block absent (invalid YAML)")
dashboard = config.get("dashboard") if isinstance(config, dict) else None
if not isinstance(dashboard, dict) or "basic_auth" not in dashboard:
    # Comments explain a refusal only; they can never authorize a public bind.
    commented = re.search(r"^\s*#\s*basic_auth\s*:", text, re.MULTILINE)
    refuse("commented" if commented else "block absent")
auth = dashboard["basic_auth"]
if not isinstance(auth, dict) or not all(
    isinstance(auth.get(key), str) and auth[key].strip()
    for key in ("username", "password")
):
    refuse("empty value (username and password must both be non-empty)")
PY
}

say "harness: hermes (pin $PIN, port $PORT)"

# The §5 contract is checked before anything else touches this host: a refusal here means nothing
# was installed, started or read.
cfv_validate "$CFV_MODE"
if cfv_refused; then
  say ""
  say "HERMES: FAIL ($CFV_FAILED) — contract refused; nothing was installed or started"
  exit 2
fi
if [ "$CFV_MODE" = "contract" ]; then
  say ""
  say "HERMES: CONTRACT PASS — the §5 set is accepted (specs/HARNESS-MATRIX.md §5); nothing installed"
  exit 0
fi

# An interpreter refusal stops the ladder, but it does not stop the verdict: a caller must be able to
# tell `FAIL python` + `HERMES: FAIL (1)` from a crash that printed rows and died (CF-141).
check_python_compatibility || { say ""; verdict HERMES; exit $?; }

h=$(hb)
version=
if [ -n "$h" ]; then
  if [ -x "$VENV/bin/hermes" ]; then
    ok "binary" "$h"
  else
    bad "binary" "host-provided $h (not installed by this adapter — run --apply)"
  fi
  version=$(hv "$h")
  [ "$version" = "$PIN" ] && ok "version" "$version (pin $PIN)" \
    || bad "version" "${version:-unknown} != pin $PIN"
else
  bad "binary" "absent — run --apply"
fi

# gateway
if (command -v ss >/dev/null && ss -tln 2>/dev/null | grep -q ":$PORT ") 2>/dev/null; then
  # An occupied port is not evidence that the bind is legal: a 127.0.0.1 probe answers on an
  # unauthenticated 0.0.0.0 gateway too. Evaluate the SAME gate the --apply start path uses (one
  # parser: check_public_bind_auth) before certifying anything. Measured before this check
  # (CF-192): --apply printed PASS port / PASS status_probe / HERMES: PASS and exited 0 on an
  # occupied :$PORT whose config carried no dashboard.basic_auth.
  if port_auth_reason=$(check_public_bind_auth); then
    ok "port" "listening on :$PORT"
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$PORT/api/status" 2>/dev/null || echo 000)
    # NOTE: `hermes serve` has no /health (302 to login); /api/status is the probe.
    [ "$code" = 200 ] && ok "status_probe" "/api/status -> 200" || bad "status_probe" "/api/status -> $code"
  else
    # A gateway a previous --apply started still certifies (the branch above); a listener without
    # the block does not, and the row is counted so the layer line stays truthful.
    bad "port" "listening on :$PORT (not started by this adapter; auth unverified — a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml — ${port_auth_reason:-block absent (config check failed)})"
  fi
else
  if [ "$MODE" = "--apply" ]; then
    # Do not count a FAIL for a state this run is about to change: --check still reports it
    # (measured: a real apply started the gateway and the layer still said NODE: FAIL (1)).
    note "port — nothing on :$PORT yet; --apply starts the gateway"
  else
    bad "port" "nothing on :$PORT"
  fi
fi

# inference provider — the one thing install cannot supply
if [ -f "$HOME/.hermes/.env" ] && grep -qE '^[A-Z_]+_API_KEY=' "$HOME/.hermes/.env" 2>/dev/null; then
  ok "inference_key" "a provider key is present in ~/.hermes/.env (value not read)"
else
  bad "inference_key" "no provider key — a turn dies at 'No inference provider configured'"
fi

if [ "$MODE" = "--apply" ]; then
  say "apply"
  if [ ! -x "$VENV/bin/hermes" ] || [ "$version" != "$PIN" ]; then
    if [ -x "$VENV/bin/hermes" ]; then
      note "venv version ${version:-unknown} != pin $PIN — installing pin"
    fi
    "$PYTHON_BIN" -m venv "$VENV" || { bad "venv" "creation failed"; say ""; verdict HERMES action; exit $?; }
    log_template="$HOME/.hermes-install-$PORT.XXXXXXXX.log"
    if pip_log=$(umask 077; mktemp "$log_template" 2>&1); then
      : # mktemp creates a private log before pip is invoked.
    else
      bad "install_log" "cannot create $log_template — $pip_log"
      say ""; verdict HERMES action; exit $?
    fi
    "$VENV/bin/python" -m pip install --no-cache-dir "hermes-agent==$PIN" >"$pip_log" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
      ok "install" "$("$VENV/bin/hermes" --version 2>/dev/null | head -1)"
    else
      bad "install" "pip exited $rc — log: $pip_log"
      say ""; verdict HERMES action; exit $?
    fi
  else
    note "already installed: $("$h" --version 2>/dev/null | head -1)"
  fi
  # CF-006: --apply names the binary it placed, so the node manifest can record where the harness
  # lives and verify-node.sh can measure THAT binary rather than whatever PATH resolves (the venv
  # binary is under $HOME and normally is not on PATH at all).
  [ -x "$VENV/bin/hermes" ] && ok "binary" "$VENV/bin/hermes"

  if ! (command -v ss >/dev/null && ss -tln 2>/dev/null | grep -q ":$PORT ") 2>/dev/null; then
    if auth_reason=$(check_public_bind_auth); then
      nohup "$VENV/bin/hermes" serve --host 0.0.0.0 --port "$PORT" --skip-build >"$HOME/.node-serve-$PORT.log" 2>&1 &
      sleep 6
      code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$PORT/api/status" 2>/dev/null || echo 000)
      if [ "$code" = 200 ]; then
        ok "gateway_start" "/api/status -> 200"
        if (command -v ss >/dev/null && ss -tln 2>/dev/null | grep -q ":$PORT ") 2>/dev/null; then
          ok "port" "listening on :$PORT (started by --apply)"
        elif command -v ss >/dev/null 2>&1 && ss -tln >/dev/null 2>&1; then
          bad "port" "ss shows nothing on :$PORT after a 200 from /api/status"
        else
          # A minimal image can lack a working ss; the 200 is then the only listener evidence.
          warn "port" "ss unavailable — listener unconfirmed; /api/status 200 is the evidence"
        fi
      else
        bad "gateway_start" "-> $code (see ~/.node-serve-$PORT.log)"
      fi
    else
      bad "gateway_start" "refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml — ${auth_reason:-block absent (config check failed)}"
    fi
  fi
fi

say ""
if [ "$MODE" = "--apply" ]; then verdict HERMES action; else verdict HERMES; fi
exit $?
