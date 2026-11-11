# 10. scripts/configure_family.py

| Field | Value |
|---|---|
| Path | `~/code-factory/scripts/configure_family.py` [scripts/configure_family.py:1] |
| Repository | `code-factory` |
| Revision | tree `ffecec4`, blob `1ff5a6db`, sha256 `44135f4deee873b823bcac9f53c236b4aa35496d3c20bb34bbe6fb00060a454a` (7 891 bytes); last changed in `222a8b0` (2026-11-03, "lane workdir targets and configurable node disk floors") |
| Status | **VERIFIED — every request measured against a recording stub, and the daemon side measured against a scratch `schedulerd` built from its source over a copy of the live DB, 2026-11-05; the live service was never addressed** |

## 1. Purpose and why it matters

- What it does: it derives the canonical lane family from the two families it treats as
  canonical (`crier`, `9router`), then creates and reconfigures the matching `code-factory-*`
  lanes [scripts/configure_family.py:2-6] [scripts/configure_family.py:52-65].
- The derivation is not hand-written: the suffix set comes from `SELECT name, namespace_id,
  admission_mode, COALESCE(cooldown_floor_s,0), workdir FROM projects WHERE name LIKE
  '<family>%'` and the family prefix is rewritten into a template
  [scripts/configure_family.py:54-62]. Measured shape line: `derived shape from crier, 9router
  -> docs, docs-qa, dogfood, foreman, foreman-qa, ops, perf, pm, qa, readme, readme-qa, releng,
  releng-qa, review, review-qa, sync` — 16 suffixes, in that order.
- For **every** lane in that set it sets `parent='code-factory'`, `admission_mode`, the whole
  `prompt` text, `prompt_mode='append'`, `cooldown_floor_s` and `cooldown_ceiling_s`
  [scripts/configure_family.py:177-187]. It does **not** write `weight`, `priority`, `model`,
  `provider`, `enabled`, `worker_model` or `workdir` [scripts/configure_family.py:177-187].
- It rewrites four files in the repository tree, in place and unconditionally:
  `prompts/docs.md`, `prompts/readme.md`, `prompts/releng.md`, `prompts/perf.md`
  [scripts/configure_family.py:102-114]. Measured: those four files are already byte-identical to
  the module's text, so the rewrite changed no content — the step ran anyway (four `wrote` lines).
- It assigns namespaces only through the daemon API, never through SQL
  [scripts/configure_family.py:171]; the response of that call is discarded.
- **What a run achieves depends on the peer, and that is the module's central finding.** Two runs
  against the same 880-row copy of the live `projects` table, 2026-11-05:
  - against the recording stub, which answers HTTP and never touches the store, the script issues
    its full 32 calls (16 `POST`, 16 `PUT`) and exits 0. Ten names already existed (409), six were
    answered 201, and 7 of the pre-existing rows changed on the six columns above.
  - against a scratch `schedulerd` (built from the daemon source at
    `~/coding-hermes-scheduler/coding-herms-scheduler`, simulation mode, loopback
    `127.0.0.1:19095`, same copy DB) the run **configures exactly one lane and fails the other
    fifteen**. The script opens a SQLite write transaction at its first `UPDATE`
    [scripts/configure_family.py:177] and commits only after the whole loop
    [scripts/configure_family.py:189]; while that transaction is open the daemon's `INSERT` for the
    next lane cannot take the write lock, waits out the 5 s `busy_timeout` the daemon arms
    (`~/coding-hermes-scheduler/coding-herms-scheduler/internal/database/schema.go:64`) and
    answers `500 … database is locked (5) (SQLITE_BUSY)`. Each refusal takes about 10 s, the run ends
    with `failed:` listing 15 lanes, and the exit status is **0**. Both runs are quoted verbatim in
    section 3.
- Because a failed `POST` is `continue`d [scripts/configure_family.py:165-169], the failing lane also
  gets no `PUT` and no `UPDATE`: in the stub fault run one refused lane produced 31 calls (16
  `POST`, 15 `PUT`), not 32.
- What it can change, measured on the copy: `code-factory-dogfood` `cooldown_floor_s` 3600 →
  259200; `code-factory-releng` `cooldown_floor_s` 3600 → 21600 **and** `cooldown_ceiling_s`
  691200 → 172800; `code-factory-ops` `parent` `''` → `'code-factory'`, `admission_mode` `''` →
  `'cooldown'`, prompt 0 → 3390 bytes; `code-factory-pm` floor 3600 → 21600; `code-factory-sync`
  floor 3600 → 21600 and prompt 2923 → 1358; `code-factory-qa` prompt 1539 → 1384;
  `code-factory-review` prompt 1082 → **3390** — the review lane has no `LANE_PROMPT` entry, so it
  falls back to the `foreman` file [scripts/configure_family.py:117-127]
  [scripts/configure_family.py:172-176] and loses its review-specific prompt.
- What breaks if the module is absent: nothing else in this repository produces the full family.
  The live fleet carries 17 `code-factory%` rows; `code-factory-docs-qa`, `code-factory-foreman`,
  `code-factory-foreman-qa`, `code-factory-readme-qa`, `code-factory-releng-qa` and
  `code-factory-review-qa` are absent today. `scripts/add_family_lanes.py:50` covers eight other
  names only.
- What breaks if it lies: the only success statement is assembled from the values it *intended* to
  send, not from a readback — `configured.append(f"{name} ns={ns} mode={mode} floor={floor}
  {remote_note}")` [scripts/configure_family.py:188] — and the namespace `PUT` return value is
  discarded [scripts/configure_family.py:171]. Measured: with that `PUT` answered 500 the lane is
  still printed as `code-factory-releng ns=releases` while the DB readback three lines below shows
  `ns=code-factory`.
- A run leaves no board row and no run receipt: it writes prompts, the six DB columns and the two
  API calls [scripts/configure_family.py:102-201], while the fleet's per-work record is the
  append-only board (fact: FACT-09). Reconstructing a run needs shell history, daemon logs or an
  external snapshot.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| Python 3 interpreter | measured on **3.14.9**; stdlib only, no third-party import | `#!/usr/bin/env python3` [scripts/configure_family.py:1] | interpreter-level failure only; no minimum is declared |
| SQLite scheduler DB | live file measured at 16 GB, WAL; the copy used for all runs carries 880 `projects` rows | `~/.hermes/coding-hermes/scheduler.db` [scripts/configure_family.py:19] | unguarded `sqlite3.connect` with a 60 s busy timeout [scripts/configure_family.py:50-51]; a missing file is created empty and the derivation then finds no suffixes |
| `lane_target` sibling module | shipped in the same directory | same directory as this file, put on `sys.path` explicitly [scripts/configure_family.py:16-17] | `ImportError` at import time [scripts/configure_family.py:17] |
| Scheduler daemon HTTP API | hard-coded `http://127.0.0.1:9090` [scripts/configure_family.py:20] | loopback of the host that owns the DB | `HTTPError` returns a status; a transport failure is **not** caught [scripts/configure_family.py:42-46] and kills the run (measured: connection dropped before a response → `http.client.RemoteDisconnected`, exit 1) |
| Operator token in another process's environment | — | `/proc/1755676/environ`, key `SCHEDULER_OPERATOR_TOKEN` [scripts/configure_family.py:24-28] | `FileNotFoundError` before anything is written; measured: `/proc/1755676` does not exist on 2026-11-05 |
| Repo prompt directory | — | `<ROOT>/prompts/` [scripts/configure_family.py:103] | `FileNotFoundError` on the first `open(...,"w")` [scripts/configure_family.py:104] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `json` | stdlib [scripts/configure_family.py:9] | request bodies are JSON-encoded [scripts/configure_family.py:32]; responses are parsed as JSON, with an empty body defaulted to `{}` [scripts/configure_family.py:44] | a 2xx with a non-JSON body raises `JSONDecodeError` inside the `try`, which catches only `HTTPError` — measured: a 201 carrying HTML ends the run with exit 1 [scripts/configure_family.py:44] |
| `os` | stdlib [scripts/configure_family.py:10] | `os.path.expanduser` for DB/ROOT/HOME [scripts/configure_family.py:19-22], `os.path.join` for prompt paths [scripts/configure_family.py:103] [scripts/configure_family.py:173], `os.makedirs(..., exist_ok=True)` for local workdirs [scripts/configure_family.py:154], `os.path.exists` [scripts/configure_family.py:176] | `$HOME` moves DB, ROOT and the derived workdir check together; nothing validates them |
| `sqlite3` | stdlib [scripts/configure_family.py:11] | one connection [scripts/configure_family.py:50], `PRAGMA busy_timeout=60000` [scripts/configure_family.py:51], parameterized `SELECT` [scripts/configure_family.py:55-59], parameterized `UPDATE` [scripts/configure_family.py:177-187], single `commit()` after the loop [scripts/configure_family.py:189], readback `SELECT` [scripts/configure_family.py:197-200] | requires `parent`, `admission_mode`, `prompt`, `prompt_mode`, `cooldown_floor_s`, `cooldown_ceiling_s` [scripts/configure_family.py:178-179]; a renamed column fails the `UPDATE`. Default isolation (`isolation_level=''`) is what makes the run one long write transaction |
| `sys` | stdlib [scripts/configure_family.py:12] | inserts the script's own directory on `sys.path` so `lane_target` resolves [scripts/configure_family.py:16] | `ImportError` at [scripts/configure_family.py:17] |
| `urllib.error` | stdlib [scripts/configure_family.py:13] | catches `HTTPError` only, keeps at most 200 characters of the body [scripts/configure_family.py:45-46] | measured: a 300-byte error body reaches stdout as 200 characters — the printed `failed:` line is 229 bytes including the `failed: code-factory-qa: 500 ` prefix |
| `urllib.request` | stdlib [scripts/configure_family.py:14] | builds a `Request` with a bearer header, `Content-Type: application/json` and a 30 s timeout [scripts/configure_family.py:33-44]; every call measured carried exactly one `Authorization: Bearer …` and one `application/json` header | no retry, no keep-alive reuse, no proxy handling |
| `lane_target` | sibling module [scripts/configure_family.py:17] | `parse(str) -> target` [scripts/configure_family.py:149], `TargetError` [scripts/configure_family.py:150], `target.is_local` [scripts/configure_family.py:153], `target.path` [scripts/configure_family.py:154], `target.display()` [scripts/configure_family.py:158-159] | a changed return shape breaks the local/remote branch and the printed note; measured: all 16 derived workdirs parsed local, so the remote branch was not exercised |

`HOME = os.path.expanduser("~")` is assigned and never read [scripts/configure_family.py:22].

### 2c. Service contracts (both sides must be named)

The daemon is a separate repository
(`~/coding-hermes-scheduler/coding-herms-scheduler`), so its files are cited by absolute
path. Those files were read, and the handlers were exercised, on 2026-11-05.

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| Scheduler `POST /api/v1/projects` [scripts/configure_family.py:160-164] | this script writes | HTTP/1.1 JSON, bearer token, 30 s timeout | `{"name", "repo_url": "local:<ROOT>", "workdir"}` — three keys, measured on all 16 calls | `~/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:219` (`createProject`): required fields at `~/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:226`, defaults `weight=10, priority=5, cooldown_s=900` at `~/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:250`, born-disarmed `p.Enabled = false` at `~/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:273`, `409 project already exists` at `~/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:279`, any other DB error mapped to 500 at `~/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:290`, `201` with the stored project at `~/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:293` |
| Scheduler `PUT /api/v1/projects/<name>` [scripts/configure_family.py:171] | this script writes | HTTP/1.1 JSON | `{"namespace_id": <ns>}` — one key; response status and body are discarded | `~/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:442` (`updateProject`) → `~/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:557` (`database.UpdateProject`) → `~/coding-hermes-scheduler/coding-herms-scheduler/internal/database/projects.go:886` (`namespace_id = ?`) |
| Lane-shape gate behind both writes | in (enforced by the peer) | — | refuses an off-convention workdir for a `<primary>-<family>` lane before any DB write | `~/coding-hermes-scheduler/coding-herms-scheduler/internal/api/lane_onboarding.go:291` (`validateLaneOnCreate`) → `~/coding-hermes-scheduler/coding-herms-scheduler/internal/api/lane_onboarding.go:197` (`validateLaneWorkdir`); accepted roots at `~/coding-hermes-scheduler/coding-herms-scheduler/internal/api/lane_onboarding.go:87`; measured: the derived `stand-in/<family>/code-factory` workdirs were accepted (201/409, no 400) |
| `projects` table [scripts/configure_family.py:55-59] [scripts/configure_family.py:177-187] | this script reads and writes | direct SQLite, its own connection | six columns per row (section 1) | the daemon's own writer is `~/coding-hermes-scheduler/coding-herms-scheduler/internal/database/projects.go:33` (`CreateProject`) and is bypassed by this write; the daemon holds one connection (`SetMaxOpenConns(1)` at `~/coding-hermes-scheduler/coding-herms-scheduler/internal/database/schema.go:57`) with `PRAGMA busy_timeout=5000` at `~/coding-hermes-scheduler/coding-herms-scheduler/internal/database/schema.go:64`, which is why the script's open transaction starves it |
| `<ROOT>/prompts/*.md` [scripts/configure_family.py:102-114] | this script writes, then reads its own output back into rows [scripts/configure_family.py:172-176] | filesystem | one fixed template per lane [scripts/configure_family.py:68-100] | the consumed artifact is the `prompt` column, not the file; the tick-time prompt reader lives in the daemon and was not exercised here |

## 3. Verification

Every run below was executed on 2026-11-05 against a **copy** of the live scheduler DB (880
`projects` rows plus eight small tables; the live DB was opened read-only) and either a recording
stub API (Python `http.server` on loopback) or a scratch `schedulerd` built from the daemon source
and bound to `127.0.0.1:19095`. The live daemon on `:9090` and the live DB were never addressed.

The module under test is copied and exactly four literals are repointed — `DB`, `API`, `ROOT`, and
the `/proc/<pid>/environ` token block — because none of them has an override seam (section 7). Every
statement that decides what is asked for, and what is printed, is the shipped code.

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| Compiles | `python3 -m py_compile scripts/configure_family.py` | no output | 2026-11-05 | PASS (`COMPILE-OK`) |
| Argument surface | `grep -nE 'argparse\|argv\|dry.?run\|--check' scripts/configure_family.py` | no matches if none exists | 2026-11-05 | no match (grep exit 1): the module reads **no arguments at all** [scripts/configure_family.py:9-28] |
| Undo artifact | `grep -nE 'backup\|\.bak\|shutil\|DELETE' scripts/configure_family.py` | no matches if none exists | 2026-11-05 | no match (grep exit 1) |
| Token source present | run with DB/ROOT/API redirected, `/proc` line untouched | either a token or a clear failure | 2026-11-05 | `FileNotFoundError: [Errno 2] No such file or directory: '/proc/1755676/environ'`, exit 1, nothing written |
| Stub, no faults (run S1) | `python3 harness.py baseline` — stub answers 201 for absent names, 409 for present ones, 200 for `PUT`, and writes nothing | the exact request set with no failures | 2026-11-05 | 32 calls: 16 `POST /api/v1/projects`, 16 `PUT /api/v1/projects/<name>`; 6 × 201, 10 × 409; `failed: none`; exit 0; 7 rows changed; 4 prompt files rewritten byte-identically |
| Stub, one `POST` answered 500 (run S2) | `python3 harness.py post500` | failure must be visible to automation | 2026-11-05 | 31 calls (16 `POST`, 15 `PUT`); `failed: code-factory-qa: 500 {"error": "injected 500"}`; **exit 0**; that lane got no `PUT` and no `UPDATE` |
| Stub, one `PUT` answered 500 (run S3) | `python3 harness.py put500` | a failed namespace write must not read as success | 2026-11-05 | 32 calls; exit 0; the lane is printed `code-factory-releng ns=releases …` while the readback below prints `ns=code-factory`; the `UPDATE` for that lane still landed |
| Stub, 300-byte error body (run S4) | `python3 harness.py post500long` | body truncation as coded | 2026-11-05 | `failed:` line is 229 bytes: the 29-byte prefix plus exactly 200 bytes of body; exit 0 |
| Stub, 201 with a non-JSON body (run S5) | `python3 harness.py badjson` | success status with unparseable body | 2026-11-05 | `JSONDecodeError` traceback at [scripts/configure_family.py:44], exit 1, no rows committed, prompts already rewritten |
| Stub, connection dropped on call 5 (run S6) | `python3 harness.py abort` | state must not be half-applied | 2026-11-05 | `http.client.RemoteDisconnected`, exit 1; 5 calls already issued (3 `POST`, 2 `PUT`); **0** DB rows changed; the four prompt writes had already run |
| Scratch daemon, `code-factory-docs` row deleted first (run D1) | `python3 harness.py daemon` over a copy DB with every row `enabled=0` | a create plus fifteen conflicts | 2026-11-05 | `created: code-factory-docs`; 15 × `500 … database is locked (5) (SQLITE_BUSY)`; `configured:` lists one lane; **exit 0**; 170 s wall clock; the created row came back with `namespace_id=docs`, `parent=code-factory`, `prompt_mode=append`, floor 604800, ceiling 4838400, weight 10, priority 5, cooldown_s 900, `model=''`, `provider=''`, `enabled=0` |
| Scratch daemon, second run (run D2) | same command again on the same DB | second run changes nothing | 2026-11-05 | `created: none`; 15 × 500 again; **0** rows changed; exit 0; 150 s wall clock — the family does not advance |
| Read-back of the family | the script's own `family now:` block, after each run | four columns per row | 2026-11-05 | printed for every `code-factory%` row; it cannot confirm `prompt`, `prompt_mode`, `parent` or `cooldown_ceiling_s` [scripts/configure_family.py:196-201] |

Verbatim, run S1 — the summary block that carries the counts:

```
created: code-factory-docs-qa, code-factory-foreman, code-factory-foreman-qa, code-factory-readme-qa, code-factory-releng-qa, code-factory-review-qa
failed: none

configured:
  code-factory-docs ns=docs mode=cooldown floor=604800
  code-factory-docs-qa ns=qa mode= floor=0
  …
  code-factory-sync ns=duckbrain-sync mode=cooldown floor=21600
```

The complete 32-line request record from run S1, as the stub received it (seq, method, path, body):

```
 1 POST /api/v1/projects                     {"name": "code-factory-docs", "repo_url": "local:<ROOT>", "workdir": "~/.hermes/stand-in/docs/code-factory"}
 2 PUT  /api/v1/projects/code-factory-docs   {"namespace_id": "docs"}
 3 POST /api/v1/projects                     {"name": "code-factory-docs-qa", "repo_url": "local:<ROOT>", "workdir": "~/.hermes/stand-in/pm/code-factory-docs"}
 4 PUT  /api/v1/projects/code-factory-docs-qa {"namespace_id": "qa"}
 5 POST /api/v1/projects                     {"name": "code-factory-dogfood", "repo_url": "local:<ROOT>", "workdir": "~/.hermes/stand-in/dogfood/code-factory"}
 6 PUT  /api/v1/projects/code-factory-dogfood {"namespace_id": "dogfood"}
 7 POST /api/v1/projects                     {"name": "code-factory-foreman", "repo_url": "local:<ROOT>", "workdir": "~/code-factory"}
 8 PUT  /api/v1/projects/code-factory-foreman {"namespace_id": "coding-hermes"}
 9 POST /api/v1/projects                     {"name": "code-factory-foreman-qa", "repo_url": "local:<ROOT>", "workdir": "~/.hermes/stand-in/pm/code-factory-foreman"}
10 PUT  /api/v1/projects/code-factory-foreman-qa {"namespace_id": "qa"}
11 POST /api/v1/projects                     {"name": "code-factory-ops", "repo_url": "local:<ROOT>", "workdir": "~/.hermes/stand-in/pm-lane/code-factory"}
12 PUT  /api/v1/projects/code-factory-ops    {"namespace_id": "ops"}
13 POST /api/v1/projects                     {"name": "code-factory-perf", "repo_url": "local:<ROOT>", "workdir": "~/.hermes/stand-in/perf/code-factory"}
14 PUT  /api/v1/projects/code-factory-perf   {"namespace_id": "perf"}
15 POST /api/v1/projects                     {"name": "code-factory-pm", "repo_url": "local:<ROOT>", "workdir": "~/.hermes/stand-in/pm-lane/code-factory"}
16 PUT  /api/v1/projects/code-factory-pm     {"namespace_id": "pm"}
17 POST /api/v1/projects                     {"name": "code-factory-qa", "repo_url": "local:<ROOT>", "workdir": "~/.hermes/stand-in/pm/code-factory"}
18 PUT  /api/v1/projects/code-factory-qa     {"namespace_id": "qa"}
19 POST /api/v1/projects                     {"name": "code-factory-readme", "repo_url": "local:<ROOT>", "workdir": "~/.hermes/stand-in/readme/code-factory"}
20 PUT  /api/v1/projects/code-factory-readme {"namespace_id": "docs"}
21 POST /api/v1/projects                     {"name": "code-factory-readme-qa", "repo_url": "local:<ROOT>", "workdir": "~/.hermes/stand-in/pm/code-factory-readme"}
22 PUT  /api/v1/projects/code-factory-readme-qa {"namespace_id": "qa"}
23 POST /api/v1/projects                     {"name": "code-factory-releng", "repo_url": "local:<ROOT>", "workdir": "~/.hermes/stand-in/releng-lane/code-factory"}
24 PUT  /api/v1/projects/code-factory-releng {"namespace_id": "releases"}
25 POST /api/v1/projects                     {"name": "code-factory-releng-qa", "repo_url": "local:<ROOT>", "workdir": "~/.hermes/stand-in/pm/code-factory-releng"}
26 PUT  /api/v1/projects/code-factory-releng-qa {"namespace_id": "qa"}
27 POST /api/v1/projects                     {"name": "code-factory-review", "repo_url": "local:<ROOT>", "workdir": "~/.hermes/stand-in/review/code-factory"}
28 PUT  /api/v1/projects/code-factory-review {"namespace_id": "review"}
29 POST /api/v1/projects                     {"name": "code-factory-review-qa", "repo_url": "local:<ROOT>", "workdir": "~/.hermes/stand-in/pm/code-factory-review"}
30 PUT  /api/v1/projects/code-factory-review-qa {"namespace_id": "qa"}
31 POST /api/v1/projects                     {"name": "code-factory-sync", "repo_url": "local:<ROOT>", "workdir": "~/.hermes/sync-workdirs/code-factory-sync"}
32 PUT  /api/v1/projects/code-factory-sync   {"namespace_id": "duckbrain-sync"}
```

`<ROOT>` is the scratch repo copy in that run; every call carried `Authorization: Bearer
<redacted>` and `Content-Type: application/json`, and no other header the module sets. The `PUT`
bodies are one key each; the `POST` bodies are three keys each, in that order, and never carry
`enabled`, `model`, `provider` or pacing.

Verbatim, run S2 — the 500 on `code-factory-qa` and what it suppresses:

```
failed: code-factory-qa: 500 {"error": "injected 500"}

configured:
  code-factory-docs ns=docs mode=cooldown floor=604800
  code-factory-docs-qa ns=qa mode= floor=0
  …
```

Exit code 0; the `qa` line is absent from `configured:`, its `PUT` was never issued, and its row
kept `prompt` 1539 / floor 21600.

Verbatim, run S3 — the two statements that contradict each other, a few lines apart:

```
  code-factory-releng ns=releases mode=cooldown floor=21600
…
  code-factory-releng            ns=code-factory   mode=cooldown  floor=21600
```

Verbatim, run D1 — the first missing lane is created, then every later lane is starved by the
script's own open transaction:

```
created: code-factory-docs
failed: code-factory-docs-qa: 500 {"error":"create project \"code-factory-docs-qa\": database is locked (5) (SQLITE_BUSY)"}
; code-factory-dogfood: 500 {"error":"create project \"code-factory-dogfood\": database is locked (5) (SQLITE_BUSY)"}
…
```

Verbatim, run D2 — the second run over the same store changes nothing and still fails fifteen lanes:

```
created: none
failed: code-factory-docs-qa: 500 {"error":"create project \"code-factory-docs-qa\": database is locked (5) (SQLITE_BUSY)"}
…
```

## 4. Metrics emitted

**NONE.** No counter, histogram, gauge or exporter is defined, and no metrics client is imported
[scripts/configure_family.py:9-14]. The only channel is stdout, which is unstructured `print`
traffic [scripts/configure_family.py:63-65] [scripts/configure_family.py:191-201].

The process exit status carries no failure signal, and this is measured three ways on 2026-11-05: a
lane refused with 500 (run S2), a namespace `PUT` refused with 500 (run S3), and a run in which
**fifteen of sixteen lanes were refused** while one was configured (run D1) all exited **0**. The
only non-zero exits observed came from exceptions: a missing prompt file, a missing token, a
non-JSON success body (run S5) and a dropped connection (run S6). Dispatch rate, per-lane latency
and failure counts are therefore not available from this module; they must be read from the daemon.

## 5. Log lines it can generate

| Kind | Line (verbatim) | Emitted when |
|---|---|---|
| descriptive | `derived shape from crier, 9router -> docs, docs-qa, dogfood, foreman, foreman-qa, ops, perf, pm, qa, readme, readme-qa, releng, releng-qa, review, review-qa, sync` [scripts/configure_family.py:63-65] | after the derivation `SELECT`, before any write; measured on every run |
| descriptive | `wrote <ROOT>/prompts/docs.md` [scripts/configure_family.py:114] | once per prompt file, before any DB or API write; four lines measured per run |
| descriptive | `note: code-factory-docs workdir is remote: <target>` [scripts/configure_family.py:159] | only when the derived workdir parses as non-local [scripts/configure_family.py:157-159]; not exercised — all 16 derived workdirs parsed local in both rigs |
| descriptive | `created: none` or `created: code-factory-docs-qa, code-factory-foreman, …` [scripts/configure_family.py:191] | end of run; lists the names whose `POST` answered 201 only — six in run S1, one in run D1, none in run D2 |
| evidentiary for a human, invisible to automation | `failed: code-factory-qa: 500 {"error": "injected 500"}` [scripts/configure_family.py:192] | end of run; the only place a per-lane failure appears; entries are joined with `; ` and each embeds up to 200 bytes of the peer's body, newline included — which is why a long body strands a `; ` at the start of the next line, and why the exit status is still 0 |
| descriptive | `  code-factory-docs ns=docs mode=cooldown floor=604800` [scripts/configure_family.py:193-195] | end of run; built from the intended values, not from a readback (run S3 proves the difference) |
| descriptive | `  code-factory-docs              ns=code-factory   mode=cooldown  floor=604800` [scripts/configure_family.py:196-201] | end of run; a readback of four columns only — it cannot confirm `prompt`, `prompt_mode`, `parent` or `cooldown_ceiling_s` |

There is no logger, level, destination file or retention policy: the module writes only to file
descriptors 1 and 2 [scripts/configure_family.py:9-14] [scripts/configure_family.py:63-201].

## 6. Failure modes

Direction means: does it fail loud or quiet, does it over- or under-report, and does it write before
it fails?

| Failure | Presents as | Direction | Recovery |
|---|---|---|---|
| **The daemon and the script share one SQLite file** (any real run) [scripts/configure_family.py:177-189] | the first lane is configured, then every later `POST` returns `500 … database is locked (5) (SQLITE_BUSY)` after about 10 s; 15 failures; exit 0; measured in runs D1 and D2 | **quiet and structural**: the family advances by at most one lane per run and the exit code reports success | stop holding the transaction across the loop — batch the `UPDATE`s after the HTTP phase, or commit per lane; there is no flag for either |
| Token source gone (hard-coded `/proc/1755676/environ`) [scripts/configure_family.py:24-25] | `FileNotFoundError: [Errno 2] No such file or directory: '/proc/1755676/environ'`, exit 1 | loud, and safe: nothing is written before it, because the read precedes the DB open [scripts/configure_family.py:25] [scripts/configure_family.py:50] | edit the constant; there is no flag or env override [scripts/configure_family.py:24-28]. Measured: this is the state on 2026-11-05, so the script cannot currently start |
| Token variable absent from that process's environment | `StopIteration` from the bare `next(...)` generator [scripts/configure_family.py:26-28] | loud but opaque — the traceback names `StopIteration`, not the missing key | none in-process |
| `<ROOT>/prompts` missing or unwritable [scripts/configure_family.py:103-104] | `FileNotFoundError` on the first `open(path,"w")`, exit 1, after the shape line has printed | partially loud: no DB/API write yet, but any prompt file rewritten earlier in the loop stays rewritten | recreate the directory; there is no `makedirs` for `prompts/` (only for lane workdirs [scripts/configure_family.py:154]) |
| `POST /api/v1/projects` answers anything other than 201/409 [scripts/configure_family.py:165-169] | `failed: …` on stdout, that lane skipped — no `PUT`, no `UPDATE` — exit status still 0 [scripts/configure_family.py:192] | quiet to automation, under-reports: a partial family looks like a clean run | rerun; the 409 path treats an existing row as "configure it" [scripts/configure_family.py:167-171] |
| `PUT /api/v1/projects/<name>` fails (403/404/500) [scripts/configure_family.py:171] | nothing; the return value is discarded and the lane is still appended to `configured` with its intended namespace [scripts/configure_family.py:188] | over-reports: claims a namespace change that did not happen (measured, run S3) | inspect the row; the readback prints `namespace_id` for rows that exist [scripts/configure_family.py:196-201] |
| Row absent when the `UPDATE` runs (peer answered 201 without inserting) [scripts/configure_family.py:177-187] | no error; `UPDATE … WHERE name=?` affects 0 rows and the lane is still listed under `configured` [scripts/configure_family.py:188] | over-reports; silent no-op — measured in run S1, where six of the sixteen `configured` lines name rows the stub never created | create the row, then rerun |
| A 2xx with a body that is not JSON | `JSONDecodeError` traceback, exit 1, after the four prompt writes [scripts/configure_family.py:44] | loud, mid-run | fix or front the peer; the prompt files are already rewritten |
| A transport failure (connection dropped, DNS, timeout) | `http.client.RemoteDisconnected` or `URLError`, exit 1 [scripts/configure_family.py:42-46] | split-brain: the DB transaction is rolled back because `commit()` is last [scripts/configure_family.py:189], while created rows, namespace `PUT`s and the four prompt rewrites are already durable elsewhere — measured in run S6: 5 calls issued, 0 DB rows changed, 4 prompt writes done | rerun after fixing; there is no compensating delete or restore step anywhere in the module |
| DB locked longer than this script's 60 s busy timeout | `sqlite3.OperationalError` after 60 s [scripts/configure_family.py:50-51] | loud, but only after all four prompt files have been rewritten [scripts/configure_family.py:102-114] | rerun; nothing to roll back in the DB |
| Derived workdir is unparseable | `failed: <name>: invalid workdir target '<wd>': …`, lane skipped, exit 0 [scripts/configure_family.py:148-152] | quiet to automation, under-reports | fix the source family's workdir and rerun |
| Derived workdir is off the daemon's lane convention | `400 … is off-convention: -<family> lanes live in …`, lane skipped, exit 0 [scripts/configure_family.py:165-169] | quiet to automation; one entry in `failed:` | fix the source family's workdir; measured: none of the 16 derived workdirs was refused by the current daemon |
| Re-run after a partial success | the second run changes no DB values (measured: 0 rows, run D2) but re-issues the whole request set and rewrites the 4 prompt files again [scripts/configure_family.py:102-114] [scripts/configure_family.py:160-189] | idempotent on values, not on effects: each run is another authenticated write pass, and prompt files lose any local edit | none needed for the DB; prompt files cannot be hand-edited without being overwritten |

## 7. Environment and settings it reads

- Database: `DB = os.path.expanduser("~/.hermes/coding-hermes/scheduler.db")`
  [scripts/configure_family.py:19]; the live file is 16 GB and WAL.
- API base: `API = "http://127.0.0.1:9090"` [scripts/configure_family.py:20].
- Repository root used for `repo_url`, for `prompts/`, and for local lane workdirs:
  `ROOT = os.path.expanduser("~/code-factory")` [scripts/configure_family.py:21]
  [scripts/configure_family.py:103] [scripts/configure_family.py:163].
- Credential: read from `/proc/1755676/environ`, key `SCHEDULER_OPERATOR_TOKEN`
  [scripts/configure_family.py:24-28], and sent as a bearer header
  [scripts/configure_family.py:37-41]. This is neither an argv value nor a mode-600 file path of the
  kind the credential rule records (fact: FACT-05): the token is scraped out of an unrelated
  process's environment, and the read fails if that PID is gone — the measured state on 2026-11-05.
- No command-line arguments and no environment-variable reads: no `argparse`/`argv` use and no
  `os.environ`/`os.getenv` call [scripts/configure_family.py:9-28]. There is therefore no `--check`,
  `--diff`, `--dry-run` or `--project` switch; the target set, the values and the prompt text are
  all compile-time constants [scripts/configure_family.py:52-138].
- Cadence ceilings written by the run, as `seconds = hours × 3600` and `days = 604800`
  [scripts/configure_family.py:128-138]: `docs`/`readme`/`perf` = 4838400 s, `releng`/`qa`/`sync` =
  172800 s, `pm` = 691200 s, `dogfood` = 2073600 s, `duckbrain` = 0; `review` has no entry and
  falls back to `floor × 8` = 4838400 s [scripts/configure_family.py:184]. Admission mode is
  `mode or "cooldown"` [scripts/configure_family.py:181], so a source lane with an empty mode still
  becomes `cooldown` — while the printed `configured:` line echoes the source's empty mode, not the
  value written.
- Prompt-file mapping: lane base → file under `<ROOT>/prompts/`, defaulting to `foreman`
  [scripts/configure_family.py:117-127] [scripts/configure_family.py:172-176]; an absent file
  becomes an empty prompt string rather than an error [scripts/configure_family.py:176]. `review`
  has no entry, which is why its stored prompt becomes the 3390-byte foreman text.
- The four prompt bodies it writes are constants in the module, each followed by the same
  ground-rule block [scripts/configure_family.py:68-100] [scripts/configure_family.py:105-113].
- Workdir derivation: the source family's workdir with the family name replaced by `code-factory`
  [scripts/configure_family.py:61-62] [scripts/configure_family.py:143]. Measured result:
  `~/.hermes/stand-in/docs/code-factory`, `~/.hermes/stand-in/pm/code-factory`,
  `~/.hermes/sync-workdirs/code-factory-sync`, and `~/code-factory` for the
  `foreman` lane. Under fact: FACT-01 and fact: FACT-02 a lane is expected to run on the project's
  bunker node, so these control-host stand-in paths are a mismatch to resolve, not a documented
  exception.
- Local workdirs are `mkdir -p`'d before the API call [scripts/configure_family.py:153-155]; remote
  targets are registered as-is with a printed note [scripts/configure_family.py:157-159], so the
  module touches the filesystem outside `ROOT` as well (it creates the stand-in directories).
- Exit codes: `0` on a clean run **and** on a run where fifteen of sixteen lanes were refused (runs
  S2, S3, D1, D2); `1` from any uncaught traceback (missing prompt file, missing token, non-JSON
  body, dropped connection). No other code is produced.

## 8. Evidence of record

- Source identity: blob `1ff5a6db`, sha256 `44135f4deee873b823bcac9f53c236b4aa35496d3c20bb34bbe6fb00060a454a`,
  tree `ffecec4`, last touching commit `222a8b0` (2026-11-03). The module compiles cleanly.
- Rig 1 — recording stub: `stub_server.py` under
  `~/.hermes/cache/scratch/md10v/` is a `ThreadingHTTPServer` that records method, path,
  `Authorization`, `Content-Type`, `Content-Length` and the JSON body of every request to a JSONL
  file, answers 201/409/200 from an in-process existence set seeded from a read-only copy of the
  `projects` table, and can inject a 500 per name, a long error body, a non-JSON 201, or a dropped
  connection at the N-th call. It never writes the store, so the DB effects reported for runs S1–S6
  are the script's own `UPDATE`/`commit`, not the stub's.
- Rig 2 — scratch daemon: `schedulerd` compiled from
  `~/coding-hermes-scheduler/coding-herms-scheduler` on 2026-11-05 (the binary shipped in
  that tree is dated 2026-10-17 and predates the current `lane_onboarding.go`; its empty
  docs/readme/perf/review workdir allow-list refused those lanes, which is why the binary was
  rebuilt rather than used as shipped), run as `schedulerd -db copy.db -config scratch-config.toml
  -listen 127.0.0.1:19095 --simulate --max-concurrent 1 --min-interval 30s` with its operator token
  in a mode-600 config file (fact: FACT-05). The copy holds the full schema and 880 `projects` rows
  plus `migrations`, `namespaces`, `tick_workers`, `tick_dispatch`, `hook_runs`, `feature_usage` and
  `remote_events_stats`, with every row `enabled=0` so nothing could be scheduled.
- Harness: `harness.py` in the same scratch directory copies the 880-row `projects` table into
  `scheduler-copy.db`, copies `prompts/*.md` into a scratch `ROOT`, then runs the module as a
  subprocess with exactly four literals repointed: `DB` → the copy, `API` → the loopback port,
  `ROOT` → the scratch repo copy, and the `/proc/<pid>/environ` token block → a literal token.
  Nothing else in the file is altered, and the exit status reported is the subprocess's own.
- Prompt drift, as measured: `prompts/docs.md`, `readme.md`, `releng.md` and `perf.md` in the
  worktree are byte-identical to the module's output, so a run rewrites them with no content change
  — but a hand edit to any of the four would be lost without any message.
- Live state, read-only, 2026-11-05: 17 `code-factory%` rows, all with
  `workdir=~/code-factory`; `code-factory-dogfood` floor 3600, `code-factory-releng` floor
  3600 / ceiling 691200, `code-factory-review` prompt 1082, `code-factory-sync` prompt 2923 — the
  values the measured run would overwrite.
- Side effect of the rig, disclosed: `ROOT` and the API were redirected, but the derived lane
  workdirs are absolute stand-in paths, so the module's `os.makedirs(..., exist_ok=True)`
  [scripts/configure_family.py:154] ran against `~/.hermes/stand-in/...` (and
  `~/.hermes/sync-workdirs/...`). No file content was written there; the directories are
  the ones a real run creates anyway.
- Not verified here, and not claimed: any run against the live API or the live DB. Every daemon-side
  statement comes from a `schedulerd` built from the same source against a copied store on loopback;
  the live unit on `:9090` was never addressed.
- Undo: **there is none in the module.** No snapshot, copy, `.bak`, journal or `DELETE` call exists
  [scripts/configure_family.py:9-201] (grep for `backup|.bak|shutil|DELETE` returns nothing).
  Restoring the overwritten `parent`, `admission_mode`, `prompt`, `prompt_mode`, `cooldown_floor_s`
  and `cooldown_ceiling_s` values requires manual SQL from a snapshot taken outside this tool, which
  the tool neither takes nor records.
- Checker of record: `python3 scripts/master_doc_check.py docs/master --only 10- --strict`.
