# 01. scripts/add_family_lanes.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/add_family_lanes.py` |
| Repository | `code-factory` |
| Revision | `29e8e5e` (source file last changed; tree `6eea792`) |
| Status | **VERIFIED — every claim measured against a copy of the scheduler DB and a scratch `schedulerd` on 2026-11-05** |

## 1. Purpose and why it matters

`add_family_lanes.py` is the one-shot loader that registers this project's eight satellite lanes in
the scheduler and then writes their family wiring straight into the SQLite row. It does two
different things through two different writers, in two phases, and only the first phase is a
protocol client:

- **Phase 1 (HTTP, through the API):** for each of the eight lane tuples it calls
  `os.makedirs(workdir, exist_ok=True)` and then `POST /api/v1/projects` with
  `{"name", "repo_url": "local:<ROOT>", "workdir"}`, followed by
  `PUT /api/v1/projects/<name>` with `{"namespace_id": <ns>}`
  (`scripts/add_family_lanes.py:68`, `scripts/add_family_lanes.py:70`,
  `scripts/add_family_lanes.py:82`).
- **Phase 2 (direct SQL, bypassing the API):** it opens the DB file itself and runs
  `UPDATE projects SET parent='code-factory', admission_mode='cooldown', prompt=<file>,
  prompt_mode='append' WHERE name=?` for all eight names, then commits once
  (`scripts/add_family_lanes.py:87`, `scripts/add_family_lanes.py:91`,
  `scripts/add_family_lanes.py:96`).

The eight lanes are `code-factory-docs`, `code-factory-docs-qa`, `code-factory-readme`,
`code-factory-readme-qa`, `code-factory-releng`, `code-factory-releng-qa`, `code-factory-perf` and
`code-factory-review` (`scripts/add_family_lanes.py:50`). Every one is a *satellite* name: it ends
in a role suffix from the scheduler's suffix table (`-qa`, `-pm`, `-sync`, `-dogfood`, `-perf`,
`-releng`, `-review`, `-docs`, `-readme`) at
`/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/scheduler/lane_class.go:31`.
That is why the script's own docstring says it may only be run after the scheduler gained nine
satellite families (`scripts/add_family_lanes.py:4`).

- **What breaks if this module is absent:** the eight rows do not exist and nothing else in this
  repository creates them — `scripts/load_lane_config.py:21` loads exactly six core lanes, and the
  README states the split explicitly (`README.md:219`). Absent lanes are not self-healing: the
  satellite machinery only looks rows up and *skips* the ones that are missing
  (`/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:705`),
  so no docs/readme/releng/perf/review coverage exists for this project until something posts the
  rows. Measured today, the live fleet carries 17 `code-factory%` rows and **not one of them is the
  three `-qa` satellites this script would create** — `code-factory-docs-qa`,
  `code-factory-readme-qa` and `code-factory-releng-qa` are absent while `9router-docs-qa`,
  `auger-readme-qa`, `totalstack-releng-qa` and their peers exist for other projects, so the
  script's advertised outcome is *not* the live state and the gap is invisible unless someone
  queries for it (section 3, run P). The cause of those three absences is not established here.
- **What breaks if it lies:** its exit code is not a verdict. A run in which **every** lane was
  refused still exits 0 with an empty family table (measured, run E: `accepted: none` … `family:` …
  `EXIT=0`), and its second phase runs unconditionally, so a lane that was never created produces a
  silent zero-row `UPDATE` and no message at all (`scripts/add_family_lanes.py:89`). An operator
  reading "exit 0" learns nothing about whether the family exists.
- **Can it be re-run safely?** Re-runnable, yes: a duplicate POST answers 409 and is recorded as
  `<name>(existing)` rather than failing (`scripts/add_family_lanes.py:77`). Idempotent in effect,
  no: the `PUT` re-points the lane's namespace and the `UPDATE` rewrites `parent`, `admission_mode`
  and the whole `prompt` from the current repository files. Measured on the copy, a lane set by hand
  to `namespace_id='code-factory'` with `prompt='CUSTOM'` and `prompt_mode='replace'` came back as
  `ns=docs`, `prompt_mode=append`, `prompt=842` characters after one re-run (section 3, run B). All
  16 of the 17 live `code-factory%` lanes that do carry `namespace_id='code-factory'` would be moved
  onto the `docs`/`qa`/`releases`/`perf`/`review` namespaces by a live re-run, and their stored
  prompt swapped for `prompts/*.md` as it stands today.
- **What it does that it does not say:** the lanes are created **disabled**. The body carries no
  `enabled` key, and the API clamps `enabled` to false regardless — "create NEVER stores an enabled
  row" (`/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:273`).
  Measured: all eight rows landed with `enabled=0` (section 3, run A). Creating the family is not
  the same as turning it on, and this script has no step that turns it on.

## 2. Dependencies and library contracts

The scheduler these writes target is a separate repository
(`/home/kara/coding-hermes-scheduler/coding-herms-scheduler`), so its files are cited by absolute
path, spelled out at every locator even where the surrounding prose shortens the name.

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | measured on 3.14.4; stdlib only, no third-party import | `$PATH` of the operator | nothing in the module — the interpreter is the caller's |
| `systemctl` (`--user show -p MainPID --value coding-hermes-scheduler`) | any | `$PATH`; the unit must be running | **not detected**: `os.popen(...).read().strip() or "0"` turns a missing command into PID `0`, and the next line opens `/proc/0/environ` and dies with `FileNotFoundError` (`scripts/add_family_lanes.py:18`, `scripts/add_family_lanes.py:27`). Measured, run F |
| the `coding-hermes-scheduler` unit's environment | — | `/proc/<MainPID>/environ` readable by the caller | **not detected**: the generator expression throws a bare `StopIteration` when `SCHEDULER_OPERATOR_TOKEN` is not in that environment (`scripts/add_family_lanes.py:25`). Measured, run G |
| scheduler HTTP API | hard-coded `http://127.0.0.1:9090` (`scripts/add_family_lanes.py:14`) | the control host's loopback, no TLS | `URLError`/`ConnectionRefusedError` from `urlopen` is **not** caught — only `HTTPError` is — so an unreachable API is a traceback, not a refusal (`scripts/add_family_lanes.py:46`) |
| scheduler DB file | hard-coded `~/.hermes/coding-hermes/scheduler.db` (`scripts/add_family_lanes.py:15`) | same host, writable by the caller | `sqlite3.OperationalError` from `connect` at `scripts/add_family_lanes.py:87`; uncaught |
| project root and prompt files | hard-coded `~/code-factory` (`scripts/add_family_lanes.py:17`) with `prompts/{docs,qa,readme,releng,perf,review}.md` | the operator's home, not the checkout the script ships in | `FileNotFoundError` at the `open()` on `scripts/add_family_lanes.py:90`, **after** phase 1 has already written rows. Measured, run D |
| the eight stand-in workdirs | `~/.hermes/stand-in/{docs,pm,readme,releng-lane,perf,review}/<lane>` | created by the script itself via `makedirs` | never absent — the script creates them, including for lanes whose POST is then refused (measured: run C left all eight directories behind) |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `json` | stdlib | `json.dumps(body)` is the request body, `json.loads(r.read().decode() or "{}")` the response, with an empty body normalized to `{}` (`scripts/add_family_lanes.py:36`, `scripts/add_family_lanes.py:45`) | a non-JSON success body raises `JSONDecodeError` inside the `try`, which only catches `HTTPError` — traceback mid-loop |
| `urllib.request` | stdlib | `Request(method=...)` for `POST`/`PUT`; `urlopen(..., timeout=30)` is the only bound (`scripts/add_family_lanes.py:37`, `scripts/add_family_lanes.py:44`) | a 30 s stall per lane becomes an uncaught `TimeoutError`, leaving the family half-created |
| `urllib.error` | stdlib | **only** `HTTPError` is handled, and it is converted to `(code, {"error": body[:300]})` rather than raised (`scripts/add_family_lanes.py:46`) | any other transport error escapes the handler, so "the API is down" (traceback) and "the API said no" (a dict) are different classes of failure |
| `os` | stdlib | `os.popen` for the systemd PID, `os.path.expanduser` for the three home-derived paths, `os.makedirs(..., exist_ok=True)` for the workdirs (`scripts/add_family_lanes.py:16`, `scripts/add_family_lanes.py:19`, `scripts/add_family_lanes.py:69`) | a different `$HOME` silently moves `H` and `ROOT` together, which the server-side workdir gate then refuses (measured, run C) |
| `sqlite3` | stdlib | default isolation: the eight `UPDATE`s run inside one implicit transaction committed once (`scripts/add_family_lanes.py:96`); `timeout=60` plus `PRAGMA busy_timeout=60000` wait for the live scheduler's write lock (`scripts/add_family_lanes.py:87`, `scripts/add_family_lanes.py:88`) | if the process dies before `commit()` the whole prompt/parent phase rolls back — measured: after a crash on the last lane, **all eight** rows still had `prompt=''` (run D) |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| scheduler `POST /api/v1/projects` | out | HTTP/1.1 JSON over loopback | `{"name", "repo_url": "local:<ROOT>", "workdir"}` — no `enabled`, no `model`, no `provider`, no pacing | `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:219` (`createProject`); operator gate `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:30`; body defaults `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:250`; born-disarmed clamp `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:273`; `409 project already exists` `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:279` |
| scheduler `PUT /api/v1/projects/<name>` | out | HTTP/1.1 JSON over loopback | `{"namespace_id": <ns>}` — the response status is **discarded** (`scripts/add_family_lanes.py:82`) | `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:442` (`updateProject`) → `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/database/projects.go:885` (`namespace_id = ?`) |
| lane-shape gate behind both writes | in (enforced by the peer) | — | refuses an off-convention workdir for a `<primary>-<family>` lane, and an enabled-but-unarmed satellite | `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/lane_onboarding.go:197` (`validateLaneWorkdir`), allow-list built at `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/lane_onboarding.go:166` from `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/lane_onboarding.go:75`, refusal text at `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/lane_onboarding.go:222` |
| `projects` table | out | direct SQLite write, second connection | `parent`, `admission_mode`, `prompt`, `prompt_mode` for eight names | the API's own writer is `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/database/projects.go:706` (`UpdateProject`) and is **bypassed**; the admission law it enforces at `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:551` never sees this write |
| `prompts/*.md` | in | filesystem read | the six role files; each lane's `prompt` column is set to a whole file | `README.md:222` states the loader copies prompt text into the row and that re-running the loader is how an edit is propagated |

The asymmetry in the last two rows is the module's central design fact: **phase 1 is gated, phase 2
is not.** `admission_mode='cooldown'` written by SQL is never checked against the law a PUT would
enforce (`/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:551`). For these eight names it happens to agree — a lane whose name
ends in a role suffix is classified `satellite`
(`/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/scheduler/lane_class.go:124`)
and satellites take `cooldown` — so the script is consistent with the law because the names were
chosen well, not because anything checked.

## 3. Verification

Every run below was executed on 2026-11-05 against a **copy** of the live scheduler DB and a scratch
`schedulerd` bound to loopback ports 19090–19093; the live DB was opened read-only and the live
service was never addressed. The module under test was copied and its two literal targets
(`scripts/add_family_lanes.py:14`, `scripts/add_family_lanes.py:15`) repointed at the copy — that
two-line diff is the only change, and it is what makes the runs possible at all, since neither
target has an override seam (section 7).

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| A. Fresh family on an empty project table | `python3 probe_add_family_lanes.py` (API → `:19090`, DB → `copy.db`) | 8 `201`s, prompts installed, family printed | 2026-11-05 | `accepted:` all eight, `refused: none`, 8-row family table, exit 0; every row `enabled=0`, `model=''`, `provider=''`, `cooldown_s=900`, `weight=10`, `priority=5`, `cooldown_floor_s=0` |
| B. Re-run over the same rows | same command again | 8 `409`s recorded as `(existing)`, no failure | 2026-11-05 | `accepted:` eight `(existing)` entries, `refused: none`, exit 0; the deliberately customised `namespace_id`/`prompt`/`prompt_mode` were overwritten back to `docs`/842 chars/`append` |
| C. Caller whose `$HOME` differs from the daemon's | `HOME=<scratch>/fakehome python3 probe3_add_family_lanes.py` (API → `:19092`) | every POST refused with the off-convention message | 2026-11-05 | 8 × `400 … is off-convention: -docs lanes live in "…"`, `refused:` eight entries, `family:` empty, exit 0 |
| D. Missing prompt file for the last lane | `HOME=<scratch>/fakehome python3 probe4_add_family_lanes.py`, daemon's `HERMES_HOME` pointed at the same fake home | rows created, prompt phase aborts | 2026-11-05 | `accepted:` all 8, then `FileNotFoundError … prompts/review.md`, exit 1; all 8 rows left with `prompt=''`, `parent=''`, `admission_mode=''` while their namespaces were already set |
| E. Wrong operator token | `python3 probe2_add_family_lanes.py` (API → `:19091`, token deliberately mismatched) | 8 × 401, nothing created | 2026-11-05 | `accepted: none`, 8 × `401 {"error":"invalid operator credential"}`, `family:` empty, `EXIT=0`, `select count(*) from projects` = 0 |
| F. `systemctl` not on `PATH` | `PATH=<scratch>/bin /usr/bin/python3 -c "runpy.run_path('probe_add_family_lanes.py', run_name='__main__')"` | dies before any API call | 2026-11-05 | `FileNotFoundError: [Errno 2] No such file or directory: '/proc/0/environ'`, `EXIT=1` |
| G. Unit running without `SCHEDULER_OPERATOR_TOKEN` in its environ | same, with a stub `systemctl` printing a token-less PID | a message and no API call | 2026-11-05 | bare `StopIteration`, `EXIT=1` — no message at all |
| P. Live fleet, read-only | `sqlite3 -readonly ~/.hermes/coding-hermes/scheduler.db "select name,… from projects where name like 'code-factory%'"` | the family this script claims to create | 2026-11-05 | 17 rows; `repo_url`/`workdir` are `local:/home/kara/code-factory` and `/home/kara/code-factory` on every one; no `code-factory-docs-qa`, `-readme-qa`, `-releng-qa` |

Verbatim output, run A — the success path and the only machine-readable summary the script produces:

```
accepted: code-factory-docs, code-factory-docs-qa, code-factory-readme, code-factory-readme-qa, code-factory-releng, code-factory-releng-qa, code-factory-perf, code-factory-review
refused: none

family:
  code-factory-docs            ns=docs           mode=cooldown  floor=0       prompt=842
  code-factory-docs-qa         ns=qa             mode=cooldown  floor=0       prompt=1384
  code-factory-perf            ns=perf           mode=cooldown  floor=0       prompt=810
  code-factory-readme          ns=docs           mode=cooldown  floor=0       prompt=889
  code-factory-readme-qa       ns=qa             mode=cooldown  floor=0       prompt=1384
  code-factory-releng          ns=releases       mode=cooldown  floor=0       prompt=904
  code-factory-releng-qa       ns=qa             mode=cooldown  floor=0       prompt=1384
  code-factory-review          ns=review         mode=cooldown  floor=0       prompt=1099
EXIT=0
```

Verbatim output, run B — the second run over the same eight rows:

```
accepted: code-factory-docs(existing), code-factory-docs-qa(existing), code-factory-readme(existing), code-factory-readme-qa(existing), code-factory-releng(existing), code-factory-releng-qa(existing), code-factory-perf(existing), code-factory-review(existing)
refused: none
```

Verbatim output, run E — a total failure that exits 0:

```
accepted: none
refused: code-factory-docs: 401 {"error":"invalid operator credential"}
; code-factory-docs-qa: 401 {"error":"invalid operator credential"}
; code-factory-readme: 401 {"error":"invalid operator credential"}
; code-factory-readme-qa: 401 {"error":"invalid operator credential"}
; code-factory-releng: 401 {"error":"invalid operator credential"}
; code-factory-releng-qa: 401 {"error":"invalid operator credential"}
; code-factory-perf: 401 {"error":"invalid operator credential"}
; code-factory-review: 401 {"error":"invalid operator credential"}


family:
EXIT=0
```

The leading `; ` lines are not a formatting choice of the script: each refusal string embeds the
*response body*, which ends in a newline, and the entries are then joined with `"; "`
(`scripts/add_family_lanes.py:47`, `scripts/add_family_lanes.py:80`, `scripts/add_family_lanes.py:85`).

## 4. Metrics emitted

**None.** The module imports no logging or metrics library and defines no counter, timing or gauge —
the only time-like token in the file is the `timeout=30` keyword (`scripts/add_family_lanes.py:44`).
Its entire output is four plain `print()` calls: the accepted list, the refused list, the `family:`
header, and one formatted row per `code-factory%` project (`scripts/add_family_lanes.py:84`,
`scripts/add_family_lanes.py:85`, `scripts/add_family_lanes.py:98`,
`scripts/add_family_lanes.py:103`). The consequence is concrete: there is no machine-readable count
of *created* versus *already existed* versus *refused*, so a monitor cannot distinguish a first run
from a no-op re-run — the only signal is the literal string `(existing)` appended inside a free-text
line (`scripts/add_family_lanes.py:78`). Every number in section 3 had to be produced by reading the
DB afterwards, not by trusting the script.

## 5. Log lines it can generate

The module emits no levelled log lines; each line below is stdout, or a traceback on stderr. Tags
follow the field contract: **descriptive** = says what happened, **evidentiary** = carries a fact
that can be checked against the store.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stdout | `accepted: code-factory-docs, code-factory-docs-qa, code-factory-readme, code-factory-readme-qa, code-factory-releng, code-factory-releng-qa, code-factory-perf, code-factory-review` | phase 1 accepted all eight on a fresh project table (run A); on a re-run the same line carries `(existing)` after every name (run B) — `", ".join(made) or "none"` (`scripts/add_family_lanes.py:84`) | descriptive; the `(existing)` suffix is the only signal that nothing was created |
| stdout | `accepted: none` | every lane was refused and `made` is empty — the same `print` falls back to `none` (`scripts/add_family_lanes.py:84`) | descriptive; this is the failure shape that still exits 0 (run E) |
| stdout | `refused: none` | no lane was refused (`scripts/add_family_lanes.py:85`) | descriptive |
| stdout | `refused: code-factory-docs: 401 {"error":"invalid operator credential"}` | one entry per status that is neither 201 nor 409; the entry embeds the HTTP status and the first 300 bytes of the body, trailing newline included (`scripts/add_family_lanes.py:47`, `scripts/add_family_lanes.py:80`) | evidentiary: names the status and the peer's own error text; also why the line breaks per entry |
| stdout | `family:` | always, after phase 2 commits (`scripts/add_family_lanes.py:98`) | descriptive |
| stdout | `  code-factory-docs            ns=docs           mode=cooldown  floor=0       prompt=842` | one per `name LIKE 'code-factory%'` row, read back **after** the commit — `name`, `namespace_id`, `admission_mode`, `cooldown_floor_s`, `length(prompt)` (`scripts/add_family_lanes.py:99`, `scripts/add_family_lanes.py:104`) | evidentiary: the only read-back the script performs, and what proves phase 2 landed |
| stderr | `FileNotFoundError: [Errno 2] No such file or directory: '/proc/0/environ'` | `systemctl` could not be run or the unit is stopped, so PID resolved to `0` (`scripts/add_family_lanes.py:22`, `scripts/add_family_lanes.py:27`) | descriptive; the traceback is the only diagnostic |
| stderr | `StopIteration` | the unit is running but `SCHEDULER_OPERATOR_TOKEN` is absent from its environ (`scripts/add_family_lanes.py:32`) | descriptive; carries no reason at all |
| stderr | `FileNotFoundError: [Errno 2] No such file or directory: '<ROOT>/prompts/review.md'` | a prompt file is missing, after phase 1 already created rows (`scripts/add_family_lanes.py:90`) | evidentiary: the path names which role file the family depends on |

## 6. Failure modes

Direction: **closed** = the run refuses and stops; **open** = the run continues and exits 0 while
the family is not what the operator asked for.

| Failure | Presents as | Distinguished from | Direction | Recovery |
|---|---|---|---|---|
| Scheduler unit stopped, or `systemctl` not resolvable | `FileNotFoundError … '/proc/0/environ'`, exit 1, before any request (`scripts/add_family_lanes.py:27`) | a token problem, which prints `StopIteration` after the same import-time read | closed, but with no message | start `coding-hermes-scheduler`; the token can only come from its environ |
| Token variable absent from the unit's environment | bare `StopIteration`, exit 1 (`scripts/add_family_lanes.py:32`) | a *wrong* token, which reaches the API and prints `401 {"error":"invalid operator credential"}` per lane | closed | put `SCHEDULER_OPERATOR_TOKEN` in the unit's environment; the script has no other credential source |
| API unreachable, nothing listening on 9090 | `urllib.error.URLError` traceback — only `HTTPError` is caught (`scripts/add_family_lanes.py:46`) | a refused write, which returns a `(status, dict)` pair and never raises | closed, loudly | start the API; there is no override port (`scripts/add_family_lanes.py:14`) |
| Wrong or expired token | eight `401` entries, `family:` empty, **exit 0** (run E) | a shape refusal, which prints `400 … is off-convention` | **open** | exit 0 must not be read as success — read `accepted:` |
| Caller's `$HOME` is not the daemon's Hermes home | eight `400 … workdir … is off-convention: -docs lanes live in "/home/kara/.hermes/stand-in/docs/code-factory"`, exit 0 (run C) | a genuine name/workdir mismatch, which produces the same text for one lane only | **open** | run as the user that owns the daemon's `~/.hermes`; the gate resolves paths from the *server's* `HERMES_HOME`/home, not the client's (`/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/lane_onboarding.go:147`) |
| Lane already exists | `code-factory-docs(existing)` in the accepted list, exit 0 (run B) | a fresh create, which prints the bare name | open, by design | none needed for existence — but see the next row |
| An existing lane carries a namespace and prompt someone else set | nothing printed; the row silently changes | a first run, which has nothing to overwrite | **open** | re-running is the documented way to propagate `prompts/*.md` (`README.md:222`); know that it also re-points `namespace_id` and `parent` |
| A prompt file is missing | `accepted:` list printed first, then `FileNotFoundError`, exit 1, and the rows exist with `prompt=''`, `parent=''`, `admission_mode=''` (run D) | a DB write failure, which raises `OperationalError` at `scripts/add_family_lanes.py:87` | **open** — half-built rows, and the rollback is silent | restore the prompt file and re-run; the second run is safe for existence and fills the empty columns |
| A lane's row does not exist when phase 2 runs (its POST was refused) | nothing — `UPDATE … WHERE name=?` matches zero rows and commits, and `family:` simply omits it (run E) | a failed `UPDATE`, which would raise | **open** | read the `refused:` line; phase 2 cannot repair a lane phase 1 did not create |
| The primary `code-factory` row is missing | nothing: `parent='code-factory'` is written anyway, and `parent` has an index but no foreign key | a present primary, whose class derivation then nests the satellites | **open** | ensure the primary exists; the script never checks |
| Family created but never enabled | rows exist with `enabled=0`, `cooldown_floor_s=0`, and the run prints a clean family table (run A) | a live family, whose rows would show `enabled=1` and a non-zero floor | **open** — the family looks complete and schedules nothing | enable each lane with a PUT carrying the family pin; `create` never enables (`/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server_projects.go:273`) and the auto-arm path only fires on an enable transition (`/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/lane_onboarding.go:389`) |
| `model`/`provider` left empty on the new rows | the family table prints prompt lengths but never the model; the DB shows `model=''`, `provider=''` (run A) | a row pinned like the primary `code-factory` row, which carries `deepseek-v4-flash` / `deepseek-foreman` — only 2 of the 17 live rows carry a model at all | **open** — the lane inherits whatever the spawner resolves, which is exactly the pin `fact: FACT-06` says this project must not lose | PUT the model/provider, or a `model_chain`, before enabling |

## 7. Environment and settings it reads

- **No arguments at all.** `grep -cE 'argparse|sys.argv|--help|--check|--dry-run'
  scripts/add_family_lanes.py` prints `0`, so every invocation — including `--help` — executes the
  whole module-level write path. The hazard is already filed as board row CF-185
  (`.coding-hermes/board/tasks.jsonl:160`), whose probe reproduces it as `argv_handling=0`.
- **Environment variables read directly:** none. There is no `os.environ` / `os.getenv` in the file.
- **Environment read indirectly, and this is the credential path:**
  - `$HOME` through `os.path.expanduser`, for `H`, `ROOT` and the DB path
    (`scripts/add_family_lanes.py:15`, `scripts/add_family_lanes.py:16`,
    `scripts/add_family_lanes.py:17`).
  - `SCHEDULER_OPERATOR_TOKEN` out of `/proc/<MainPID>/environ` of the `coding-hermes-scheduler`
    user unit, the PID resolved by shelling out to `systemctl --user show -p MainPID --value`
    (`scripts/add_family_lanes.py:19`, `scripts/add_family_lanes.py:25`). The value is sent in the
    `Authorization` header as a bearer credential (`scripts/add_family_lanes.py:41`).
- **Hard-coded settings, none overridable:** API base `http://127.0.0.1:9090`
  (`scripts/add_family_lanes.py:14`), DB `~/.hermes/coding-hermes/scheduler.db`
  (`scripts/add_family_lanes.py:15`), unit name `coding-hermes-scheduler`
  (`scripts/add_family_lanes.py:19`), project root `~/code-factory` (`scripts/add_family_lanes.py:17`),
  request timeout 30 s (`scripts/add_family_lanes.py:44`), SQLite connect timeout 60 s and
  `busy_timeout` 60000 ms (`scripts/add_family_lanes.py:87`, `scripts/add_family_lanes.py:88`).
- **Settings on the *other* side that change this script's verdict:** the daemon's `HERMES_HOME`
  wins over its own home directory when it resolves the canonical workdir
  (`/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/lane_onboarding.go:147`), so the same script text succeeds or is refused depending on whose home
  the *server* is using — measured as runs A and C.
- **Exit codes:** `0` on a clean run **and** on a run where every lane was refused (runs A, B, C, E);
  `1` from any uncaught traceback (runs D, F, G). No other code is produced, and nothing
  distinguishes "all created" from "all refused".
- **What it writes, precisely:** `projects` rows for the eight names (via the API), and the columns
  `parent`, `admission_mode`, `prompt`, `prompt_mode` on those same rows (via SQL). It does not write
  `workdir` on an existing row, does not touch `cooldown_floor_s`, `cooldown_s`, `weight`,
  `priority`, `model`, `provider` or `enabled`, and creates no namespace.

## 8. Evidence of record

Every figure above comes from re-runnable commands executed on 2026-11-05 at tree `6eea792` (source
file at `29e8e5e`), and per `fact: FACT-10` none of them rests on a commit message.

The copy was built from the live DB without its bulk tables, because a full `.backup` of a 16.7 GB
file exceeded the scratch timeout:

```bash
sqlite3 -readonly ~/.hermes/coding-hermes/scheduler.db ".schema" > schema.sql
sqlite3 copy.db < schema.sql                 # 31 tables, schema only
# per table: migrations, projects, namespaces, tick_workers, tick_dispatch, hook_runs,
#            feature_usage, remote_events_stats — copied with ATTACH (880 projects, 20 namespaces)
sqlite3 copy.db "delete from projects;"      # so the scratch schedulerd has nothing to schedule
```

The scratch daemon was the shipped binary in simulation mode, so nothing can be spawned:

```bash
schedulerd -db copy.db -config scratch-config.toml -listen 127.0.0.1:19090 \
           --simulate --max-concurrent 1 --min-interval 30s      # /health -> 200
```

Its operator token was read from the live unit's environ into a mode-600 config file and never
placed on a command line (`fact: FACT-05`). The probe copies differ from the shipped file by exactly
two lines:

```diff
-API = "http://127.0.0.1:9090"
-DB = os.path.expanduser("~/.hermes/coding-hermes/scheduler.db")
+API = "http://127.0.0.1:19090"
+DB = "/home/kara/.hermes/cache/scratch/md01f/copy.db"
```

Scratch artefacts, not part of the repository: `~/.hermes/cache/scratch/md01f/` holds `schema.sql`,
`copy.db` … `copy4.db`, `probe_add_family_lanes.py` and `probe2/3/4_*`, `scratch-config*.toml`,
`token.txt`, and `fakehome/` (a stand-in `$HOME` whose `code-factory/prompts/` is missing
`review.md`).

Read-only live queries behind the fleet statements in sections 1 and 6:

```bash
sqlite3 -readonly ~/.hermes/coding-hermes/scheduler.db \
  "select name,namespace_id,parent,admission_mode,enabled,cooldown_s,cooldown_floor_s,model,provider,
          prompt_mode,length(prompt),created_at from projects where name like 'code-factory%'
   order by name;"
#  17 rows; namespace_id = code-factory on 16 (the exception is code-factory-ops, in "ops");
#  workdir = /home/kara/code-factory on all 17; docs/readme/perf/review floors = 604800,
#  releng floor = 3600; model/provider set on only 2 rows (code-factory, code-factory-ops)
sqlite3 -readonly ~/.hermes/coding-hermes/scheduler.db \
  "select distinct repo_url from projects where name like 'code-factory%';"
#  local:/home/kara/code-factory
sqlite3 -readonly ~/.hermes/coding-hermes/scheduler.db \
  "select id,admission_mode from namespaces where id in ('docs','qa','releases','perf','review','code-factory');"
#  code-factory|tasks ; docs|cooldown ; qa|cooldown ; perf|cooldown ; releases|cooldown ; review|cooldown
```

- **Not verified here, and not claimed:** any run against the live API or the live DB. Writing to
  the live scheduler was out of scope, so every behavioural statement comes from a `schedulerd` on
  the same binary against a copied store.
- **Not verified here:** whether the three missing `-qa` rows were ever created and later deleted.
  The events table was not mined for a delete record; only the present-tense absence is measured.
- **Prompt drift, as measured:** the live `code-factory-review` row carries a 1082-character prompt
  while the current `prompts/review.md` produces 1099 — so a re-run would silently replace that
  lane's stored prompt. `docs.md` (842), `perf.md` (810), `readme.md` (889) and `releng.md` (904) are
  unchanged, which is why runs A and B show those four lengths identical.
- Checker of record: `python3 scripts/master_doc_check.py docs/master --only 01- --strict` — run
  before the commit that adds this file; the commit carries its output.
