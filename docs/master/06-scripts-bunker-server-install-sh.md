# 06. scripts/bunker-server-install.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/bunker-server-install.sh` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: **UNKNOWN** beyond the script’s own described check/apply behaviour. The header says it is the control-host-side measure/apply script: `scripts/bunker-server-install.sh:2-5`. It also says the bunker server hosts agents, while the control host designs work: `scripts/bunker-server-install.sh:7-8`. No downstream consumer of this script is named.
- What breaks if it lies: **UNKNOWN** — every self-reporting component has this failure mode; no cross-check is present in the source.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` via `/usr/bin/env bash` | UNKNOWN | shebang: `scripts/bunker-server-install.sh:1` | Not detected inside the script; exec failure would occur outside this source |
| `lib.sh` | UNKNOWN | same directory as script via `HERE`: `scripts/bunker-server-install.sh:10-12` | No explicit guard in source; sourced at `. "$HERE/lib.sh"` (`scripts/bunker-server-install.sh:12`) |
| `bunker` | UNKNOWN | resolved by `have bunker`: `scripts/bunker-server-install.sh:28` | `[ -n "$b" ]` false branch calls `bad "bunker_client" "missing — no way to create or reach agents"` (`scripts/bunker-server-install.sh:29-33`) |
| `python3` | UNKNOWN | resolved by `have python3`: `scripts/bunker-server-install.sh:67-68` | `[ -n "$p" ] ... || warn "tool:$t" "missing (needed for the control-side scripts)"` (`scripts/bunker-server-install.sh:68`) |
| `git` | UNKNOWN | resolved by `have git`: `scripts/bunker-server-install.sh:67-68` | same `warn "tool:$t" "missing (needed for the control-side scripts)"` path (`scripts/bunker-server-install.sh:68`) |
| `curl` | UNKNOWN | resolved by `have curl`: `scripts/bunker-server-install.sh:67-68` | same path (`scripts/bunker-server-install.sh:68`) |
| `jq` | UNKNOWN | resolved by `have jq`: `scripts/bunker-server-install.sh:67-68` | same path (`scripts/bunker-server-install.sh:68`) |
| `dirname`, `cd`, `pwd`, `head`, `grep`, `printf`, `sed`, `true` | UNKNOWN | invocation sites: `scripts/bunker-server-install.sh:10,30,40,50,52,55,61,62,63,70` | No explicit guard appears in source; command failure would occur outside this source |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `. "$HERE/lib.sh"` (`scripts/bunker-server-install.sh:12`) | `lib.sh` in the same directory (`scripts/bunker-server-install.sh:10-12`) | Functions/values used: `bad`, `say`, `ok`, `warn`, `have`, `require_disk`, and variable `FAILED`; called/read at `scripts/bunker-server-install.sh:19-21,28,31,33,39-40,42,51,53,55,62-63,67-70,73` | **UNKNOWN** — no versioned contract or fallback is shown |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `$SERVER` from `BUNKER_SERVER` (`scripts/bunker-server-install.sh:14`) | outbound from this script through the `bunker` CLI | **UNKNOWN** | `"$b" list --server "$SERVER"` (`scripts/bunker-server-install.sh:47`) and `"$b" status --server "$SERVER"` (`scripts/bunker-server-install.sh:61`) | **RED** — no server-side file/function is named in source |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| — | **no check exists** | — | — | **RED** |

The header documents `./bunker-server-install.sh --check` (`scripts/bunker-server-install.sh:4`), but the script itself only recognizes `--json` (`scripts/bunker-server-install.sh:16`), and `JSON` is never used beyond assignment.

## 4. Metrics emitted

**NONE FOUND** — no metric emission path appears in `scripts/bunker-server-install.sh`. It prints human-readable check results via `say`, `ok`, `bad`, and `warn` (`scripts/bunker-server-install.sh:19-73`), but dispatch rate, latency, failure counts and liveness are unanswerable from this source.

## 5. Log lines it can generate

The level is visible only as the function name (`bad`, `ok`, `warn`, `say`); no numeric or syslog level is shown.

- `bad "server_declared" "BUNKER_SERVER unset — the client has no server to talk to"` (`scripts/bunker-server-install.sh:19`)
- `say ""` (`scripts/bunker-server-install.sh:20`, `:72`)
- `say "RESULT: FAIL ($FAILED)"` (`scripts/bunker-server-install.sh:21`, `:73`)
- `say "bunker server: $SERVER"` (`scripts/bunker-server-install.sh:25`)
- `ok "bunker_client" "$b ${v:-（version not reported）}"` (`scripts/bunker-server-install.sh:31`)
- `bad "bunker_client" "missing — no way to create or reach agents"` (`scripts/bunker-server-install.sh:33`)
- `ok "bunker_config" "$cfg"` (`scripts/bunker-server-install.sh:39`)
- `ok "server_declared" "$SERVER present in config"` (`scripts/bunker-server-install.sh:40`)
- `bad "server_declared" "$SERVER not found in $cfg"` (`scripts/bunker-server-install.sh:40`)
- `bad "bunker_config" "missing ($cfg) — the client has no server to talk to"` (`scripts/bunker-server-install.sh:42`)
- `ok "server_reachable" "$SERVER answered (agents listed: ${n:-0})"` (`scripts/bunker-server-install.sh:51`)
- `ok "agents_running" "${running:-0} running"` (`scripts/bunker-server-install.sh:53`)
- `bad "server_reachable" "$SERVER did not answer: $(printf '%s' "$out" | head -1)"` (`scripts/bunker-server-install.sh:55`)
- `say "$st" | sed 's/^/  ..    /'` (`scripts/bunker-server-install.sh:62`)
- `warn "residue" "orphan homes/keys reported by the server — reap before scaling"` (`scripts/bunker-server-install.sh:63`)
- `ok "tool:$t" "$p"` (`scripts/bunker-server-install.sh:68`)
- `warn "tool:$t" "missing (needed for the control-side scripts)"` (`scripts/bunker-server-install.sh:68`)
- `say "RESULT: PASS"` (`scripts/bunker-server-install.sh:73`)

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| `BUNKER_SERVER` unset or empty | `bad "server_declared" "BUNKER_SERVER unset — the client has no server to talk to"` and `say "RESULT: FAIL ($FAILED)"`, then `exit 1` (`scripts/bunker-server-install.sh:18-22`) | Guarded by `[ -z "$SERVER" ]` before any other check (`scripts/bunker-server-install.sh:18`) | Set `BUNKER_SERVER` before invocation; `SERVER="${BUNKER_SERVER:-}"` (`scripts/bunker-server-install.sh:14`) |
| `bunker` client missing | `bad "bunker_client" "missing — no way to create or reach agents"` (`scripts/bunker-server-install.sh:33`) | Occurs when `b=$(have bunker)` is empty (`scripts/bunker-server-install.sh:28-29`), before server reachability checks | Header says `--apply` installs missing user-space (`scripts/bunker-server-install.sh:5`), but no apply branch is implemented in this source |
| Config file missing | `bad "bunker_config" "missing ($cfg) — the client has no server to talk to"` (`scripts/bunker-server-install.sh:42`) | `[ -f "$cfg" ]` false (`scripts/bunker-server-install.sh:38`) | Create `$BUNKER_CONFIG` or `$HOME/.config/bunker/config.yaml` (`scripts/bunker-server-install.sh:37`); action not stated in source |
| Server not present in config | `bad "server_declared" "$SERVER not found in $cfg"` (`scripts/bunker-server-install.sh:40`) | `[ -f "$cfg" ]` true but `grep -q "$SERVER" "$cfg"` fails (`scripts/bunker-server-install.sh:38-40`) | Add `$SERVER` to config; source states presence is checked but gives no repair commands (`scripts/bunker-server-install.sh:40`) |
| Server did not answer | `bad "server_reachable" "$SERVER did not answer: $(printf '%s' "$out" | head -1)"` (`scripts/bunker-server-install.sh:55`) | Non-zero `rc` from `"$b" list --server "$SERVER"` (`scripts/bunker-server-install.sh:47-49,54-55`) | **UNKNOWN** — source only reports the failure |
| Orphan residue reported by server | `warn "residue" "orphan homes/keys reported by the server — reap before scaling"` (`scripts/bunker-server-install.sh:63`) | Non-fatal `warn`, gated by `grep -qi 'orphan'` after `"$b" status --server "$SERVER"` (`scripts/bunker-server-install.sh:60-63`) | Source says “reap before scaling” (`scripts/bunker-server-install.sh:63`), but exact reaping steps are not shown |
| Missing control-side tool (`python3`, `git`, `curl`, or `jq`) | `warn "tool:$t" "missing (needed for the control-side scripts)"` (`scripts/bunker-server-install.sh:68`) | Occurs when `[ -n "$p" ]` is false for one of the loop values (`scripts/bunker-server-install.sh:67-68`) | **UNKNOWN** — source only warns; header mentions `--apply` (`scripts/bunker-server-install.sh:5`), but no per-tool install branch exists in this source |
