# 09. scripts/clone_lane.py

| Field | Value |
|---|---|
| Path | `~/code-factory/scripts/clone_lane.py` [scripts/clone_lane.py:1] |
| Repository | `code-factory` |
| Revision | `83b2194` — the tree every locator below resolves against. The file itself last changed in `29e8e5e` (2026-10-29); `git diff HEAD -- scripts/clone_lane.py` prints nothing and `git hash-object` reads `713bd54` [scripts/clone_lane.py:1-92] |
| Status | **VERIFIED — script behaviour measured in 22 cases on 2026-11-05 against a fixture DB built from the live schema; one peer claim (the scheduler's acceptance of the cloned row) stays RED in §2c because it needs the live scheduler and a live lane** |

It is the only in-tree writer that `INSERT`s a lane row: `grep -rn "INSERT INTO projects" scripts/`
returns exactly one line, the statement at [scripts/clone_lane.py:70]. Every other lane script
`UPDATE`s rows that already exist [scripts/configure_family.py:178]
[scripts/load_lane_config.py:34]. That asymmetry is what this module is for, and it is also where
its risk sits: it writes rows the onboarding gate never sees.

## 1. Purpose and why it matters

- What it does: reads the source row with `SELECT * FROM projects WHERE name=?`
  [scripts/clone_lane.py:36], copies every column into a dict, overwrites eleven of them
  [scripts/clone_lane.py:44-60], then either inserts a new row [scripts/clone_lane.py:68-73] or
  updates the existing one [scripts/clone_lane.py:74-80], commits [scripts/clone_lane.py:81] and
  prints a six-field readback [scripts/clone_lane.py:83-88]. Measured: the fixture's `projects`
  table has 73 columns and the clone carries 73 values (case E1).
- Why this exists: the scheduler's satellite-workdir gate refuses every candidate path for a family
  it recognises but has no root for, so a *new* lane in such a family cannot be created through the
  API at all; cloning an existing live row is the only way to give the new project the same shape
  [scripts/clone_lane.py:4-7]. The gate and its nine-family root table are documented at
  [docs/SCHEDULER-ADMISSION.md:8-14] and [docs/SCHEDULER-ADMISSION.md:20-30]; the refusal mode — a
  recognised family with no root rejecting every workdir — is spelled out at
  [docs/SCHEDULER-ADMISSION.md:32-35].
- What breaks if this module is absent: there is no in-tree way to create a lane row. Both measured
  alternatives are inadequate. `scripts/add_family_lanes.py` creates lanes through the API and treats
  a non-201 as a refusal it must report rather than route around — "If a lane is still refused, the
  fix is not live — say so, do not fall back to SQL" [scripts/add_family_lanes.py:2-5] — and it only
  `UPDATE`s afterwards [scripts/add_family_lanes.py:92]. `scripts/configure_family.py`
  [scripts/configure_family.py:178] and `scripts/load_lane_config.py`
  [scripts/load_lane_config.py:34] are `UPDATE`-only, so they cannot materialise a missing row. The
  README lists all four as the lane toolchain [README.md:116].
- What breaks if it lies: the success line claims existence, not validity, and the module cannot
  detect the difference. Measured (case C7): `--workdir /nonexistent/nope` produced
  `created totally-made-up-lane (cloned from crier-docs)`, exit 0. The onboarding checklist requires
  rejecting an off-root path *before any row is written* [docs/SCHEDULER-ADMISSION.md:73]; this
  module has no such check, so a green "created" line is evidence of a row and nothing more. The
  readback at [scripts/clone_lane.py:83-88] cannot expose the lie either: it selects the columns the
  script just wrote, on the same connection, so it reports the write, not the lane.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | measured `3.14.9` on the probe host; syntax floor read-from-code 3.6, because the only modern construct is the f-string [scripts/clone_lane.py:70] [scripts/clone_lane.py:77] | on `PATH`, resolved by the header [scripts/clone_lane.py:1] | outside the module: the shell fails before any code runs. In-module there is no version or interpreter check [scripts/clone_lane.py:22-30] — `--help` exits 0 with no database present at all (case A1) |
| `sqlite3` module and a matching schema | CPython stdlib; schema measured read-only from the live DB — 73 columns, `name TEXT PRIMARY KEY`, two secondary indexes, `namespace_id REFERENCES namespaces(id)` | `~/.hermes/coding-hermes/scheduler.db` [scripts/clone_lane.py:19] | measured: missing file → `sqlite3.OperationalError: unable to open database file` at [scripts/clone_lane.py:32] (C3); no `projects` table → `no such table: projects` at [scripts/clone_lane.py:36] (C4); read-only file → `attempt to write a readonly database` at [scripts/clone_lane.py:69] (C5). All three are bare tracebacks, exit 1 |
| source lane row | — | `projects.name` must equal `--from` [scripts/clone_lane.py:24] [scripts/clone_lane.py:36] | measured A4, exit 1: stderr `source lane no-such-lane not found` from [scripts/clone_lane.py:38] |
| prompt file | — | only when `--prompt` is given [scripts/clone_lane.py:29]; read whole at [scripts/clone_lane.py:62] | measured: `FileNotFoundError` (C1) and `PermissionError` (C2), exit 1 each, no row written |
| a writable DB and a free write lock | — | SQLite write lock on the `projects` page [scripts/clone_lane.py:69] | measured: a competing `BEGIN IMMEDIATE` fails the run after 60.17 s with `database is locked` (D1b) |

There is no operational preflight of any kind: the module opens the database, queries it and writes
to it without a single existence, permission or schema check [scripts/clone_lane.py:32-81]. The
`py_compile` sweep in the last audit is the only mechanical check that exists for it
[docs/audits/code-factory-docs-2026-10-29-20-26-27.md:24].

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `argparse` | CPython [scripts/clone_lane.py:14] | five required options `--from`/`--to`/`--workdir`/`--namespace`/`--parent` [scripts/clone_lane.py:24-28], one optional `--prompt` [scripts/clone_lane.py:29]; a missing required option exits **2** with usage on stderr | measured A2: exit 2, `clone_lane.py: error: the following arguments are required: --from, --to, --workdir, --namespace, --parent`; A3 shows only the options actually missing, so the list is computed per invocation, never fixed |
| `os` | CPython [scripts/clone_lane.py:15] | `os.path.expanduser` on the DB path [scripts/clone_lane.py:19] and on the repo URL [scripts/clone_lane.py:51] | this is the module's whole environment coupling: redirecting `HOME` relocates both the database it opens and the `repo_url` it writes (measured in C3 vs B1, and E1 shows the clone's `repo_url` became `local:<HOME>/code-factory`) |
| `sqlite3` | CPython [scripts/clone_lane.py:16] | `connect(DB, timeout=60)` [scripts/clone_lane.py:32], `PRAGMA busy_timeout=60000` [scripts/clone_lane.py:33], `row_factory = sqlite3.Row` [scripts/clone_lane.py:34], `dict(src)` over a row [scripts/clone_lane.py:41], parameterised UPDATE/INSERT built from the row's own keys [scripts/clone_lane.py:70] [scripts/clone_lane.py:77], `commit()` [scripts/clone_lane.py:81], readback [scripts/clone_lane.py:83-87] | the 60 s bound is real and was measured twice: a lock released after 3.0 s let the write through in 3.04 s (D1a), a lock held for the whole run failed at 60.17 s (D1b). A shorter busy timeout would turn every contended run into a failure |
| `time` | CPython [scripts/clone_lane.py:17] | `time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())` for both timestamps [scripts/clone_lane.py:57-58] | measured value `2026-11-05T20:12:57Z` in the created row: UTC, second resolution, no fractional part — a consumer sorting these strings lexicographically gets the right order only while the format holds |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| SQLite `projects` table in `~/.hermes/coding-hermes/scheduler.db` [scripts/clone_lane.py:19] | read then write, one transaction [scripts/clone_lane.py:32-88] | SQLite file, `timeout=60` [scripts/clone_lane.py:32] | a full 73-column row: the source row with name, workdir, namespace, parent, `enabled=0`, `repo_url`, `prompt_mode='append'`, cleared tick fields, zeroed failure count and fresh UTC timestamps [scripts/clone_lane.py:44-60], plus the prompt contents when `--prompt` is given [scripts/clone_lane.py:61-62] | writer side named: `clone_lane.main()` [scripts/clone_lane.py:22]. Readers of the same table in this repo are the sibling lane scripts' readbacks [scripts/configure_family.py:198] [scripts/load_lane_config.py:40] [scripts/add_family_lanes.py:99] |
| the scheduler daemon that owns the gate | inbound, out of repo | not in this tree | — | **RED — requires the live scheduler.** The implementation is `coding-hermes/scheduler` (`internal/api/lane_onboarding.go`), named in prose only, at [docs/SCHEDULER-ADMISSION.md:10-14]; `grep -rn "lane_onboarding\|validateLaneWorkdir\|satelliteWorkdirRoots" --include=*.go --include=*.py .` returns no code — one hit, the prose warning at [scripts/add_family_lanes.py:4]. Whether the daemon admits, refuses or auto-disables the cloned row cannot be measured without the live DB and a live lane, which this module's rules forbid |
| `namespaces` table, via the declared foreign key on `namespace_id` | none — the constraint is declared, never enforced | — | `namespace_id TEXT REFERENCES namespaces(id) ON DELETE SET NULL`, in the live DDL (measured from the schema, not from this source) | **fail open, measured (C6):** `--namespace no-such-ns` created the row and exited 0 while `namespaces` held only `docs,readme`. `PRAGMA foreign_keys` is never enabled in this source [scripts/clone_lane.py:32-34] and SQLite defaults it off, so the writer can plant a dangling namespace pointer that the daemon later has to interpret |
| the repo-URL guard | outbound, one call, run by the operator | `python3 -B scripts/lane_target.py repo-url` [docs/SCHEDULER-ADMISSION.md:88] | the row's `repo_url` string | `scripts/lane_target.py` parses and probes it; this is the one independent consumer check available in-tree. Measured: it accepts what this module writes under `HOME=/home/kara` — `PASS repo_url 'local:~/code-factory' — root '~/code-factory' HEAD 83b2194b…`, exit 0 — and rejects the same code path under a different `HOME`: `FAIL … path does not exist or is not a directory`, exit 4 |

## 3. Verification

The database under test was never the live one. The path is built with `os.path.expanduser`
[scripts/clone_lane.py:19], so the *unmodified* script reaches a fixture by redirecting `HOME`; the
fixture is a new file holding the live `projects`/`namespaces` DDL (read through a `mode=ro` URI) and
one source lane, `crier-docs`, with a 63-character prompt, `admission_mode=cooldown`,
`cooldown_floor_s=21600`, a delivery target and a gateway key. Every row below was executed on
2026-11-05 at revision `83b2194`; the driver and the full verbatim transcript are
`~/.hermes/cache/scratch/v09/battery2.py` and `~/.hermes/cache/scratch/v09/transcript2.txt` (scratch,
pruned after 24 h — the commands are the reproducible part, not the files). Each command is
re-runnable, which is the standard this project closes a row on (`fact: FACT-10`).

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| argument surface | `python3 scripts/clone_lane.py --help` | six options, exit 0 | 2026-11-05 | PASS — `usage: clone_lane.py [-h] --from SRC --to DST --workdir WORKDIR --namespace NAMESPACE --parent PARENT [--prompt PROMPT]`, exit 0, **and it exits 0 with no database present at all** (A1), so help is not a preflight |
| required options enforced | `python3 scripts/clone_lane.py` | usage on stderr, exit 2 | 2026-11-05 | PASS — `clone_lane.py: error: the following arguments are required: --from, --to, --workdir, --namespace, --parent`, exit 2 (A2) |
| source lane absent | `… --from no-such-lane --to x --workdir /tmp/wd --namespace docs --parent cf` | one-line failure, exit 1 | 2026-11-05 | PASS — stderr `source lane no-such-lane not found`, exit 1 (A4) |
| create and readback | `HOME=$F python3 scripts/clone_lane.py --from crier-docs --to code-factory-docs --workdir <wd> --namespace docs --parent code-factory` | `created …`, then the six-field row | 2026-11-05 | PASS — `created code-factory-docs (cloned from crier-docs)` / `{'name': 'code-factory-docs', 'namespace_id': 'docs', 'admission_mode': 'cooldown', 'cooldown_floor_s': 21600, 'parent': 'code-factory', 'length(prompt)': 63}`, exit 0 (B1) |
| `--prompt` replaces the inherited prompt | same, with `--prompt` on a 350-byte file | the row carries 350, not the source's 63 | 2026-11-05 | PASS — `'length(prompt)': 350`, and the stored prompt reads 350 (B2) |
| re-run on an existing destination | run the create command twice | the second run configures instead of creating | 2026-11-05 | PASS, with a defect — both lines print: `code-factory-docs already exists — configuring it instead of creating` then `configured code-factory-docs`, exit 0, and `created_at` moved `2026-11-05T20:12:55Z → 2026-11-05T20:12:57Z` (B3) |
| re-run on a hand-configured row | set `enabled=1, prompt_mode='replace', prompt='hand-written', admission_mode='tasks', cooldown_floor_s=43200`, then re-run | it must not silently undo that | 2026-11-05 | **FAIL — measured** `before (1, 'replace', 12, 'tasks', 43200)` → `after (0, 'append', 63, 'cooldown', 21600)` (B5) |
| prompt file unreadable | `--prompt` a missing file, then a mode-000 file | clean failure, no row | 2026-11-05 | PASS — `FileNotFoundError` (C1) and `PermissionError` (C2), exit 1; `lane-c1` rows after the failure: 0 |
| database absent, table absent, file read-only | three HOMEs, as in §2a | traceback, non-zero | 2026-11-05 | PASS — `unable to open database file` (C3), `no such table: projects` (C4), `attempt to write a readonly database` (C5), exit 1 each |
| dangling namespace accepted | `--namespace no-such-ns` | refused by the declared foreign key | 2026-11-05 | **FAIL — measured** `created lane-c6 …`, exit 0, `namespace_id='no-such-ns'` while `namespaces` held `docs,readme` (C6) |
| off-root workdir accepted | `--workdir /nonexistent/nope --to totally-made-up-lane` | refused before any row is written | 2026-11-05 | **FAIL — measured** `created totally-made-up-lane (cloned from crier-docs)`, exit 0 (C7) |
| self-clone | `--from crier-docs --to crier-docs --workdir /tmp/hijacked` | unreachable | 2026-11-05 | **FAIL — measured** the *source* row was rewritten: workdir `/tmp/hijacked`, `repo_url` regenerated from `HOME`, `created_at` reset, exit 0 (B7) |
| contended lock, released | hold `BEGIN IMMEDIATE` 3.0 s in another connection, then run a clone | waits, then succeeds | 2026-11-05 | PASS — exit 0, wall 3.04 s (D1a) |
| contended lock, held | hold the same lock for the whole run | fails at the 60 s bound | 2026-11-05 | PASS — `database is locked`, exit 1, wall 60.17 s (D1b) |
| channel split on success | one successful clone | stdout only | 2026-11-05 | PASS — stdout 183 bytes, stderr 0 bytes, exit 0 (D2) |
| independent consumer check | `python3 -B scripts/lane_target.py repo-url 'local:~/code-factory'` | the row's repo URL passes the documented guard | 2026-11-05 | PASS — `PASS repo_url … HEAD 83b2194b…`, exit 0; the same guard exits 4 on the path this identical code writes under another `HOME` |

Five of these rows are FAILs. None is a crash: four are the module doing exactly what its code says,
which is why they stayed invisible while this document carried no run record.

## 4. Metrics emitted

**none.** The module imports no metrics client and no logging framework; measured,
`grep -nE "metric|counter|histogram|prometheus|statsd|logging|logger" scripts/clone_lane.py` returns
no match (rc 1). Its entire machine-readable surface is the process exit status and 183 bytes of
stdout (D2).

| Signal | Values measured | What it distinguishes |
|---|---|---|
| exit 0 | create, configure, and the three failures it cannot see (B5, C6, C7) | *nothing* — a zero exit is compatible with a dangling namespace, a nonexistent workdir and a silently rewritten row |
| exit 1 | `SystemExit` for a missing source [scripts/clone_lane.py:38]; every uncaught `sqlite3`/`OSError` from §2a | a failure the module noticed |
| exit 2 | argparse, from [scripts/clone_lane.py:23-30] | an invocation error, before any I/O |
| stdout bytes | 183 on success, 0 on every failure | success against failure, if a caller measures only that |

Timing, measured on the fixture host: one successful clone took 0.077 s (E2) and a contended one
3.04 s (D1a). That is the module's only latency figure. It has no counter, gauge, exporter or
retention, so nobody can see clone frequency or failure mix over time without re-running it; a
scrapeable series would need one counter per exit class, and none exists in this revision.

## 5. Log lines it can generate

No logger is imported [scripts/clone_lane.py:14-17]; every operator-visible line is `print` to
stdout, or a traceback on stderr.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stdout | `{dst} already exists — configuring it instead of creating` [scripts/clone_lane.py:40] | the destination row existed at the first check [scripts/clone_lane.py:39] | evidentiary *and* misleading: it is followed by `configured`, because a second existence check at [scripts/clone_lane.py:65] drives the write. Both lines print in one run (B3, B4, B7) |
| stdout | `created {dst} (cloned from {src})` [scripts/clone_lane.py:73] | no destination row at either check [scripts/clone_lane.py:68] | evidentiary for the INSERT, not for the lane — measured true for a workdir that does not exist (C7) |
| stdout | `configured {dst}` [scripts/clone_lane.py:80] | the destination existed [scripts/clone_lane.py:74] | evidentiary for the UPDATE; it never says which columns changed, and B5 shows five changed silently |
| stdout | `   {'name': …, 'namespace_id': …, 'admission_mode': …, 'cooldown_floor_s': …, 'parent': …, 'length(prompt)': …}` [scripts/clone_lane.py:88] | always, after the commit [scripts/clone_lane.py:83-87] | evidentiary for the six selected fields of the committed row — the strongest line the module prints, and still not a check of the workdir, the namespace or the gate |
| stderr | `source lane {src} not found` [scripts/clone_lane.py:38] | `SELECT … WHERE name=?` returned nothing [scripts/clone_lane.py:37] | descriptive, exit 1. `SystemExit(str)` writes to **stderr**, not stdout (measured A4) |
| stderr | `usage: clone_lane.py [-h] …` then `clone_lane.py: error: the following arguments are required: …` | a required option is missing (A2, A3) | descriptive, exit 2, nothing on stdout |
| stderr | a Python traceback ending in `sqlite3.OperationalError: …`, `FileNotFoundError` or `PermissionError` | the §6 rows below | neither — the failure path is the raw interpreter stack, with no message of the module's own |

There is no log level, timestamp, destination, rotation or dedup. A caller who captures stdout cannot
tell a run from this week from one a year ago, and a caller who captures only stderr sees nothing at
all on success (D2).

## 6. Failure modes

| Failure | Presents as | Distinguished from | Direction | Recovery |
|---|---|---|---|---|
| destination already exists | both `already exists — configuring it instead of creating` and `configured`, exit 0 [scripts/clone_lane.py:39-40] [scripts/clone_lane.py:80] | nothing distinguishes create from configure except which print came first | **fail open** — allowed to repeat, but not idempotent in effect (next row) | none needed for a first run; for a re-run, copy the row first |
| an existing row a human configured | measured B5: `enabled 1→0`, `prompt_mode replace→append`, `prompt` replaced with the source's 63 characters, `admission_mode tasks→cooldown`, `cooldown_floor_s 43200→21600`, exit 0 | a genuine configure prints no diff, so the loss is invisible in the output | **fail open and destructive** — the module re-clones the source's configuration over the destination's, and `enabled=0` disarms a lane that was running [scripts/clone_lane.py:50]. `created_at` is rewritten too [scripts/clone_lane.py:57], erasing when the lane was onboarded (B3: `20:12:55Z → 20:12:57Z`) | re-apply the intended configuration from its source of truth; nothing in the module can undo it |
| `--to` equals `--from` | measured B7: `crier-docs already exists — configuring it…`, `configured crier-docs`, exit 0, and the *source* row now reads workdir `/tmp/hijacked`, `repo_url` rebuilt from `HOME`, `created_at` reset | a clone of a sibling, which leaves the source untouched | **fail open and worst** — nothing checks that the two names differ [scripts/clone_lane.py:44-49], so a typo rewrites the canonical lane every future clone copies | restore the row from a copy; there is no rollback |
| source lane absent | `SystemExit: source lane … not found` on stderr, exit 1 [scripts/clone_lane.py:36-38] | an unopenable database, which prints `unable to open database file` from [scripts/clone_lane.py:32] | **fail closed** — the cleanest failure in the file | fix `--from`; the message names the value |
| required CLI option absent | argparse usage then `error: the following arguments are required: …`, exit 2, nothing written [scripts/clone_lane.py:23-30] | a traceback: exit 2 against exit 1 | **fail closed** | supply the option |
| prompt file unreadable | `FileNotFoundError` / `PermissionError` traceback at [scripts/clone_lane.py:62], exit 1, and **no row is written** (measured C1: 0 rows) | a write that landed without its prompt — unreachable, because the read precedes the statement at [scripts/clone_lane.py:69] | **fail closed and atomically**: the file read precedes all SQL, and the single commit at [scripts/clone_lane.py:81] means a failure inside the write leaves nothing behind | fix the path or the mode; nothing to roll back |
| database missing, schema missing, file read-only | bare traceback from [scripts/clone_lane.py:32], [scripts/clone_lane.py:36] or [scripts/clone_lane.py:69], exit 1 | a lock timeout, which names `database is locked` | **fail closed** | provision the file, table or permission; none is checked in advance |
| database locked by another writer | waits up to 60 s, then `sqlite3.OperationalError: database is locked`, exit 1 (D1b at 60.17 s; D1a shows a 3 s hold succeeded in 3.04 s) | a permission error, which fails immediately | **fail closed after 60 s** — safe, but a contended run costs a full minute per attempt | re-run; the bound is set at [scripts/clone_lane.py:32-33] and is not configurable |
| `--namespace` names no namespace | row created, exit 0, dangling pointer (C6) | a rejected insert, which never happens because `PRAGMA foreign_keys` is never enabled [scripts/clone_lane.py:32-34] | **fail open** — the row is written and the daemon inherits the problem | create the namespace or fix the row; the module cannot detect it |
| `--workdir` does not exist or is off-root | row created, exit 0 (C7) | a refused path — the API's gate refuses it [docs/SCHEDULER-ADMISSION.md:32-35], this writer does not | **fail open** — the behaviour the module exists to allow is also the one it cannot sanity-check | the guard is external: the lane-target probe and the checklist at [docs/SCHEDULER-ADMISSION.md:70-78] |
| `~` resolves somewhere without a checkout | the row's `repo_url` becomes `local:<HOME>/code-factory`, which the guard rejects with exit 4 (measured) | a correct row, which the guard accepts with exit 0 and a HEAD | **fails open at write time, caught at read time** | run it as the user who owns the checkout; the value is not hard-coded [scripts/clone_lane.py:51] |

Every failure the module *notices* is safe; every failure it does not check for is the one that
reaches the scheduler.

## 7. Environment and settings it reads

| Setting | Kind | Default | Read at | Validation |
|---|---|---|---|---|
| database path | derived from `HOME`, not settable | `~/.hermes/coding-hermes/scheduler.db`, via `os.path.expanduser` | [scripts/clone_lane.py:19] | none. There is no flag and no variable: the only override is `HOME` itself, which is what let this document measure it without touching the live DB (C3 against B1) |
| `--from` | required option | — | [scripts/clone_lane.py:24] | existence only: the row must be found [scripts/clone_lane.py:36-38] |
| `--to` | required option | — | [scripts/clone_lane.py:25] | none — not checked against the family vocabulary, and not checked against `--from` (C7, B7) |
| `--workdir` | required option | — | [scripts/clone_lane.py:26] | none — the path is stored verbatim: `--workdir /nonexistent/nope` was written and committed (C7). The gate's root rules [docs/SCHEDULER-ADMISSION.md:20-30] are never consulted |
| `--namespace` | required option | — | [scripts/clone_lane.py:27] | none — the declared foreign key is not enforced (C6) |
| `--parent` | required option | — | [scripts/clone_lane.py:28] | none; `parent` carries an index but no constraint |
| `--prompt` | optional option | — | [scripts/clone_lane.py:29], read whole at [scripts/clone_lane.py:62] | the file must be readable; content is stored verbatim, measured 350 characters for a 350-byte file (B2) |
| `enabled` | forced literal | `0` | [scripts/clone_lane.py:50] | deliberately disarmed, matching "create it disabled at an accepted path" [docs/SCHEDULER-ADMISSION.md:73] — except that the second half of that sentence, "reject an off-root path before any row is written", has no counterpart here |
| `prompt_mode` | forced literal | `'append'` | [scripts/clone_lane.py:52] | none, and it overwrites an existing `'replace'` on the update path (B5) |
| tick state | forced literals | `''`, `''`, `''`, `0` | [scripts/clone_lane.py:53-56] | none; this is the only part of the update path that behaves like a reset rather than a copy |
| `repo_url` | derived from `HOME` | `local:{expanduser('~/code-factory')}` | [scripts/clone_lane.py:51] | none at write time; the documented repo-URL guard [docs/SCHEDULER-ADMISSION.md:93-96] rejects it with exit 4 when the path is not a checkout (measured) |
| environment variables | — | — | **none read**: `grep -nE "os\.environ\|getenv\|environ" scripts/clone_lane.py` returns no match (rc 1). `HOME` acts only implicitly, inside `expanduser`, at [scripts/clone_lane.py:19] and [scripts/clone_lane.py:51] | n/a |
| config file | — | — | **none**: the only files touched are the database and the optional prompt file | n/a |

## 8. Evidence of record

A reviewer can reproduce every claim above at revision `83b2194`:

- the fixture recipe: read the live schema read-only — `sqlite3 "file:$HOME/.hermes/coding-hermes/scheduler.db?mode=ro" ".schema projects"` — execute that DDL into a scratch file, insert one source row, then run every command in §3 with `HOME` pointed at the scratch directory. The live DB is never the target. This document's runs used one such fixture, `crier-docs`, with a 63-character prompt.
- `python3 scripts/clone_lane.py --help` with `HOME` pointing at an empty directory → exit 0, which proves help performs no I/O and no preflight (A1).
- the five measured defects, one command each: `--to` equal to `--from` (B7, the source row is rewritten), `--namespace` naming nothing (C6, accepted), `--workdir /nonexistent/nope` (C7, accepted), a re-run over a hand-configured row (B5, five fields silently reverted), and a re-run on an existing destination that prints both the "already exists" and "configured" lines (B3).
- the 60-second bound, measured both ways: a 3.0 s lock released early yields success at 3.04 s; a lock held throughout yields `database is locked` at 60.17 s (D1a, D1b). It is the module's only time bound [scripts/clone_lane.py:32-33].
- the independent consumer check: `python3 -B scripts/lane_target.py repo-url 'local:~/code-factory'` → `PASS repo_url … HEAD 83b2194b…`, exit 0, while the same guard exits 4 on the path this identical code writes under a different `HOME`. This is the only check in the tree that can contradict the module's own readback, and what it contradicts is the `repo_url` column's portability rather than the write.
- the six sections that carry claims — purpose (§1), dependencies and contracts (§2), log lines (§5), failure modes (§6), environment (§7) and this one — are each backed by the runs above. One claim is deliberately still **RED**: that the live scheduler accepts the cloned row. Answering it needs `GET /api/v1/projects/<name>` against the running daemon and the parity test named in the checklist [docs/SCHEDULER-ADMISSION.md:77-80], that is, the live DB and a live lane, which this module's rules forbid. A clone that passes every row above can still be refused or auto-disarmed by the daemon, and nothing in this document says otherwise.
- the readback the module prints is not an independent check: it is the same connection selecting the columns it just wrote [scripts/clone_lane.py:83-88]. The row printed in B1 proves the commit; the FAIL rows above prove what the commit does not cover.

Facts cited: `fact: FACT-10` — a row closes only on a re-runnable command in its evidence, which is
why §3 records commands and their verbatim output rather than prose. The same document's checklist
asks the same readback discipline of every new lane [docs/SCHEDULER-ADMISSION.md:77].

Two documents in this tree are now stale against this one and were left untouched because they lie
outside this module: the index still marks module 9 RED at [docs/master/00-INDEX.md:16], and the
operations runbook still says this script's contract is unverified at [docs/OPERATIONS.md:207].
