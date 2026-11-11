# 23. scripts/load_lane_config.py

| Field | Value |
|---|---|
| Path | `~/proj-wt-md-23e/scripts/load_lane_config.py` — 45 lines, 1576 bytes, six lanes, no arguments, no flags, no config file |
| Repository | `code-factory` |
| Revision | `b9f56e6` — the `origin/main` tip every locator below was measured against on 2026-11-05 |
| Status | **VERIFIED — 21 recorded checks against scratch fixture databases; the hazardous path (a re-run against the live scheduler) was measured read-only and never executed** |

## 1. Purpose and why it matters

- **What it is, precisely: a writer, not a loader.** The name and the docstring say "lane configuration", and the docstring calls the run "one-time" [scripts/load_lane_config.py:2]. The file contains no argument parsing, no `sys` import, no config-file read and no condition on state: it connects to the scheduler database, then unconditionally executes six `UPDATE`s, then commits, then prints what the table now says [scripts/load_lane_config.py:29-45]. The lane table is a Python dict literal of six `(namespace, admission_mode, prompt_file)` triples [scripts/load_lane_config.py:20-27]. That literal is the entire configuration surface — there is nothing else to read, which settles the precedence question in §7.
- **Why it is load-bearing.** It is the path the README names for the six core lane rows: the repository is the declared source of truth and the database row is the copy [README.md:219]. (The eight added family rows get their prompt text from `add_family_lanes.py`, which reads the same `prompts/` directory [scripts/add_family_lanes.py:90] — one upstream, three writers.) The prompt text is not decoration: `prompts/foreman.md` carries the operative topology, "one Hermes foreman running on that project's bunker node, one bunker per project" (fact: FACT-01, fact: FACT-02) [prompts/foreman.md:3]. A lane whose prompt row is stale runs last month's instructions.
- **The four columns it writes are routing and budget, not cosmetics.** `namespace_id` selects which namespace's weight, `hard_cap` and `max_concurrent` the lane draws on; `admission_mode` decides whether the lane admits on board tasks or on cooldown; `prompt` is the tick's job; `prompt_mode` is forced to `append` [scripts/load_lane_config.py:34]. Three of the four are silently wrong-prone and one of them is hardcoded.
- **What breaks if it is never run: the drift is real and measurable now.** Comparing the live rows against `prompts/` read-only, all six differ: five lanes are 12 characters behind their file and `code-factory` is 1558 characters behind — 1832 live vs 3390 on disk. The prompts moved on in commits after the loader last ran (`git log -- prompts/` shows `160b872` and `6685c63` editing the harness text), and the database still holds the old text. That is what the missing refresh costs.
- **What breaks if it lies: the receipt is a re-read, not a report.** The closing loop `SELECT`s `name, namespace_id, admission_mode, length(prompt)` from the table and prints it [scripts/load_lane_config.py:39-45]. Nothing in it is a count of what the `UPDATE`s did, nothing names the lanes it intended to change, and nothing distinguishes a row it just wrote from a row it never touched — measured, an untouched `code-factory-docs` lane prints in exactly the same shape as the six it rewrote (§3 row 1). A run that changed nothing therefore prints a table that reads like a completed configuration.
- **Blast radius: six live scheduler lanes, on the control host, with no dry run.** The write path is unconditional and the repo's sanctioned "edit the prompt and re-run the loader" refresh [README.md:219] is the same command. Against the live database that command would now impose 13 field-level changes: six namespace rewrites (`code-factory` → `coding-hermes`, `qa`, `dogfood`, `duckbrain-sync`), one admission-mode flip (`code-factory-duckbrain`, `tasks` → `cooldown`), and six prompt replacements (§3 row 2). The board already carries the defect as P2 in progress: "any invocation, including `--help`, rewrites six live scheduler lanes" [~/code-factory/.gitreins/tasks.yaml:1403].

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | 3.14.4 here; needs 3.6+ for f-strings and `Path.read_text` [scripts/load_lane_config.py:44] [scripts/load_lane_config.py:32] | the interpreter on `PATH` | nothing in the file — no version guard, no check beyond the `#!/usr/bin/env python3` shebang [scripts/load_lane_config.py:1] |
| `sqlite3` module | stdlib, linked SQLite 3.46.1 here | the interpreter's stdlib | `ModuleNotFoundError` at import, before any work [scripts/load_lane_config.py:10] |
| the scheduler database | any schema with `projects(name, namespace_id, admission_mode, prompt, prompt_mode)` | `$SCHEDULER_DB` or `~/.hermes/coding-hermes/scheduler.db` [scripts/load_lane_config.py:13-17] | `sqlite3.OperationalError: no such table: projects`, exit 1 — after the script has already created a 0-byte file at that path (§3 row 6) |
| `prompts/<lane>.md` × 6 | 167 lines, 10385 bytes total | `$CODE_FACTORY_ROOT` (default: the repo root) `+ /prompts` [scripts/load_lane_config.py:18] [scripts/load_lane_config.py:32] | `FileNotFoundError`, exit 1, whole batch rolled back (§3 row 8) |

No network, no subprocess, no third-party package. The three imports are the whole dependency list [scripts/load_lane_config.py:8-10].

### 2b. Library contracts

| Import / call | Contract relied on | If it changes |
|---|---|---|
| `os.environ.get("SCHEDULER_DB", default)` [scripts/load_lane_config.py:14-16] | a **set-but-empty** variable returns `""`, not the default | measured: `SCHEDULER_DB=` yields `sqlite3.OperationalError: unable to open database file`, exit 1 (§3 row 7) |
| `os.environ.get("CODE_FACTORY_ROOT", HERE)` [scripts/load_lane_config.py:18] | same set-but-empty hazard; a relative value resolves against the **current working directory**, not the repo | an empty value makes the prompt path `prompts/<lane>.md` relative to `$PWD`; measured absent-directory behaviour is a clean `FileNotFoundError` (§3 row 8) |
| `pathlib.Path(__file__).resolve().parents[1]` [scripts/load_lane_config.py:12] | the repo root is two levels above the resolved script, symlinks followed | a copied or symlinked script silently re-roots the prompt directory; nothing warns |
| `Path.read_text()` with no `encoding=` [scripts/load_lane_config.py:32] | the platform default encoding — `locale.getpreferredencoding(False)` | measured: under `LC_ALL=C PYTHONUTF8=0` this is `ascii`, and every prompt file contains U+2014, so the run dies with `UnicodeDecodeError: 'ascii' codec can't decode byte 0xe2 in position 14` (§3 row 10) |
| `sqlite3.connect(DB, timeout=60)` [scripts/load_lane_config.py:29] | the file is **created if absent**; `timeout` is the busy wait | measured: a typo'd path produces a 0-byte database file and a `no such table` failure; a held write lock produces a 60 s wait then `database is locked` (§3 rows 6, 11) |
| `PRAGMA busy_timeout=60000` [scripts/load_lane_config.py:30] | per-connection busy handler, redundant with the connect timeout but harmless | a lock survives both for 60 s, then fails closed |
| Python's implicit transaction + `con.commit()` [scripts/load_lane_config.py:37] | the six `UPDATE`s are **one** transaction: an exception before `commit()` discards all of them | measured twice on failures that struck *after* earlier lanes had already been `UPDATE`d — §3 rows 8 and 14 — and both times the table was left identical to its pre-run state. This is the file's best property and it is accidental, not designed: there is no `try`/`rollback` anywhere |
| `CHECK(admission_mode IN ('','cooldown','tasks'))` on the live schema | the only vocabulary validation on this path | measured: `always` is refused by the database with `IntegrityError: CHECK constraint failed` and exit 1 (§3 row 9) |
| `REFERENCES namespaces(id)` on the live schema | **not enforced** — `PRAGMA foreign_keys` is `0` in a fresh Python connection, and the script never turns it on | measured: `namespace_id='no-such-namespace'` is accepted, exit 0, and the row is left pointing at a namespace with zero rows (§3 row 12) |

### 2c. Peers — both sides named

| Peer | Direction | Transport | Payload | Other side |
|---|---|---|---|---|
| the scheduler database | this script → DB | one SQLite write transaction on `projects` [scripts/load_lane_config.py:33-37] | six `UPDATE`s setting `namespace_id`, `admission_mode`, `prompt`, `prompt_mode` | the scheduler daemon outside this repo consumes those columns; inside this repo the same columns are read by [scripts/bunker_config_gen.py:181] and rewritten by [scripts/configure_family.py:178] and [scripts/add_family_lanes.py:92] |
| `prompts/*.md` | file → script | `read_text()`, platform encoding [scripts/load_lane_config.py:32] | the six role files, 3390 bytes for the foreman role alone | the repo's own source-of-truth claim [README.md:219]; the files are also read by `configure_family.py` [scripts/configure_family.py:176] and `add_family_lanes.py` [scripts/add_family_lanes.py:90], so three scripts share one upstream |
| `~/.hermes/fleet.toml` | declaration ← operator | TOML, **not read by this script** | `namespace_id = "code-factory"` on every code-factory lane [~/.hermes/fleet.toml:1918] | the value this script contradicts — it writes `coding-hermes`, `qa`, `dogfood`, `duckbrain-sync` [scripts/load_lane_config.py:21-26] |
| board row CF-170 | board → operator | task record | "load_lane_config.py has no read-only mode: any invocation, including `--help`, rewrites six live scheduler lanes" [~/code-factory/.gitreins/tasks.yaml:1403] | the operator-facing fix, still `in_progress`; §6 rows 1 and 13 are its measured reproduction |

The three overlapping writers are worth naming as a set: this script writes `namespace_id, admission_mode, prompt, prompt_mode` for six lanes; `configure_family.py` writes `parent, admission_mode, prompt, prompt_mode, cooldown_floor_s, cooldown_ceiling_s` [scripts/configure_family.py:178]; `add_family_lanes.py` writes `parent, admission_mode='cooldown', prompt, prompt_mode` [scripts/add_family_lanes.py:92]. Whichever ran last owns the row, and no file records which ran last.

## 3. Verification

Measured 2026-11-05 in worktree `~/proj-wt-md-23e` at `b9f56e6`, Python 3.14.4, SQLite 3.46.1. Every fixture is a scratch database under `$TMPDIR` carrying the live `projects` and `namespaces` schema including both constraints, selected via `SCHEDULER_DB`; the live database (16,792,596,480 bytes) was opened **read-only** (`file:…?mode=ro`) for rows 2 and 3 and written by nothing.

| # | Check | Command | Expected | Result |
|---|---|---|---|---|
| 1 | complete fixture: six configured lanes + one unconfigured lane, all at `namespace_id=code-factory` | `SCHEDULER_DB=$F CODE_FACTORY_ROOT=$WT python3 scripts/load_lane_config.py` | six rows rewritten, exit 0 | **PASS (and the defect is visible)** — exit 0, seven receipt lines; after: `code-factory\|coding-hermes\|tasks`, `-qa\|qa`, `-pm\|coding-hermes`, `-dogfood\|dogfood`, `-sync\|coding-hermes`, `-duckbrain\|duckbrain-sync\|cooldown` (mode flipped from `tasks`). The untouched `code-factory-docs` printed identically, `prompt=3` |
| 2 | what a re-run would impose on the **live** database | read-only `SELECT` + comparison against `prompts/*.md` | inventory only | **MEASURED, not executed** — 13 field-level differences: 6 namespaces (`code-factory` → `coding-hermes`/`qa`/`dogfood`/`duckbrain-sync`), 1 mode (`code-factory-duckbrain` `tasks` → `cooldown`), 6 prompts. Live lengths 1832/1372/1374/1406/1346/1392 vs file 3390/1384/1386/1418/1358/1404 |
| 3 | receipt coverage vs configuration coverage | `SELECT … WHERE name LIKE 'code-factory%'` on the live DB | — | **17 rows** match the receipt's filter; the script configures **6**. The other 11 print in the same shape with no marker saying they were not written |
| 4 | partial fixture: three of six lanes present | same invocation | silent success | **FAIL-OPEN CONFIRMED** — exit 0, three receipt lines; the three absent lanes appear nowhere and no line says "0 rows updated" |
| 5 | zero-row `projects` table | same invocation | silent success | **FAIL-OPEN CONFIRMED** — exit 0, zero bytes of output; the run reports nothing at all |
| 6 | `SCHEDULER_DB` names a file that does not exist | same invocation | refusal, no side effect | **PARTIAL — closed on status, open on the filesystem**: `sqlite3.OperationalError: no such table: projects`, exit 1, and a 0-byte database file is created at the typo'd path (`ls -l` → 0 bytes, `select count(*) from sqlite_master` → 0) |
| 7 | `SCHEDULER_DB` set to the empty string | `SCHEDULER_DB= … python3 …` | default used? | **set-but-empty is not "missing"** — `sqlite3.OperationalError: unable to open database file`, exit 1 |
| 8 | `CODE_FACTORY_ROOT` whose `prompts/` lacks `duckbrain.md` (the last lane) | same invocation | refusal, nothing half-written | **PASS (closed) — atomic**: `FileNotFoundError: … root6/prompts/duckbrain.md`, exit 1, and the dump afterwards shows all seven rows still `OLD` — the five lanes already `UPDATE`d were rolled back |
| 9 | `admission_mode` outside the DB vocabulary (`always`), via a mutated scratch copy | same invocation | refused | **PASS (closed)** — `sqlite3.IntegrityError: CHECK constraint failed: admission_mode IN ('','cooldown','tasks')`, exit 1, all seven rows unchanged |
| 10 | C locale with UTF-8 mode off, real prompts | `LC_ALL=C LANG=C PYTHONUTF8=0 PYTHONCOERCECLOCALE=0 …` | — | **dies on the first file**: `UnicodeDecodeError: 'ascii' codec can't decode byte 0xe2 in position 14: ordinal not in range(128)`, exit 1, table unchanged |
| 11 | another writer holds `BEGIN IMMEDIATE` | python holder + `timeout 120` on the run | bounded wait, then refusal | **PASS** — `sqlite3.OperationalError: database is locked`, exit 1, `ELAPSED=60s`, table unchanged |
| 12 | `namespace_id` with no `namespaces` row, via a mutated scratch copy | same invocation + `PRAGMA foreign_keys` | refused if the FK is enforced | **FAIL-OPEN CONFIRMED** — `PRAGMA foreign_keys` → `(0,)`; the write lands (`code-factory-pm\|no-such-namespace\|cooldown`), exit 0, `SELECT count(*) FROM namespaces WHERE id='no-such-namespace'` → 0 |
| 13 | argument safety: `--dry-run --check` | `… python3 scripts/load_lane_config.py --dry-run --check` | no write | **FAIL-OPEN CONFIRMED** — the row went from `code-factory\|tasks\|3` to `coding-hermes\|tasks\|3390`, exit 0, stderr 0 bytes. No `sys` import exists to read `argv` [scripts/load_lane_config.py:8-10] |
| 14 | lane tuple with two elements instead of three | mutated scratch copy | refused before any write | **PASS (closed)** — `ValueError: not enough values to unpack (expected 3, got 2)`, exit 1, all prompts still `OLD` (the `UPDATE`s already executed were rolled back) |
| 15 | database file mode 444 | same invocation | refusal | **PASS (closed)** — `sqlite3.OperationalError: attempt to write a readonly database`, exit 1 |
| 16 | `SCHEDULER_DB` is a directory | same invocation | refusal | **PASS (closed)** — `sqlite3.OperationalError: unable to open database file`, exit 1 |
| 17 | idempotency | run, `.dump`, run again, `.dump`, `diff` | second run changes nothing | **PASS** — `diff` empty; the second run still emits the full seven-line receipt and still executes six `UPDATE`s |
| 18 | stored text is the file | `SELECT prompt` vs `Path.read_text()` per lane | identical | **PASS** — `code-factory: chars=3390 bytes=3413 identical=True`; `code-factory-duckbrain: chars=1404 bytes=1410 identical=True` |
| 19 | streams and duration | `/usr/bin/time`, stdout and stderr to separate files | — | **MEASURED** — `real 0.06`, stdout `487B` / `7 lines`, stderr `0B`. The success path writes nothing to stderr and prints no summary line |
| 20 | statics | `python3 -m py_compile scripts/load_lane_config.py` | rc 0 | **PASS** — rc 0, silent |
| 21 | repo regression test for this path | `grep -rn load_lane_config tests/` | a fixture | **ABSENT** — no test names the script; `tests/` contains no fixture for it. Board row CF-170 requires one [~/code-factory/.gitreins/tasks.yaml:1403] |

## 4. Metrics emitted

**None, and the reason is structural.** The script writes no metric file, no counter, no structured line and no exit-status word. Its whole output surface is one `print` per matching row [scripts/load_lane_config.py:43-45]: 487 bytes over seven lines on a six-lane fixture, 0 bytes on stderr (§3 row 19). There is no counter to read because the file never inspects what its `UPDATE`s did — no `cursor.rowcount`, no `changes()`, no before/after comparison. The receipt is a fresh `SELECT` of the table, so it reports the world, not the action.

What an operator can and cannot answer from that output:

- **Can**: what the four printed columns hold *now*, for every `code-factory%` row — because the receipt prints them. Prompt *size* is included, so `prompt=0` is visible at a glance.
- **Cannot**: how many rows this run changed (a full rewrite, a partial no-op and a zero-row no-op all exit 0 and print the same shape), whether a lane in the configuration is missing from the database (it simply does not print — §3 row 4), or which of the 17 printed rows the run actually wrote (§3 rows 1, 3).
- **Cannot, despite appearances**: `prompt_mode`. It is written as a literal [scripts/load_lane_config.py:34] and the receipt does not select it, so the one column that is not configurable is also the one column not verifiable from the output.

The nearest thing to a real metric is the database itself: a drift check that compares `projects.prompt` against `prompts/<role>.md` is re-runnable and is exactly the read-only comparison in §3 row 2 — it answers "is the lane running the text the repo ships" without running the writer at all. That check is the measurement this module should have had; it lives in this document and not in the repo.

## 5. Log lines it can generate

There is no logging and no level vocabulary. The rows below are the two shapes the file can produce: a receipt line, or an uncaught exception's last line. Nothing is tagged, prefixed or timestamped; the success path writes 0 bytes to stderr (§3 row 19).

| Level | Line (verbatim, as measured) | Format site | Emitted when | Kind |
|---|---|---|---|---|
| `–` (stdout) | `code-factory             ns=coding-hermes  mode=tasks     prompt=3390` | [scripts/load_lane_config.py:44] | one line per `code-factory%` row, after the commit | descriptive — a re-read of the row, not a report of the write |
| `–` (stdout) | `code-factory-docs        ns=code-factory   mode=cooldown  prompt=3` | [scripts/load_lane_config.py:44] | same loop — a lane the run never touched, printed in the identical shape | descriptive, and the shape is why a no-op looks like a success |
| `–` (stderr) | `FileNotFoundError: [Errno 2] No such file or directory: '~/.hermes/cache/scratch/md25b/md23e/root6/prompts/duckbrain.md'` | [scripts/load_lane_config.py:32] | a prompt file is absent under `$CODE_FACTORY_ROOT` | evidentiary — names the exact path that was missing, so the cause is checkable; says nothing about which lanes were already updated (they rolled back) |
| `–` (stderr) | `sqlite3.IntegrityError: CHECK constraint failed: admission_mode IN ('','cooldown','tasks')` | [scripts/load_lane_config.py:33] | an `admission_mode` outside the schema's vocabulary | evidentiary — names the refused vocabulary, so the bad value is recoverable from the line |
| `–` (stderr) | `sqlite3.OperationalError: database is locked` | [scripts/load_lane_config.py:33] | a competing writer held the database past the 60 s busy wait | evidentiary for the fact of contention, silent about the holder and the lane |
| `–` (stderr) | `sqlite3.OperationalError: no such table: projects` | [scripts/load_lane_config.py:33] | `$SCHEDULER_DB` points at an empty or wrong database | evidentiary — and the tell for §3 row 6: the script has just created the empty file |
| `–` (stderr) | `ValueError: not enough values to unpack (expected 3, got 2)` | [scripts/load_lane_config.py:31] | a lane tuple in the literal has the wrong arity | descriptive — a source defect surfaced at runtime, with no lane name in the message |
| `–` (stdout) | *(nothing)* | [scripts/load_lane_config.py:37] | **every successful run** — there is no summary line, no count, no `RESULT:` word | the absence is the finding: a wrapper grepping stdout for a verdict finds only data rows |

## 6. Failure modes

Direction is stated as "does the run end up green when it should not". Six of the fourteen rows fail **open**, one fails both ways at once, and the seven that fail closed do so because of SQLite, not because of a check in this file.

| Failure | Presents as | Direction | Distinguished from / recovery |
|---|---|---|---|
| 1. A re-run against the live scheduler (the documented refresh) | exit 0, a healthy-looking seven-line receipt | **fails OPEN — the worst in this file.** Six lanes move from `namespace_id=code-factory` to `coding-hermes`/`qa`/`dogfood`/`duckbrain-sync`, `code-factory-duckbrain` flips `tasks`→`cooldown`, and every prompt is replaced; measured read-only as 13 field-level differences (§3 row 2). Namespace decides the lane's budget and concurrency, so the lanes keep ticking — in the wrong pool | nothing distinguishes it: the receipt prints the new values as if they were intended. Recovery is manual and per-row. The repo already knows: CF-170 forbids the write without an explicit `--apply` [~/code-factory/.gitreins/tasks.yaml:1403] |
| 2. A lane in the configuration does not exist in the database | exit 0, that lane missing from the receipt, no message | **fails OPEN on evidence** — `UPDATE … WHERE name=?` matching zero rows is a success to SQLite (§3 row 4) | distinguish by comparing the receipt's row count against the six lanes in the literal; there is no other signal. Recovery: create the row first, then re-run |
| 3. The whole table is empty | exit 0, **zero bytes of output** | **fails OPEN and silent** — the most dangerous shape, because an empty receipt reads as "nothing to do" (§3 row 5) | an operator who expects six lines and sees none has the only available clue |
| 4. A `namespace_id` that does not exist | exit 0, the row now points at a namespace with no configuration | **fails OPEN** — `PRAGMA foreign_keys` is `0`, so the declared `REFERENCES namespaces(id)` never fires (§3 row 12) | distinguish by joining: `SELECT p.name FROM projects p LEFT JOIN namespaces n ON n.id=p.namespace_id WHERE n.id IS NULL`. Recovery: fix the value, not the constraint |
| 5. An `admission_mode` outside the vocabulary | `IntegrityError`, exit 1, nothing written | **fails CLOSED** — but only because the schema carries `CHECK(admission_mode IN ('','cooldown','tasks'))` (§3 row 9) | a database without that CHECK would accept the value silently; the file itself validates nothing |
| 6. A prompt file is missing | `FileNotFoundError`, exit 1, all six rows unchanged | **fails CLOSED and atomically** — the uncommitted transaction is discarded (§3 row 8) | the traceback names the path, so the cause is unambiguous; the cost is that five lanes' worth of work is thrown away rather than the one bad lane being named and skipped |
| 7. `$SCHEDULER_DB` names a path that does not exist | 0-byte database file created, then `no such table: projects`, exit 1 | **closed on status, open on the filesystem** — it leaves a stray empty database at the typo'd location for the next reader to mistake for a store (§3 row 6) | distinguish by the file's size and by `select count(*) from sqlite_master` → 0. Recovery: delete the stray file, fix the path |
| 8. `$SCHEDULER_DB` set but empty | `unable to open database file`, exit 1 | **fails CLOSED** — but note the trap: `os.environ.get(k, default)` does not treat `""` as missing, so a shell that exports the variable empty never reaches the default (§3 row 7) | the default is used only when the variable is genuinely unset |
| 9. A competing writer holds the database | 60 s pause, then `database is locked`, exit 1, nothing written | **fails CLOSED** — the busy timeout is honest about how long it waited but the message never says so; the operator sees a hang and then a one-line failure (§3 row 11) | distinguish from a hung run by the constant 60 s and the unchanged table |
| 10. Non-UTF-8 locale | `UnicodeDecodeError`, exit 1, nothing written | **fails CLOSED, loudly** — and it will hit any cron or container whose `LANG` is not UTF-8, because every prompt file contains U+2014 and `read_text()` takes the platform encoding (§3 row 10) | the fix is one argument: `read_text(encoding="utf-8")`. Until then `LC_ALL=C.UTF-8` is a workaround, not a fix |
| 11. Database file read-only | `attempt to write a readonly database`, exit 1 | **fails CLOSED** (§3 row 15) | indistinguishable in shape from row 9; the message is the whole difference |
| 12. A malformed lane tuple | `ValueError`, exit 1, nothing written | **fails CLOSED** — the unpack happens inside the loop, but the transaction absorbs it (§3 row 14) | the message does not name the lane; recovery is by reading the literal |
| 13. An operator passes a safety flag (`--dry-run`, `--help`, `--check`) | the write happens and exit is 0 | **fails OPEN — a safety control that does not exist.** The file imports `os`, `pathlib`, `sqlite3` and nothing else, so `argv` is never read; measured, `--dry-run --check` rewrote the row (§3 row 13) | this is CF-170's headline. Recovery: do not invoke the script against a database you care about; there is no safe invocation |
| 14. `prompt_mode` is hardcoded to `append` | a lane configured as `replace` is silently switched to `append` | **fails OPEN, from source rather than from a probe** — the literal sits inside the `UPDATE` [scripts/load_lane_config.py:34] and the receipt does not select the column, so the change is invisible twice over | every live row happens to be `append` today, which is why this has never bitten; the moment one is set to `replace` it becomes a silent regression |

## 7. Environment and settings it reads

**The precedence question, answered from the source rather than assumed:** there is **no configuration file at all**. The lane table is a Python literal [scripts/load_lane_config.py:20-27], so a lane's namespace, admission mode and prompt file cannot be overridden by any file or variable — changing them means editing the script. For the two values that *are* environment-driven, the order is **environment → default**, where "default" means the `os.environ.get` fallback and nothing else:

| Key | Where read | Default | What a missing key does | What an empty or bad key does |
|---|---|---|---|---|
| `SCHEDULER_DB` | [scripts/load_lane_config.py:14-16] | `~/.hermes/coding-hermes/scheduler.db`, built from `pathlib.Path.home()` — the invoking user's home, so `sudo` sends it to root's home | the default path is used, silently | **empty string** → `unable to open database file`, exit 1 (§3 row 7); **relative path** → resolved against `$PWD`; **absent file** → created 0-byte, then `no such table`, exit 1 (§3 row 6) |
| `CODE_FACTORY_ROOT` | [scripts/load_lane_config.py:18] | `HERE` = `Path(__file__).resolve().parents[1]`, i.e. the repo root [scripts/load_lane_config.py:12] | the repo's own `prompts/` is used — the correct default in every checkout, including this worktree | **empty string** → `prompts/<lane>.md` relative to `$PWD`; **wrong root** → `FileNotFoundError` naming the file, exit 1, nothing written (§3 row 8) |
| `LANG` / `LC_ALL` / `PYTHONUTF8` | not read by this file — read by `Path.read_text()` at [scripts/load_lane_config.py:32] | the interpreter's idea of the platform encoding | normal on a UTF-8 host | **`LC_ALL=C` with UTF-8 mode off** → `UnicodeDecodeError` on the first prompt file, exit 1 (§3 row 10) |
| *(inherited)* working directory | not read; needed only because `prompts/` may resolve relative to it | `$PWD` | — | matters only when `$CODE_FACTORY_ROOT` or `$SCHEDULER_DB` is relative |

**Not read, and each absence matters:** no command-line flag — the script never imports `sys` [scripts/load_lane_config.py:8-10], so `--help`, `--check`, `--dry-run` and any typo are all equally ignored (§3 row 13); no config file; no `~/.hermes/fleet.toml`, even though that file declares `namespace_id = "code-factory"` for every one of these lanes [~/.hermes/fleet.toml:1918] — the disagreement is therefore never detected by either side; and no credential of any kind, which is the one thing this module honours: no token is read and no secret is passed on a command line (fact: FACT-05).

**One name inconsistency worth fixing while here.** This file reads `SCHEDULER_DB`; the sibling reader `scripts/repo_freshness.py` reads `CF_SCHEDULER_DB` for the same database [scripts/repo_freshness.py:68]. An operator who exports one and runs the other silently gets the default path — and on this file a wrong default means writing to, or creating, the wrong database.

## 8. Evidence of record

- Revision: worktree `~/proj-wt-md-23e`, branch `wt/md-23e`, based on `origin/main` at `b9f56e6` (2026-11-05). `scripts/load_lane_config.py` is 45 lines / 1576 bytes there; every locator in this document was resolved against that tree.
- Probe harness (kept, re-runnable): `~/.hermes/cache/scratch/md23e_probe.sh` — 18 numbered cases, full transcript at `~/.hermes/cache/scratch/md23e_probe.log` — plus three ad-hoc runs recorded in the same directory (the `--dry-run` invocation of §3 row 13, the empty-`SCHEDULER_DB` run of §3 row 7, and the stream-size run of §3 row 19). All fixtures live under `$TMPDIR/md23e`; nothing in the set writes to `~/.hermes/coding-hermes/scheduler.db`.
- The complete-run measurement behind §3 row 1 — six configured lanes plus one unconfigured, before and after. Lines are elided where marked; the receipt lines sit between the two dumps because that is when they printed:

  ```
  --- before ---                 # SELECT name, namespace_id, admission_mode, prompt_mode, length(prompt)
  code-factory|code-factory|tasks|append|3
  code-factory-docs|code-factory|cooldown|append|3
  code-factory-duckbrain|code-factory|tasks|append|3
  …                              # 4 more rows, all namespace_id=code-factory
  code-factory             ns=coding-hermes  mode=tasks     prompt=3390
  code-factory-docs        ns=code-factory   mode=cooldown  prompt=3
  code-factory-duckbrain   ns=duckbrain-sync mode=cooldown  prompt=1404
  …                              # 4 more receipt lines, same shape
  EXIT=0
  --- after ---
  code-factory|coding-hermes|tasks|append|3390
  code-factory-docs|code-factory|cooldown|append|3
  code-factory-duckbrain|duckbrain-sync|cooldown|append|1404
  ```

  Note the `code-factory-duckbrain` line: `mode=tasks` before, `mode=cooldown` after, and the receipt prints the new value with no indication that it changed — the flip CF-170 names.
- The two fail-open probes that carry the argument, verbatim apart from one row-count line:

  ```
  === P7 mutated copy: a 7th lane named code-factory-nope that is not in the DB ===
  EXIT=0
  no code-factory-nope row exists (expected: absent)

  === P19 argv is never read: --dry-run/--check/--help still write ===
  before: code-factory|code-factory|tasks|3
  EXIT=0
  after:  code-factory|coding-hermes|tasks|3390
  ```

- The boundary probe, verbatim — bounded wait, closed direction, nothing written:

  ```
  === P11 another writer holds the DB: does the run wait 60 s then fail? ===
  holder: BEGIN IMMEDIATE held
  sqlite3.OperationalError: database is locked
  EXIT=1 ELAPSED=60s
  --- after (rollback: all OLD except the holder's own row) ---
  code-factory|code-factory|tasks|append|3
  ```

- The live-database comparison behind §1 and §3 row 2, run read-only as `file:…?mode=ro`:

  ```
  lane                     live ns          CFG ns           ns?  live mode  CFG mode  mode?  prompt==file
  code-factory             code-factory     coding-hermes    DIFF tasks      tasks     same   False
  code-factory-duckbrain   code-factory     duckbrain-sync   DIFF tasks      cooldown  DIFF   False
  … (four more rows, all ns=DIFF, mode=same, prompt=False)
  total field-level differences a re-run would impose: 13
  ```

- Repair directions this document does not implement (all outside its scope, and CF-170 owns them): add `--apply` and make the default a read-only diff; read with `encoding="utf-8"` [scripts/load_lane_config.py:32]; turn on `PRAGMA foreign_keys=ON` and check `cursor.rowcount` per lane; and reconcile the `CFG` namespaces with `fleet.toml` [~/.hermes/fleet.toml:1918] instead of the four namespaces the table writes today [scripts/load_lane_config.py:21-26].
- Standing rule this section obeys: a row closes only with a command that can be re-run, never with a commit message (fact: FACT-10) — every claim above is either the probe transcript or the read-only query beside it.
- **Stale pointer to fix elsewhere:** `docs/master/00-INDEX.md` still lists this module as RED. The index row is outside this document's scope and needs its status updated alongside this commit.
