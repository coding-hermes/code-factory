# M11 — DISPATCHER (crier-fleet)

## 1. Identity

| Field | Value |
|---|---|
| Module name | DISPATCHER (`crier-fleet`) |
| Path | `/home/kara/crier-fleet/dispatcher.py` (538 lines) |
| Revision | `283bca91091933177ec521e52f37f1bc987cf7da` (crier-fleet HEAD) |
| Language / runtime | Python — `#!/usr/bin/env python3`, no pinned version; host `python3` = 3.14.9 |
| Owner lane | crier-fleet (control plane) |
| Status | **VERIFIED** — `dispatcher.py` read in full (job model, ledger, completion bridge, settings, loop, all 23 log lines); the live-job tests are decoration (no assert) and the synchronous `CF_DURABLE_JOB=0` path is unmeasured (§7) |

## 2. Purpose, authority and position

Runs on the control box, one loop for every agent on every box, and executes the work *inside*
the agent's container via `bunker exec`. It decides the job model (start detached, poll with short
calls, kill on deadline) and keeps a replay ledger. It may not decide admission
or what the work is — that is the scheduler and the directive.

**What breaks if this module is absent.** No task leaves the bus: every dispatch sits in the
inbox until it expires.

**What breaks if it lies.** Two distinct modes:
- A task recorded as done that never ran. The ledger replays a recorded result instead of
  re-running a redelivery (`dispatcher.py:470-475`) — **but only for a task whose result reached
  the ledger before the crash** (F11-3).
- **The deadline kill does not kill the harness's children (B01).** The
  runner template starts the harness as `timeout {limit} … hermes chat -q … &` (`:260`); GNU
  timeout puts the command in **its own process group** (`:246-249` documents this). The deadline
  kill at `:329` sends `kill -TERM -$(cat {d}/pid)` — `pid` is run.sh's own `$$` (`:291` runs
  `setsid sh run.sh`), so it kills **run.sh's** process group (run.sh + the heartbeat subshell +
  the `timeout` wrapper), *not* the separate timeout group holding `hermes` and its children. An
  independent disposable execution measured `timeout_still_live=True` after the
  runner group was terminated. The "kill the process GROUP so nothing keeps spending" guarantee is
  **withdrawn** until a test proves the deadline path kills the harness group and its children
  (F11-8).

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 job model and durable execution | `dispatch_durable` (`:215-331`); `dispatch` switch (`:334-358`) | **active** | start detached (`:291` `setsid sh`), poll, kill run.sh's process group (`:329`); `CF_DURABLE_JOB=0` selects the synchronous path. **The kill does NOT reach the GNU-timeout group holding the harness** (B01, F11-8) |
| S2 ledger and idempotency | `ledger_load`/`ledger_put` (`:365-397`), replay (`:470-475`) | **active** | redelivery replays recorded result |
| S3 completion bridge | `deliver`-before-`ack` (`:500-519`), reply encoding | **active** | `reply_b64` never echoes the task body |
| S4 agent registry and scope | `AGENTS` (`:104-109`), per-dispatch scoped GitHub token (`:62-98`) | **active** | `fleet_agents.json` |

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| `bunker` CLI | 0.1.4+ (cert pinning) — **absolute path** default `/home/kara/.local/bin/bunker` (`:60`, `BUNKER_BIN`) | control box | exit 127 from subprocess |
| `hermes` CLI | on the node | `$HOME/.local/bin/hermes` | `DONE:127` in the job status file |

**4b. Library contracts**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `crier_client.Crier` | crier | `retrieve` (`:435`), `deliver` (`:508`), `ack` (`:519`, `:448`, `:465`) — **not** `send`/`retrieve`/`complete` | a `retrieve` rename stops polling silently |
| `fleet-gh-scope.py` | external tool (`SCOPE_TOOL`, `:68`) | `dispatch_env` / `env_prefix` (`:91-98`) | an unavailable scoper is non-fatal: dispatches carry no `GH_TOKEN` |

**4c. Service contracts** — see §6.

## 5. Settings register

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `DISPATCH_POLL_S` | 5 (`:43`) | positive float | poll interval | shorter polls raise bus load |
| `DISPATCH_PROGRESS_S` | 20 (`:45`) | positive int | seconds between progress lines the node runner writes | **no suppression branch exists** — the runner loop (`:250-257`) writes a line then `sleep {hb}`; `0` removes the delay (busy loop), a negative value fails the `sleep` and the loop continues; 0 or negative does not suppress progress (B25) |
| `DISPATCH_LEASE_S` | 1800 (`:46`) | positive int | inbox lease | too long holds messages during a crash |
| `DISPATCH_EXEC_TIMEOUT` | `"400s"` (`:47`, a **string**) | — | **inert in this revision** — assigned at `:47` and never read (`grep -n EXEC_TIMEOUT dispatcher.py` → 1 match, the assignment itself; B22 AST check: exactly one `Store` reference, no load). The real per-call timeout is `_bunker`'s `timeout` argument (default 120, `:204-209`), with the outer subprocess capped at `timeout + 20` (`:209`); this env var adds no timeout prefix to `bunker exec` and changes nothing at run time |
| `DISPATCH_TASK_S` | `"240"` (`:48`, a **string**) | positive int at use (`task_seconds`, `:196`) | fallback task duration | a non-numeric env value raises `ValueError` **at use** (`int(TASK_S)` at `:196`), not at admission |
| `DISPATCH_MARGIN_S` | 60 (`:52`) | positive int | reserve before the caller's deadline | see F11-4 |
| `DISPATCH_TASK_CAP_S` | 7200 (`:53`) | positive int | ceiling on the envelope wall | a larger envelope wall is clamped |
| `BUNKER_BIN` | `/home/kara/.local/bin/bunker` (`:60`) | absolute path | which bunker binary runs | PATH order would otherwise pick a wrong binary |
| `CF_DURABLE_JOB` | `"1"` (`:336`) | `"0"` or non-`"0"` | execution mode switch | **`"0"` selects the synchronous `hermes chat -q` path (`:334-358`)**, bypassing the detached start/poll job model (B23) |
| `DISPATCH_LOG` / `DISPATCH_PIDFILE` | `$FLEET/logs/dispatcher.log` / `$FLEET/dispatcher.pid` (`:41-42`) | a path | log/PID location | a wrong path loses the journal/lock |
| `FLEET_GH_SCOPE` | `/home/kara/.hermes/scripts/fleet-gh-scope.py` (`:68`) | a path | scoped-token minter | a wrong path disables scoped tokens (non-fatal) |
| `FLEET_AGENTS` / `FLEET_AGENTS_FILE` | `fleet_agents.json` (`:104-109`) | a dict / path | agent registry | empty → "no FLEET_AGENTS configured" |
| `CRIER_URL` (read as `BUS`) | `http://<bus-host>:8767` (`:38`) | an http(s) endpoint | which bus the dispatcher polls and replies to | a wrong URL polls/replies to the wrong bus |
| `TOKEN_FILE` (bearer) | `/home/kara/.hermes/secrets/crier-fleet.token` (`:39`, a constant) | a path | the bus bearer identity | a missing file → client construction fails (`client for %s failed`) |
| `KEYS` (signing) | `$FLEET/keys` (`:40`, a constant) | a directory | the reply-signing key store | a missing key dir breaks reply signing |

## 6. Contracts in and out

Canonical ids are the register of record (OUTLINE Part IV, CT-01..CT-18). Rows that are
cross-system contracts carry their CT id; an interface with no canonical entry is listed with a
`(local)` tag and is not a peer to any CT row, so it cannot be matched against another chapter.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-03 | crier | in | crier server `internal/registry/handler.go:1690` `HandleRetrieve` (the lease-granting side) | `dispatcher.py:435` `crier.retrieve` (the client side) | works |
| CT-06 | scheduler | out | `dispatcher.py:500-508` builds the completion reply `{in_reply_to, agent, ok, …}`; transported via crier `internal/registry/handler.go:990` `HandleDeliver` into the scheduler's inbox | scheduler `internal/scheduler/dispatch_leg.go:713` `dispatchReplyVerdict` | **works** — the dispatcher always sends `ok` (`:501`), which is exactly the field `dispatchReplyVerdict` reads. CF-355 (status-vs-ok) belongs to the **node worker** (CT-04), not this producer |

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| python compile | `python3 -m py_compile dispatcher.py` | exit 0 | 2026-11-07, rev `283bca9` (re-confirmed unchanged) | PASS |
| live job tests | `tests/test_durable_job.py` / `test_job_kill.py` | failure oracle | not run | **UNVERIFIED** — these scripts print results but do not assert (`tests/test_durable_job.py` contains no `assert`/`raise`/`exit`), so they cannot fail (F11-2) |

A "source read (538 lines)" row cannot be a test — reading a file cannot fail; the body read is
recorded in §1/§13 instead.

## 8. Metrics

**RED — none (absence-proved).** The dispatcher emits no counters, gauges or histograms
— `grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' dispatcher.py` → 0 matches. Dispatch
rate, job duration, kill count and redelivery count are answerable only by grepping the log. (It
appends a `dispatch-ledger.jsonl`, but that is a replay ledger, not an emitted metric.)

## 9. Log lines (verbatim)

Complete inventory (all 23 `log()` **call sites**; `grep -n 'log(' dispatcher.py` returns **25**
lines — `:81` a comment mentioning `log()` and `:112` the `def log(` definition, plus the 23 calls;
`dispatcher.py:112` `log()` writes to `DISPATCH_LOG`):

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| warn | `scoped token mint failed for %s (%s) — dispatching without GH_TOKEN` (`:97`) | scoper unreachable | descriptive |
| warn | `text_b64 did not decode: %s` (`:147`) | malformed dispatch | descriptive |
| info | `job %s started on %s (limit %ss, wall %ss)` (`:294`) | job start | evidentiary |
| info | `job %s progress: %s` (`:316`) | progress tick | descriptive |
| info | `job %s finished rc=%s after %.0fs` (`:319`) | job end | evidentiary |
| warn | `ledger write failed for %s: %s` (`:397`) | ledger append OSError (swallowed) | descriptive |
| error | `dispatcher already running as pid %s — exiting this copy` (`:405`) | double start | evidentiary |
| info | `no FLEET_AGENTS configured — nothing to dispatch` (`:413`) | empty registry | evidentiary |
| info | `dispatcher up: %d agents, bus=%s, poll=%ss, lease=%ss` (`:415`) | start | descriptive |
| error | `client for %s failed: %s` (`:422`) | **local client construction fails** — `client_for` (`:128-132`) only builds a `Crier` (URL parse, key load, token); no network call, so this is a credential/client-config failure, not node unreachability (B64 / B26) | descriptive |
| info | `dispatch ledger: %d recorded result(s) — redeliveries replay instead of re-running` (`:425`) | start | evidentiary |
| error | `retrieve failed for %s: %s` (`:437`) | poll error | descriptive |
| error | `empty task %s -> %s: refusing, acking so it stops looping` (`:446`) | blank directive | evidentiary |
| error | `ack failed for empty %s: %s` (`:450`) | ack of an empty task fails | descriptive |
| error | `JSON-blob task %s -> %s refused: an envelope is not a directive` (`:463`) | envelope-as-directive | evidentiary |
| error | `ack failed for blob %s: %s` (`:467`) | ack of a blob refusal fails | descriptive |
| info | `redelivery %s -> %s: replaying recorded result (no re-execution)` (`:475`) | ledger replay | evidentiary |
| info | `dispatch %s -> %s: %s` (`:477`) | a fresh dispatch (not a redelivery) | evidentiary |
| error | `reply delivery failed for %s (left unacked): %s` (`:510`) | reply deliver failure | descriptive |
| info | `done %s (%s) in %ss — acked` (`:521`) | successful reply delivered + acked | evidentiary |
| info | `FAILED %s (%s) in %ss — reported and acked: %s` (`:523`) | failed task reported + acked | evidentiary |
| error | `ack failed for %s: %s — will redeliver` (`:526`) | ack failure | descriptive |
| error | `dispatcher died:\n%s` (`:537`) | uncaught exception in the loop | evidentiary |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Harness overruns deadline | `DONE:124`, job killed (`:319` `job … finished rc=…`) | a crash (`DONE:1` + traceback) | **partial** — the kill at `:329` terminates run.sh's process group; whether the GNU-timeout group holding `hermes` and its children dies with it is **unverified** (F11-8). Do not assume automatic descendant termination; check for surviving harness processes after the deadline |
| Local client/key/config failure | `client for %s failed` (`:422`) — `client_for` (`:128-132`) builds a `Crier`, no network call | a node execution failure | check `KEYS`/token/`BUS` config, not the node |
| Node unreachable | a later `bunker exec` failure (`_bunker`, `:204-212`) with no job dir | a local client failure | check the bunker node, not the client config |
| Reply refused by guard | task runs, answer lost | a timeout | base64 on both legs (`:484-499`) |
| Reply delivery failed | `reply delivery failed for %s (left unacked)` (`:510`) | a failed task (which is acked) | the message stays unacked and redelivers |
| Crash before ledger write | the task ran (`:479`) but `ledger_put` (`:481`) never persisted → no replay record | a recorded redelivery | **OPEN** — F11-3: redelivery replay is not crash-safe |
| Ledger write failed | `ledger write failed …` (`:397`), in-memory ledger still updated | a durable ledger | the write failure is swallowed; only the in-memory copy survives |

## 11. Limits and margins

- `task_seconds` (`:185-197`) = `max(30, min(CAP_S, wall_s - MARGIN_S))`; a `wall_s <= 0` falls
  back to `TASK_S`. **F11-4:** it does **not** refuse a caller budget too small for the 30 s floor
  — `task_seconds(10)` and `task_seconds(60)` both return 30 (a 30 s budget that overruns the
  caller's own 10 s deadline). The "reserve" is intended, not guaranteed.
- **F11-5 (serial head-of-line):** the main loop iterates agents serially (`:428-442`) and
  `dispatch` waits synchronously for a job to finish (`:479`) before servicing the next message.
  One long job blocks polling and execution for every later agent in the process — no per-agent
  concurrency. The worst case is unmeasured.
- **F11-6 (B23, B24).** `dispatch` (`:334-358`) selects `dispatch_durable` only when
  `CF_DURABLE_JOB != "0"`; `CF_DURABLE_JOB=0` runs `bunker exec … hermes chat -q` synchronously
  with `timeout (limit+30)`. The synchronous path is **not** ledger-less:
  `main()` checks the ledger before calling `dispatch` (`:470-475`) and records either execution
  mode's result after it (`:481-483`). `CF_DURABLE_JOB=0` bypasses the detached start/poll/kill
  supervision, but it still participates in the outer replay ledger. The crash-before-ledger-write
  gap (F11-3) applies to both modes.
- Every short bunker call is bounded (`:204-212`); the 300 s stream boundary is why the job model
  exists (`:218-222`).

## 12. Cross-references

- F1 DISPATCH AND SETTLEMENT is the flow this module executes on the control box — **flow chapter not written** (OUTLINE Part II, all 16 flows MISSING).
- M10 CRIER is the transport; M9 SCHEDULER is the settlement consumer.
- The per-dispatch scoped token is minted by `fleet-gh-scope.py` → `~/.hermes/scripts/gh-app-token.py`
  (not M7's `github-app-token.py`) — see M7 §12.

## 13. Evidence of record

- Code read: `dispatcher.py` (538 lines, read in full).
- Commands run: `python3 -m py_compile dispatcher.py` (PASS); `grep -n 'log(' dispatcher.py` (25 lines: 23 call sites + comment `:81` + def `:112`); `grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' dispatcher.py` (0 matches); `grep -n EXEC_TIMEOUT dispatcher.py` (1 match, `:47` — inert).
- Rev stamped: `283bca9` (re-confirmed: `git rev-parse HEAD` = `283bca91091933177ec521e52f37f1bc987cf7da`, `wc -l dispatcher.py` = 538).
- Board rows: CF-334, CF-355, CF-365.
- **Findings:**
  - **F11-1** (carried) — no pinned Python; calls `retrieve`/`deliver`/`ack`, never `send`/`complete`.
  - **F11-2** (carried) — the test scripts print without asserting.
  - **F11-3** — redelivery replay is not unconditional crash-safe: `dispatch` (`:479`) runs before
    `ledger_put` (`:481`).
  - **F11-4** — `DISPATCH_MARGIN_S` is an intended reserve, not a guaranteed one.
  - **F11-5** — the serial loop (`:428-442`, `:479`) head-of-line-blocks later agents.
  - **F11-6** — the `CF_DURABLE_JOB=0` synchronous path (`:334-358`) was undocumented; it bypasses
    the durable job model.
  - **F11-7** (new) — `DISPATCH_TASK_S` is a string until `int()` at use (`task_seconds` def `:185`, `int(TASK_S)` at `:196`), so
    a bad env value raises `ValueError` at use, not at admission.
  - **F11-8** (new, B01) — the deadline kill at `:329` (`kill -TERM -$(cat {d}/pid)`) targets
    run.sh's process group; the harness runs under GNU timeout's own process group (`:260`, `:246-249`),
    so a surviving-harness failure mode exists and the descendant-termination guarantee is withdrawn
    until a test proves the kill reaches the harness group.

## RED field count: 2 (Metrics §8, live-job test row §7 — decoration, cannot fail)

## FLIGHT DATA FILE - M11 DISPATCHER

```checklist
TITLE: M11 DISPATCHER
WHO: CONTROL HOST
POLL - run one dispatcher cycle against a queued agent
√ LEASE - exactly one message leased; the run starts
REPLY - let the worker finish
√ LEDGER - dispatch-ledger.jsonl grows by one line naming the corr id
FRESHNESS - compare dispatcher service start to its script mtime
√ CURRENT - no negative elapsed in the journal (a stale poller lies about time)
```
