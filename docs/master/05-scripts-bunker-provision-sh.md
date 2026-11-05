# 05. scripts/bunker-provision.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/bunker-provision.sh` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: Provision/check/apply/destroy of a project bunker from config plus CLI overrides becomes unavailable. Source header: `bunker-provision.sh — control host: provision ONE project's bunker from a config file, with CLI overrides, and destroy it again.` Usage examples in the source: `#   bunker-provision.sh --config cf-bunker.conf --check`, `#   bunker-provision.sh --config cf-bunker.conf --apply   [--agent A] [--server S] ...`, `#   bunker-provision.sh --config cf-bunker.conf --destroy --yes`.
- What breaks if it lies: **UNKNOWN** — the source shows pass/fail rows (`ok` / `bad`) but does not state the consequence of false reports.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | UNKNOWN | `/usr/bin/env` resolves `bash` on `PATH` (`#!/usr/bin/env bash`) | Not detected in-script; shell invocation fails |
| `bunker` CLI | UNKNOWN | `PATH` (`b=$(have bunker)`) | `bad "bunker_cli" "no bunker client on PATH"; return 1` in `check()`; `apply()` returns 1 when `[ -n "$b" ]` fails |
| `scripts/lib.sh` | UNKNOWN | Same directory as this script: `HERE="$(cd "$(dirname "$0")" && pwd)"`, then `. "$HERE/lib.sh"` | Not prechecked; sourcing `. "$HERE/lib.sh"` fails if the file is missing |
| `python3` | UNKNOWN | `PATH`; direct local invocations such as `python3 "$HERE/node_env.py"` and `python3 "$HERE/node_seed.py"` | Not prechecked; commands fail when invoked |
| `curl` | UNKNOWN | `PATH`; invoked as `curl -s -K - -o /dev/null -m 8 -w '%{http_code}'` | Not prechecked; `code=${code:-000}` causes a `bad "duckbrain:$ns"` row when no HTTP code is produced |
| `base64` | UNKNOWN | `PATH`; invoked as `base64 -w0 "$CRIER_AGENT_KEY_FILE"` | Not prechecked; command substitution fails/omits the key |
| `timeout` | UNKNOWN | `PATH`; invoked as `timeout 45 "$b" list` and similar | Not prechecked; command fails if `timeout` is absent |
| `mktemp`, `chmod`, `cp`, `rm`, `sed`, `head`, `tail`, `grep`, `date` | UNKNOWN | `PATH`; used throughout, e.g. `tmp=$(mktemp); chmod 600 "$tmp"`, `cp "$HERE/node_env.py" "$tmp"`, `rm -f "$tmp"` | Not prechecked; commands fail if absent |
| `scripts/bunker-crier-connect.sh` | UNKNOWN | Same directory as this script (`"$HERE/bunker-crier-connect.sh"`) | Not prechecked; failures handled by `bad "crier_stage" ...` or `bad "crier_connect" ...` |
| `scripts/node-create.sh` | UNKNOWN | Same directory as this script (`"$HERE/node-create.sh"`) | Not prechecked; failure handled by `bad "node_create" "node-create.sh reported FAIL — see its rows; continuing with the identity"` |
| `scripts/node_env.py` | UNKNOWN | Same directory as this script; local invocation `python3 "$HERE/node_env.py"` and staged copy via `cp "$HERE/node_env.py" "$tmp"` | Not prechecked; local refusal/failure reported as `bad "env_profile" ...`; stage failure reported as `bad "env_profile" "could not stage node_env.py"` |
| `scripts/node_seed.py` | UNKNOWN | Same directory as this script; invoked as `python3 "$HERE/node_seed.py" build ...` | Not prechecked; build refusal handled by `bad "node_seed" "build refused the declared seed — see the row above"` |
| `scripts/node_gateway_auth.py` | UNKNOWN | Same directory as this script; copied via `cp "$HERE/node_gateway_auth.py" "$tmp"` | Not prechecked; stage failure handled by `bad "gateway_auth" "could not stage node_gateway_auth.py"` |
| `scripts/node_identity.py` | UNKNOWN | Same directory as this script; copied via `cp "$HERE/node_identity.py" "$tmp"` | Not prechecked; stage failure handled by `bad "node_json" "could not stage node_identity.py"` |
| `config/node-seed.txt` | UNKNOWN | `$HERE/../config/node-seed.txt` (`seed_manifest="$HERE/../config/node-seed.txt"`) | Missing handled by `warn "node_seed" "config/node-seed.txt is absent — nothing declares what a node receives"` |

### 2b. Library contracts

| Source | Contract | Breaks if |
|---|---|---|
| `. "$HERE/lib.sh"` | Sourced `scripts/lib.sh` provides shell functions and state used throughout: `say`, `ok`, `bad`, `warn`, `note`, `have`, `shq`, and the `FAILED` counter used in `[ "$FAILED" -eq 0 ]`. | If `lib.sh` is missing or its function names/meanings change, call
