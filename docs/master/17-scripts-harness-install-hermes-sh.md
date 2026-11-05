# 17. scripts/harness/install-hermes.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/harness/install-hermes.sh` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: The direct `--check`/`--apply` action for the measured Hermes adapter is unavailable. The source defines those modes (`MODE="${1:---check}"`) and the install/start logic, so without this file the harness cannot perform this script’s checks or install/start the gateway through this path. Broader downstream failure is **UNKNOWN** from this file.
- What breaks if it lies: A false `PASS` from this self-reporting component could leave the gateway or provider key missing. The source names one specific downstream symptom: `"no provider key — a turn dies at 'No inference provider configured'"`. Beyond that, **UNKNOWN**.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | **UNKNOWN** (shebang is `#!/usr/bin/env bash`) | `PATH` for `env bash` | shebang failure; also uses `BASH_REMATCH`, `[[ =~ ]]`, `<<<` |
| `python3` (`HERMES_PYTHON_BIN`) | `>=3.11,<3.14` | `PATH` (default `python3`) | `"$PYTHON_BIN" --version` fails or `check_python_compatibility` calls `bad "python" "unable to run $PYTHON_BIN --version"` |
| `sed` | **UNKNOWN** | `PATH` | not explicitly checked; used in `sed -nE` during Python version parsing |
| `head` | **UNKNOWN** | `PATH` | not explicitly checked; used in version parsing pipeline |
| `grep` | **UNKNOWN** | `PATH` | not explicitly checked; used by `grep -q` and `grep -qE` for port/key checks |
| `curl` | **UNKNOWN** | `PATH` | not explicitly checked; absent means status probe emits `000` via `\|\| echo 000` |
| `ss` | **UNKNOWN** | `PATH` | checked via `command -v ss`; missing leads to `warn "port" "ss unavailable — listener unconfirmed; /api/status 200 is the evidence"` |
| `mktemp` | **UNKNOWN** | `PATH` | failure captured in `pip_log=$(umask 077; mktemp "$log_template" 2>&1)`, then `bad "install_log" "cannot create $log_template — $pip_log"` |
| `nohup` | **UNKNOWN** | `PATH` | not checked; gateway start would fail |
| `hermes` | `$PIN` (default `0.19.0`) | `$VENV/bin/hermes` or `PATH` via `hb()` | absent binary -> `bad "binary" "absent — run --apply"`; version mismatch -> `bad "version" "${version:-unknown} != pin $PIN"` |
| `pip` (as `"$VENV/bin/python" -m pip`) | **UNKNOWN** | inside `$VENV` after venv creation | install return code `rc=$?`; non-zero -> `bad "install" "pip exited $rc — log: $pip_log"` |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `json` | Python standard library | `json.loads(value)` parses double-quoted scalar strings; non-string result raises `ValueError` in `scalar()` | The strict YAML subset parser may reject or mishandle quoted scalars |
| `pathlib` | Python standard library | `Path(sys.argv[1]).read_text(encoding="utf-8")` reads config; `(OSError, UnicodeError)` are caught and reported as `"block absent (config unreadable)"` | Config reading or error reporting may change |
| `re` | Python standard library | `re.fullmatch`, `re.match`, `re.search` are used to parse YAML keys/scalars and detect commented `basic_auth` | The config parser may accept/reject different YAML or comments |
| `sys` | Python standard library | `sys.argv[1]` supplies config path; `sys.exit(1)` in `refuse()` | Input path or exit behavior may change |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `install-hermes.sh` status probe | outbound HTTP request / inbound HTTP response | HTTP over TCP to loopback | `GET /api/status`, no body; evaluates `-w '%{http_code}'` | `hermes` gateway started by `"$VENV/bin/hermes" serve --host 0.0.0.0 --port "$PORT" --skip-build` |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| Script `--check` mode | `scripts/harness/install-hermes.sh --check` | `HERMES: PASS` exit 0, or `HERMES: FAIL ($FAILED)` exit 1 | **UNKNOWN — no recorded run** | **RED** |

## 4. Metrics emitted

**NONE FOUND** — this is a RED field. Dispatch rate, latency, failure counts and liveness are all unanswerable without reading `lib.sh` or grepping logs. The script only increments `$FAILED` from `lib.sh` and prints `HERMES: PASS`
