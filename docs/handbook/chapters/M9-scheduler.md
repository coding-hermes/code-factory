# M9 — SCHEDULER

## 1. Identity

| Field | Value |
|---|---|
| Module name | SCHEDULER |
| Path | `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/` (Go) |
| Revision | `1771d3aad61e6c1ce2845e3f1450f88aa73340b3` (scheduler repo HEAD, re-stamped this round) |
| Language / runtime | Go — `go.mod` declares `go 1.26.0` + `toolchain go1.26.6`; `go env GOVERSION` resolves **go1.26.6** (`GOTOOLCHAIN=auto`). Host `go version` = **go1.26.5** (default PATH `/home/kara/.local/bin/go`); `/usr/bin/go` = go1.26.8, `/snap/bin/go` = go1.27.1 |
| Owner lane | coding-hermes-scheduler (control plane) |
| Status | **UNVERIFIED** — settlement (`dispatch_leg.go:260-336, :713-726`), `internal/bus/dispatch.go:175-208`, the admission authority (`admission_mode.go:98-129, 143-208, 230-267`), the binary defaults (`cmd/schedulerd/main.go:95-200`), the auth path (`internal/api/auth.go:187-197`), the API route table (`internal/api/server.go:289-346`) and `config.example.toml` read this round; `tick_process.go`/`packer_select.go`/`namespace_alloc.go` grep-level, not line-by-line; §9 log inventory narrowed to the settlement/batch-dispatch surface (2 of 379 sites) with the uncovered count named as RED |

## 2. Purpose, authority and position

The control plane's clock and admission authority. It decides when a lane's cadence tick fires,
whether it is admitted (eligibility, tasks-vs-cooldown, board gates, fairness, budget
reservation), and how a dispatch settles. It may not decide what the foreman *does* with the work
— that is the directive it hands off.

**What breaks if this module is absent.** No cadence tick fires; nothing is admitted, dispatched
or settled.

**What breaks if it lies.** `dispatchReplyVerdict` (`dispatch_leg.go:713-726`) reads only
`payload["ok"]` and treats the *absence* of a verdict as success (`:709-712`). A node reply
carrying `status:"failed"` (the field `node-bus-worker.py:1132` actually sends) and no `ok` is
scored a success — the control-plane half of the silent-success defect (CF-355).

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 admission and allocation | `admission_mode.go`, `tick_process.go`, `packer_select.go`, `namespace_alloc.go`, `usage_pool_policy.go` | **active** | `admission_mode.go:98` `admissionModeFor` (project override → namespace default → cooldown); `:112` `admissionModeForProject` (DB read); `tick_process.go:40` `evaluate()`; `packer_select.go:19` `Pack`; `namespace_alloc.go:131` `Allocate`; `usage_pool_policy.go:21` `reserveUsagePools` |
| S2 execution and settlement | `spawn`, `slot_pool`, `lifecycle`, `dispatch_leg` | **active** | `dispatch_leg.go:260` `awaitDispatchReply`; `:262-336` constructs completed/failed/timeout outcomes |
| S3 durable state | `scheduler.db` + migration stores | **active** | live store has **30** tables (measured `sqlite3 … '.tables'`); see §5/§3 note for the run-correctness keys |
| S4 operator surfaces | `cmd/schedulerd`, `scheduler-dispatch`, `scheduler-query`, `queueprobe`, `migrate`, `backfill-commit-signals`, `cooldown-residue` | **operator-invoked** | `ls cmd/` → 7 command dirs; no unit invokes another unit — these are CLI entrypoints an operator (or a foreman step) runs, not a scheduler lane |

**Operator surfaces (B18).** The daemon mounts its HTTP routes in `internal/api/server.go:289-346`
(auth on mutations via `extractBearerOrHeaderToken`, `internal/api/auth.go:187-197`): read surfaces
`/api/v1/{health,live,status,config,projects,projects/,hooks,hooks/plan,hooks/{id},lanes/tree,lanes,links,links/,cadence,namespaces,namespaces/,groups,groups/,templates,templates/,ticks,ticks/,queue,openapi.json,metrics}`;
mutations `/api/v1/{evaluate,pause,resume,events}` plus `events/stream`; observatory
`/api/v1/observatory{,/stream}` and `/api/v1/gateway-errors`. The recovery commands
(`reap-sessions`, `verify-board`, `migrate`) are CLI-only flags/subcommands, not HTTP routes.
Per-route request/response shapes and write-authority readbacks are **not** written this round —
the route inventory is, the per-route contract is not (a named RED on S4, B18).
| S5 doctrine | `scheduler-rules.md`, `dispatch-spec.md`, `execution-contracts.md`, `execution-store.md`, `runbook-drain-restart.md`, `hop-liveness-watchdog.md` | **legacy (documentation)** | six doctrine docs present under `docs/`; presence is existence, not invocation — no unit reads them at runtime |

**Ordered admission procedure (B16, written this round).** The composed decision sequence, in
order of authority:

1. **Mode precedence** (`admission_mode.go:98-107` `admissionModeFor`): a project-level
   `cooldown`/`tasks` mode wins; otherwise the namespace's mode wins; otherwise **cooldown**.
   `admissionModeForProject` (`:112-129`) re-reads the same precedence from the DB for post-tick
   paths.
2. **Board ownership** (`boardOwnedByLane`, `:177-184`): an explicit `BoardOwnershipOwner`/
   `BoardOwnershipShared` override wins; otherwise the filesystem derivation (`laneOwnsBoard`,
   workdir containment, `:143-184`).
3. **Board workability** (`tasksAdmissionDue`, `:230-242`): for a tasks-mode lane, admission
   requires an owned, readable, workable board with `workable > 0`; an empty workdir or
   non-owned board is a refusal (`:232-239`).
4. **Last-tick failure** (`lastTickStatusFailed`, `:266-267`): a project whose
   `last_tick_status='failed'` stands the tasks-mode waiver down — the next tick paces on the full
   effective cooldown instead of re-admitting (SCHED-GAP-214).
5. **Usage-pool reservation** (`usage_pool_policy.go:26-63` `reserveUsagePools`): a disabled
   policy (`!policy.Enabled`) or nil authority returns `(false, nil)` — no reservation, no
   refusal; a missing/invalid `host_id` or empty pool set returns `ErrUsagePoolMissing`; remote
   lanes append `host:<id>`, local lanes append `LocalPoolID`; `ObserveOnly` checks without
   reserving (a `Denied` decision logs and returns `false, nil`); otherwise lease recovery runs,
   then `ReserveAll` enforces the reservation. Refusal outcomes are `false, <named error>`, not a
   silent drop.

**Durable-state store keys (B17, written this round).** The 30-table store's run-correctness
keys and their relationships, at `internal/database/migrations.go`:

| Table | Locator | Key / guarantee |
|---|---|---|
| `tick_dispatch` | `:1217-1232` | `tick_id` PRIMARY KEY; `lane, agent, corr_id, message_id, transport, state, reply, error`; indexes on `corr_id`, `message_id`, `state` — the dispatch receipt |
| `execution_runs` | `:1391` (+`recovery_idx :1410`) | one row per run, `state` + `updated_at` for recovery |
| `workspace_leases` | `:1412` (+`one_writer_idx :1423`) | **single-active-writer** unique index — the workspace ownership guarantee |
| `execution_attempts` | `:1427` (+`step_gen_idx :1970`) | attempt generation; `step`/`gen` uniqueness (`execution_attempts_step_gen_idx`) |
| `execution_events` | `:1449` (+`run_idx :1458`) | per-run event sequence (`run_id, event_id`) |
| `verification_receipts` | `:1460` | per-attempt verification receipt |
| `execution_projections` | `:1470` | the materialized run state |
| `execution_outbox` | `:1479` (+`pending_idx :1489`) | durable-delivery queue, pending by `state, available_at, created_at` |

Relationship: a run (`execution_runs`) has 1:N attempts (`execution_attempts`) and 1:N ordered
events (`execution_events`); the projection is the materialized run state; the outbox is the
durable-delivery queue; the workspace lease is the single-active-writer boundary. The write
authorities and recovery queries per table are not yet written — the keys, their uniqueness
guarantees and their relationships are.

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| Go toolchain | `go 1.26.0` + `toolchain go1.26.6` (`go.mod`) | build host | `GOTOOLCHAIN=auto` auto-selects 1.26.6 (build PASS); with `GOTOOLCHAIN=local` the 1.26.5 host would be below the toolchain directive |
| SQLite (scheduler.db) | via `modernc.org/sqlite v1.60.1` | control host | DB open failure |

**4b. Library contracts**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `modernc.org/sqlite` | external | the CGo-free SQLite driver backing `scheduler.db` | a driver change breaks the 30-table store |
| `BurntSushi/toml` | external | `config.example.toml` parsing | a config-key change breaks lane config |

**4c. Service contracts** — see §6.

## 5. Settings register

**Binary defaults (read this round, B18/F9-3).** The daemon's actual flag defaults are in
`cmd/schedulerd/main.go` (flag definitions span `:95-200+`); `config.example.toml` is the *example*
register, and its commented values are **not** the runtime defaults. The full flag surface is **57
definitions**, measured with `grep -cE 'flag\.(String|Int|Int64|Bool|Duration|Float64)' cmd/schedulerd/main.go` = 57.

| Setting | Binary default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `db` | `$HOME/.hermes/coding-hermes/scheduler.db` (`:95`) | a path | SQLite store | a wrong path opens a different store |
| `listen` | `127.0.0.1:9090` (`:96`) | an addr | HTTP surface | off-loopback exposes the API |
| `min-interval` | **30 s** (`:108`) | Go duration | fastest tick interval | below it ticks are refused/never fire |
| `max-interval` | 24 h (`:109`) | Go duration | slowest tick interval | above it lanes starve |
| `num-levels` | 10 (`:110`) | >= 1 | priority levels | 0 breaks the priority sort |
| `budget` (weight budget) | 100 (`:111`) | >= 1 | weight budget per evaluation | 0 admits nothing |
| `max-concurrent` | **10** (`:112`) | >= 1 | concurrent foreman ticks | a load gate is a separate knob (see below) |
| `namespace-mode` | **false** (`:113`) | bool | multi-namespace scheduling | off disables reserved/hard_cap |
| `tick-timeout` | 7200 s / 2 h (`:114`) | Go duration | wall-clock before a tick is killed | too short kills legitimate ticks |
| `api-read-timeout` | 5 s (`:122`) | Go duration | per-request deadline for heavy read surfaces | a stalled DB helper returns 504 naming it (SCHED-GAP-1575-B) |
| `gateway-response-timeout` | 30 m (`:128`) | Go duration | per-turn POST deadline (min of this and tick-timeout) | `0` disables |
| `gateway-transient-retries` | 3 (`:138`) | int | 5xx/refused retry count (SCHED-GAP-1681) | 0 = single attempt |
| `slot-patience` | 5 m (`:142`) | Go duration | how long a spawn waits for a free slot | the drop emits a `slot_pool` event (ADV-R08/G3) |
| `tasks-pacing` | 60 s (`:143`) | Go duration | min post-tick spacing for tasks-mode projects | 0 = disabled |
| `load-gate-threshold` | **0 (disabled)** (`:144`) | float (1-min load avg) | defer new spawns while load >= threshold | 0 disables; namespaces opt out via `load_gate='off'` |
| `feature-prune-weeks` | 8 (`:145`) | int | dead-feature reaper prune window | flag only — nothing is auto-deleted |
| `peer-freshness-window` | `database.PeerFreshnessWindowDefault` (`:148`) | int seconds | REMOTE-003 peer heartbeat freshness | a too-short window spuriously ages peers |
| `spawn-mem-limit-mb` | 0 (`:149`) | MiB | per-spawn `RLIMIT_AS` cap (ADV-R11) | 0 = no cap; a low cap kills spawns |
| `board-stasis-gate` | **true** (`:150`) | bool | exclude a cooldown BUILDER lane whose board is unchanged (SCHED-GAP-1678) | off admits stasis lanes |
| `hooks-file` | `$HOME/.hermes/hooks.toml` (`:151`) | a path | S13 ordered pre/post hooks | a missing file → a named absence, not a crash |
| `session-silence-grace` | 0 (`:159`) | Go duration | terminate a gateway tick with no token/tool delta (SCHED-GAP-1707) | 0 disables the guard |
| `session-poll-loop-min-ticks` | 0 (`:170`) | int | terminate a confirmed sleep-poll loop (SCHED-GAP-1698) | 0 disables |
| `disable-tick-push` | false (`:172`) | bool | skip the per-tick git push at exit (SCHED-GAP-1594) | true stops tick push-at-exit |
| `no-exec-fallback` | **true** (`:190`) | bool | disable `exec.Command` fallback when gateway fails | false re-enables the exec fallback |

**Auxiliary / routing / lifecycle flags (name = default; consequence is scoped, not expanded per
row).** Remaining 32 of the 57: `tls-cert`/`tls-key` `""` (`:102-103`, HTTPS pair), `public-url`
`""` (`:107`), `test-verify` `0` (`:174`), `verify-board` `""` (`:175`), `session-reap-threshold`
`DefaultHermesReapStaleAfter` (`:176`), `reap-sessions` false (`:177`), `reap-sessions-apply` false
(`:178`), `session-db` `DefaultHermesSessionDBPath()` (`:179`), `duckbrain-ns` `"scheduler"`,
`duckbrain-url` `http://localhost:3000`, `duckbrain-interval` 5m (`:180-182`), `simulate` false,
`sim-success` 0.85, `sim-idle` 0.0, `sim-count` 0 (`:183-186`), `gateway-url`
`http://127.0.0.1:8642`, `gateway-key` `$API_SERVER_KEY` (`:187-188`), `model-rates-file`
`$SCHEDULER_MODEL_RATES_FILE` (`:189`), `foreman-home` `$HOME/.hermes/foreman` (`:191`),
`sim-setup` false, `sim-ticks` 10 (`:192-193`), `config` `""` (`:194`), `failure-window` 100,
`auto-disable-failure-rate` 0, `auto-disable-window` 100, `auto-disable-min-ticks` 50 (`:195-198`),
`groups-file` `""`, `templates-file` `""` (`:199-200`), plus `log-file`/`show-config`/`schema`/
`version` (after `:200`). These are simulation (`sim-*`), verification (`test-verify`,
`verify-board`), DuckBrain sync, routing/pricing, or auto-disable controls — none is an
admission/execution-settlement control, so their consequence is scoped to their own subsystem. The
57-flag boundary is the quoted grep above; the consequence column is **not expanded per row** for
these, which is a named RED on the register (deepseek #2 / sol B19), not a hidden gap.

**Load correction (F9-3, re-derived this round).** Round-4 claimed the `[daemon]` / `[gateway]` /
`[duckbrain]` root sections are "not loaded until FEAT-005 wires `LoadConfig`". **That is FALSE.**
`config.LoadRootConfig(*configFile)` is called ten times at daemon boot
(`cmd/schedulerd/main.go:640, 673, 762, 854, 870, 968, 995, 1023, 1054, 1309`), and
`internal/config/loader.go` implements the three-layer merge: (1) struct defaults, (2) the TOML
file, (3) `SCHEDULER_*` environment overrides (`applyEnvOverrides`). The only true residue is that
`config.example.toml`'s header NOTE is stale — a board row against the example file, not a
statement about the daemon.

## 6. Contracts in and out

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| M9-C1 | owner | in | **operator config** — `fleet.toml` + `scheduler.db` project rows (lane enabled/cadence/weight/pin); the load path is `config.LoadRootConfig` (`internal/config/loader.go`, called at `main.go:640,673,762,854,870,968,995,1023,1054,1309`) | `internal/scheduler/admission_mode.go:112` `admissionModeForProject` (reads the lane's admission mode from the DB) | **UNVERIFIED** — the consumer is nameable; the producer is operator config, not a function (N5: root config *is* loaded through `LoadRootConfig`; only the example file's NOTE is stale) |
| M9-C2 | crier | out | `internal/bus/dispatch.go:202` `payload()` emits `text_b64` (base64), field **`board`** (not `board_row`) | **node** `scripts/node-bus-worker.py:986` `process` reads `text` (not `text_b64`); **dispatcher** `dispatcher.py:142-150` decodes `text_b64` — the two consumers disagree | **broken** — CF-354: node reads `text`, scheduler sends `text_b64` |
| M9-C3 | crier | in | completion reply | `dispatch_leg.go:713` `dispatchReplyVerdict` reads only `payload["ok"]` | **broken** — CF-355: node sends `status`, scheduler reads `ok` |

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| build | `go build ./...` (scheduler repo) | exit 0 | 2026-11-06, rev `1771d3aa` | **PASS** (rc 0) |
| durable state | `sqlite3 ~/.hermes/coding-hermes/scheduler.db '.tables'` | tables listed | 2026-11-06 | **PASS** — 30 tables; no `verdicts` table |
| go test (clean env) | `env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./...` | green | 2026-11-06, rev `1771d3aa` | **PASS (rc 0)** — all 25 packages ok; `internal/scheduler` ran 158.3s (not cached) and passed |
| go test (three env-sensitive tests) | `env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./internal/scheduler/ -run 'TestSCHEDGAP091_DrainTimeoutStampsOrphan|TestOperatorRestartApprovalEnv|TestAbortInFlightTicks_OperatorApprovedStamp' -count=1` | green | 2026-11-06, rev `1771d3aa` | **PASS (rc 0)** — 0.409s |

**Env-contamination correction (F9-6).** Round-4 reported `go test ./...` FAIL with
`SCHED-GAP-1726 goroutine census: 1 goroutine(s) still parked in evalDrain at suite exit`. That
FAIL is an artifact of the writer's shell carrying the ambient `SCHEDULER_OPERATOR_RESTART_APPROVED=1`
(the var is load-bearing in `internal/scheduler/restart_approval.go` and
`schedgap1608_operator_restart_test.go`, and this shell reports it =1). With the var **unset** the
three operator-restart tests pass in 0.409s and the full suite is green (25/25).

## 8. Metrics

**Measured — real, not RED.** The scheduler serves `GET /api/v1/metrics`
(`internal/api/server_metrics.go`) with blocks `spawns`, `deferrals`, `nudges`, `ticks`,
`tick_duration_ms`, `gateway`, `outcomes`, `stalls`, `escalations`, `lane_churn`,
`dispatch_inbox`, each carrying an `available: true|false` honesty shape and a per-block source in
`metricsSources()` (`:125`). `metricsWindow` is 24h (`:42`). **Semantics (B22, read this round):**
`deferrals` is a per-process SCHED-GAP-155 admission counter, monotonic since daemon boot and
**reset by a restart** (no persisted equivalent) (`:132-136`); `spawns` is read from the `ticks`
table joined to `projects` (`:127-130`). **Locator correction (F9-4):** `metricsSpawns` is the
`func` keyword at `:195`, not `:192` (which is the doc comment).

## 9. Log lines (verbatim)

**Scope, stated (deepseek #1).** This is the settlement/batch-dispatch surface, **not** a full
inventory. The control plane has **379** `log.Printf` call sites
(`grep -rn "log.Printf" internal/scheduler/*.go | wc -l` = 379, measured this round). The two rows
below are the settlement/batch-dispatch lines; the remaining **377** sites are uncovered and are
the named RED on this field — not a "sample" claimed as complete.

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `DISPATCH: %s tick=%s agent=%s corr=%s message=%s transport=%s wall=%s lane_ref=%s board_ref=%s` (`dispatch_leg.go:252`) | a dispatch is issued | evidentiary |
| — | `DISPATCH: <proj> tick=<id> inbox seen=<n> correlated=<n> uncorrelated=<n> keys=<csv> acked=<n> deferred=<n>` (`:456`) | one per retrieve batch | evidentiary |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Silent success | pass for a `status:"failed"` reply | a real pass | **OPEN** — CF-355 (`dispatch_leg.go:713-726`) |
| `text_b64` vs `text` mismatch | node cannot execute the dispatch | a malformed envelope | **OPEN** — CF-354 |
| Deadline expiry | `DispatchStateExpired`, `TickTimeout` (`:291-314`) | a failed reply (`TickFailed`, `:316-325`) | the reply is PARTIAL, named `dispatch_deadline` |
| No authoritative lane inventory | 8 vs 16 vs 1 lanes across three modules | a single census | **OPEN** — CF-335 |
| Env-contaminated test | the operator-restart tests FAIL only when `SCHEDULER_OPERATOR_RESTART_APPROVED=1` is ambient | a code break | unset the var (`env -u … go test`); F9-6 |

## 11. Limits and margins

- The reply await is bounded by the same session deadline the node got as `limits.wall_s`
  (`:255-260`); the wall is printed because it decides both the node's budget and the await.
- `dispatchReplyVerdict`'s documented premise is "absence of a verdict is SUCCESS" (`:709-712`) —
  the exact place a `status` field is ignored.
- **Admission authority (B19, locator re-pinned this round).** `admission_mode.go:143-184`
  `laneOwnsBoard` derives board ownership from the filesystem (workdir containment);
  `boardOwnedByLane` is **defined at `:177`** (doc comment `:173`), honours an explicit
  per-project override (`database.BoardOwnershipOwner`/`Shared`) before falling back to the
  filesystem derivation, and is **called at `:234`** inside `tasksAdmissionDue`. Operator mutation
  auth is in `internal/api/auth.go:187-197` `extractBearerOrHeaderToken` (Bearer or
  `X-Operator-Token` header).

## 12. Cross-references

- F11 SCHEDULING ADMISSION is the primary flow; F1 DISPATCH AND SETTLEMENT is its terminal half.
- M10 CRIER is the transport (M9-C2/C3).
- M2 DISPATCH (node side) and M11 DISPATCHER are the two inbox consumers.
- M4 BOARD rows gate admission (S1); see M4 §12 for the M9-only ownership of that gate.

## 13. Evidence of record

- Code read: `internal/scheduler/dispatch_leg.go` (`:245-364`, `:700-759`), `internal/bus/dispatch.go`
  (`:170-214`), `internal/scheduler/admission_mode.go` (`:98-129, 143-208, 230-267`),
  `internal/scheduler/usage_pool_policy.go:26-63`, `cmd/schedulerd/main.go:95-200`,
  `internal/api/auth.go:187-197`, `internal/api/server.go:289-346`, `internal/api/server_metrics.go:125-136, :195`,
  `config.example.toml` (full), `internal/database/migrations.go` (grep: `:1217-1232, :1391-1489, :1970, :2036`).
- Commands run: `go build ./...` (PASS); `env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./...`
  (PASS, 25/25); the three env-sensitive tests (PASS, 0.409s); `grep -n 'LoadRootConfig' cmd/schedulerd/main.go` (10 sites);
  `grep -rn "log.Printf" internal/scheduler/*.go | wc -l` (379); `grep -cE 'flag\.(String|Int|Int64|Bool|Duration|Float64)' cmd/schedulerd/main.go` (57);
  `sqlite3 … '.tables'` (30 tables).
- Rev re-stamped: `1771d3aa`.
- Board rows: CF-334, CF-335, CF-337, CF-343, CF-346, CF-353, CF-354, CF-355.
- **Findings:**
  - **F9-1** (carried) — settlement exists (`dispatch_leg.go:260-336`); the real defect is CF-355.
  - **F9-2** (carried) — 30 tables, not 26; no `verdicts` table.
  - **F9-3** (corrected) — `LoadRootConfig` IS loaded at boot (`main.go:640,673,762,854,870,968,995,1023,1054,1309`), three-layer merge in `loader.go`. The only residue: `config.example.toml`'s header NOTE is stale.
  - **F9-4** — `metricsSpawns` is at `:195`, not `:192`.
  - **F9-5** (carried) — binary defaults are 30s/10/false (`main.go:108/:112/:113`); the six
    previously-unlocated settings now carry locators (`:122, :128, :138, :142, :143, :145`).
  - **F9-6** (carried) — round-4's `go test ./...` FAIL was env contamination, not a code break; clean-env PASSES (25/25).
  - **F9-7** (new, B16/B17) — the ordered admission procedure and the run-correctness store keys
    are written this round (see §3 note).

## RED field count: 5 (§9 log inventory 2 of 379 sites — the remaining 377 are the named RED, not a "sample"; §3 S1 grep-level (`tick_process`/`packer_select`/`namespace_alloc` not line-by-line); §5 the auxiliary-flag consequence column not expanded per row; S4 per-route contract not written — B18; S3 write authorities/recovery queries not written — B17)
