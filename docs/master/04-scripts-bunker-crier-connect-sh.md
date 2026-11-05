# 04. scripts/bunker-crier-connect.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/bunker-crier-connect.sh` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- Purpose from `bunker-crier-connect.sh:2`: "control host: put ONE bunker agent on the crier bus and prove it."
- It provides three modes: `--check`, `--apply`, `--stage` from argument parsing `bunker-crier-connect.sh:149` and dispatch `bunker-crier-connect.sh:157`.
- It is described as separate from provisioning, re-runnable without touching clone/harness/credentials (`bunker-crier-connect.sh:9-11`).
- If absent: the command to connect/reconnect an agent to the crier bus and prove it is missing; no `--check`, `--apply`, or `--stage` dispatch occurs from this file (`bunker-crier-connect.sh:2`, `bunker-crier-connect.sh:149`, `bunker-crier-connect.sh:157`).
- If it lies: a false `CRIER: CONNECTED — $AGENT at $URL (signed read accepted)` (`bunker-crier-connect.sh:97`) would make an operator believe the agent's signed inbox route was exercised. The script explicitly warns an unsigned read proves nothing about the agent's key (`bunker-crier-connect.sh:91-93`).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | UNKNOWN — source gives only `#!/usr/bin/env bash` (`bunker-crier-connect.sh:1`) | Control host interpreter required by the shebang; also invoked on the agent node as `bash -lc` inside `bunker exec` (`bunker-crier-connect.sh:53`, `bunker-crier-connect.sh:80`, `bunker-crier-connect.sh:115`, `bunker-crier-connect.sh:132`) | Not checked in source |
| `curl` | UNKNOWN | Control host `PATH`; called for `/agents/$AGENT/inbox` (`bunker-crier-connect.sh:29`) and `/health` (`bunker-crier-connect.sh:40`) | No explicit check; `probe()` substitutes `${code:-000}` (`bunker-crier-connect.sh:30`), so a failed or empty curl result becomes `000` |
| `bunker` | UNKNOWN | Control host `PATH`; discovered with `command -v bunker` (`bunker-crier-connect.sh:51`) and required via `have bunker` (`bunker-crier-connect.sh:79`, `bunker-crier-connect.sh:109`, `bunker-crier-connect.sh:126`) | `check`: `bad "identity" "no bunker client on PATH"` and return 1 (`bunker-crier-connect.sh:79`); `stage`/`apply`: `bad "bunker_cli" "no bunker client on PATH"` and return 1 (`bunker-crier-connect.sh:110`, `bunker-crier-connect.sh:127`) |
| `timeout` | UNKNOWN | Control host `PATH`; used to cap `bunker exec` remote calls (`bunker-crier-connect.sh:52`, `bunker-crier-connect.sh:80`) | Not explicitly checked in source |
| `mktemp` | UNKNOWN | Control host `PATH`; called in `stage` and `apply` (`bunker-crier-connect.sh:111`, `bunker-crier-connect.sh:128`) | Not explicitly checked in source |
| `chmod` | UNKNOWN | Control host `PATH` for temp file permissions (`bunker-crier-connect.sh:111`, `bunker-crier-connect.sh:128`); agent node inside `bunker exec ... bash -lc 'chmod 600 "$HOME/.node/crier.json"'` (`bunker-crier-connect.sh:115`, `bunker-crier-connect.sh:132`) | Not explicitly checked in source |
| `date` | UNKNOWN | Control host `PATH`; called in `stage` and `apply` (`bunker-crier-connect.sh:113`, `bunker-crier-connect.sh:130`) | Not explicitly checked in source |
| `sed` | UNKNOWN | Control host `PATH`; called by `usage()` (`bunker-crier-connect.sh:25`) | Not explicitly checked in source |
| `grep`, `head` | UNKNOWN | Agent node; used inside the remote `bunker exec` signed-probe pipeline (`bunker-crier-connect.sh:53`) | Not explicitly checked in source; if the remote pipeline produces no usable output, `check()` continues with the unsigned probe path (`bunker-crier-connect.sh:55`) |
| `python3` | UNKNOWN | Agent node; invoked inside the remote `bunker exec` signed probe when signing files are present (`bunker-crier-connect.sh:53`) | Not directly checked; if `agent.key`, `crier.token`, or `node-bus-worker.py` are missing, the signed probe is skipped (`bunker-crier-connect.sh:53`, `bunker-crier-connect.sh:55`) |
| `$HOME/.node/agent.key`, `$HOME/.node/auth/crier.token`, `$HOME/node-bus-worker.py` | UNKNOWN — versions/checksums not shown | Agent node; tested by the remote shell in `check()` for signed-probe prerequisites (`bunker-crier-connect.sh:53`) | Not reported individually; if any is missing/empty/file absent, the signed probe is skipped (`bunker-crier-connect.sh:53`, `bunker-crier-connect.sh:55`) |
| `cat` | UNKNOWN | Agent node; called inside `bunker exec` to read `$HOME/.node/crier.json` (`bunker-crier-connect.sh:80`) | Not explicitly checked in source |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `. "$HERE/lib.sh"` (`bunker-crier-connect.sh:21`) | `$HERE/lib.sh` in the same checkout, where `HERE="$(cd "$(dirname "$0")" && pwd)"` (`bunker-crier-connect.sh:20`) | Shell callables: `say`, `bad`, `ok`, `warn`, and `have`. Representative call sites include `say "crier-connect --check — agent=$AGENT url=$URL"` (`bunker-crier-connect.sh:35`), `bad "agent" "AGENT unset"` (`bunker-crier-connect.sh:36`), `ok "bus_health" "$URL/health -> 200"` (`bunker-crier-connect.sh:42`), `warn "inbox" ...` (`bunker-crier-connect.sh:70`), and `have bunker` (`bunker-crier-connect.sh:79`, `bunker-crier-connect.sh:109`, `bunker-crier-connect.sh:126`). It also reads a variable `FAILED` (`bunker-crier-connect.sh:61`, `bunker-crier-connect.sh:94`, `bunker-crier-connect.sh:104`) that is not defined or initialized in this file. | UNKNOWN — this file does not state what `lib.sh` guarantees. If the sourced file is missing or the named helper/variable contract changes, the script fails at source time (`bunker-crier-connect.sh:21`) or at the first call/read that uses the changed name. |
