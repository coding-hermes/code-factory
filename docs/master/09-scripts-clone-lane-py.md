# 09. scripts/clone_lane.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/clone_lane.py` [scripts/clone_lane.py:1] |
| Repository | `code-factory` [scripts/clone_lane.py:1] |
| Revision | **UNKNOWN** — the source does not expose a revision [scripts/clone_lane.py:1-92] |
| Status | **RED — no execution evidence is recorded here** [scripts/clone_lane.py:1-92] |

## 1. Purpose and why it matters

- What it does: reads a source row from the SQLite `projects` table, applies lane-specific overrides, and inserts or updates the destination row [scripts/clone_lane.py:32-59] [scripts/clone_lane.py:64-81].
- Why this exists: the module docstring says the scheduler lane-onboarding gate refuses recognized families without a workdir root, and that cloning a live row is the way to give a new project the same shape [scripts/clone_lane.py:2-7].
- What breaks if this module is absent: **UNKNOWN** — the source describes the onboarding condition but does not show the downstream scheduler failure or an alternative implementation [scripts/clone_lane.py:4-7].
- What breaks if it lies: **UNKNOWN** — this source does not define an independent consumer-side check of the printed outcome [scripts/clone_lane.py:64-88].

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| Python 3 interpreter | **UNKNOWN** | The executable header invokes `python3` [scripts/clone_lane.py:1] | **UNKNOWN** — no preflight check is implemented [scripts/clone_lane.py:22-92] |
| SQLite database | **UNKNOWN** | `~/.hermes/coding-hermes/scheduler.db` is the connection target [scripts/clone_lane.py:19] | Connection or SQL failure may surface from the unguarded database operations; the exact presentation is **UNKNOWN** [scripts/clone_lane.py:32-36] [scripts/clone_lane.py:64-81] |
| Source lane row | **UNKNOWN** | `projects.name` must match `--from` [scripts/clone_lane.py:24] [scripts/clone_lane.py:36-38] | Missing source exits with the source-lane error [scripts/clone_lane.py:36-38] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `argparse` | Python import named `argparse` [scripts/clone_lane.py:14] | Builds a parser, requires `--from`, `--to`, `--workdir`, `--namespace`, and `--parent`, and accepts optional `--prompt` [scripts/clone_lane.py:23-30] | **UNKNOWN** — no compatibility check is shown [scripts/clone_lane.py:22-30] |
| `os` | Python import named `os` [scripts/clone_lane.py:15] | Expands the database path and the hard-coded local repository path [scripts/clone_lane.py:19] [scripts/clone_lane.py:51] | **UNKNOWN** — no compatibility check is shown [scripts/clone_lane.py:15-19] [scripts/clone_lane.py:51] |
| `sqlite3` | Python import named `sqlite3` [scripts/clone_lane.py:16] | Opens the database, sets a busy timeout and row factory, executes parameterized lookups, writes a row, commits, and reads back selected fields [scripts/clone_lane.py:32-34] [scripts/clone_lane.py:36-40] [scripts/clone_lane.py:64-88] | **UNKNOWN** — no compatibility check is shown [scripts/clone_lane.py:16] [scripts/clone_lane.py:32-88] |
| `time` | Python import named `time` [scripts/clone_lane.py:17] | Produces UTC `created_at` and `updated_at` strings in `%Y-%m-%dT%H:%M:%SZ` format [scripts/clone_lane.py:57-58] | **UNKNOWN** — no compatibility check is shown [scripts/clone_lane.py:17] [scripts/clone_lane.py:57-58] |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| SQLite `projects` table in `~/.hermes/coding-hermes/scheduler.db` [scripts/clone_lane.py:19] | `clone_lane.py` reads and writes rows [scripts/clone_lane.py:32-88] | SQLite connection [scripts/clone_lane.py:32] | A cloned project row with destination name, workdir, namespace, parent, disabled state, local repo URL, prompt mode, tick fields, failure count, timestamps, and optional prompt contents [scripts/clone_lane.py:44-62] | **UNKNOWN** — this source names no consuming file:function; **RED** [scripts/clone_lane.py:32-88] |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| Argument surface only | `python3 scripts/clone_lane.py --help` [scripts/clone_lane.py:1] | **UNKNOWN** — the source defines the parser but does not record help output [scripts/clone_lane.py:23-30] | **UNKNOWN** — no run record is present in the source [scripts/clone_lane.py:1-92] | **RED** |
| Database mutation and readback | `python3 scripts/clone_lane.py --from SOURCE --to DEST --workdir WORKDIR --namespace NAMESPACE --parent PARENT [--prompt PROMPT]` [scripts/clone_lane.py:9-11] | A commit is attempted and a selected destination row is printed after the write [scripts/clone_lane.py:64-88] | **UNKNOWN** — no run record is present in the source [scripts/clone_lane.py:1-92] | **RED** |
| Dedicated `--check` mode | **UNKNOWN** — no `--check` argument is defined [scripts/clone_lane.py:23-30] | **UNKNOWN** | **UNKNOWN** | **RED** [scripts/clone_lane.py:22-30] |

## 4. Metrics emitted

- No metric counter, histogram, exporter, or explicit latency measurement is present; the source emits operational `print` calls instead [scripts/clone_lane.py:40] [scripts/clone_lane.py:73] [scripts/clone_lane.py:80] [scripts/clone_lane.py:88].
- Dispatch rate, failure counts, and liveness are **UNKNOWN** from this source [scripts/clone_lane.py:22-92].

## 5. Log lines it can generate

- `print(f"{a.dst} already exists — configuring it instead of creating")` [scripts/clone_lane.py:39-40]
- `print(f"created {a.dst} (cloned from {a.src})")` [scripts/clone_lane.py:69-73]
- `print(f"configured {a.dst}")` [scripts/clone_lane.py:75-80]
- `print("  ", dict(r))` [scripts/clone_lane.py:83-88]

The source does not show a logger, log level, destination, or retention policy; those are **UNKNOWN** [scripts/clone_lane.py:14-17] [scripts/clone_lane.py:22-92].

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Source lane is absent | `raise SystemExit(f"source lane {a.src} not found")` [scripts/clone_lane.py:36-38] | **UNKNOWN** — no separate failure classification is shown [scripts/clone_lane.py:36-38] | **UNKNOWN** — no recovery routine is shown [scripts/clone_lane.py:22-38] |
| Required CLI argument is absent | Parser-level failure from a required argument declaration [scripts/clone_lane.py:23-30] | **UNKNOWN** — exact rendered argparse text is not shown | Supply the missing argument and rerun; no in-process recovery is shown [scripts/clone_lane.py:23-30] |
| Destination lane already exists | `print(f"{a.dst} already exists — configuring it instead of creating")`; the existing row is updated rather than inserted [scripts/clone_lane.py:39-44] [scripts/clone_lane.py:65-80] | **UNKNOWN** — no distinct exit status is defined [scripts/clone_lane.py:39-80] | **UNKNOWN** — no rollback or recovery routine is shown [scripts/clone_lane.py:64-81] |
| Prompt file cannot be read | The source calls `open(a.prompt).read()` when `--prompt` is supplied [scripts/clone_lane.py:61-62] | Exact exception and output are **UNKNOWN** — the call is not caught here [scripts/clone_lane.py:61-62] | **UNKNOWN** — no recovery routine is shown [scripts/clone_lane.py:61-62] |
| Database connection, SQL, insert/update, or commit failure | **UNKNOWN** — database operations are not wrapped in a local exception handler [scripts/clone_lane.py:32-36] [scripts/clone_lane.py:64-81] | **UNKNOWN** — the source defines no error taxonomy [scripts/clone_lane.py:32-81] | **UNKNOWN** — no rollback or retry path is shown [scripts/clone_lane.py:32-81] |

## 7. Environment and settings it reads

- Database path: `DB = os.path.expanduser("~/.hermes/coding-hermes/scheduler.db")` [scripts/clone_lane.py:19].
- Local repository URL written into the row: `f"local:{os.path.expanduser('~/code-factory')}"` [scripts/clone_lane.py:51].
- Required settings: `--from`, `--to`, `--workdir`, `--namespace`, and `--parent`; optional setting: `--prompt` [scripts/clone_lane.py:24-30].
- Prompt setting effect: when present, the file named by `--prompt` is read in full and assigned to the row's `prompt` field [scripts/clone_lane.py:61-62].
- No environment-variable lookup is shown in this source; any other environment contract is **UNKNOWN** [scripts/clone_lane.py:14-19] [scripts/clone_lane.py:22-92].

## 8. Evidence of record

- The mutation is committed with `con.commit()` [scripts/clone_lane.py:81].
- After the commit, the script selects `name`, `namespace_id`, `admission_mode`, `cooldown_floor_s`, `parent`, and `length(prompt)` for the destination row and prints the resulting row [scripts/clone_lane.py:83-88].
- No independent run receipt, digest, exit-status record, or external consumer check is shown; those are **UNKNOWN** [scripts/clone_lane.py:22-92].
- Section status remains **RED** until a re-runnable check and its result are recorded [scripts/clone_lane.py:22-30].
