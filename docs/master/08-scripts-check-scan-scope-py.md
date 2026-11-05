# 08. scripts/check_scan_scope.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/check_scan_scope.py` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: the posture-doc gate does not run; a scanned doc line can contain `gitleaks` without `--log-opts` on the same line, so a green claim does not define the revision range it scanned (`/home/kara/code-factory/scripts/check_scan_scope.py:4-11`, `/home/kara/code-factory/scripts/check_scan_scope.py:76-78`).
- What breaks if it lies: the process can print `RESULT: OK` and exit `0` even though a `gitleaks` claim has no `--log-opts`, because the gate is the only signal; this would accept unscoped posture claims (`/home/kara/code-factory/scripts/check_scan_scope.py:106-114`).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| Python standard-library modules `argparse`, `sys`, `pathlib` | **UNKNOWN** — not pinned in source | Available to the Python interpreter running the script (`/home/kara/code-factory/scripts/check_scan_scope.py:27-29`) | **UNKNOWN** — source has no explicit presence check |
| `__future__.annotations` | **UNKNOWN** — not pinned in source | Supported by the Python compiler (`/home/kara/code-factory/scripts/check_scan_scope.py:25`) | **UNKNOWN** — source has no explicit presence check |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `__future__` | Python future statement | `annotations` import (`/home/kara/code-factory/scripts/check_scan_scope.py:25`) | **UNKNOWN** — source defines no fallback |
| `argparse` | Python standard library | `ArgumentParser`, `add_argument("root", nargs="?", default=None, help=...)`, `parse_args(argv)` (`/home/kara/code-factory/scripts/check_scan_scope.py:73-87`) | Optional `root` argument parsing may break |
| `pathlib` | Python standard library | `Path`, `.glob`, `.exists`, `.read_text`, `.relative_to`, `.as_posix`, `.resolve`, `.parent`, `.is_dir` (`/home/kara/code-factory/scripts/check_scan_scope.py:29,41-47,58-63,89-92`) | File discovery and reading may break |
| `sys` | Python standard library | `sys.exit(main())` (`/home/kara/code-factory/scripts/check_scan_scope.py:117-118`) | Exit-code propagation may break |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| **NONE IDENTIFIED** | — | — | — | — |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| — | **no check exists** | — | — | **RED** |

## 4. Metrics emitted

**NONE FOUND** — the source only prints gate result lines; no dispatch rate, latency, failure counts, or liveness metrics are emitted (`/home/kara/code-factory/scripts/check_scan_scope.py:92-113`).

## 5. Log lines it can generate

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| — | `  FAIL  audit-scope: {root} is not a readable directory` | `root.is_dir()` is false before `scan`; exits `2` (`/home/kara/code-factory/scripts/check_scan_scope.py:92-95`) | result/output |
| — | `RESULT: FAIL (unreadable path)` | An unreadable root or scanned file path is detected; exits `2` (`/home/kara/code-factory/scripts/check_scan_scope.py:94-95,100-101`) | result/output |
| — | `  FAIL  audit-scope: {exc}` | `scan()` raises `UnreadablePath`; exits `2` (`/home/kara/code-factory/scripts/check_scan_scope.py:98-101`) | result/output |
| — | `  FAIL  audit-scope: {relpath}:{lineno} gitleaks claim names no {SCOPE_FLAG}` | A scanned line contains `gitleaks` but not `--log-opts` (`/home/kara/code-factory/scripts/check_scan_scope.py:64-68,102-105`) | result/output |
| — | `RESULT: FAIL ({len(violations)} violation(s))` | Any violation exists; exits `1` (`/home/kara/code-factory/scripts/check_scan_scope.py:106-108`) | result/output |
| — | `  OK  audit-scope: no posture docs found` | No scanned files matched (`/home/kara/code-factory/scripts/check_scan_scope.py:109-110`) | result/output |
| — | `  OK  audit-scope: {claims} gitleaks claim(s) name their {SCOPE_FLAG}` | Files were scanned and all claims have `--log-opts` (`/home/kara/code-factory/scripts/check_scan_scope.py:111-112`) | result/output |
| — | `RESULT: OK` | Clean run; exits `0` (`/home/kara/code-factory/scripts/check_scan_scope.py:113-114`) | result/output |

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Repo root is not a readable directory | `  FAIL  audit-scope: {root} is not a readable directory` then `RESULT: FAIL (unreadable path)`, exit `2` (`/home/kara/code-factory/scripts/check_scan_scope.py:92-95`) | Root check happens before scanning; message names `{root}` and says `is not a readable directory` (`/home/kara/code-factory/scripts/check_scan_scope.py:92-93`) | Provide a repo root that exists and is a directory (`/home/kara/code-factory/scripts/check_scan_scope.py:88-92`) |
| A scanned posture file cannot be read | `  FAIL  audit-scope: {relpath} unreadable ({exc})` then `RESULT: FAIL (unreadable path)`, exit `2` (`/home/kara/code-factory/scripts/check_scan_scope.py:60-63,98-101`) | `UnreadablePath` is raised from `OSError` during `Path.read_text`, after the root directory check passes (`/home/kara/code-factory/scripts/check_scan_scope.py:60-63`) | Fix permissions or path so the file can be read (`/home/kara/code-factory/scripts/check_scan_scope.py:61`) |
| Posture
