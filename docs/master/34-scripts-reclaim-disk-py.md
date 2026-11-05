# 34. scripts/reclaim_disk.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/reclaim_disk.py` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: fixed user-space caches and expired node job/clone directories are not reaped by this script. The docstring says `Reap only fixed user-space caches and expired node job/clone directories.` (`file:2`). The reclaim function iterates `BUILD_CACHES` and `AGED_PARENTS` (`file:102-111`).
- What breaks if it lies: **UNKNOWN** — downstream consumers of the returned `reclaimed_bytes`, `reclaimed_mib`, and `entries` summary are not shown in this source (`file:120-125`), so the impact of inaccurate reporting cannot be established from this file.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| None identified; imports are standard-library modules only (`file:6-12`) | — | Python standard library | Python import failure at startup; no explicit check in this source |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `__future__` | — | Imported at `file:4`; enables annotations support | **UNKNOWN** |
| `argparse` | — | CLI definition: `ArgumentParser`, `add_subparsers`, `add_parser`, `add_argument`, `parse_args` (`file:130-138`) | **UNKNOWN** |
| `json` | — | Serialises result via `json.dumps(result)` (`file:164`) | **UNKNOWN** |
| `math` | — | Validates job TTL with `math.isfinite` (`file:46`) | **UNKNOWN** |
| `os` | — | Resolves real paths with `os.path.realpath` (`file:27`, `file:43`) | **UNKNOWN** |
| `pathlib` | — | `Path` objects and filesystem operations throughout (`file:10`; usage examples `file:27-38`, `file:43-77`) | **UNKNOWN** |
| `sys` | — | `sys.stderr` for error output (`file:145`); `sys.exit(main())` entrypoint (`file:168-169`) | **UNKNOWN** |
| `time` | — | Current epoch with `time.time()` (`file:49`); mtime-based age calculation (`file:90-91`) | **UNKNOWN** |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| **UNKNOWN** | — | — | — | **RED** |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| — | **no check exists** | — | — | **RED** |

## 4. Metrics emitted

No dispatch rate, latency, failure-count, or liveness metric is emitted continuously by this source.

The script can emit a one-shot JSON result when `--json` is passed (`file:137`, `file:163-164`) containing:

- `root`, `reclaimed_bytes`, `reclaimed_mib`, `job_ttl_hours`, `entries` (`file:120-125`)

The human-readable stdout output includes one line per entry and a “nothing to reclaim” note when `reclaimed_bytes` is zero (`file:160-162`).

## 5. Log lines it can generate

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stdout | `  note reclaim — nothing to reclaim` | when `not result["reclaimed_bytes"]` is true / zero bytes reclaimed (`file:161-162`) | descriptive |

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| `--root` resolves to `/` or is not a directory | `ValueError("root must be a directory other than /")` (`file:44-45`); `main` prints `reclaim: <exc>` to stderr and returns `2` (`file:144-146`) | Invalid TTL; filesystem `OSError` (`file:46-47`, `file:144-146`) | Correct `--root` and rerun; no automatic recovery in source |
| `--job-ttl-hours` is non-finite or negative | `ValueError("job TTL must be finite and nonnegative")` (`file:46-47`); `main` returns `2` (`file:144-146`) | Invalid root; filesystem `OSError` | Correct `--job-ttl-hours` and rerun |
| Target path is symlink/outside root/protected | `safety_reason` returns `skipped:symlink`, `skipped:outside-root`, or `skipped:protected` (`file:27-38`); entry recorded as `skipped` with `bytes` 0 (`file:64-66`, `file:84-85`) | Action `absent` (`file:86-87`) or `kept` for fresh object (`file:90-92`) | Intentional safety skip; no recovery needed |
| Filesystem `OSError` during traversal/stat/unlink/rmdir | `OSError` propagates from filesystem operations (`file:70-79`) to `main`, which prints to stderr and returns `2` (`file:144-146`) | `ValueError` validation failures | Manual intervention; source does not retry or identify the failing path |
| Partial removal: some children cannot be removed | `remove` returns `complete = False`, so entry is recorded as `kept` rather than `reaped` (`file:69-76`, `file:98`) | Complete reaping, where action is `reaped` (`file:98`) | Manual inspection of remaining contents |

## 7. Environment and settings it reads

No environment variables are read in this source.

CLI settings:

- `targets` subcommand has no additional args (`file:132`)
- `run --root` is required (`file:134`)
- `run --job-ttl-hours` is a float defaulting to `24` (`file:135`; function default also `job_ttl_hours: float = 24` at `file:42`)
- `run --dry-run` is a boolean flag (`file:136`)
- `run --json` is a boolean flag (`file:137`)

Built-in constants:

- `BUILD_CACHES` (`file:14-20`)
- `AGED_PARENTS` (`file:21`)
- `PROTECTED` (`file:22`)

## 8. Evidence of record

- none yet
