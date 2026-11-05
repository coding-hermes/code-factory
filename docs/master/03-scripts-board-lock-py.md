# 03. scripts/board_lock.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/board_lock.py` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: **UNKNOWN**. The source says the adjudicator makes board-lock classification “re-runnable instead of hand-derived by every tick” (`file:7-8`), but it does not name a downstream consumer that fails in its absence.
- What breaks if it lies: **UNKNOWN**. The source defines HELD only when a live holder is proven (`file:10-14`) and RESIDUE otherwise (`file:16-19`); a false classification would contradict those definitions, but no specific blast radius is stated.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `__future__.annotations` | UNKNOWN | Imported at `file:33` | UNKNOWN — plain import at `file:33` |
| `argparse` | UNKNOWN | Imported at `file:35` | UNKNOWN — plain import at `file:35` |
| `errno` | UNKNOWN | Imported at `file:36` | UNKNOWN — plain import at `file:36` |
| `fcntl` | UNKNOWN | Imported at `file:37` | UNKNOWN — plain import at `file:37` |
| `os` | UNKNOWN | Imported at `file:38` | UNKNOWN — plain import at `file:38` |
| `re` | UNKNOWN | Imported at `file:39` | UNKNOWN — plain import at `file:39` |
| `subprocess` | UNKNOWN | Imported at `file:40` | UNKNOWN — plain import at `file:40` |
| `sys` | UNKNOWN | Imported at `file:41` | UNKNOWN — plain import at `file:41` |
| `pathlib` | UNKNOWN | Imported at `file:42` | UNKNOWN — plain import at `file:42` |
| `git` executable | UNKNOWN | Invoked as `"git"` at `file:129`; must be runnable via `subprocess.run` | `commits_after_mtime()` returns `"unknown"` on `OSError` or `subprocess.SubprocessError` (`file:142-143`) and on non-zero return code (`file:144-145`) |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `__future__` | UNKNOWN | `annotations` import enables deferred annotation evaluation (`file:33`) | UNKNOWN |
| `argparse` | UNKNOWN | `ArgumentParser(description=...)` (`file:162-164`), `add_argument("path", ...)` (`file:165-170`), `parse_args()` (`file:171`) provide CLI path parsing/defaulting | CLI parsing or default path behavior may change |
| `errno` | UNKNOWN | `errno.EWOULDBLOCK` and `errno.EAGAIN` identify flock contention (`file:88`) | Held-lock detection may fail |
| `fcntl` | UNKNOWN | `fcntl.flock(fd, fcntl.LOCK_EX \| fcntl.LOCK_NB)` probes non-blocking exclusive flock (`file:86`); `fcntl.flock(fd, fcntl.LOCK_UN)` releases it (`file:91`) | HELD/flock-eagain detection changes |
| `os` | UNKNOWN | `os.path.realpath` (`file:51`, `file:67`), `os.getpid` (`file:52`), `os.listdir` (`file:59`), `os.readlink` (`file:64`), `os.open` (`file:81`), `os.close` (`file:94`), `os.stat` (`file:126`) provide process/filesystem probes | Holder detection, flock probe, or mtime reading may fail |
| `pathlib` | UNKNOWN | `Path` (`file:44-45`), `exists` (`file:150`), `parent` (`file:131`), `expanduser` (`file:172`), `glob` (`file:100`), `rglob` (`file:104`), `open` (`file:112`), `iterdir` (`file:54`), `is_file` (`file:101`, `file:105`), `is_dir` (`file:103`) provide path handling | Path resolution and file scanning may change |
| `re` | UNKNOWN | `re.compile(rb"flock\|fcntl")` compiles a byte regex (`file:46`); `.search(line)` scans each line (`file:113`) | `consumer_count()` results change |
| `subprocess` | UNKNOWN | `subprocess.run(["git", ...], capture_output=True, timeout=30, check=False)` runs `git log` and captures stdout/stderr (`file:125-141`) | Commit counting or timeout behavior changes |
| `sys` | UNKNOWN | `sys.exit(main())` exits with `main()` return code (`file:177`) | Script exit status changes |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| **UNKNOWN** | — | — | — | **RED** |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| — | **no check exists** | — | — | **RED** |

## 4. Metrics emitted

**NONE FOUND** — this is a RED field. The source prints verdicts to stdout (`file:172`) but contains no metrics, counters, or telemetry references. Dispatch rate, latency, failure counts and liveness are not present in this file.

## 5. Log lines it can generate

No logging calls are present in the source. The following stdout verdict lines are documented or constructed in the file; they are output, not log lines.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stdout | `ABSENT` | `lock.exists()` is false; `adjudicate()` returns `"ABSENT"` (`file:150-151`) | verdict output |
| stdout | `HELD holder=pid-1234` | `fd_holders()` returns a non-empty list; `adjudicate()` returns `f"HELD holder=pid-{holders[0]}"` (`file:152-154`) | verdict output |
| stdout | `HELD holder=flock-eagain` | `flock_probe()` returns `("held", "flock-eagain")`; `adjudicate()` returns `f"HELD holder={detail}"` (`file:88-89`, `file:155-157`) | verdict output |
| stdout | `RESIDUE consumers=<n> commits_after_mtime=<n\|unknown>` | no fd holder and no flock held; `adjudicate()` returns the residue f-string (`file:155-158`) | verdict output |

## 6
