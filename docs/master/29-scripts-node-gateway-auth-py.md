# 29. scripts/node_gateway_auth.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/node_gateway_auth.py` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: `dashboard.basic_auth` would not be ensured on a fresh node; the source docstring says a Hermes gateway refuses to bind `0.0.0.0` without it and no create-path stage writes it, so `NODE: PASS` is unreachable (`scripts/node_gateway_auth.py:4-7`). The script “adds the block when it is absent and leaves an existing one untouched” (`scripts/node_gateway_auth.py:6`).
- What breaks if it lies: **UNKNOWN** (it is a self-reporting script that prints `PASS`/`FAIL`; the source provides no independent verification of the reported config state).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `os` | UNKNOWN | importable as `os` (`scripts/node_gateway_auth.py:17`) | UNKNOWN |
| `secrets` | UNKNOWN | importable as `secrets` (`scripts/node_gateway_auth.py:18`) | UNKNOWN |
| `sys` | UNKNOWN | importable as `sys` (`scripts/node_gateway_auth.py:19`) | UNKNOWN |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `os` | `os` module imported at `scripts/node_gateway_auth.py:17` | `os.makedirs(os.path.dirname(password_file) or ".", exist_ok=True)` at `scripts/node_gateway_auth.py:64`; `os.open(password_file, os.O_WRONLY \| os.O_CREAT \| os.O_TRUNC, 0o600)` at `scripts/node_gateway_auth.py:65`; `os.fdopen(fd, "w")` at `scripts/node_gateway_auth.py:66`; `os.chmod(password_file, 0o600)` and `os.chmod(tmp, 0o600)` at `scripts/node_gateway_auth.py:68,82`; `os.replace(tmp, config)` at `scripts/node_gateway_auth.py:83` | UNKNOWN |
| `secrets` | `secrets` module imported at `scripts/node_gateway_auth.py:18` | `secrets.token_urlsafe(24)` at `scripts/node_gateway_auth.py:63` | UNKNOWN |
| `sys` | `sys` module imported at `scripts/node_gateway_auth.py:19` | `sys.stderr` at `scripts/node_gateway_auth.py:33,45,59`; `sys.argv[1:]` at `scripts/node_gateway_auth.py:95`; `sys.exit` at `scripts/node_gateway_auth.py:95` | UNKNOWN |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| **UNKNOWN** | — | — | — | **RED** |

No service call or network import is visible in the source; the script only opens local files (`scripts/node_gateway_auth.py:16-95`).

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| — | **no check exists** | — | — | **RED** |

## 4. Metrics emitted

**NONE FOUND** — the source only prints stdout/stderr lines and writes the password/config files (`scripts/node_gateway_auth.py:45-90`). Metric questions remain a RED field.

## 5. Log lines it can generate

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| ? | `usage: node_gateway_auth.py <config.yaml> <password-file> [username]` | `len(argv) < 2` at `scripts/node_gateway_auth.py:30-35`; written to `sys.stderr` | usage / stderr |
| ? | `FAIL  gateway_auth — cannot read {config} ({exc})` | `OSError` opening `config` at `scripts/node_gateway_auth.py:44-45`; written to `sys.stderr`; returns 1 | error / stderr |
| ? | `PASS  gateway_auth — dashboard.basic_auth already present in {config}` | an existing `dashboard:` block whose next 8 lines contain `basic_auth:` at `scripts/node_gateway_auth.py:48-55`; written to stdout | success / stdout |
| ? | `FAIL  gateway_auth — {config}:{idx + 1} has a dashboard block without basic_auth; left untouched (a human must reconcile it)` | an existing `dashboard:` block without `basic_auth:` at `scripts/node_gateway_auth.py:56-61`; written to `sys.stderr`; returns 2 | error / stderr |
| ? | `PASS  gateway_auth — added dashboard.basic_auth (user {username}) to {config}` | after adding `dashboard.basic_auth` and replacing the config at `scripts/node_gateway_auth.py:85-87`; written to stdout | success / stdout |
| ? | `PASS  gateway_auth — password stored at {password_file}, mode 600 (not printed)` | after writing/replacing the config at `scripts/node_gateway_auth.py:88-90`; written to stdout | success / stdout |

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Missing required CLI arguments (`len(argv) < 2`) | `usage: node_gateway_auth.py <config.yaml> <password-file> [username]` on stderr; exit 2 (`scripts/node_gateway_auth.py:30-35`) | Distinct usage message; no file read is attempted | Rerun with `<config.yaml> <password-file> [username]` as shown in the usage line |
| `OSError` reading config, other than `FileNotFoundError` | `FAIL  gateway_auth — cannot read {config} ({exc})` on stderr; exit 1 (`scripts/node_gateway_auth.py:44-46`) | `FileNotFoundError` is caught separately and treated as `lines = []` (`scripts/node_gateway_auth.py:42-43`) | UNKNOWN |
| Existing `dashboard:` block without `basic_auth:` | `FAIL  gateway_auth — {config}:{idx + 1} has a dashboard block without basic_auth; left untouched (a human must reconcile it)` on stderr; exit 2 (`scripts/node_gateway_auth.py:56-61`) | Distinct from absent `dashboard:` (which is added) and from existing `basic_auth:` (which passes) | Source says “a human must reconcile it” (`scripts/node_gateway_auth.py:58`) |

## 7. Environment and settings it reads

- No environment variables are read in the source.
- Reads CLI arguments via `sys.argv[1:]` at `scripts/node_gateway_auth.py:95`; positional values are `config` = `argv[0]`, `password_file` = `argv[1]`, and optional `username` = `argv[2]` or default `"node"` at `scripts/node_gateway_auth.py:36-37`.
- Reads the file named by the first CLI argument with `open(config)` at `scripts/node_gateway_auth.py:40`, if it exists; `FileNotFoundError` is treated as empty input (`lines = []` at `scripts/node_gateway_auth.py:42-43`).
- The password file path is used only as an output path; it is created/written at mode `600` and never read (`scripts/node_gateway_auth.py:64-68`).

## 8. Evidence of record

- none yet
