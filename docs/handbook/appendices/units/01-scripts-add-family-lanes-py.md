# 01. scripts/add_family_lanes.py

| Field | Value |
|---|---|
| Path | `~/code-factory/scripts/add_family_lanes.py` |
| Repository | `code-factory` |
| Revision | source last changed `9bee3fe6` (2026-11-16); reference tree `a7c5a8b9` |
| Status | **UNVERIFIED — source-verified and stub-tested on 2026-11-22; no fresh scratch scheduler or live API run (§3, §8)** |

## 1. Purpose and why it matters

This operator-invoked loader creates and configures eight predefined code-factory satellite lanes
through the scheduler HTTP API [scripts/add_family_lanes.py:1-2,105-120,145-235]. It does not
activate them. The creation payload and update payload do not contain `enabled`
[scripts/add_family_lanes.py:170-175,135-142]. The scheduler is the admission authority; API
acceptance is not evidence of actual scheduling.

Phase 1 GETs each URL-quoted lane name. For a 404 it creates the workdir, then POSTs `name`,
`repo_url=local:<ROOT>`, `workdir` and `namespace_id`. A 201 is created; a 200 GET is present only
if its returned project identifies the requested name. A 409 or any other non-201 POST is refused,
not treated as an existing lane. Other GET statuses are refused. The loop accounts for every lane,
but if any phase-1 refusal occurred it returns 2 before starting phase 2 for **any** lane
[scripts/add_family_lanes.py:101-102,159-207]. Existing lanes do not have their namespace updated by
this script; the override applies to creation [scripts/add_family_lanes.py:123-124,163-175,197-199,209-219].

Phase 2 reads `prompts/<role>.md` and PUTs exactly these six fields to the individual project route:

| Field | Desired value |
|---|---|
| `prompt` | complete role prompt file contents |
| `prompt_mode` | `append` |
| `parent` | `code-factory` |
| `admission_mode` | `cooldown` |
| `model` | current value, or empty string when falsey |
| `provider` | current value, or empty string when falsey |

[scripts/add_family_lanes.py:127-142]. If all six fields already match, no PUT is sent. Otherwise
only 200/204 accepts the PUT, followed by a GET which must return 200 and match all six fields;
preparation, PUT and readback failures are counted as refusals [scripts/add_family_lanes.py:209-235].
A failure can leave previously created or configured lanes in place: this is not an all-or-nothing
operation. Re-running reconciles pointer fields, including replacing a custom prompt, but retains
nonempty current model and provider values. A phase-1 failure prevents all phase-2 updates, even for
lanes already created during that run.

| Lane | Workdir | Namespace | Prompt |
|---|---|---|---|
| `code-factory-docs` | `~/.hermes/stand-in/docs/code-factory` | `docs` | `docs` |
| `code-factory-docs-qa` | `~/.hermes/stand-in/pm/code-factory-docs` | `qa` | `qa` |
| `code-factory-readme` | `~/.hermes/stand-in/readme/code-factory` | `docs` | `readme` |
| `code-factory-readme-qa` | `~/.hermes/stand-in/pm/code-factory-readme` | `qa` | `qa` |
| `code-factory-releng` | `~/.hermes/stand-in/releng-lane/code-factory` | `releases` | `releng` |
| `code-factory-releng-qa` | `~/.hermes/stand-in/pm/code-factory-releng` | `qa` | `qa` |
| `code-factory-perf` | `~/.hermes/stand-in/perf/code-factory` | `perf` | `perf` |
| `code-factory-review` | `~/.hermes/stand-in/review/code-factory` | `review` | `review` |

The paths expand against the caller's home; `ROOT` is derived from the script's checkout, not from
home [scripts/add_family_lanes.py:12-14,105-120].

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Where | Absence or failure |
|---|---|---|
| Python 3 and standard library | operator environment | interpreter is external to the script [scripts/add_family_lanes.py:1-10] |
| scheduler API | `--api-base`, default `http://127.0.0.1:9090` | connection/timeout returns 599, then is counted as a GET/POST/PUT/readback refusal [scripts/add_family_lanes.py:12,25-27,83-91] |
| bearer token | token file, environment or scheduler user unit | unavailable, unreadable or empty token prints `ERROR:` and returns 64 [scripts/add_family_lanes.py:37-69,145-151] |
| role prompt files | checkout's `prompts/` | unreadable file becomes a phase-2 preparation refusal; phase 1 may already have created lanes [scripts/add_family_lanes.py:127-132,209-216] |
| stand-in directories | caller's home | created only for 404 lanes; `makedirs` errors are not caught by the refusal path [scripts/add_family_lanes.py:159-165] |

### 2b. Library contracts

| Import | Provider | Contract relied on | Boundary |
|---|---|---|---|
| `argparse` | stdlib | `UsageParser.error` exits 64 [scripts/add_family_lanes.py:17-34] | invalid arguments do not reach token resolution |
| `urllib` | stdlib | JSON requests, bearer header, 30-second timeout; HTTP error status returned with empty body, response deliberately redacted [scripts/add_family_lanes.py:72-91] | `URLError` and `TimeoutError` map to 599; malformed successful JSON is not caught [scripts/add_family_lanes.py:83-91] |
| `json` | stdlib | request serialization, successful response decoding; empty response normalizes to `{}` [scripts/add_family_lanes.py:72-86] | invalid successful JSON may raise rather than return 2 |
| `os` | stdlib | home expansion, checkout root, workdir creation, token lookup [scripts/add_family_lanes.py:13-14,37-69,163-165] | filesystem exceptions outside the guarded reads can escape |

### 2c. Service contracts

| Peer | Direction | Transport | Payload / response | Other side |
|---|---|---|---|---|
| Scheduler project API | out | HTTP GET/POST/PUT with bearer auth | GET by quoted name; POST four creation fields; PUT six pointer fields; GET verifies PUT [scripts/add_family_lanes.py:72-102,159-230] | Scheduler service is external; its implementation and admission decisions were not exercised here |
| Prompt files | in | filesystem read | six role files, whole content [scripts/add_family_lanes.py:105-120,127-142] | files in the checkout under `prompts/` |
| Operator | in/out | CLI and stdout/stderr | options and return codes in §7; summary and refusal lines in §5 | caller must inspect the exit code and named failures |

## 3. Verification

Executed on 2026-11-22 in reference tree `a7c5a8b9`. The pytest module starts a local HTTP stub and
executes the real script in subprocesses, not a scheduler daemon [tests/test_add_family_lanes_exit_status.py:25-113].
The five cases cover full and partial creation refusal, no-op existing projects, PUT refusal and an
API-only source assertion [tests/test_add_family_lanes_exit_status.py:130-172]. They do not establish
live scheduler admission, readback-mismatch handling, token failure, or complete successful creation.

| Check | Command | Result |
|---|---|---|
| Compile | `python3 -m py_compile scripts/add_family_lanes.py` | exit 0 |
| Execute cases | `python3 -m pytest tests/test_add_family_lanes_exit_status.py -q` | exit 0; 5 passed in 2.78s |
| Collection | `python3 -m pytest tests/test_add_family_lanes_exit_status.py --collect-only -q` | exit 0; 5 tests collected in 0.21s |
| Ruff check | `ruff check scripts/add_family_lanes.py docs/handbook/appendices/units/01-scripts-add-family-lanes-py.md` | exit 0; `All checks passed!` |
| Markdown format | `ruff format --check docs/handbook/appendices/units/01-scripts-add-family-lanes-py.md` | exit 2; Markdown formatting requires preview mode, so this is not a pass |
| Handbook gate | `python3 scripts/handbook_lint.py` | exit 0; `handbook_lint: clean` |

```text
.....                                                                    [100%]
5 passed in 2.78s
5 tests collected in 0.21s
handbook_lint: clean
```

The 2026-11-05 battery at revision `29e8e5e` measured the removed implementation; its old outputs
are retained in git history, not evidence for this version. No fresh scratch schedulerd battery or
live scheduler request was run. The checks above plus line-by-line source inspection are the current
basis; they do not prove the scheduler accepts the desired configuration.

## 4. Metrics emitted

No metrics library is imported [scripts/add_family_lanes.py:4-10]. The per-run summary gives counts,
not a durable metric or independent store inspection [scripts/add_family_lanes.py:153-157,201-207,232-235].

## 5. Log lines it can generate

These are source-derived formats, not claimed transcripts from a live scheduler.

| Stream | Format | Condition |
|---|---|---|
| stdout | `summary created=<n> present=<n> refused=<n>` | phase-1 failure or completion of phase 2 [scripts/add_family_lanes.py:203-204,232] |
| stderr | `refused: <name>: POST <status>` | creation rejected, including 409 [scripts/add_family_lanes.py:180-183,205-206] |
| stderr | `refused: <name>: GET <status>` | initial lookup rejected [scripts/add_family_lanes.py:192-195,205-206] |
| stderr | `refused: <name>: phase-2 PUT <status>` | update rejected [scripts/add_family_lanes.py:219-223,233-234] |
| stderr | `refused: <name>: phase-2 readback failed` | GET after PUT failed or any pointer differs [scripts/add_family_lanes.py:224-230,233-234] |
| stderr | `refused: <name>: phase-2 preparation failed` | prompt unreadable; an additional detail line is printed immediately [scripts/add_family_lanes.py:210-216,233-234] |
| stderr | `ERROR: <reason>` | token resolution failed [scripts/add_family_lanes.py:147-151] |

`present` counts GET 200 before identity validation; a malformed existing response can therefore
increment both `present` and `refused`. Phase-2 refusals can likewise overlap with `created` or
`present`, so these counters are not disjoint outcome categories [scripts/add_family_lanes.py:177-195,209-235].

## 6. Failure modes

| Failure | Result | Recovery / limitation |
|---|---|---|
| token unavailable or empty | `ERROR:`; 64 before API calls [scripts/add_family_lanes.py:37-69,145-151] | provide a readable token file or configured token; do not print credentials |
| initial GET or creation refused | count refusal, finish phase-1 loop, return 2; no phase 2 [scripts/add_family_lanes.py:159-207] | inspect named status and correct admission or connectivity; already-created rows remain |
| prompt unreadable | phase-2 preparation refusal, continue remaining lanes, return 2 [scripts/add_family_lanes.py:127-132,209-216,232-235] | restore prompt and re-run |
| PUT rejected or readback differs | refusal and exit 2 [scripts/add_family_lanes.py:219-235] | inspect service state and re-run; HTTP error bodies are intentionally suppressed |
| matching pointers | no PUT, no readback on that lane [scripts/add_family_lanes.py:217-218] | this is a no-op based on the initial GET, not a fresh post-update verification |
| malformed successful JSON or workdir filesystem error | can escape as a traceback [scripts/add_family_lanes.py:83-91,163-165] | the documented 0/2/64 contract does not cover every unexpected exception |

## 7. Environment and settings it reads

| Setting | Meaning |
|---|---|
| `--api-base` | scheduler API base; default `http://127.0.0.1:9090` [scripts/add_family_lanes.py:12,25-27] |
| `--namespace` | override namespace for newly created lanes, not an existing lane update [scripts/add_family_lanes.py:28-30,123-124,163-175,209-219] |
| `--token-file` | token read from the specified file, taking priority [scripts/add_family_lanes.py:31-33,59-65] |
| `CODER_API_TOKEN` | fallback when no token file is specified [scripts/add_family_lanes.py:59-66] |
| `SCHEDULER_OPERATOR_TOKEN` | last fallback: read from `/proc/<MainPID>/environ`; PID from `systemctl --user show -p MainPID --value coding-hermes-scheduler` [scripts/add_family_lanes.py:37-56,65-68] |
| Home and checkout | home determines stand-in paths; the script location determines `ROOT` and prompt paths [scripts/add_family_lanes.py:13-14,105-120,127-128] |

Exit contract: **0 = all applied** (phase 1 accepted, phase 2 applied and verified or no-op);
**2 = any refusal** (GET, POST, PUT, readback or preparation); **64 = usage error**, including
unavailable/empty token. Argument errors exit at `UsageParser.error` [scripts/add_family_lanes.py:17-20];
token errors return at [scripts/add_family_lanes.py:145-151]; phase-1 refusal returns at
[scripts/add_family_lanes.py:201-207]; final 2-or-0 return is [scripts/add_family_lanes.py:232-235].
Unexpected exceptions remain possible as described in §6.

## 8. Evidence of record

- Source: `scripts/add_family_lanes.py:1-239`, last-change revision `9bee3fe6`, reference tree `a7c5a8b9`.
- Executed on 2026-11-22: compile, five stub-based pytest cases, collection, Ruff and handbook gate
  in §3. Collection was not substituted for execution. Pytest also emitted an asyncio fixture-scope
  deprecation warning; the test run nevertheless exited 0.
- `tests/test_add_family_lanes_exit_status.py:169-172` asserts absence of the old direct-write import
  and path; this is a static assertion, not an end-to-end scheduler test.
- `grep -rn 'sqlite3' docs/handbook/` surveys the handbook: occurrences in other units document their
  own tools; none is an operating instruction for this loader. The command itself appears here as a
  search reference, and the historical test above guards removal.
- Chapter III.M2.S1 remains in `docs/handbook/chapters/M2-dispatch.md:33`; it names this loader.
- Historical scratch battery: revision `29e8e5e`, 2026-11-05, removed implementation only. No claim
  about current live fleet state or live API operation is made here.
