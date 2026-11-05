# 10. scripts/configure_family.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/configure_family.py` [scripts/configure_family.py:1] |
| Repository | `code-factory` |
| Revision | tree `6eea792`; the file last changed in `222a8b0` (2026-11-03, "lane workdir targets and configurable node disk floors"); blob `1ff5a6db`, sha256 `44135f4deee873b8…` [scripts/configure_family.py:1] |
| Status | **UNVERIFIED — behaviour measured against a copy of the scheduler DB; the live daemon/API effect is not reproduced here** |

## 1. Purpose and why it matters

- What it does: it derives the canonical lane family from the two families it treats as canonical (`crier`, `9router`), then creates and reconfigures the matching `code-factory-*` lanes [scripts/configure_family.py:2-6] [scripts/configure_family.py:52-65].
- The derivation is not hand-written: the suffix set comes from `SELECT name, namespace_id, admission_mode, COALESCE(cooldown_floor_s,0), workdir FROM projects WHERE name LIKE '<family>%'` and the family prefix is rewritten into a template [scripts/configure_family.py:54-62].
- Measured shape: `derived shape from crier, 9router -> docs, docs-qa, dogfood, foreman, foreman-qa, ops, perf, pm, qa, readme, readme-qa, releng, releng-qa, review, review-qa, sync` — 16 suffixes.
- What it can change, measured against a copy of the live DB: for **every** lane in that set it sets `parent='code-factory'`, `admission_mode`, the whole `prompt` text, `prompt_mode='append'`, `cooldown_floor_s` and `cooldown_ceiling_s` [scripts/configure_family.py:177-187]. It does **not** write `weight`, `priority`, `model`, `provider`, `enabled` or `worker_model` [scripts/configure_family.py:177-187].
- It also rewrites four files in the repository tree, in place and unconditionally: `prompts/docs.md`, `prompts/readme.md`, `prompts/releng.md`, `prompts/perf.md` [scripts/configure_family.py:102-114].
- It assigns namespaces only through the daemon API, not through SQL [scripts/configure_family.py:171].
- Why it matters: it is a family-wide rewrite. On the measured copy it moved an existing lane's cadence floor from 3600 s to 259200 s (`code-factory-dogfood`), **reduced** another lane's ceiling from 691200 s to 172800 s (`code-factory-releng`), and replaced the 3390-byte prompt of `code-factory-ops` where the row previously held none.
- What breaks if the module is absent: **UNKNOWN** — nothing in this repository shows another producer of these rows; whether the scheduler self-heals the family is not shown [scripts/configure_family.py:1-201].
- What breaks if it lies: the only success statement is assembled from the values it *intended* to send, not from a readback: `configured.append(f"{name} ns={ns} mode={mode} floor={floor}{remote_note}")` [scripts/configure_family.py:188], and the namespace `PUT` return value is discarded [scripts/configure_family.py:171]. A failed namespace write therefore still prints as configured.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| Python 3 interpreter | **UNKNOWN** — no minimum is declared [scripts/configure_family.py:1] | `#!/usr/bin/env python3` [scripts/configure_family.py:1] | interpreter-level failure only |
| SQLite scheduler DB | **UNKNOWN** | `~/.hermes/coding-hermes/scheduler.db` [scripts/configure_family.py:19] | unguarded `sqlite3.connect` with a 60 s busy timeout [scripts/configure_family.py:50-51] |
| `lane_target` sibling module | **UNKNOWN** | same directory as this file, put on `sys.path` explicitly [scripts/configure_family.py:16-17] | `ImportError` at import time [scripts/configure_family.py:17] |
| Scheduler daemon HTTP API | **UNKNOWN** | `http://127.0.0.1:9090` [scripts/configure_family.py:20] | `HTTPError` returns a status; other transport errors are **not** caught [scripts/configure_family.py:45-46] |
| Operator token in another process's environment | **UNKNOWN** | `/proc/1755676/environ`, key `SCHEDULER_OPERATOR_TOKEN` [scripts/configure_family.py:24-28] | `FileNotFoundError` before anything is written; measured: `/proc/1755676` does not exist on 2026-11-05 |
| Repo prompt directory | **UNKNOWN** | `<ROOT>/prompts/` [scripts/configure_family.py:103] | `FileNotFoundError` on the first `open(...,"w")` [scripts/configure_family.py:104]; measured with a prompt-less root, where the probe's traceback reads line 100 because the probe redacts the four token lines |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `json` | stdlib [scripts/configure_family.py:9] | request bodies are JSON-encoded [scripts/configure_family.py:32]; responses are parsed as JSON, with an empty body defaulted to `{}` [scripts/configure_family.py:44] | **UNKNOWN** — no version or schema guard |
| `os` | stdlib [scripts/configure_family.py:10] | `os.path.expanduser` for DB/ROOT/HOME [scripts/configure_family.py:19-22], `os.path.join` for prompt paths [scripts/configure_family.py:103] [scripts/configure_family.py:173], `os.makedirs(..., exist_ok=True)` for local workdirs [scripts/configure_family.py:154], `os.path.exists` [scripts/configure_family.py:176] | **UNKNOWN** |
| `sqlite3` | stdlib [scripts/configure_family.py:11] | one connection [scripts/configure_family.py:50], `PRAGMA busy_timeout=60000` [scripts/configure_family.py:51], parameterized `SELECT` [scripts/configure_family.py:55-59], parameterized `UPDATE` [scripts/configure_family.py:177-187], single `commit()` [scripts/configure_family.py:189], readback `SELECT` [scripts/configure_family.py:197-200] | requires the `projects` schema with `parent`, `admission_mode`, `prompt`, `prompt_mode`, `cooldown_floor_s`, `cooldown_ceiling_s` [scripts/configure_family.py:178-179]; a renamed column fails the `UPDATE` |
| `sys` | stdlib [scripts/configure_family.py:12] | inserts the script's own directory on `sys.path` so `lane_target` resolves [scripts/configure_family.py:16] | `ImportError` at [scripts/configure_family.py:17] |
| `urllib.error` | stdlib [scripts/configure_family.py:13] | catches `HTTPError` only, and keeps at most 200 characters of the body [scripts/configure_family.py:45-46] | a non-HTTP transport error (`URLError`, timeout) propagates as an exception; measured direction is "crash after partial external writes" (section 6) |
| `urllib.request` | stdlib [scripts/configure_family.py:14] | builds a `Request` with a bearer header and 30 s timeout [scripts/configure_family.py:33-44] | **UNKNOWN** |
| `lane_target` | sibling module in the same directory [scripts/configure_family.py:17] | `parse(str) -> target` [scripts/configure_family.py:149], `TargetError` [scripts/configure_family.py:150], `target.is_local` [scripts/configure_family.py:153], `target.path` [scripts/configure_family.py:154], `target.display()` [scripts/configure_family.py:158-159] | a changed return shape breaks the local/remote branch and the printed note |

`HOME = os.path.expanduser("~")` is assigned and never read [scripts/configure_family.py:22].

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| Scheduler daemon `POST /api/v1/projects` [scripts/configure_family.py:160-164] | this script writes | HTTP JSON, bearer token [scripts/configure_family.py:37-41] | `{"name", "repo_url": "local:<ROOT>", "workdir"}` only [scripts/configure_family.py:163] | **UNKNOWN** in this repository — the handler is not here; **RED** |
| Scheduler daemon `PUT /api/v1/projects/<name>` [scripts/configure_family.py:171] | this script writes | HTTP JSON | `{"namespace_id": ns}` | **UNKNOWN** in this repository — **RED** |
| SQLite `projects` table [scripts/configure_family.py:55-59] [scripts/configure_family.py:177-187] | this script reads and writes | direct SQLite | six columns per row (section 1) | **UNKNOWN** — the reader is the daemon, whose source is not in this tree; **RED** |
| `<ROOT>/prompts/*.md` [scripts/configure_family.py:102-114] | this script writes, then reads its own output back into rows [scripts/configure_family.py:172-176] | filesystem | a fixed template per lane [scripts/configure_family.py:68-100] | **UNKNOWN** — the tick-time prompt reader is not in this tree; **RED** |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| Compiles | `python3 -m py_compile scripts/configure_family.py` | no output | 2026-11-05 | PASS (`COMPILE-OK`) |
| Full behaviour against a DB copy | probe `/home/kara/.hermes/cache/scratch/md10f/probe/run_probe.py` — copies the live `projects` table read-only into `scheduler-copy.db`, redirects `DB`, `ROOT` and the HTTP layer, leaves every statement intact [scripts/configure_family.py:50-201] | 16 lanes configured, no duplicate rows | 2026-11-05 | 16 configured, 6 created, 0 failed; 32 HTTP calls (16 `POST`, 16 `PUT`); 7 of the pre-existing rows changed |
| Idempotency (docstring claim [scripts/configure_family.py:6]) | probe `twice_probe.py`, same code run twice on one copy | second run changes nothing | 2026-11-05 | run 1 changed 7 rows, run 2 changed **0** rows; run 2 still printed `created: none` and still issued the 16 `POST` + 16 `PUT` calls |
| Read-only / diff mode | `grep -nE 'argparse\|argv\|dry.?run\|--check' scripts/configure_family.py` | no matches if none exists | 2026-11-05 | no match (grep exit 1): the module reads **no arguments at all** [scripts/configure_family.py:9-28] |
| Undo artifact | `grep -nE 'backup\|\.bak\|shutil\|DELETE' scripts/configure_family.py` | no matches if none exists | 2026-11-05 | no match (grep exit 1); after a full run the scratch tree contains no `.bak` file either |
| Token source present | run with DB/API redirected, `/proc` line untouched | either a token or a clear failure | 2026-11-05 | `FileNotFoundError: [Errno 2] No such file or directory: '/proc/1755676/environ'` at line 25, exit 1, nothing written |
| Partial-failure visibility | probe `exit_probe.py`, one lane's `POST` answered 500 | failure must be visible to automation | 2026-11-05 | stdout `failed: code-factory-qa: 500 injected 500`, **exit code 0** |
| Crash mid-run | probe `crash_probe.py`, raise on the 5th `UPDATE` [scripts/configure_family.py:177] | state must not be half-applied | 2026-11-05 | 0 DB rows changed (no `commit` reached [scripts/configure_family.py:189]); 10 HTTP calls already issued; the 4 prompt writes [scripts/configure_family.py:102-114] had already executed |

## 4. Metrics emitted

**NONE.** No counter, histogram, gauge or exporter is defined, and no metrics client is imported [scripts/configure_family.py:9-14]. The only channel is stdout, which is unstructured `print` traffic [scripts/configure_family.py:63-65] [scripts/configure_family.py:191-201].

This matters for automation: the process exit status carries no failure signal. A lane whose creation returned 500 is recorded in the `failed` list and the script still exits 0 [scripts/configure_family.py:167-169] [scripts/configure_family.py:192]; measured in the `exit_probe.py` row of section 3. Dispatch rate, per-lane latency and failure counts are therefore **UNKNOWN** from this module and must be read from the daemon, whose side is not in this tree.

## 5. Log lines it can generate

| Kind | Line (verbatim) | Emitted when |
|---|---|---|
| descriptive | `derived shape from crier, 9router -> docs, docs-qa, dogfood, foreman, foreman-qa, ops, perf, pm, qa, readme, readme-qa, releng, releng-qa, review, review-qa, sync` [scripts/configure_family.py:63-65] | after the derivation `SELECT`, before any write |
| descriptive | `wrote /home/kara/code-factory/prompts/docs.md` [scripts/configure_family.py:114] | once per prompt file, before any DB or API write |
| descriptive | `note: code-factory-docs workdir is remote: <target>` [scripts/configure_family.py:159] | only when the derived workdir parses as non-local [scripts/configure_family.py:157-159] |
| descriptive | `created: none` / `created: code-factory-docs, code-factory-docs-qa, …` [scripts/configure_family.py:191] | end of run; lists `POST` 201 responses only |
| evidentiary only for a human | `failed: code-factory-qa: 500 injected 500` [scripts/configure_family.py:192] | end of run; the **only** place a per-lane failure appears, and the exit status stays 0 |
| descriptive | `  code-factory-docs ns=docs mode=cooldown floor=604800` [scripts/configure_family.py:193-195] | end of run; built from the intended values, not from a readback |
| descriptive | `  code-factory-docs              ns=code-factory   mode=cooldown  floor=604800` [scripts/configure_family.py:196-201] | end of run; a DB readback of four columns only — it cannot confirm `prompt`, `prompt_mode`, `parent` or `cooldown_ceiling_s` |

No logger, level, destination file or retention policy exists; the module only writes to file descriptors 1 and 2 [scripts/configure_family.py:9-14] [scripts/configure_family.py:63-201].

## 6. Failure modes

Direction means: does it fail loud or quiet, does it over- or under-report, and does it write before it fails?

| Failure | Presents as | Direction | Recovery |
|---|---|---|---|
| Token source gone (hard-coded `/proc/1755676/environ`) [scripts/configure_family.py:24-25] | `FileNotFoundError: [Errno 2] No such file or directory: '/proc/1755676/environ'`, exit 1 | loud, and safe: nothing is written before it, because the read precedes the DB open [scripts/configure_family.py:25] [scripts/configure_family.py:50] | edit the constant; there is no flag or env override [scripts/configure_family.py:24-28]. Measured: this is the state on 2026-11-05, so the script cannot currently start |
| Token variable absent from that process's environment | `StopIteration` from the bare `next(...)` generator [scripts/configure_family.py:26-28] | loud but opaque — the traceback names `StopIteration`, not the missing key | none in-process |
| `<ROOT>/prompts` missing or unwritable [scripts/configure_family.py:103-104] | `FileNotFoundError` on the first `open(path,"w")`, exit 1, after the shape line has already printed | partially loud: no DB/API write yet, but any prompt file rewritten earlier in the loop stays rewritten | recreate the directory; there is no `makedirs` for `prompts/` (only for lane workdirs [scripts/configure_family.py:154]) |
| `POST /api/v1/projects` returns anything other than 201/409 [scripts/configure_family.py:165-169] | line `failed: …` on stdout, that lane skipped, exit status still 0 [scripts/configure_family.py:192] | quiet to automation, under-reports: a partial family looks like a clean run | rerun; the 409 path treats an existing row as "configure it" [scripts/configure_family.py:167-171] |
| `PUT /api/v1/projects/<name>` fails (403/404/500) [scripts/configure_family.py:171] | nothing; the return value is discarded and the lane is still appended to `configured` with its intended namespace [scripts/configure_family.py:188] | over-reports: claims a namespace change that did not happen | inspect the row; the only evidence is the DB readback, which prints the namespace column but only for rows that exist [scripts/configure_family.py:196-201] |
| Row absent when the `UPDATE` runs (API answered 201/409 but inserted nothing) [scripts/configure_family.py:177-187] | no error; `UPDATE … WHERE name=?` affects 0 rows and the lane is still listed under `configured` [scripts/configure_family.py:188] | over-reports; silent no-op | create the row, then rerun |
| Crash between two lanes (transport error, `KeyboardInterrupt`, SQL failure) | traceback, exit 1 | split-brain: the DB transaction is rolled back because `commit()` is last [scripts/configure_family.py:189], while created rows, namespace `PUT`s and the four prompt rewrites are already durable on their own systems | measured: rerun after fixing; there is no compensating delete or restore step anywhere in the module |
| DB locked longer than the busy timeout | `sqlite3.OperationalError` after 60 s [scripts/configure_family.py:50-51] | loud, but only after all four prompt files have been rewritten [scripts/configure_family.py:102-114] | rerun; nothing to roll back in the DB |
| Derived workdir is unparseable | `failed: <name>: invalid workdir target '<wd>': …`, lane skipped, exit 0 [scripts/configure_family.py:148-152] | quiet to automation, under-reports | fix the source family's workdir and rerun |
| Re-run after a partial success | second run changes no DB values (measured: 0 rows), but re-issues all 32 HTTP calls and rewrites the 4 prompt files again [scripts/configure_family.py:102-114] [scripts/configure_family.py:160-189] | idempotent on values, not on effects: each run is another 32 authenticated writes | none needed for the DB; prompt files lose any local edit every run |

## 7. Environment and settings it reads

- Database: `DB = os.path.expanduser("~/.hermes/coding-hermes/scheduler.db")` [scripts/configure_family.py:19].
- API base: `API = "http://127.0.0.1:9090"` [scripts/configure_family.py:20].
- Repository root used for `repo_url`, for `prompts/`, and for local lane workdirs: `ROOT = os.path.expanduser("~/code-factory")` [scripts/configure_family.py:21] [scripts/configure_family.py:103] [scripts/configure_family.py:163].
- Credential: read from `/proc/1755676/environ`, key `SCHEDULER_OPERATOR_TOKEN` [scripts/configure_family.py:24-28]. This is neither an argv value nor a mode-600 file path of the kind the credential rule records (fact: FACT-05); the token is scraped out of an unrelated process's environment, and it fails if that PID is gone — which is the measured state on 2026-11-05.
- No command-line arguments and no environment-variable reads: there is no `argparse`/`argv` use and no `os.environ`/`os.getenv` call [scripts/configure_family.py:9-28]. There is therefore no `--check`, `--diff`, `--dry-run` or `--project` switch; the target set, the values and the prompt text are all compile-time constants [scripts/configure_family.py:52-138].
- Cadence ceilings written by the run, as `seconds = hours × 3600` and `days = 604800` [scripts/configure_family.py:128-138]: `docs`/`readme`/`perf` = 4838400 s, `releng`/`qa`/`sync` = 172800 s, `pm` = 691200 s, `dogfood` = 2073600 s, `duckbrain` = 0. Any other base falls back to `floor * 8` [scripts/configure_family.py:184].
- Prompt-file mapping: lane base → file under `<ROOT>/prompts/`, defaulting to `foreman` [scripts/configure_family.py:117-127] [scripts/configure_family.py:172-176]; an absent file becomes an empty prompt string rather than an error [scripts/configure_family.py:176].
- The four prompt bodies it writes are constants in the module, each followed by the same ground-rule block [scripts/configure_family.py:68-100] [scripts/configure_family.py:105-113].
- Workdir derivation: the source family's workdir with the family name replaced by `code-factory` [scripts/configure_family.py:61-62] [scripts/configure_family.py:143]. Measured result: `/home/kara/.hermes/stand-in/docs/code-factory`, `/home/kara/.hermes/stand-in/pm/code-factory`, and so on — control-host stand-in paths, not a bunker target. Under fact: FACT-01 and fact: FACT-02 a lane is expected to run on the project's bunker node, so these workdirs are a mismatch to resolve, not a documented exception.
- Local workdirs are `mkdir -p`'d before the API call [scripts/configure_family.py:153-155]; remote targets are registered as-is with a printed note [scripts/configure_family.py:157-159].

## 8. Evidence of record

- Source identity: blob `1ff5a6db`, sha256 `44135f4deee873b823bcac9f53c236b4aa35496d3c20bb34bbe6fb00060a454a`, tree `6eea792`, last touching commit `222a8b0` (2026-11-03). The module compiles cleanly.
- What the run writes, measured on a copy of the live `projects` table (`~/.hermes/cache/scratch/md10f/probe/scheduler-copy.db`, 880 rows copied read-only; the live DB is never opened for writing): 16 lanes targeted, 6 created, 0 failed; 7 of the pre-existing rows changed, on exactly the six columns the `UPDATE` names [scripts/configure_family.py:177-187].
- Sample of the measured deltas: `code-factory-dogfood` `cooldown_floor_s` 3600 → 259200; `code-factory-releng` `cooldown_floor_s` 3600 → 21600 **and** `cooldown_ceiling_s` 691200 → 172800; `code-factory-ops` `parent` `''` → `'code-factory'`, `admission_mode` `''` → `'cooldown'`, prompt 0 → 3390 bytes; `code-factory-pm` and `code-factory-sync` floor 3600 → 21600.
- Undo: **there is none in the module.** No snapshot, copy, `.bak`, journal or `DELETE` call exists [scripts/configure_family.py:9-201] (grep for `backup|.bak|shutil|DELETE` returns nothing), and no backup artifact appeared in the scratch tree after a full run. Restoring the overwritten `parent`, `admission_mode`, `prompt`, `prompt_mode`, `cooldown_floor_s` and `cooldown_ceiling_s` values requires manual SQL from a snapshot taken outside this tool, which the tool neither takes nor records.
- Undo is also asymmetric: the database writes are one transaction committed at the end [scripts/configure_family.py:189], so a crash rolls them back, but the four `prompts/*.md` writes [scripts/configure_family.py:102-114] and the `POST`/`PUT` calls [scripts/configure_family.py:160-171] execute before that commit and are not rolled back — measured with an injected failure on the 5th `UPDATE`: 0 DB rows changed, 10 HTTP calls issued, the 4 prompt writes already done (their bytes were unchanged only because the module's text matched the tree copy).
- The run leaves no board row and no run receipt: the module writes only prompts, the DB columns above and the two API calls [scripts/configure_family.py:102-201], while the fleet's per-work record is the append-only board (fact: FACT-09). A run is therefore reconstructable only from shell history, daemon logs, or an external snapshot.
- Probe artifacts (not part of the repository): `/home/kara/.hermes/cache/scratch/md10f/probe/run_probe.py`, `twice_probe.py`, `exit_probe.py`, `crash_probe.py`, `failure_probe.py`, with `out.txt` and `fail.txt` holding the captured stdout of each run.
- Section status remains **UNVERIFIED**, not VERIFIED: the copy run proves what the module does to the DB and to the prompt files, but the daemon-side effect of `POST`/`PUT` (row defaults on create, namespace persistence) is **UNKNOWN** in this tree, and no independent live receipt exists.
