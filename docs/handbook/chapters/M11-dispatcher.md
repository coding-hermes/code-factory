# M11 — DISPATCHER (crier-fleet)

## 1. Identity

| Field | Value |
|---|---|
| Module name | DISPATCHER (`crier-fleet`) |
| Path | `/home/kara/crier-fleet/dispatcher.py` (538 lines) |
| Revision | `283bca91091933177ec521e52f37f1bc987cf7da` (crier-fleet HEAD, re-confirmed this round) |
| Language / runtime | Python — `#!/usr/bin/env python3`, no pinned version; host `python3` = 3.14.9 |
| Owner lane | crier-fleet (control plane) |
| Status | **VERIFIED** — `dispatcher.py` read in full this round (job model, ledger, completion bridge, settings, loop, all 23 log lines); the live-job tests are decoration (no assert) and the synchronous `CF_DURABLE_JOB=0` path is unmeasured (§7) |

## 2. Purpose, authority and position

Runs on the control box, one loop for every agent on every box, and executes the work *inside*
the agent's container via `bunker exec`. It decides the job model (start detached, poll with short
calls, kill on deadline) and keeps a replay ledger. It may not decide admission
or what the work is — that is the scheduler and the directive.

**What breaks if this module is absent.** For agents whose deployment routes them through
`crier-fleet`, no task leaves the bus: every dispatch sits in the inbox until it expires. This is
**not** the only inbox consumer: `scripts/node-bus-worker.py` independently retrieves inbox
messages (`:1320-1340`), processes them (`:1374`), invokes the harness (`:1148-1149`), delivers
the reply (`:1389-1395`) and acknowledges (`:1528-1539`), with its own entrypoint that does not
import the dispatcher. The absence consequence is therefore scoped to agents served by the
control-host dispatcher, not a property of the bus as a whole.

**What breaks if it lies.** Two distinct modes:
- A task recorded as done that never ran. The ledger replays a recorded result instead of
  re-running a redelivery (`dispatcher.py:470-475`) — **but only for a task whose result reached
  the ledger before the crash** (F11-3).
- **The deadline kill does not kill the harness's children (B01, corrected this round).** The
  runner template starts the harness as `timeout {limit} … hermes chat -q … &` (`:260`); GNU
  timeout puts the command in **its own process group** (`:246-249` documents this). The deadline
  kill at `:329` sends `kill -TERM -$(cat {d}/pid)` — `pid` is run.sh's own `$$` (`:291` runs
  `setsid sh run.sh`), so it kills **run.sh's** process group (run.sh + the heartbeat subshell +
  the `timeout` wrapper), *not* the separate timeout group holding `hermes` and its children. An
  independent disposable execution (sol round-5) measured `timeout_still_live=True` after the
  runner group was terminated. The "kill the process GROUP so nothing keeps spending" guarantee is
  **withdrawn** until a test proves the deadline path kills the harness group and its children
  (F11-8).

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 job model and durable execution | `dispatch_durable` (`:215-331`); `dispatch` switch (`:334-358`) | **active** | start detached (`:291` `setsid sh`), poll, kill run.sh's process group (`:329`); `CF_DURABLE_JOB=0` selects the synchronous path. **The kill does NOT reach the GNU-timeout group holding the harness** (B01, F11-8) |
| S2 ledger and idempotency | `ledger_load`/`ledger_put` (`:365-397`), replay (`:470-475`) | **active** | redelivery replays recorded result |
| S3 completion bridge | `deliver`-before-`ack` (`:500-519`), reply encoding | **active** | `reply_b64` never echoes the task body; `reply_len` measures the *selected excerpt*, not the full harness output (§11) |
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
| `DISPATCH_PROGRESS_S` | 20 (`:45`) | positive int | seconds between progress lines the node runner writes | **no suppression branch exists** — the runner loop (`:250-257`) writes a line then `sleep {hb}`; `0` removes the delay (busy loop), a negative value fails the `sleep` and the loop continues |
| `DISPATCH_LEASE_S` | 1800 (`:46`) | positive int | inbox lease | too long holds messages during a crash |
| `DISPATCH_EXEC_TIMEOUT` | `"400s"` (`:47`, a **string**) | — | **inert in this revision** — assigned at `:47` and never read (`grep -n EXEC_TIMEOUT dispatcher.py` → 1 match, the assignment itself). The real per-call timeout is `_bunker`'s `timeout` argument (default 120, `:204-209`), with the outer subprocess capped at `timeout + 20` (`:209`) |
| `DISPATCH_TASK_S` | `"240"` (`:48`, a **string**) | positive int at use (`task_seconds`, `:196`) | fallback task duration | a non-numeric env value raises `ValueError` **at use** (`int(TASK_S)` at `:196`), not at admission |
| `DISPATCH_MARGIN_S` | 60 (`:52`) | positive int | reserve before the caller's deadline | see F11-4 |
| `DISPATCH_TASK_CAP_S` | 7200 (`:53`) | positive int | ceiling on the envelope wall | a larger envelope wall is clamped |
| `BUNKER_BIN` | `/home/kara/.local/bin/bunker` (`:60`) | absolute path | which bunker binary runs | PATH order would otherwise pick a wrong binary |
| `CF_DURABLE_JOB` | `"1"` (`:336`) | `"0"` or non-`"0"` | execution mode switch | **`"0"` selects the synchronous `hermes chat -q` path (`:334-358`)**, bypassing the detached start/poll job model |
| `DISPATCH_LOG` / `DISPATCH_PIDFILE` | `$FLEET/logs/dispatcher.log` / `$FLEET/dispatcher.pid` (`:41-42`) | a path | log/PID location | a wrong path loses the journal/lock |
| `FLEET_GH_SCOPE` | `/home/kara/.hermes/scripts/fleet-gh-scope.py` (`:68`) | a path | scoped-token minter | a wrong path disables scoped tokens (non-fatal) |
| `FLEET_AGENTS` / `FLEET_AGENTS_FILE` | `fleet_agents.json` (`:104-109`) | a dict / path | agent registry | empty → "no FLEET_AGENTS configured" |
| `CRIER_URL` (read as `BUS`) | `http://<bus-host>:8767` (`:38`) | an http(s) endpoint | which bus the dispatcher polls and replies to | a wrong URL polls/replies to the wrong bus. **The host literal is redacted** in this public chapter; the real default is the tailnet address at `dispatcher.py:38` (`BUS = os.environ.get("CRIER_URL", …)`) — `<bus-host>` is a placeholder, not a configured value |
| `TOKEN_FILE` (bearer) | `/home/kara/.hermes/secrets/crier-fleet.token` (`:39`, a constant) | a path | the bus bearer identity | a missing file → client construction fails (`client for %s failed`) |
| `KEYS` (signing) | `$FLEET/keys` (`:40`, a constant) | a directory | the reply-signing key store | a missing key dir breaks reply signing |

**Completion bridge — reply target and output retention (sol B24, documented this round).** The
reply target is `payload_reply_to(msg, default="orchestrator")` (`:158-163`): the envelope's
`payload.reply_to` string when present, otherwise `"orchestrator"` — the fallback recipient is
**not** configurable by env. Output retention is lossy and differs by mode: the durable path polls
only the **last 4000 bytes** of the job's `out.log` (`tail -c 4000`, `:304`) and then selects the
**last six nonempty lines** (`:320-321`), truncating the answer to 1500 chars on failure (`:323`)
and 8000 on success (`:324`); the synchronous path likewise takes the last six nonempty lines
(`:356-357`) capped at 8000 (`:358`). `reply_len` at `:504` measures this **selected excerpt**
(`len(output)`), not the harness's full output — a completion's evidence is the tail, never the
whole run.

## 6. Contracts in and out

Canonical ids are the register of record (OUTLINE Part IV, CT-01..CT-18). Rows that are
cross-system contracts carry their CT id; an interface with no canonical entry is listed with a
`(local)` tag and is not a peer to any CT row, so it cannot be matched against another chapter.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-03 | crier | in | crier server `internal/registry/handler.go:1690` `HandleRetrieve` (the lease-granting side) | `dispatcher.py:435` `crier.retrieve` (the client side) | works |
| CT-06 | scheduler | out | `dispatcher.py:400` `main` (reply build `:500-508`; `crier.deliver` `:508`); transported by crier `internal/registry/handler.go:990` `HandleDeliver` into the scheduler's inbox | `internal/scheduler/dispatch_leg.go:713` `dispatchReplyVerdict` (reads only `payload["ok"]`) | **works** — the dispatcher always sends `ok` (`:501`), which is exactly the field `dispatchReplyVerdict` reads. CF-355 (status-vs-ok) belongs to the **node worker** (CT-04), not this producer |

**Protected service-delivery compatibility (sol B01, corrected this round — the header is
`X-Crier-Audience`).** The dispatcher supplies `sender` through the Python client
(`crier_client.Crier.deliver`, `:508`) but does **not** supply the full protected service-delivery
control set — no body `idempotency_key`, no `X-Crier-Audience` header (`HeaderServiceAudience =
"X-Crier-Audience"`, `internal/registry/agentsig.go:35`). Crier enforces those for a recipient
registered as a protected service (`internal/registry/service_auth.go:128-168`, called at
`handler.go:1147`): a signed sender, a body sender matching the signed `X-Agent-ID`, an
allowlisted sender→recipient pair, and — when an audience is configured — a nonempty
`idempotency_key` and a matching audience. The dispatcher's reply leg is therefore compatible with
an **un-protected** scheduler recipient only; the "works" state above is scoped to that measured
recipient policy, and does not claim the constructed request succeeds against a protected service
recipient (not asserted to be enabled on the live relay).

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| python compile | `python3 -m py_compile dispatcher.py` | exit 0 | 2026-11-07, rev `283bca9` | PASS |
| live job tests | `tests/test_durable_job.py` / `test_job_kill.py` | failure oracle | not run this round | **UNVERIFIED** — these scripts print results but do not assert (`tests/test_durable_job.py` contains no `assert`/`raise`/`exit`), so they cannot fail (F11-2) |

The round-3 "source read (538 lines) PASS" row was decoration — reading the file cannot fail. It
is removed; the body read is recorded in §1/§13 instead.

## 8. Metrics

**RED — none (absence-proved this round).** The dispatcher emits no counters, gauges or histograms
— `grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' dispatcher.py` → 0 matches. Dispatch
rate, job duration, kill count and redelivery count are answerable only by grepping the log. (It
appends a `dispatch-ledger.jsonl`, but that is a replay ledger, not an emitted metric.)

## 9. Log lines (verbatim)

Complete inventory (all 23 `log()` **call sites**; `grep -n 'log(' dispatcher.py` returns **25**
lines — `:81` a comment mentioning `log()` and `:112` the `def log(` definition, plus the 23 calls;
`dispatcher.py:112` `log()` writes to `DISPATCH_LOG`). **Emitted-severity correction (sol B24):**
`log(msg)` (`:112-120`) takes one message string and emits only `"<timestamp> <msg>\n"` — there is
**no severity field**, no level parameter, and no structured level anywhere on the write path. The
`Level` column below is therefore **operator-inferred** from the message text, not an emitted
attribute, and there is no level-based filtering of the journal. (The round-17 table presented
`warn`/`error`/`info` as emitted levels — that was a misrepresentation.)

| Level (inferred — none emitted) | Line | Emitted when | Kind |
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
| error | `client for %s failed: %s` (`:422`) | **local client construction fails** — `client_for` (`:128-132`) only builds a `Crier` (URL parse, key load, token); no network call, so this is a credential/client-config failure, not node unreachability | descriptive |
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
- **F11-6:** `dispatch` (`:334-358`) selects `dispatch_durable` only when `CF_DURABLE_JOB != "0"`;
  `CF_DURABLE_JOB=0` runs `bunker exec … hermes chat -q` synchronously with `timeout (limit+30)`.
  `main()` checks the ledger before calling `dispatch` (`:470-475`) and records either execution
  mode's result after it (`:481-483`). `CF_DURABLE_JOB=0` bypasses the detached start/poll/kill
  supervision, but it still participates in the outer replay ledger. The crash-before-ledger-write
  gap (F11-3) applies to both modes.
- **F11-11 (output retention, sol B24):** the completion carries only the last-six-lines tail of
  the last-4000-bytes of `out.log` (durable) or the last six lines (sync); `reply_len` (`:504`)
  is the length of that excerpt, not the full harness output. Evidence/report preservation is
  therefore lossy by construction.
- Every short bunker call is bounded (`:204-212`); the 300 s stream boundary is why the job model
  exists (`:218-222`).

## 12. Cross-references

- F1 DISPATCH AND SETTLEMENT is the flow this module executes on the control box — **flow chapter not written** (OUTLINE Part II, all 16 flows MISSING).
- M10 CRIER is the transport; M9 SCHEDULER is the settlement consumer.
- The per-dispatch scoped token is minted by `fleet-gh-scope.py` → `~/.hermes/scripts/gh-app-token.py`
  (not M7's `github-app-token.py`) — see M7 §12.

## 13. Evidence of record

- Code read: `dispatcher.py` (538 lines, read in full this round).
- Commands run: `python3 -m py_compile dispatcher.py` (PASS); `grep -n 'log(' dispatcher.py` (25 lines: 23 call sites + comment `:81` + def `:112`); `grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' dispatcher.py` (0 matches).
- Rev stamped: `283bca9` (re-confirmed).
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
  - **F11-7** — `DISPATCH_TASK_S` is a string until `int()` at use (`task_seconds` def `:185`, `int(TASK_S)` at `:196`), so a bad env value raises `ValueError` at use, not at admission.
  - **F11-8** (carried, B01) — the deadline kill at `:329` (`kill -TERM -$(cat {d}/pid)`) targets
    run.sh's process group; the harness runs under GNU timeout's own process group (`:260`, `:246-249`),
    so a surviving-harness failure mode exists and the descendant-termination guarantee is withdrawn
    until a test proves the kill reaches the harness group.
  - **F11-9** (carried) — the §2 absence consequence is scoped to control-host-dispatched agents;
    `node-bus-worker.py` is the independent inbox consumer.
  - **F11-10** (corrected, sol B01) — the dispatcher's reply leg supplies `sender` but no protected
    service-delivery `idempotency_key`/`X-Crier-Audience`, so "works" is scoped to un-protected recipients.
  - **F11-11** (new, sol B24) — output retention (last 4000 bytes → last six lines) and the
    `"orchestrator"` fallback recipient are documented; `reply_len` measures the excerpt.
  - **F11-12** (new, sol B24) — the §9 table presented `warn`/`error`/`info` as emitted log levels;
    `log()` (`:112-120`) emits no severity — only `"<timestamp> <msg>\n"`. The `Level` column is now
    labelled **operator-inferred**, not emitted.

## RED field count: 2 (Metrics §8 — absence-proved; live-job test row §7 — decoration, cannot fail)
