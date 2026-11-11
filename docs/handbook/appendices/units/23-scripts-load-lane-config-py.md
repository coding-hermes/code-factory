# 23. scripts/load_lane_config.py

| Field | Value |
|---|---|
| Path | `scripts/load_lane_config.py` — 175 lines; six configured lanes; argparse options and an explicit write mode [scripts/load_lane_config.py:1] [scripts/load_lane_config.py:17-24] [scripts/load_lane_config.py:41-67] |
| Repository | `code-factory` |
| Revision | `08080027` — the read-only-by-default fix named by CF-304 [scripts/load_lane_config.py:2-6] |
| Status | **VERIFIED — 16 recorded checks against fixture databases; the live scheduler was not opened by these checks** [scripts/load_lane_config.py:80-89] |

## 1. Purpose and why it matters

- **What it is, precisely: a reporter with an explicit writer mode.** The module reports the six configured lane updates by default; `--apply` is required to write them, and `--dry-run` takes precedence over `--apply` [scripts/load_lane_config.py:2-6] [scripts/load_lane_config.py:150-162].
- **The configuration surface is a six-entry Python mapping.** Each entry supplies a project name, namespace, admission mode and prompt stem [scripts/load_lane_config.py:17-24].
- **The default report is read-only.** Report mode opens the database through a SQLite `mode=ro` URI and does not call the writer [scripts/load_lane_config.py:80-89] [scripts/load_lane_config.py:150-162].
- **The write path is narrow and explicit.** `apply_updates()` executes one parameterized `UPDATE` for each configured lane and commits once; `main()` reaches it only when `read_only` is false [scripts/load_lane_config.py:31-38] [scripts/load_lane_config.py:150-162].
- **The report describes the proposed update and then reads back matching rows.** It does not claim a row-count metric [scripts/load_lane_config.py:105-119] [scripts/load_lane_config.py:126-147].
- **The prompt files are read as UTF-8 before the database work.** A missing or unreadable prompt is converted into a named operator-facing error [scripts/load_lane_config.py:92-102].
- **CF-304 is the recorded reason for this behavior.** The board row records a read-only default, explicit `--apply`, and no-write proof for diagnostic modes [`.coding-hermes/board/tasks.jsonl:278`] [fact: FACT-09].

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Contract | Evidence |
|---|---|---|
| `python3` | The shebang selects Python 3, and the module imports only standard-library modules [scripts/load_lane_config.py:1] [scripts/load_lane_config.py:8-12] | No third-party package is imported [scripts/load_lane_config.py:8-12] |
| SQLite database | The selected database must already be a file containing the `projects` table and the six configured project rows [scripts/load_lane_config.py:80-89] [scripts/load_lane_config.py:105-119] | A missing database is refused before connection [scripts/load_lane_config.py:80-82]; missing project rows are refused [scripts/load_lane_config.py:115-119] |
| Prompt files | Six files under `prompts/` are read using UTF-8, with the stem supplied by the configuration mapping [scripts/load_lane_config.py:17-24] [scripts/load_lane_config.py:92-102] | Missing and unreadable files produce `LaneConfigError` [scripts/load_lane_config.py:98-101] |

No network or subprocess is used by this module; its imports are standard-library imports [scripts/load_lane_config.py:8-12].

### 2b. Library contracts

| Call or value | Contract relied on | Measured consequence |
|---|---|---|
| `argparse.ArgumentParser` | `--apply`, `--dry-run`, `--check` and `--db` are declared options; invalid arguments are rejected by argparse [scripts/load_lane_config.py:41-67] | `--bogus` exited 2 and printed usage naming the four options [scripts/load_lane_config.py:41-67] |
| `database_path()` | An explicit `--db` path wins; otherwise `SCHEDULER_DB` is consulted before the home-derived fallback [scripts/load_lane_config.py:70-77] | An empty or directory-valued database selection exited 1 [scripts/load_lane_config.py:70-77] |
| `open_database(path, read_only)` | Report mode uses `file:<path>?mode=ro` with `uri=True`; apply mode uses a writable SQLite connection [scripts/load_lane_config.py:80-89] | Report mode succeeded against a mode-0444 database, while apply mode exited 1 without changing it [scripts/load_lane_config.py:80-89] |
| `Path.read_text(encoding="utf-8")` | Prompt decoding is independent of the locale's preferred encoding [scripts/load_lane_config.py:92-102] | Default and `--check` modes exited 0 under `LC_ALL=C` [scripts/load_lane_config.py:92-102] |
| `con.commit()` | The six updates become durable only in the explicit apply path [scripts/load_lane_config.py:31-38] [scripts/load_lane_config.py:150-164] | A second `--apply` left the database byte-identical after the first apply [scripts/load_lane_config.py:31-38] |

### 2c. Peers — both sides named

| Peer | Direction | Payload | Evidence |
|---|---|---|---|
| `projects` table | script → SQLite | `namespace_id`, `admission_mode`, `prompt` and `prompt_mode='append'` for six named rows [scripts/load_lane_config.py:31-38] | The readback selects matching project rows after report or apply [scripts/load_lane_config.py:140-147] |
| `prompts/*.md` | file → script | Prompt text for the six mapping entries [scripts/load_lane_config.py:17-24] [scripts/load_lane_config.py:92-102] | The report prints the source prompt stem and lengths [scripts/load_lane_config.py:126-137] |
| CF-304 board row | board → evidence record | The row records the read-only default and explicit apply contract [`.coding-hermes/board/tasks.jsonl:278`] [fact: FACT-09] | The current script behavior is exercised by `tests/test_lane_config_readonly.py` [tests/test_lane_config_readonly.py:90-162] |

## 3. Verification

Measured against commit `08080027` with the fixture harness recorded in the CF-304 test suite. Each row below is one recorded check; report modes used a fixture database and the live scheduler was not used [tests/test_lane_config_readonly.py:33-46] [tests/test_lane_config_readonly.py:49-69].

| # | Check | Command | Result |
|---|---|---|---|
| 1 | No arguments | `python3 scripts/load_lane_config.py --db "$FIXTURE_DB"` | **PASS** — exit 0 and the database digest was unchanged [scripts/load_lane_config.py:150-162] |
| 2 | `--check` | `python3 scripts/load_lane_config.py --db "$FIXTURE_DB" --check` | **PASS** — exit 0 and no database write [scripts/load_lane_config.py:56-59] [scripts/load_lane_config.py:150-162] |
| 3 | `--dry-run` | `python3 scripts/load_lane_config.py --db "$FIXTURE_DB" --dry-run` | **PASS** — exit 0 and no database write [scripts/load_lane_config.py:51-54] [scripts/load_lane_config.py:150-162] |
| 4 | `--help` | `python3 scripts/load_lane_config.py --help` | **PASS** — exit 0 and help listed `--apply`, `--dry-run`, `--check` and `--db` [scripts/load_lane_config.py:41-67] |
| 5 | Missing database file | `python3 scripts/load_lane_config.py --db "$MISSING_DB"` | **PASS** — exit 1 with `ERROR: database missing: ...`; no file was created [scripts/load_lane_config.py:80-82] [scripts/load_lane_config.py:165-170] |
| 6 | Explicit apply and idempotent second apply | `python3 scripts/load_lane_config.py --db "$FIXTURE_DB" --apply`, then repeat the same command | **PASS** — the first run changed the database; the second left it byte-identical [scripts/load_lane_config.py:31-38] [scripts/load_lane_config.py:150-162] |
| 7 | Invalid option | `python3 scripts/load_lane_config.py --db "$FIXTURE_DB" --bogus` | **PASS** — exit 2; argparse printed usage and `unrecognized arguments: --bogus` [scripts/load_lane_config.py:41-67] |
| 8 | Empty `SCHEDULER_DB` | `SCHEDULER_DB="" python3 scripts/load_lane_config.py` | **PASS** — exit 1 with a named missing database path [scripts/load_lane_config.py:70-77] [scripts/load_lane_config.py:165-170] |
| 9 | `SCHEDULER_DB` is a directory | `SCHEDULER_DB="$FIXTURE_DIR" python3 scripts/load_lane_config.py` | **PASS** — exit 1 with a named missing database path [scripts/load_lane_config.py:70-82] |
| 10 | Default mode under the C locale | `LC_ALL=C python3 scripts/load_lane_config.py --db "$FIXTURE_DB"` | **PASS** — exit 0; UTF-8 prompt reads succeeded [scripts/load_lane_config.py:92-102] |
| 11 | `--check` under the C locale | `LC_ALL=C python3 scripts/load_lane_config.py --db "$FIXTURE_DB" --check` | **PASS** — exit 0 [scripts/load_lane_config.py:56-59] [scripts/load_lane_config.py:92-102] |
| 12 | Report mode against a mode-0444 database | `chmod 0444 "$FIXTURE_DB"; python3 scripts/load_lane_config.py --db "$FIXTURE_DB"` | **PASS** — exit 0 and the report did not write [scripts/load_lane_config.py:80-89] |
| 13 | Apply mode against a mode-0444 database | `python3 scripts/load_lane_config.py --db "$FIXTURE_DB" --apply` | **PASS** — exit 1 with `ERROR: database operation failed: attempt to write a readonly database`; the digest was unchanged [scripts/load_lane_config.py:80-89] [scripts/load_lane_config.py:168-170] |
| 14 | Prompt file mode 000 | `chmod 000 prompts/sync.md; python3 scripts/load_lane_config.py --db "$FIXTURE_DB"` | **PASS** — exit 1 with a named unreadable prompt [scripts/load_lane_config.py:92-102] [scripts/load_lane_config.py:165-167] |
| 15 | Missing parent directory for `--db` | `python3 scripts/load_lane_config.py --db /nonexistent/dir/x.db; test -e /nonexistent/dir/x.db` | **PASS** — the command exited 1 and `test -e` reported absent; the path was not created [scripts/load_lane_config.py:80-82] |
| 16 | Exact first two stdout lines for default and dry-run | `python3 scripts/load_lane_config.py --db "$FIXTURE_DB"` and the same command with `--dry-run` | **PASS** — both exited 0, both had empty stderr, and both began with the quoted lines below [scripts/load_lane_config.py:126-137] [scripts/load_lane_config.py:150-162] |

Default mode:

```text
UPDATE set (current -> target; source is the prompt text copied):
code-factory: namespace_id 'coding-hermes' -> coding-hermes; admission_mode 'tasks' -> tasks; prompt length 6528 -> 6528 (prompts/foreman.md); prompt_mode 'append' -> 'append'
```

`--dry-run`:

```text
UPDATE set (current -> target; source is the prompt text copied):
code-factory: namespace_id 'coding-hermes' -> coding-hermes; admission_mode 'tasks' -> tasks; prompt length 6528 -> 6528 (prompts/foreman.md); prompt_mode 'append' -> 'append'
```

## 4. Metrics emitted

The module emits no separate metric file or counter; its observable success output is the proposed update report followed by database readback [scripts/load_lane_config.py:126-147].

The output can show current values and prompt lengths for matching `code-factory%` rows [scripts/load_lane_config.py:140-147]. It does not expose `cursor.rowcount` or a changed-row total [scripts/load_lane_config.py:31-38] [scripts/load_lane_config.py:126-147].

## 5. Log lines it can generate

The success path writes the update heading, one proposed-update line per configured lane, and one readback line per matching database row [scripts/load_lane_config.py:126-147]. Error paths prefix named configuration failures with `ERROR:` and return 1 [scripts/load_lane_config.py:165-170].

| Stream | Example | Emission site | Meaning |
|---|---|---|---|
| stdout | `UPDATE set (current -> target; source is the prompt text copied):` | [scripts/load_lane_config.py:126-127] | The report heading [scripts/load_lane_config.py:126-127] |
| stdout | `code-factory: namespace_id ...; prompt_mode 'append' -> 'append'` | [scripts/load_lane_config.py:128-137] | One proposed update for a configured lane [scripts/load_lane_config.py:128-137] |
| stdout | `code-factory             ns=... mode=... prompt=...` | [scripts/load_lane_config.py:140-147] | One readback row [scripts/load_lane_config.py:140-147] |
| stderr | `ERROR: database missing: ...` | [scripts/load_lane_config.py:165-167] | A named configuration refusal [scripts/load_lane_config.py:80-82] [scripts/load_lane_config.py:165-167] |
| stderr | `ERROR: database operation failed: ...` | [scripts/load_lane_config.py:168-170] | A SQLite operation failure [scripts/load_lane_config.py:168-170] |

## 6. Failure modes

| Failure | Presents as | Direction | Evidence and recovery |
|---|---|---|---|
| Missing database file | `ERROR: database missing: ...`, exit 1 | **Fails closed before opening SQLite** | The file check precedes connection [scripts/load_lane_config.py:80-82]; provide an existing database path [scripts/load_lane_config.py:70-77] |
| Missing configured project row | `ERROR: project rows missing: ...`, exit 1 | **Fails closed** | `read_rows()` compares returned names with the six mapping keys [scripts/load_lane_config.py:105-119] |
| Missing or unreadable prompt | `ERROR: prompt file missing: ...` or `ERROR: prompt file unreadable: ...`, exit 1 | **Fails closed before a write** | Prompt loading occurs before connection and apply [scripts/load_lane_config.py:92-102] [scripts/load_lane_config.py:154-162] |
| Invalid command-line option | argparse usage and exit 2 | **Fails closed** | The parser rejects unknown arguments [scripts/load_lane_config.py:41-67] |
| Report, check or dry-run mode | Exit 0 with report and unchanged database | **Read-only by construction** | `read_only` is true unless apply is requested without a diagnostic override [scripts/load_lane_config.py:150-162] |
| Explicit apply | Six updates and one commit, exit 0 on success | **Writes only when requested** | `apply_updates()` is called only on the non-read-only branch [scripts/load_lane_config.py:31-38] [scripts/load_lane_config.py:160-162] |
| Apply against a read-only database | `ERROR: database operation failed: attempt to write a readonly database`, exit 1 | **Fails closed** | The read-only SQLite operation is rejected and the recorded digest stayed unchanged [scripts/load_lane_config.py:80-89] [scripts/load_lane_config.py:168-170] |
| Empty or directory database selection | Named database refusal, exit 1 | **Fails closed** | `database_path()` and `open_database()` validate the selected path [scripts/load_lane_config.py:70-89] |
| C locale | Successful UTF-8 prompt reads in report and check modes | **No locale decoding failure in the measured modes** | The read explicitly supplies UTF-8 [scripts/load_lane_config.py:92-102] |
| Second explicit apply | Exit 0 with byte-identical database | **Idempotent in the recorded fixture** | The same six values are written and committed again [scripts/load_lane_config.py:31-38] |

## 7. Environment and settings it reads

The script reads `SCHEDULER_DB` when `--db` is absent, and otherwise uses the explicit `--db` value; the fallback is derived by `pathlib.Path.home()` [scripts/load_lane_config.py:70-77].

It reads `CODE_FACTORY_ROOT` at module load time, falling back to the repository root derived from the script location [scripts/load_lane_config.py:14-15]. Prompt names and target values come from the in-file `CFG` mapping, not a separate configuration file [scripts/load_lane_config.py:17-24].

| Setting | Read site | Behavior |
|---|---|---|
| `SCHEDULER_DB` | [scripts/load_lane_config.py:73-77] | Selects the database when `--db` is absent [scripts/load_lane_config.py:70-77] |
| `CODE_FACTORY_ROOT` | [scripts/load_lane_config.py:14-15] | Selects the root beneath which the six prompt files are read [scripts/load_lane_config.py:92-102] |
| `--apply` | [scripts/load_lane_config.py:45-49] | Enables the write branch [scripts/load_lane_config.py:150-162] |
| `--dry-run` | [scripts/load_lane_config.py:50-54] | Forces read-only behavior, including when `--apply` is also present [scripts/load_lane_config.py:150-153] |
| `--check` | [scripts/load_lane_config.py:55-59] | Is a read-only alias for report mode [scripts/load_lane_config.py:150-153] |
| `--db` | [scripts/load_lane_config.py:60-65] | Overrides the environment/default database selection [scripts/load_lane_config.py:70-77] |
| Locale | Not directly consulted for decoding | Prompt reads supply `encoding="utf-8"` [scripts/load_lane_config.py:92-102] |

The module does not read a fleet TOML file or credentials; its imports and environment reads are visible in the source [scripts/load_lane_config.py:8-15].

## 8. Evidence of record

- The source measurement recorded 175 lines and SHA-256 `92e35c7ebe41614d6eec7b9fe34434185cd91619eb46a0168a7c9842d7cb20e2` for `scripts/load_lane_config.py`; the source ends at the `SystemExit(main())` entry point [scripts/load_lane_config.py:174-175].
- Commit `08080027` is the implementation revision documented here; the board row records its full commit hash and passing guard result [`.coding-hermes/board/tasks.jsonl:278`] [fact: FACT-09].
- The re-runnable fixture suite is `tests/test_lane_config_readonly.py`; it covers default report, dry-run, explicit apply, named refusals and a pre-fix red control [tests/test_lane_config_readonly.py:90-225].
- The measured checks in §3 were run against fixture databases; the live scheduler was not opened by these checks [tests/test_lane_config_readonly.py:33-46] [scripts/load_lane_config.py:80-89].
- The board evidence rule is satisfied here by commands that can be run again, rather than by the commit message alone [fact: FACT-10].
- Not measured: behavior against a live scheduler database, because the recorded verification scope used fixture databases only [tests/test_lane_config_readonly.py:33-46].
