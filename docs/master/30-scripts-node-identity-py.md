# 30. scripts/node_identity.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/node_identity.py` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: The merge protection is absent; a provisioner that rewrote `$HOME/.node/node.json` with its own flat schema would silently delete fields written by `project-node.sh` and break every consumer (`/home/kara/code-factory/scripts/node_identity.py:10-14`). The atomic mode-600 write is also absent (`/home/kara/code-factory/scripts/node_identity.py:14`).
- What breaks if it lies: **UNKNOWN** (every self-reporting component has this failure mode).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `json` | UNKNOWN | Imported at `/home/kara/code-factory/scripts/node_identity.py:20` | UNKNOWN |
| `os` | UNKNOWN | Imported at `/home/kara/code-factory/scripts/node_identity.py:21` | UNKNOWN |
| `sys` | UNKNOWN | Imported at `/home/kara/code-factory/scripts/node_identity.py:22` | UNKNOWN |
| `tempfile` | UNKNOWN | Imported at `/home/kara/code-factory/scripts/node_identity.py:23` | UNKNOWN |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `json` | Python standard library (`/home/kara/code-factory/scripts/node_identity.py:20`) | `json.load(fh)` reads the existing object (`/home/kara/code-factory/scripts/node_identity.py:67`); `json.dump(doc, fh, indent=1, sort_keys=True)` writes the merged object (`/home/kara/code-factory/scripts/node_identity.py:92`) | **UNKNOWN** |
| `os` | Python standard library (`/home/kara/code-factory/scripts/node_identity.py:21`) | Filesystem/path operations: `os.path.exists`, `os.path.dirname`, `os.path.abspath`, `os.makedirs(..., exist_ok=True)`, `os.fdopen`, `os.chmod(tmp, 0o600)`, `os.replace(tmp, path)`, `os.unlink(tmp)` (`/home/kara/code-factory/scripts/node_identity.py:64,87-95,98`) | **UNKNOWN** |
| `sys` | Python standard library (`/home/kara/code-factory/scripts/node_identity.py:22`) | `sys.stderr` for diagnostics (`/home/kara/code-factory/scripts/node_identity.py:53,60,73,84`); `sys.exit(main(...))` for process return code (`/home/kara/code-factory/scripts/node_identity.py:111`) | **UNKNOWN** |
| `tempfile` | Python standard library (`/home/kara/code-factory/scripts/node_identity.py:23`) | `tempfile.mkstemp(dir=directory)` returns an fd and temp path in the target directory (`/home/kara/code-factory/scripts/node_identity.py:89`) | **UNKNOWN** |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| None detected | — | — | — | `/home/kara/code-factory/scripts/node_identity.py:20-111` shows only local file and stdlib operations |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| — | **no check exists** | — | — | **RED** |

## 4. Metrics emitted

**NONE FOUND** — no dispatch rate, latency, failure counts, or liveness output appears in the source; only exit-code-bearing `PASS`/`FAIL`/usage diagnostics are printed (`/home/kara/code-factory/scripts/node_identity.py:53,60,73,84,104,106`). **RED**.

## 5. Log lines it can generate

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stderr (no log level) | `usage: node_identity.py <path> key=value [key=value ...]` | `len(argv) < 2` (`/home/kara/code-factory/scripts/node_identity.py:51-55`) | usage diagnostic |
| stderr (no log level) | `FAIL  identity — argument is not key=value: {p}` | argument has no `=` or has an empty key (`/home/kara/code-factory/scripts/node_identity.py:58-61`) | error diagnostic |
| stderr (no log level) | `FAIL  identity — {path} is not a readable JSON object ({exc}); left untouched` | existing path cannot be read as a JSON object, or top level is not an object (`/home/kara/code-factory/scripts/node_identity.py:64-75`) | error diagnostic |
| stderr (no log level) | `FAIL  identity — {exc}` | `set_path` raises `ValueError`, e.g. an empty `key[]` declaration (`/home/kara/code-factory/scripts/node_identity.py:83-85`) | error diagnostic |
| stdout (no log level) | `PASS  identity — merged {', '.join(changed)} into {path}` | at least one key changed (`/home/kara/code-factory/scripts/node_identity.py:103-104`) | success diagnostic |
| stdout (no log level) | `PASS  identity — {path} already carries every value (unchanged)` | no keys changed (`/home/kara/code-factory/scripts/node_identity.py:105-106`) | success diagnostic |

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Existing path is unreadable JSON or top level is non-object | `FAIL  identity — {path} is not a readable JSON object ({exc}); left untouched` on stderr; exit code 1 (`/home/kara/code-factory/scripts/node_identity.py:70-75`) | Bad arguments return exit code 2; write failures raise uncaught exceptions | Repair or remove the file, or make its top level a JSON object |
| Bad argument / usage | `usage: node_identity.py <path> key=value [key=value ...]` on stderr; exit code 2 (`/home/kara/code-factory/scripts/node_identity.py:51-55`), or `FAIL  identity — argument is not key=value: {p}`; exit code 2 (`/home/kara/code-factory/scripts/node_identity.py:58-61`) | Unreadable existing file returns exit code 1; write failure raises a traceback | Provide `<path>` and valid `key=value` pairs |
| Empty `key[]` declaration | `FAIL  identity — {exc}` where `{exc}` is `"{dotted}[] was declared empty"`; exit code 2 (`/home/kara/code-factory/scripts/node_identity.py:30-33,83-85`) | Other bad-argument and file-read failures | Supply at least one non-empty comma-separated item |
| Directory creation, temp-file write, `chmod`, or `replace` failure | Uncaught exception; code attempts `os.unlink(tmp)` then re-raises (`/home/kara/code-factory/scripts/node_identity.py:87-101`) | `PASS`/`FAIL` branches return 0/1/2; this bypasses them | **UNKNOWN** |

## 7. Environment and settings it reads

**NONE DETECTED** — the code reads no environment variables or config files; it uses only command-line arguments (`/home/kara/code-factory/scripts/node_identity.py:50-57`) and the path argument (`/home/kara/code-factory/scripts/node_identity.py:56`). The docstring mentions `$HOME/.node/node.json`, but the script itself receives the file path as `argv[0]` (`/home/kara
