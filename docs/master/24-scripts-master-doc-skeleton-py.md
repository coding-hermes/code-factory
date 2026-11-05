# 24. scripts/master_doc_skeleton.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/master_doc_skeleton.py` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: The master-document skeleton under `/home/kara/code-factory/docs/master` is not generated; `OUT.mkdir(parents=True, exist_ok=True)` and `fn.write_text(section(i, title, p, repo, r), encoding="utf-8")` never run. The script’s stated job is `"Build the 40-module master-document skeleton from the repositories."`
- What breaks if it lies: The skeleton’s central claim that **RED** means “no evidence yet” becomes false. The script states `"Every **RED** is a claim that has no evidence yet"` and `"A section turns green by running a command, never by editing prose."` If this module lies, unverified fields could be presented as verified, and operators cannot trust the generated skeleton.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `git` | unknown | On `PATH` of the machine running the script; invoked as `subprocess.run(["git", "-C", repo, "rev-parse", "--short", "HEAD"], ...)` | `rev()` returns `"unknown"` via `except Exception: return "unknown"`; missing `git` does not crash the script but revision becomes `"unknown"` |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `json` | Python 3 stdlib | `json.dumps` serializes the final summary dict to JSON for stdout: `print(json.dumps({"modules": len(entries), "out": str(OUT), "red_fields": len(entries) * 4}))` | The final stdout shape changes; any consumer of that JSON breaks |
| `re` | Python 3 stdlib | Provides regex compilation and matching/substitution: `SKIP = re.compile(...)`, `re.findall(...)`, and `re.sub(...)` in `section` | Module discovery or derived dependency/log output can silently change |
| `subprocess` | Python 3 stdlib | `subprocess.run` runs the `git` command with `capture_output=True`, `text=True`, `errors="replace"`, `timeout=20` and returns `CompletedProcess` | Revision may become `"unknown"` if the call raises; if timeout behavior changes, runs may hang or fail differently |
| `pathlib.Path` | Python 3 stdlib | Filesystem traversal, existence checks, path relativity, text read/write, and directory creation: `Path`, `root.rglob("*")`, `p.is_file()`, `p.relative_to(root).as_posix()`, `path.read_text(...)`, `fn.write_text(...)`, `OUT.mkdir(...)` | File discovery, generated paths, or writes fail/change |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| **UNKNOWN** | — | — | — | **RED** |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| — | **no check exists** | — | — | **RED** |

## 4. Metrics emitted

**NONE FOUND** — this is a RED field. Dispatch rate, latency, failure counts and liveness are all unanswerable without reading code or grepping logs.

## 5. Log lines it can generate

**NONE DETECTED** — RED: an operator has nothing to read when this fails.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| `git` missing or `git rev-parse` fails in `rev()` | Repository revision becomes `"unknown"`; no exception is raised | A real commit hash that is literally `"unknown"` | Install/restore `git` on `PATH` and ensure repository is readable; rerun |
| A path in `REPOS` is missing/unreadable during `modules_for()` | That repository contributes no module entries; the generated index has fewer than 40 modules | A repository that genuinely has no `.go`, `.sh`, `.py`, or `specs/*.md` matching files | Check each `REPOS` path exists and is readable |
| Cannot create/write the output directory or file (`OUT.mkdir(parents=True, exist_ok=True)` or `fn.write_text(...)`) | Script crashes with `OSError`/`PermissionError` traceback | Other Python runtime exceptions | Ensure `/home/kara/code-factory/docs/master` is writable and disk is available |

## 7. Environment and settings it reads

| Variable | Default | Effect if unset |
|---|---|---|
| — | — | None read at runtime; the strings `API_`, `CRIER_`, `DISPATCH_`, `GITREINS_`, `HERMES_` appear only as prefix filters in `derive()` and are not environment lookups |

## 8. Evidence of record

- none yet
