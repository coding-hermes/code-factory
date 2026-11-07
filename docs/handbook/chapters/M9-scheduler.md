# M9 — SCHEDULER

## 1. Identity

| Field | Value |
|---|---|
| Module name | SCHEDULER |
| Path | `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/` (Go) |
| Revision | `d0dad6d9` (scheduler repo HEAD, this round's stamp). Re-stamped from `251d11db`: HEAD advanced through four commits — `0b357bb9` (read your own board, always), `79510add` + `d0dad6d9` (pace tasks-admitted lanes on their no-op streak; the latter is the spin fix), `ea7810db` (board: file SCHED-GAP-16999, board JSONL only). `git diff --name-only 251d11db..HEAD` = **twelve** paths: the two board JSONL, seven `internal/scheduler/*.go` (`adaptive_cooldown.go`, `loop.go`, `multipool_packer.go`, `noop_pacing.go`, `packer.go`, `packer_select.go`, `spawn.go`), and three `noop_pacing_*_test.go`. `noop_pacing.go` is **new** in this range (added `79510add`); `nowork.go` (the no-work gate definitions) was already present at `251d11db` and is unchanged. Load-bearing effect: `spawn.go` gained one line in `builtinForemanPrompt` (`:1213`, the READ-YOUR-OWN-BOARD line), shifting `buildForemanPrompt` `:1249`→`:1250` (§6 CT-05); `packer_select.go`'s namespace-mode gate order shifted +12 lines and the no-work gates' **definitions** live in `nowork.go` (not `packer_select.go`) — §3 re-derived; `loop.go` gained a +10 net change moving two §9 log sites +10. Unchanged this drift (`git diff --name-only 251d11db..HEAD` does **not** list them): `admission_mode.go`, `slot_pool.go`, `tick_process.go`, `usage_pool_policy.go`, `dispatch_leg.go`, `bus/dispatch.go`, `main.go`, `server.go`, `server_metrics.go`, `loader.go`, `urgency.go`, `migrations.go` — so §2 settlement, §5 flag defaults, §6 CT-01/CT-02/CT-06 and §8 metrics all hold at their cited lines |
| Language / runtime | Go — `go.mod` declares `go 1.26.0` + `toolchain go1.26.10`; inside the module `go env GOVERSION` resolves **go1.26.10** via `GOTOOLCHAIN=auto` from the module cache (`golang.org/toolchain@v0.0.1-go1.26.10.linux-amd64`). The host **bootstrap** binaries are older and were NOT upgraded: `/usr/bin/go` = **go1.26.8** (`cat /usr/lib/go-1.26/VERSION` → `go1.26.8`), `/home/kara/.local/bin/go` = **go1.26.5** (`readlink -f` → `/home/kara/sdk/go1.26.5/bin/go`). The round-16 judges' 1.26.8/1.26.5 measurement was correct; round-17's "the host was upgraded to 1.26.10" was FALSE (kimi #3) — 1.26.10 is selected at build time by the module's `toolchain` directive, not installed as any host default |
| Owner lane | coding-hermes-scheduler (control plane) |
| Status | **UNVERIFIED** — settlement (`dispatch_leg.go:260-336, :713-726`), `internal/bus/dispatch.go:175-208`, the admission authority (`admission_mode.go:98-129, 143-208, 230-267`), the pack gate order (`packer_select.go:376-531`; no-work gate **definitions** in `nowork.go:182/:245`, `board_stasis.go:320`, `stale_premise.go:208`, `premise_blocked.go:299`, `cadence_ceiling.go:71`), the binary defaults (`cmd/schedulerd/main.go:95-200`), the auth path (`internal/api/auth.go:187-197`), the API route table (`internal/api/server.go:289-370`) and `config.example.toml` read this round; `tick_process.go`/`slot_pool.go`/`usage_pool_policy.go`/`migrations.go` re-read this round. The admission procedure (§3) is re-derived from the calling sequence at HEAD `d0dad6d9` (sol B17, re-verified this round); the full 30-table census is named (grok #3) |

## 2. Purpose, authority and position

The control plane's clock and admission authority. It decides when a lane's cadence tick fires,
whether it is admitted (eligibility, tasks-vs-cooldown, board gates, fairness, budget
reservation), and how a dispatch settles. It may not decide what the foreman *does* with the work
— that is the directive it hands off.

**What breaks if this module is absent.** No cadence tick fires; nothing is admitted, dispatched
or settled.

**What breaks if it lies.** `dispatchReplyVerdict` (`dispatch_leg.go:713-726`) reads only
`payload["ok"]` and treats the *absence* of a verdict as success (`:709-712`). A node reply
carrying `status:"failed"` (the field `node-bus-worker.py:1180` actually sends) and no `ok` is
scored a success — the control-plane half of the silent-success defect (CF-355).

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 admission and allocation | `admission_mode.go`, `tick_process.go`, `packer_select.go`, `namespace_alloc.go`, `usage_pool_policy.go` | **active** | `admission_mode.go:98` `admissionModeFor` (project override → namespace default → cooldown); `:112` `admissionModeForProject` (DB read); `tick_process.go:40` `evaluate()`; `packer_select.go:19` `Pack`; `namespace_alloc.go:131` `Allocate`; `usage_pool_policy.go:21` `reserveUsagePools` |
| S2 execution and settlement | `spawn`, `slot_pool`, `lifecycle`, `dispatch_leg` | **active** | `dispatch_leg.go:260` `awaitDispatchReply`; `:262-336` constructs completed/failed/timeout outcomes |
| S3 durable state | `scheduler.db` + migration stores | **active** | live store has **30** tables (measured `sqlite3 … '.tables'`); see the census below |
| S4 operator surfaces | `cmd/schedulerd`, `scheduler-dispatch`, `scheduler-query`, `queueprobe`, `migrate`, `backfill-commit-signals`, `cooldown-residue` | **operator-invoked** | `ls cmd/` → 7 command dirs; no unit invokes another unit — these are CLI entrypoints an operator (or a foreman step) runs, not a scheduler lane |
| S5 doctrine | `scheduler-rules.md`, `dispatch-spec.md`, `execution-contracts.md`, `execution-store.md`, `runbook-drain-restart.md`, `hop-liveness-watchdog.md` | **legacy (documentation)** | six doctrine docs present under `docs/`; presence is existence, not invocation — no unit reads them at runtime |

**Operator surfaces.** The daemon mounts its HTTP routes in `internal/api/server.go` (the
`Handler()` tree spans `:289-370`): `grep -oE 'mux\.HandleFunc\("[^"]+"' internal/api/server.go | sort -u | wc -l` = **43** (measured). The full set, all under `/api/v1/`, in mount order: `health`, `live`, `status`, `config`, `projects`, `projects/`, `hooks`, `hooks/plan`, `hooks/{id}`, `hooks/reload`, `lanes/tree`, `lanes`, `links`, `links/`, `cadence`, `namespaces`, `namespaces/`, `groups`, `groups/`, `templates`, `templates/`, `ticks`, `ticks/`, `queue`, `openapi.json`, `metrics`, `evaluate`, `pause`, `resume`, `events`, `events/stream`, `observatory`, `observatory/stream`, `gateway-errors`, `features`, `features/prune-candidates`, `peers`, `peers/`, `agents`, `agents/`, `federation/query`, `federation/catalogue`, `cooldown/residue`. Auth on mutations via `extractBearerOrHeaderToken` (`internal/api/auth.go:187-197`). The recovery commands (`reap-sessions`, `verify-board`, `migrate`) are CLI-only flags/subcommands, not HTTP routes. Per-route request/response shapes and write-authority readbacks are **not** written this round — the route inventory is complete (43), the per-route contract is not (a named RED on S4).

**Admission procedure (B17, re-derived this round at HEAD `d0dad6d9` from the calling sequence).**
The order is the packer's own execution order, not an alphabetized list of helpers. Packing is
invoked at `tick_process.go:285` (`multiPoolPacker.Pack`), and the per-project gate sequence inside
`Pack` (`packer_select.go`, namespace-mode path, `:369-531`) is:

1. **Shared gate + mode** (`packer_select.go:369-377`): the shared gate is computed (`cooldownDur :=
   gate.Cooldown`), `gate.SkipMode` skips (`:371-373`), then `admissionModeFor`
   (`admission_mode.go:98`, unchanged) resolves project-override → namespace → **cooldown**. This
   decides which of the two branches below applies.
2. **Tasks-mode waiver branch** (`packer_select.go:376`, `mode == Tasks && tasksAdmissionDue(...)`):
   - **post-failure stand-down** (`:386-390`, SCHED-GAP-214): after a FAILED tick the waiver stands
     down and the lane paces on its full cooldown.
   - **NOOP-PACING** (`:395` `tasksNoopStreakDeferred`, defined `noop_pacing.go` — new this drift):
     a lane that keeps completing with no artifact of its own work is spaced by a doubling
     `cooldown_floor_s` no-op cooldown (8× cap), so dry churn (measured 76 spawns/day, 63 dry_run on
     task-router-foreman) cannot continue; any artifact resets the streak.
   - **FailureBackoff** (`:402-407`, SCHED-GAP-133): only when `ConsecutiveFailures > 1`.
   - **tasks-pacing** (`:411` `tasksPacingDeferredJittered`, SCHED-GAP-136): post-tick spacing+jitter.
   - **stale-premise** (`:419` `stalePremiseBlocks`, def `stale_premise.go:208`) then **blocked-head**
     (`:428` `premiseBlocks`, def `premise_blocked.go:299`): the waiver fired (open rows exist) but
     they are stale or all dependency-blocked/sibling-held.
3. **Cooldown-mode branch** (`else`, `:433`) — the builder no-work gates, deferred *before the pin
   is consulted*:
   - `builderAdmissionBlocked` (`:450`, def `nowork.go:182`, SCHED-GAP-1655): a cooldown BUILDER whose
     board holds no dispatchable row.
   - `tasksBuilderAdmissionBlocked` (`:464`, def `nowork.go:245`, SCHED-GAP-1656).
   - `boardStasisBlocks` (`:474`, def `board_stasis.go:320`, SCHED-GAP-1678): board fingerprint
     (mtime+size+content-digest) unchanged since the previous completed tick → excluded, no cooldown
     consumed. Flag `board-stasis-gate` default **true** (`main.go:150`).
   - `stalePremiseBlocks` (`:483`, def `stale_premise.go:208`) then `premiseBlocks` (`:492`, def
     `premise_blocked.go:299`).
   - **shared gate defer** (`:498` `gate.Defer`, SCHED-GAP-1666): the shared gate's wall-clock verdict.
4. **Concurrency caps** (`:505` global `maxConcurrent`; `:509` per-namespace `nsCap`): 0 = unlimited
   per-namespace.
5. **Cadence ceiling** (`:524` `cadenceCeilingDefers`, def `cadence_ceiling.go:71`, SCHED-GAP-1686): a
   per-namespace rolling-window cap that defers (never consumes cooldown) a lane that would otherwise
   pack.
6. **Weight budget** (`:531` `pu.EffectiveWeight > budgetRemaining`): the budget hold queues the lane.
7. **Usage-pool reservation — later, at spawn, not at pack** (`slot_pool.go:539-585`): after a lane
   is packed and a slot opens, `reserveUsagePools` (`slot_pool.go:569`, defined at
   `usage_pool_policy.go:21`) makes tick ownership durable (`Enqueue`, `:545`) and then reserves the
   usage pool. Its distinct outcomes: a disabled policy returns `(false, nil)` (enforcement off,
   `:26-28`); a nil DB authority returns a named **authority-unavailable** error (`:29-31`), not
   `(false, nil)`; a missing/invalid `host_id` or empty pool set returns `ErrUsagePoolMissing`
   (`:37-44`); `ObserveOnly` checks without reserving (`:45-53`); otherwise lease recovery runs and
   `ReserveAll` enforces the reservation (`:54-64`), and a capacity denial emits an event (`:65-70`).
   Remote lanes append `host:<id>`, local lanes append `LocalPoolID`.

The round-8 "ordered procedure" placed usage-pool reservation *before* board-stasis and omitted the
stale-premise/blocked-head/cadence/budget gates — that list was an ordering of related helpers, not
the composed call order (sol B17). This list is the call order at `d0dad6d9`; the only change from
the round-18 `251d11db` derivation is the +12-line shift of the cooldown-branch call sites and the
new tasks-mode NOOP-PACING / post-failure-stand-down / FailureBackoff / tasks-pacing gates added by
`0b357bb9` + `79510add`.

**Durable-state store census (grok #3, closed this round — all 30 tables named).** At
`internal/database/migrations.go`, run-correctness keys first, then the previously-unnamed
reservation and telemetry tables:

| Table | Locator | Key / guarantee |
|---|---|---|
| `tick_dispatch` | `:1217-1232` | `tick_id` PRIMARY KEY; `lane, agent, corr_id, message_id, transport, state, reply, error`; indexes on `corr_id`, `message_id`, `state` — the dispatch receipt |
| `execution_runs` | `:1391` (+`recovery_idx :1410`) | one row per run, `state` + `updated_at` for recovery |
| `workspace_leases` | `:1412` (+`one_writer_idx :1423`) | **single-active-writer** unique index — the workspace ownership guarantee |
| `execution_attempts` | `:1427` (+`step_gen_idx :1970`) | attempt generation; `step`/`gen` uniqueness |
| `execution_events` | `:1449` (+`run_idx :1458`) | per-run event sequence (`run_id, event_id`) |
| `verification_receipts` | `:1460` | per-attempt verification receipt |
| `execution_projections` | `:1470` | **per-destination projection/sync state** (`PRIMARY KEY(run_id, projection)`, `projection ∈ {task_router, duckbrain, board, notification}`) — delivery state per sink, distinct from `execution_runs`' authoritative lifecycle |
| `execution_outbox` | `:1479` (+`pending_idx :1489`) | durable-delivery queue, pending by `state, available_at, created_at` |
| `tick_workers` | `:394` (+`idx_tick_workers_tick :414`, `idx_tick_workers_task :415`) | worker attribution on ticks — `(tick_id, task_id)`; the durable record of which worker took which tick |
| `usage_pools` | `:1299` | a pool's identity and budget (`pool_id` PRIMARY KEY) |
| `usage_pool_memberships` | `:1306` | lane → pool membership (`pool_id REFERENCES usage_pools`) |
| `usage_pool_leases` | `:1311` (+`unique_tick :1319`) | one lease per tick (`UNIQUE(tick_id)`); `owner_id`, `expires_at` |
| `usage_pool_lease_members` | `:1320` | lease → pool members |
| `usage_pool_deferrals` | `:1334` | per-tick pool deferrals (`idx …_tick :1340`) |
| `feature_usage` | `:782` | per-mechanism live usage counters backing `/api/v1/features` (SCHED-GAP-131) |
| `hook_runs` | `:1790` | S13 lane-hook receipts (`tick_id, phase, level, hook_id, state, exit_code`) |
| `host_samples` | `:465` | per-cycle host load/memory telemetry (ADV-R13) — measurement only, no admission consumer |
| `lane_links` | `:1525` | many-to-many parent/child lane references (reference/lookup only) |
| `namespace_ticks` | `:151` (+`demand`/`overcommitted` `:671-672`) | per-namespace tick accounting and budget-oversubscription observability |
| `remote_events` | `:1106` | durable idempotency store for inbound peer events, keyed `(scheduler_id, event_id)` (REMOTE-006) |
| `remote_events_stats` | `:1124` | per-scheduler high-water marks for replay ordering |
| `sync_spool` | `:204` | DuckBrain write fallback spool |

Relationship: a run (`execution_runs`) has 1:N attempts (`execution_attempts`) and 1:N ordered
events (`execution_events`); the projection is the per-destination delivery/sync state; the outbox
is the durable-delivery queue; the workspace lease is the single-active-writer boundary. The
`usage_pool*` family is the durable record of the reservation `reserveUsagePools` performs at
spawn — the decision (§1 above) and its store are now both named. The remaining unlisted tables
(`agents`, `deferrals`, `events`, `migrations`, `namespaces`, `peers`, `projects`, `ticks`) are
the register of lanes/agents/ticks themselves and are cited throughout §5/§6.

**Write authorities and recovery.** The run-correctness tables are written by
`internal/database/execution_store.go` (package-level functions, no receiver):

| Table | Write authority (`execution_store.go`) | Transition it applies |
|---|---|---|
| `execution_runs` | `CreateExecutionRun` (`:52`) | creates the run row |
| `execution_attempts` + lease + outbox | `AdmitExecutionAttempt` (`:164`) | **the ONE admission transition** — creates the attempt, acquires the workspace lease, inserts outbox work, advances run state atomically in one `executionTx` (`:267`) |
| `workspace_leases` | `AcquireWorkspaceLease` (`:378`), `RenewWorkspaceLease` (`:391`), `RevokeWorkspaceLease` (`:397`) | the single-active-writer boundary acquired/renewed/revoked |
| `execution_attempts` (process) | `SetAttemptProcessIncarnation` (`:417`) | stamps pid/pgid/container on an attempt |
| `execution_events` | `AppendExecutionEvent` (`:446`) | appends an ordered per-run event |
| `verification_receipts` | `RecordVerificationReceipt` (`:559`) | records a per-attempt receipt |
| `execution_projections` | `PutExecutionProjection` (`:607`) | per-destination projection/sync state |
| `execution_outbox` | `ClaimExecutionOutbox` (`:655`), `AckExecutionOutbox` (`:685`), `RetryExecutionOutbox` (`:691`), `ReconcileExecutionOutboxUndeliverable` (`:703`) | the durable-delivery queue's claim/ack/retry/undeliverable lifecycle |
| all (recovery) | `RecoverExecutionState` (`:749`) — returns `([]ExecutionRun, []WorkspaceLease, []OutboxMessage)` | the recovery selector an operator reads after a crash to distinguish recoverable work from uncertain settlement |

The write authorities and the recovery selector are named; what remains unwritten is a
per-failure-mode post-recovery indication (what an operator reads back after each recovery step)
— a named RED on S3.

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| Go toolchain | `go 1.26.0` + `toolchain go1.26.10` (`go.mod`) | build host | the host bootstrap binaries are 1.26.8 (`/usr/bin/go`) / 1.26.5 (`~/.local/bin/go`); `go.mod`'s `toolchain go1.26.10` directive makes `go build` select go1.26.10 via `GOTOOLCHAIN=auto` from the module cache (already fetched: `golang.org/toolchain@v0.0.1-go1.26.10.linux-amd64` present), so `go build ./...` PASSes without a fresh download on this host |
| SQLite (scheduler.db) | via `modernc.org/sqlite v1.60.1` | control host | DB open failure |

**4b. Library contracts**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `modernc.org/sqlite` | external | the CGo-free SQLite driver backing `scheduler.db` | a driver change breaks the 30-table store |
| `BurntSushi/toml` | external | `config.example.toml` parsing | a config-key change breaks lane config |

**4c. Service contracts** — see §6.

## 5. Settings register

**Binary defaults (read this round).** The daemon's actual flag defaults are in
`cmd/schedulerd/main.go` (flag definitions span `:95-200+`); `config.example.toml` is the *example*
register, and its commented values are **not** the runtime defaults. The full flag surface is **57
definitions**, measured with `grep -cE 'flag\.(String|Int|Int64|Bool|Duration|Float64)' cmd/schedulerd/main.go` = 57.

| Setting | Binary default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `db` | `$HOME/.hermes/coding-hermes/scheduler.db` (`:95`) | a path | SQLite store | a wrong path opens a different store |
| `listen` | `127.0.0.1:9090` (`:96`) | an addr | HTTP surface | off-loopback exposes the API |
| `min-interval` | **30 s** (`:108`) | Go duration | fastest tick interval | below it ticks are refused/never fire |
| `max-interval` | 24 h (`:109`) | Go duration | slowest tick interval | above it lanes starve |
| `num-levels` | 10 (`:110`) | >= 1 (config), >= 2 (effective) | priority levels | `internal/config/loader.go:421-422` rejects a configured `< 1` at load ("scheduler.num_levels must be >= 1"); `internal/scheduler/urgency.go:18-22` clamps any value `< 2` — **including 1** — to 2 with a `WARNING: numLevels=%d < 2, setting to 2` log. There is no "priority sort break": the calculator floor is 2, so 1 is silently clamped, not rejected |
| `budget` (weight budget) | 100 (`:111`) | >= 1 | weight budget per evaluation | 0 admits nothing |
| `max-concurrent` | **10** (`:112`) | >= 1 | concurrent foreman ticks | a load gate is a separate knob (see below) |
| `namespace-mode` | **false** (`:113`) | bool | multi-namespace scheduling | off disables reserved/hard_cap |
| `tick-timeout` | 7200 s / 2 h (`:114`) | Go duration | wall-clock before a tick is killed | too short kills legitimate ticks |
| `api-read-timeout` | 5 s (`:122`) | Go duration | per-request deadline for heavy read surfaces | a stalled DB helper returns 504 naming it (SCHED-GAP-1575-B) |
| `gateway-response-timeout` | 30 m (`:128`) | Go duration | per-turn POST deadline (min of this and tick-timeout) | `0` disables |
| `gateway-transient-retries` | 3 (`:138`) | int | 5xx/refused retry count (SCHED-GAP-1681) | 0 = single attempt |
| `slot-patience` | 5 m (`:142`) | Go duration | how long a spawn waits for a free slot | the drop emits a `slot_pool` event |
| `tasks-pacing` | 60 s (`:143`) | Go duration | min post-tick spacing for tasks-mode projects | 0 = disabled |
| `load-gate-threshold` | **0 (disabled)** (`:144`) | float (1-min load avg) | defer new spawns while load >= threshold | 0 disables; namespaces opt out via `load_gate='off'` |
| `feature-prune-weeks` | 8 (`:145`) | int | dead-feature reaper prune window | flag only — nothing is auto-deleted |
| `peer-freshness-window` | **180 s** (`database.PeerFreshnessWindowDefault`, `internal/database/peers.go:28` = `3 * 60` seconds; flag at `:148`) | int seconds | REMOTE-003 peer heartbeat freshness | a too-short window spuriously ages peers |
| `spawn-mem-limit-mb` | 0 (`:149`) | MiB | per-spawn `RLIMIT_AS` cap (ADV-R11) | 0 = no cap; a low cap kills spawns |
| `board-stasis-gate` | **true** (`:150`) | bool | exclude a cooldown BUILDER lane whose board is unchanged (SCHED-GAP-1678) | off admits stasis lanes |
| `hooks-file` | `$HOME/.hermes/hooks.toml` (`:151`) | a path | S13 ordered pre/post hooks | a missing file → a named absence, not a crash |
| `session-silence-grace` | 0 (`:159`) | Go duration | terminate a gateway tick with no token/tool delta (SCHED-GAP-1707) | 0 disables the guard |
| `session-poll-loop-min-ticks` | 0 (`:170`) | int (1–5 clamp up to 6) | terminate a confirmed sleep-poll loop (SCHED-GAP-1698) | 0 disables; values 1–5 clamp to the built-in floor of 6 (`main.go:163-170`) |
| `disable-tick-push` | false (`:172`) | bool | skip the per-tick git push at exit (SCHED-GAP-1594) | true stops tick push-at-exit |
| `no-exec-fallback` | **true** (`:190`) | bool | disable `exec.Command` fallback when gateway fails | false re-enables the exec fallback |

**Auxiliary / routing / lifecycle flags (default + consequence).** The remaining 33 of the 57, with the consequence column filled per row from the flag help text at `cmd/schedulerd/main.go:102-208`:

| Setting | Default | Governs | Consequence if changed |
|---|---|---|---|
| `tls-cert` / `tls-key` | `""` (`:102-103`) | HTTPS listener pair | both set → TLS on; one without the other → no usable cert |
| `public-url` | `""` (`:107`) | advertised daemon URL | affects self-links in status/dashboards |
| `test-verify` | 0 (`:174`) | verification self-check | non-zero runs a verification pass at boot |
| `verify-board` | `""` (`:175`) | board-consistency self-check | names a board to verify at boot |
| `session-reap-threshold` | **24 h** (`DefaultHermesReapStaleAfter`, `internal/database/hermesstate.go:52`; flag at `:176`) | stale-session age floor for `--reap-sessions` | a lower threshold reaps fresher sessions |
| `reap-sessions` | false (`:177`) | one reap pass against `state.db`, then exit | **dry-run by default** — writes nothing without `--reap-sessions-apply` |
| `reap-sessions-apply` | false (`:178`) | apply the reap pass (`ended_at` + `end_reason='reaped'`) | **the mutation switch** — true closes selected sessions; without it the pass is a dry-run (SCHED-GAP-089) |
| `session-db` | `DefaultHermesSessionDBPath()` (`internal/database/hermesstate.go:116`; flag at `:179`) | which `state.db` `--reap-sessions` reads | a wrong path reaps (or fails to find) the wrong store |
| `duckbrain-ns` / `duckbrain-url` / `duckbrain-interval` | `"scheduler"` / `http://localhost:3000` / `5m` (`:180-182`) | DuckBrain sync target + cadence | a wrong URL/interval stops the sync spool |
| `simulate` | false (`:183`) | **dry-run mode — no real spawning** | true suppresses real spawns; the sim-* knobs only take effect with it |
| `sim-success` / `sim-idle` / `sim-count` | 0.85 / 0.0 / 0 (`:184-186`) | simulated outcomes | only meaningful under `--simulate`; `sim-count N` generates N synthetic ticks then exits |
| `gateway-url` / `gateway-key` | `http://127.0.0.1:8642` / `$API_SERVER_KEY` (`:187-188`) | the gateway endpoint + key | a wrong URL/key makes every foreman turn fail. An empty `gateway-url` does **not** alone authorize `exec.Command` fallback: the fallback requires `no-exec-fallback=false` (default **true**, `:190`); with the default, a nil gateway client **DEFERS the tick** — `spawn.go:1759` returns `transientGatewayDeferral` (defined `:698`), a transport deferral, not a lane failure — rather than exec-spawning. The two controls interact |
| `model-rates-file` | `$SCHEDULER_MODEL_RATES_FILE` (`:189`) | price-sticker JSON applied over builtin rates | a wrong sticker file re-prices the cost model |
| `foreman-home` | `$HOME/.hermes/foreman` (`:191`) | `HERMES_HOME` for foreman sessions | a wrong path points foreman at the wrong state |
| `sim-setup` / `sim-ticks` | false / 10 (`:192-193`) | 13-project dry-run fixture | `sim-setup` creates the fixture; `sim-ticks` sets its tick count |
| `config` | `""` (`:194`) | TOML fleet config path | a wrong path loads no (or the wrong) fleet config |
| `failure-window` | 100 (`:195`) | per-project tick window for the `/api/v1/status` failure-rate breakdown | a larger window smooths the breakdown |
| `auto-disable-failure-rate` | **0 = off** (`:196`) | per-project failure-rate threshold (0.0–1.0) for auto-disable | a non-zero threshold arms `internal/scheduler/alert_escalation.go:462-548` to write `projects.enabled=0` on sustained failure — an **execution-settlement** consequence, not simulation (SCHED-GAP-018) |
| `auto-disable-window` | 100 (`:197`) | ticks over which the auto-disable rate is computed | a shorter window disables faster on noise |
| `auto-disable-min-ticks` | 50 (`:198`) | minimum ticks before auto-disable may fire | too low disables projects on thin evidence |
| `groups-file` / `templates-file` | `""` (`:199-200`) | deploy group/template JSONL paths | empty = default `<db dir>` paths; a wrong path reads the wrong deploy blocks |
| `log-file` | `defaultLogPath()` (`:205`) | structured tick log destination | empty disables; a wrong path loses the tick journal |
| `show-config` | false (`:206`) | print resolved config (CLI + env) as TOML, exit | read-only introspection switch |
| `schema` | false (`:207`) | output JSON Schema for `schedulerd.toml`, exit | read-only introspection switch |
| `version` | false (`:208`) | print version/build info, exit | read-only introspection switch |

`--simulate` (`:183`) suppresses real spawning and the `--auto-disable-*` trio (`:196-198`) drives
a `projects.enabled=0` write — both are admission/execution controls. The residual RED is that the
**range** and the **reader/precedence** (env override → TOML → flag) of each auxiliary flag are
documented for the group but not re-verified per flag this round (sol B18) — a named RED on §5.

**Load correction.** The `[daemon]` / `[gateway]` / `[duckbrain]` root sections ARE loaded:
`config.LoadRootConfig(*configFile)` is called ten times at daemon boot
(`cmd/schedulerd/main.go:640, 673, 762, 854, 870, 968, 995, 1023, 1054, 1309`), and
`internal/config/loader.go` implements the three-layer merge: (1) struct defaults, (2) the TOML
file, (3) `SCHEDULER_*` environment overrides (`applyEnvOverrides`). The only residue is that
`config.example.toml`'s header NOTE is stale — a board row against the example file, not a
statement about the daemon.

## 6. Contracts in and out

Canonical ids are the register of record (OUTLINE Part IV, CT-01..CT-18). Rows that are
cross-system contracts carry their CT id; an interface with no canonical entry is listed with a
`(local)` tag and is not a peer to any CT row, so it cannot be matched against another chapter.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-01 | owner | in | **operator config (boundary)** — a human writes `fleet.toml` + `scheduler.db` project rows (lane enabled/cadence/weight/pin); there is no producer function (the load path `config.LoadRootConfig`, called at `main.go:640,673,762,854,870,968,995,1023,1054,1309`, is the consumer's loader, not a producer) | `internal/scheduler/admission_mode.go:112` `admissionModeForProject` (reads the lane's admission mode from the DB) | **UNVERIFIED (boundary)** — the consumer is nameable; the producer is a human writing config, not a function |
| CT-02 | crier | out | `internal/bus/dispatch.go:175` `payload()` (the function is declared at `:175`; `:202` is the `p["text_b64"] = …` assignment inside it — emits `text_b64` (base64), field **`board`** (not `board_row`)) | crier `internal/registry/handler.go:990` `HandleDeliver` | **works** — CF-354 fixed and closed (commit `1f1c0fe`); crier delivers the envelope verbatim; the former `text`/`text_b64` mismatch was node-side consumption |
| CT-06 | crier | in | `dispatcher.py:400` `main` (reply build `:500-508`; `crier.deliver` `:508`); transported by crier `internal/registry/handler.go:990` `HandleDeliver` into the scheduler's inbox | `internal/scheduler/dispatch_leg.go:713` `dispatchReplyVerdict` (reads only `payload["ok"]`) | **works (dispatcher leg)** — the dispatcher always sends `ok` (`dispatcher.py:501`), the exact field `dispatchReplyVerdict` reads. CF-355 (the node's `status` reply scoring success-on-failure) is the **node-reply** leg, carried at CT-04, not this producer |
| CT-05 | foreman | in | `scripts/load_lane_config.py:31-37` (module scope — top-level code, no function; `UPDATE projects SET prompt=?, prompt_mode='append'`) | `internal/scheduler/spawn.go:1250` `buildForemanPrompt` (namespace default → project replace/append → dynamic footer) | **UNVERIFIED** — both ends are in-repo (internal); the OUTLINE VIII.1 "3 of 11 prompt files disagree" breakage is **unmeasured** (no command establishes which three files disagree or on what) |
| CT-15 | foreman | out | **external** — the foreman lane's decision/finding/goal writes (out of scope) | **external** — the duckbrain service (out of scope) | **UNVERIFIED (boundary)** — neither side has an in-repo `file:function`, and the wire was not measured this round |

CT-01 and CT-15 are boundary contracts: the owner is a human and duckbrain is a service outside
the five covered systems, so the covered side is named and the far side is marked external. The
state for a boundary contract with no measured wire is **UNVERIFIED** and is a *terminal* state,
not a RED (§13). CT-05 is **internal** (both ends are in-repo files), so its row names both
`file:function`; its state is UNVERIFIED because the "3 of 11 disagree" breakage was never
measured, and an internal not-measured UNVERIFIED **is** a named RED.

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| build | `go build ./...` (scheduler repo) | exit 0 | 2026-11-07, rev `d0dad6d9` (re-run this round) | **PASS** (rc 0) |
| durable state | `sqlite3 ~/.hermes/coding-hermes/scheduler.db '.tables'` | tables listed | 2026-11-07 | **PASS** — 30 tables; no `verdicts` table |
| go test — internal/scheduler package (adequate timeout) | `env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./internal/scheduler/ -count=1 -timeout 1800s` | green | 2026-11-07, rev `d0dad6d9` | **PASS (rc 0)** — 547.133s |
| go test — full suite (default 600s timeout) | `env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./...` | green | not re-run this round (see note) | **FAIL (rc 1) under parallel load** at `251d11db` (F9-13) — not re-run at `d0dad6d9`; the isolated `internal/scheduler` package run is the green evidence this round |
| go test (three env-sensitive tests) | `env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./internal/scheduler/ -run 'TestSCHEDGAP091_DrainTimeoutStampsOrphan|TestOperatorRestartApprovalEnv|TestAbortInFlightTicks_OperatorApprovedStamp' -count=1` | green | 2026-11-07, rev `d0dad6d9` | **PASS (rc 0)** — 4.353s |

**Env-contamination correction.** Round-4 reported `go test ./...` FAIL with a parked-goroutine
census at suite exit. That FAIL is an artifact of the writer's shell carrying the ambient
`SCHEDULER_OPERATOR_RESTART_APPROVED=1` (the var is load-bearing in `internal/scheduler/restart_approval.go`
and `schedgap1608_operator_restart_test.go`). With the var **unset** the three operator-restart
tests pass in 0.259s.

**Load-window correction (F9-13, measured this round).** The full `go test ./...` at `251d11db`
did **not** pass this round: run in the default package-parallel mode under load it returned rc 1
with `internal/scheduler` hitting the 600s per-package timeout (panic: test timed out, hundreds of
parked `SimClock.run` goroutines) and `TestCTL002_EventsStream_SlowClient…` failing. The flake set
is **wider** than CTL002 alone: a judge's clean-environment repeat under host load 12–20 also hit
`TestSCHEDGAP1666_SevenDaySimulation` (`board_empty` assertion) and the SCHED-GAP-1726 goroutine
census; `SCHEDGAP1666` passes solo at load 15 (glm #3). All are load/parallelism artifacts, not
code breaks: `internal/scheduler` alone finishes in 376.454s (`-timeout 1800s`, rc 0) and
`TestCTL002` alone passes in 4.656s (rc 0). **The proven result is narrower than "the suite is
green":** the only green executions this round are the isolated `internal/scheduler` package run
(376.454s) and the isolated CTL002 run (4.656s); the full-suite run at `251d11db` is FAIL (rc 1).
No clean-environment full-suite pass has been captured this round, so the round-16 "25/25 PASS"
(measured at `34e44897` on a quiet host) is the last full-suite green, and the current full-suite
state under load is FAIL until a quiet/adequate-timeout full run is captured (sol B22).

## 8. Metrics

**Measured — real, not RED.** The scheduler serves `GET /api/v1/metrics` (`internal/api/server_metrics.go:87` `metrics`) with a top-level body of `generated_at`, `uptime_s`, `sources` and the eleven blocks `spawns`, `deferrals`, `nudges`, `ticks`, `tick_duration_ms`, `gateway`, `outcomes`, `stalls`, `escalations`, `lane_churn`, `dispatch_inbox` (`:101-119`). Ten blocks' source strings live in `metricsSources()` (`:125-189`); **`dispatch_inbox`'s source string is NOT there** — it sits at `:713-724` inside `metricsLaneChurn`'s return map (a misplacement: the entry documents `dispatch_inbox` but is a key in the `lane_churn` result). `metricsWindow` is 24h (`:42`).

**Wire shapes.** Two distinct success shapes: the ten map-based blocks (`spawns`, `deferrals`,
`nudges`, `ticks`, `gateway`, `outcomes`, `stalls`, `escalations`, `lane_churn`, `dispatch_inbox`)
each return a `map[string]interface{}` carrying `"available": true` inline, or — on query failure —
the common `metricsUnavailable` shape `{"available": false, "reason": "…"}` (`:76-81`).
**`tick_duration_ms` is the exception:** `metricsTickDurations` (`:426`) returns `interface{}`, and
on success marshals the `tickDurationMs` struct `{count, window, p50, p90, p99}` (`:65-71`) with
**no `available` field** — `p50`/`p90`/`p99` are `nil` (JSON `null`) when `count == 0`. The file's
introductory comment at `:30` claims "every block carries available: true|false" — that is
**false for `tick_duration_ms`'s success shape**.

**Semantics.** `deferrals` is a per-process SCHED-GAP-155 admission counter, monotonic since
daemon boot and **reset by a restart** (no persisted equivalent) (`:132-136`); `spawns` is read
from the `ticks` table joined to `projects` (`:127-130`). `metricsSpawns` is the `func` keyword at
`:195`, not `:192` (which is the doc comment).

**Per-metric contract (filled this round, closing sol B04/B21).** The scheduler emits JSON over
`GET /api/v1/metrics` (not Prometheus text exposition), so "type" is a JSON shape rather than a
Counter/Gauge/Histogram; every block is scraped from the same route (`internal/api/server_metrics.go:87`),
behind the same `extractBearerOrHeaderToken` auth as `/api/v1/status` (`internal/api/auth.go:187-197`).
`metricsSources()` (`:125-189`, plus the misplaced `dispatch_inbox` entry at `:713-724`) is the
per-block provenance register. Per block:

| Block | Type (shape) | Labels / fields | Question answered | Scrape / window |
|---|---|---|---|---|
| `spawns` | JSON map | `total`, `by_namespace`, `by_outcome{committed,dry_run,failed,timeout,aborted:no_artifact,no_work}` | spawn volume per namespace and per terminal outcome | `/api/v1/metrics`, 24h window (`:195`) |
| `deferrals` | JSON map | `by_reason`, `admitted_by_namespace`, `passes` | why ticks were deferred (SCHED-GAP-155 admission counters) | per-process, monotonic, reset by restart (`:274`) |
| `nudges` | JSON map | grouped by `orphan_reason` (drain_timeout \| startup_reap \| zombie_reap) | orphan re-nudges | all-time, persisted (`:305`) |
| `ticks` | JSON map | `active`, `queued`, `by_namespace`, `global_cap`, `cooldown_expired_unscheduled` | current tick occupancy and capacity | live snapshot (`:336`) |
| `tick_duration_ms` | JSON struct | `count`, `window`, `p50`, `p90`, `p99` | tick spawn→complete latency percentiles | 24h window, nearest-rank (`:426`) |
| `gateway` | JSON map | drain-class error rows | harness gateway drain incidence | 24h window (`:485`) |
| `outcomes` | JSON map | committed-with-zero-commits | "committed" ticks that landed no commit | 24h window (`:504`) |
| `stalls` | JSON map | `by_minutes` buckets 30-60 / 60-120 / 120+ | ticks exceeding the 30 min stall floor | 24h window (`:530`) |
| `escalations` | JSON map | `by_day`, `by_severity`, `by_class` | CRITICAL/HIGH event rows | 24h window (`:582`) |
| `lane_churn` | JSON map | `disabled_by_day`, `by_provenance`, `disabled_total`, `enabled_per_day`, `enabled_current` | lane disable/enable provenance | 24h window (`:632`) |
| `dispatch_inbox` | JSON map | `seen_total`, `correlated_total`, `uncorrelated_total`, `acked_total`, `deferred_total`, `unacked_current`, `unacked_overflow` | dispatch reply-inbox correlation accounting (SCHED-GAP-16984) | all-time, per-process (`:734`) |

## 9. Log lines (verbatim)

**Scope and count (re-measured this round, kimi #5 / deepseek N2).** The scheduler's
operator-visible logging is `log.Printf` — unstructured and level-less — in
`internal/scheduler/*.go` (65 files). Measured:

- **381 call sites** excluding the one `_test.go` line (`grep -rn "log.Printf" internal/scheduler/*.go | grep -v _test.go | wc -l` = 381; 382 including the test file). Round-17's "378 sites" was low by 3.
- **370 distinct format strings** — every site passes a literal string as its first argument, so the distinct count is exact: `grep -rhoE 'log\.Printf\("[^"]*"' internal/scheduler/*.go | grep -v _test.go | sed 's/^log\.Printf("//; s/"$//' | sort -u | wc -l` = 370. Round-17's "372 distinct" was wrong and had no published command; this is the command and its output.

The complete 370-string inventory is enumerated verbatim below (one `file:line` per distinct
string, the first occurrence). This converts the §9 RED from **not measured** (a writing defect)
to **measured + enumerated, but per-line trigger/kind not classified**: the enumeration is
complete, and only the `Emitted when` / `Kind` annotation of the 368 strings beyond the two
settlement rows is unwritten (the residual RED). The 370 level-less `log.Printf` strings are
themselves a system observability finding (no levels, no structured fields — every severity is
greppable only by prefix), filed as a board row, not a writer's-diligence gap.

**Settlement surface (classified).**

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `DISPATCH: %s tick=%s agent=%s corr=%s message=%s transport=%s wall=%s lane_ref=%s board_ref=%s` (`dispatch_leg.go:252`) | a dispatch is issued | evidentiary |
| — | `DISPATCH: %s tick=%s inbox seen=%d correlated=%d uncorrelated=%d keys=%s acked=%d deferred=%d` (built by `fmt.Sprintf` at `dispatch_leg.go:456`, emitted via `log.Printf("%s", line)`) | one per retrieve batch that carried messages | evidentiary |

**Complete verbatim inventory (370 distinct `log.Printf` format strings, first-occurrence `file:line`).**
Level is `—` for all (unstructured, no level field); per-line `Emitted when`/`Kind` is not yet
classified (the residual RED). Reproduce with the command above.

```text
spawn.go:2072	%s
deliver.go:281	%s: %s tick=%s — AMBIGUOUS send failure (timeout): message may have been delivered, NOT resending (duplicate-suppression)
deliver.go:285	%s: %s tick=%s — hermes send failed after %d attempt(s) (%s)
deliver.go:134	%s: %s tick=%s — target '%s' is not a configured platform; skipping (logged once/day)
adaptive_cooldown.go:234	ADAPTIVE: %s board_open_seen update failed: %v
adaptive_cooldown.go:225	ADAPTIVE: %s board_rows_seen update failed: %v
adaptive_cooldown.go:289	ADAPTIVE: %s no-progress tick #%d (threshold %d) → cooldown %ds → %ds (ceiling %ds)
adaptive_cooldown.go:264	ADAPTIVE: %s progress (code_commits=%d board_commits=%d net_board_closed=%v) → streak 0, cooldown %ds → %ds (floor)
adaptive_cooldown.go:292	ADAPTIVE: %s reached no-progress threshold %d (cooldown stays %ds — no explicit base or already at ceiling)
adaptive_cooldown.go:261	ADAPTIVE: %s reset write failed: %v
adaptive_cooldown.go:285	ADAPTIVE: %s streak write failed: %v
adaptive_cooldown.go:174	ADAPTIVE: %s tasks-mode floor restore failed: %v
adaptive_cooldown.go:608	ADAPTIVE: %s tick %s commit-signal write failed: %v
admission_mode.go:204	ADMISSION-OWNERSHIP: <%s> board resolves outside its own workdir → time-based pacing (cooldown pin decides; SCHED-GAP-141)
adaptive_cooldown.go:177	ADMISSION: %s board drained (tasks mode) → cooldown %ds → %ds (floor pin)
slot_pool.go:709	ADMIT: %s tick=%s reason=%s nudge=%s
slot_pool.go:706	ADMIT: %s tick=%s reason=%s nudge=%s cooldown_remaining=%.0fs (EARLY)
loop.go:2623	ADMIT: candidate query failed: %v — no admission lines this pass
schedgap157.go:125	ADMIT: record admission stamp tick %s: %v
schedgap157.go:110	ADMIT: record deferral %s (%s): %v
loop.go:2344	ADMIT: scan candidate row: %v
deliver.go:497	ALERT: %s tick=%s — %s (no delivery target configured)
deliver.go:520	ALERT: %s tick=%s → %s
deliver.go:509	ALERT: temp file: %v
alert_escalation.go:554	AUTO-DISABLE: disabled %s — failure_rate=%.4f (%d/%d, window=%d, threshold=%.2f)
alert_escalation.go:550	AUTO-DISABLE: failed to disable %s: %v
alert_escalation.go:505	AUTO-DISABLE: query ticks for %s: %v
alert_escalation.go:486	AUTO-DISABLE: scan project name: %v
board_guard.go:208	BOARD-GUARD-REFUSAL (SCHED-GAP-1699): %s branch %s — merge REFUSED until changeset is split:\n%v
board_stasis.go:274	BOARD-UNCHANGED: skipping %s — board unchanged since tick %s (SCHED-GAP-1678)
board_wake.go:477	BOARD-WAKE-WATCHDOG: poll loop silent for %v (threshold %v) — board-driven wake dead, clock cadence unaffected
board_wake.go:328	BOARD-WAKE: %s board changed but holds no actionable work (deferred/fixture-only) — no wake
board_wake.go:332	BOARD-WAKE: %s board changed — wake armed (debounce %v)
slot_pool.go:495	BOARD-WAKE: %s tick=%s — inherited board-wake stamp refused: shared cooldown gate (%s, remaining=%.0fs of %.0fs, mode=%s); spawn dropped (SCHED-GAP-16928)
board_wake.go:379	BOARD-WAKE: %s wake — forced re-evaluation (work_to_spawn=%t, rows=%d, can_verify=%t)
schedgap1660.go:199	BOARD-WAKE: %s — shared cooldown gate refuses the board-write admission (%s, remaining=%.0fs of %.0fs, mode=%s); stamp dropped (SCHED-GAP-1666)
board_wake.go:222	BOARD-WAKE: baseline scan failed (fail-open, first successful poll re-baselines): %v
board_wake.go:289	BOARD-WAKE: board enumeration failed (fail-open, no wake): %v
budget_hold.go:164	BUDGET-HOLD: namespace %s over budget (demand %d > alloc %d, over %d) — holding %d project(s) this cycle: %v%s
packer.go:351	BUDGET: %s blocked (%s) — excluded from greedy selection; running ticks untouched
multipool_packer.go:258	BUDGET: %s blocked (%s) — excluded from selection; running ticks untouched
budget.go:265	BUDGET: %s spend query failed (%v) — budget enforcement OFF this cycle
spawn.go:2334	BUILDER-GUARD: %s tick=%s cancel raced a completed turn — tick keeps its own outcome
spawn.go:2308	BUILDER-GUARD: %s tick=%s session cancelled — recording outcome %s
builder_guard.go:499	BUILDER-GUARD: abort %s (project %s) after %v with %d interactions and zero writes (session cancel: %t)
builder_guard.go:470	BUILDER-GUARD: nudge %s (project %s): %s
loop.go:826	BUILDER-GUARD: pass complete — %d nudged, %d aborted
bump.go:115	BUMP: %s 12h hard cap exceeded (started %s) — force-reverting with %d tick(s) remaining
bump.go:163	BUMP: %s Phase A revert (%s) failed: %v — hard cap will retry
bump.go:128	BUMP: %s countdown write failed: %v
bump.go:134	BUMP: %s final bump tick consumed — auto-reverting (Phase A restore + Phase B adaptive re-eval)
bump.go:60	BUMP: flag tick %s (%s) failed: %v
packer_select.go:525	CEILING: ns=%s lane=%s deferred — cadence ceiling (ticks=%d + selected=%d >= %v), boost=%s
lifecycle.go:595	CLEANUP: %d stale running ticks timed out
schedgap1666.go:328	COOLDOWN-GATE: project row %s unreadable (%v) — falling open to the caller's own decision
spawn.go:3716	COST: project=%s tick=%s marginal_usd=%.6f sticker_usd=%.6f source=%s provider=%s model=%s
bus_hook.go:69	CRIER: lane-state publish dropped: %v
bus_hook.go:52	CRIER: tick-terminal publish dropped: %v
tick_process.go:975	DANGLING: cleaned %d dead running tick(s) from previous process (dead pid or stale gateway heartbeat)
tick_process.go:946	DANGLING: last_tick_completed update failed: %v
tick_process.go:961	DANGLING: reaping tick %s (pid=%d): %v
tick_process.go:886	DANGLING: startup cleanup query failed: %v
tick_process.go:922	DANGLING: startup cleanup — no dead-pid or stale-gateway ticks found (live gateway ticks left running)
slot_pool.go:442	DEDUP: skipping %s (tick %s) — already running or reserved
tick_process.go:464	DEDUP: skipping %s — already running
spawn.go:701	DEFERRED: %s tick=%s gateway transient blip — deferring (NOT a lane failure): %v
spawn.go:1748	DEFERRED: %s tick=%s no gateway client and exec fallback disabled — deferring (NOT a lane failure)
deliver.go:376	DELIVER: %s tick=%s — deliver_mode=link but no public base URL configured (--public-url), falling back to full
deliver.go:399	DELIVER: %s tick=%s — file mode (%v), falling back to full
deliver.go:359	DELIVER: %s tick=%s — no delivery target configured
deliver.go:354	DELIVER: %s tick=%s — no output
deliver.go:456	DELIVER: %s tick=%s — temp file: %v
deliver.go:373	DELIVER: %s tick=%s — unknown deliver_mode %q, falling back to full
deliver.go:463	DELIVER: %s tick=%s — write temp file: %v
deliver.go:473	DELIVER: %s tick=%s → %s
deliver.go:265	DELIVER: attempt %d/%d failed: %v (%s)%s
premise_blocked.go:317	DEPENDENCY-BLOCKED: deferring %s — pending row(s) blocked on incomplete depends_on (SCHED-GAP-1658)
dispatch_leg.go:160	DISPATCH: %s tick target agent %s uses its REGISTERED relay endpoint %s (targeted dispatch)
dispatch_leg.go:414	DISPATCH: %s tick=%s ack %s: %v
dispatch_leg.go:237	DISPATCH: %s tick=%s agent=%s corr=%s REFUSED: %v
dispatch_leg.go:252	DISPATCH: %s tick=%s agent=%s corr=%s message=%s transport=%s wall=%s lane_ref=%s board_ref=%s
slot_pool.go:749	DISPATCH: %s tick=%s dispatch targets unreadable (%v) — running locally as before
dispatch_leg.go:397	DISPATCH: %s tick=%s inbox retrieve: %v (retrying)
dispatch_leg.go:778	DISPATCH: %s tick=%s receipt write failed: %v
slot_pool.go:564	DISPATCH: %s tick=%s targeted agent %s — dispatch targets unreadable (%v), references fall back to the lane workdir
tick_process.go:1254	DISPATCH: hand-out %s (lane %s) closed as expired — %s
tick_process.go:1229	DISPATCH: orphan sweep query failed: %v
tick_process.go:1257	DISPATCH: orphan sweep — no abandoned hand-outs
tick_process.go:1250	DISPATCH: reaping orphaned hand-out %s (lane %s): %v
spawn.go:3057	ERROR persisting session_id for %s: %v
packer.go:299	ERROR scanning project row: %v
spawn.go:3076	ERROR updating tick %s to running: %v
spawn.go:3044	ERROR: stdout scanner panic for tick %s: %v
alert_escalation.go:742	ESCALATION: auto-disable check error: %v
alert_escalation.go:736	ESCALATION: consecutive failures check error: %v
alert_escalation.go:739	ESCALATION: duplicate workdir check error: %v
alert_escalation.go:730	ESCALATION: health check error: %v
alert_escalation.go:243	ESCALATION: parse time %q: %v
alert_escalation.go:357	ESCALATION: query ticks for %s: %v
alert_escalation.go:238	ESCALATION: scan completion: %v
alert_escalation.go:343	ESCALATION: scan project name: %v
alert_escalation.go:216	ESCALATION: scan project: %v
alert_escalation.go:366	ESCALATION: scan tick: %v
alert_escalation.go:424	ESCALATION: scan workdir project: %v
alert_escalation.go:733	ESCALATION: starvation check error: %v
loop.go:1590	EVAL-STALL: last eval %v ago with %d running ticks — forced re-evaluation (threshold %v, recovered=%t, misses=%d)
loop.go:1652	EVAL-ZERO-SELECT: %d consecutive zero-select eval(s) with %d eligible project(s) — evaluation is picking nothing
loop.go:1705	EVAL-ZERO-SELECT: query eligible projects: %v
tick_process.go:401	EVAL: %d project(s) selected, %d/%d budget used
tick_process.go:211	EVAL: cleaned up %d stale tick(s)
tick_process.go:587	EVAL: escalation check error: %v
tick_process.go:319	EVAL: packer error: %v
events.go:57	EVENT: failed to write event [%s] %s: %v
packer_select.go:225	FAIRNESS: %s boosted (cooldown=%ds failures=%d window=%v starved=%v) — starvation guarantee
multipool_packer.go:332	FAIRNESS: %s boosted in flat fallback (cooldown=%ds failures=%d window=%v starved=%v)
packer.go:369	FAIRNESS: %s boosted in flat packer (cooldown=%ds failures=%d window=%v starved=%v)
loop.go:850	FEATURES: periodic flush: %v
multipool_packer.go:569	FLAT-FALLBACK: packed %d unassigned/fallback project(s), used=%d budget=%d
gateway_health_gate.go:881	GATEWAY DEAD — deferring spawns, re-probing every %s: %s
spawn.go:1784	GATEWAY ENDPOINT: %s tick=%s url=%s url_source=%s key_source=%s
spawn.go:2842	GATEWAY FAIL: %s tick=%s error=%v — falling back to exec.Command
spawn.go:2403	GATEWAY FAIL: %s tick=%s status=%s — recorded failed: %s
spawn.go:2135	GATEWAY FALLBACK: %s tick=%s primary model=%q provider=%q rejected (HTTP 401/403) — retrying once with model=%q provider=%q
spawn.go:2180	GATEWAY FOREMAN FALLBACK: %s tick=%s chain exhausted (primary=%q/%q retry=%q/%q) — final attempt model=%q provider=%q
spawn.go:1888	GATEWAY KEY PROBE: %s tick=%s error=%v — proceeding to dispatch
spawn.go:846	GATEWAY KEY REJECTED: %s tick=%s error=%v — failing fast, no dispatch, no exec fallback
spawn.go:2032	GATEWAY RETRY: %s tick=%s attempt=%d/%d model=%q provider=%q session_key=%s error=%v
spawn.go:2138	GATEWAY ROUTER REFUSAL: %s tick=%s model=%q provider=%q unservable-rating (HTTP 503) — advancing to model=%q provider=%q (no breaker trip: the rating was unservable, not the pair dead)
spawn.go:2628	GATEWAY STALLED: %s tick=%s turn deadline %v exceeded (tick deadline %v still alive) — recording stalled failure: %v
gateway_health_gate.go:902	GATEWAY reconnected — resuming spawns
tick_process.go:683	GATEWAY-DEFER: deferring %s (tick %s) — %s (row stays queued, not started)
tick_process.go:680	GATEWAY-DEFER: deferring %s — %s (no row enqueued; re-picked when the gateway answers)
gateway_health_gate.go:331	GATEWAY-HEALTH-GATE: NOT ARMED (no gateway client) - spawns will not be gated
gateway_health_gate.go:334	GATEWAY-HEALTH-GATE: armed ttl=%s
gateway_health_gate.go:834	GATEWAY-HEALTH-GATE: recovered%s after %d deferral(s) — spawns admitted again
gateway_health_gate.go:645	GATEWAY-HEALTH: endpoint verdict cache full (%d) — evicted %s
gateway_health_gate.go:538	GATEWAY-HEALTH: probe failed for endpoint %s, deferring its lanes for %s: %s
gateway_health_gate.go:536	GATEWAY-HEALTH: probe failed, deferring spawns for %s: %s
gateway_health_gate.go:522	GATEWAY-HEALTH: probe rejected the key for %s (%v) — the gate is FAIL-OPEN for auth errors; 
spawn.go:345	GATEWAY-POST-TRACE: tick=%s project=%s model=%s provider=%s classification=%s mode=%s deadline=%v elapsed=%v events=%d attempts=%d session=%s idle_fired=%t
spawn.go:641	GATEWAY-UNAVAILABLE: %s tick=%s class=%s at=%s — tick not run (gateway availability): %v
spawn.go:2561	GATEWAY: %s tick=%s tokens=%d/%d attempts=%d
gateway_endpoint.go:241	GATEWAY: derived endpoint client for %s (cache size=%d)
tick_process.go:853	HANDOFF: adopted live gateway tick %s (%s) without replaying its request
tick_process.go:849	HANDOFF: live gateway tick %s (%s) not claimed — slot pool at capacity; DB dedup remains active
tick_process.go:823	HANDOFF: live-gateway adoption query failed: %v
slot_pool.go:770	HOOK: %s tick=%s vetoed by %s: %v
spawn.go:2503	IDLE-INTERVENTION: %s tick=%s follow-up turn error (ignored; tick outcome unchanged): %v
spawn.go:2496	IDLE-INTERVENTION: %s tick=%s zero artifacts — firing ONE bounded in-session turn
infra_alert_throttle.go:153	INFRA-ALERT: ignoring %s=%q (want a positive Go duration) — using %v
infra_alert_throttle.go:249	INFRA-ALERT: suppressed repeat %s/%s (window %v)
lane_output.go:138	LANE-OUTPUT: %s %s output count write failed: %v
lane_output.go:157	LANE-OUTPUT: %s %s streak read failed: %v
lane_output.go:162	LANE-OUTPUT: %s %s streak write failed: %v
lane_output.go:212	LANE-OUTPUT: %s (%s) zero-output streak reached %d — HIGH event emitted
lane_output.go:124	LANE-OUTPUT: %s namespace read failed: %v
lane_output.go:99	LANE-OUTPUT: %s tick %s read failed: %v
loop.go:1247	LOAD-GATE: bypassed for %s (tick %s) — work runs on %s (remote dispatch)
tick_process.go:506	LOAD-GATE: bypassed for %s — work runs on %s (remote dispatch); local load %.2f is not the constraint
tick_process.go:619	LOAD-GATE: deferring %s (tick %s) — load %.2f >= threshold %.2f (row stays queued, not started)
tick_process.go:616	LOAD-GATE: deferring %s — load %.2f >= threshold %.2f (no row enqueued; re-picked when load drops)
load_gate.go:102	LOAD-GATE: namespace lookup %s: %v (fail open — gate applies)
loop.go:925	LOOP: eval drain did not stop within %v
loop.go:863	LOOP: health (goroutines=%d, slots=%d/%d, last_eval=%v)
loop.go:932	LOOP: shutdown drain timed out after %v — marking in-flight ticks failed
loop.go:1005	LOOP: shutdown drain timed out — marked tick %s (project %s) failed (orphan=%s)
loop.go:968	LOOP: shutdown drain: iterate running ticks: %v
loop.go:987	LOOP: shutdown drain: mark tick %s (project %s) failed: %v
loop.go:946	LOOP: shutdown drain: query running ticks: %v
loop.go:961	LOOP: shutdown drain: scan running tick: %v
loop.go:728	LOOP: starting %s eval loop (event-driven, budget=%d, max_concurrent=%d, debounce=5s) goroutines=%d
loop.go:1293	MANUAL-SPAWN: %s admitted ahead of the shared cooldown gate (%s, remaining=%.0fs of %.0fs) — operator bypass (e)
loop.go:1297	MANUAL-SPAWN: %s shared cooldown gate could not read the lane's facts — operator bypass (e) proceeds unreconciled
memory_keys.go:204	MEMORY-KEYS: %s observed %d DuckBrain memory write(s) — non-commit artifact (SCHED-GAP-1680)
memory_keys.go:200	MEMORY-KEYS: %s transcript scan failed: %v (reading 0)
nowork.go:205	NO-WORK: deferring %s — board holds 0 dispatchable rows (%d open rows counted)
nowork.go:202	NO-WORK: deferring %s — board read failed at %s (gate blocked on the pre-log read)
noop_guard.go:306	NOOP-GUARD: %s tick=%s re-entering SAME session: %s
noop_guard.go:311	NOOP-GUARD: %s tick=%s re-entry turn error (ignored; tick verdict unchanged): %v
noop_guard.go:298	NOOP-GUARD: %s tick=%s re-entry unavailable (no live session channel) — event emitted instead
noop_pacing.go:102	NOOP-PACING: %s deferred — %d consecutive no-op tick(s), next admission spaced %.0fs (cooldown floor)
noop_pacing.go:140	NOOP-PACING: %s streak reset failed: %v
noop_pacing.go:147	NOOP-PACING: %s streak write failed: %v
namespace_gate.go:174	NS-CAP: namespace %s at cap (%d/%d running) — %s (tick %s) left QUEUED after waiting %s
packer_select.go:893	NS-UNASSIGNED: %d project(s) with nil/unknown namespace 
packer_select.go:889	NS-UNASSIGNED: %d project(s) with nil/unknown namespace, 
packer.go:537	OVERDUE: %s force-selected (age=%v past 2x cooldown) — bypassing budget gate
packer.go:428	PACKER-SORTED[%d]: %s urgency=%.1f pri=%.0f last=%s
packer.go:534	PACKER: max concurrency reached (%d), stopping
packer.go:701	PACKER: nothing packed — checked %d projects, skipped budget=%d cooldown=%d already-running=%d budget-cap=%d namespace-cap=%d board-unchanged=%d, total-running=%d/%d
board_awareness.go:240	PENDING-BOOST: <%s> boost cleared (pending=0)
board_awareness.go:286	PENDING-BOOST: <%s> boosted (pending=%d)
board_awareness.go:330	PENDING-BOOST: <%s> freshness check subtracted %d mid-flip pending row(s) (raw=%d)
session_silence.go:657	POLL-LOOP: %s tick=%s confirmed poll-looping but no live registered session to cancel — skipping
spawn.go:2218	POLL-LOOP: %s tick=%s guard cancel recorded — confirmed span %ds (reason %s)
session_silence.go:663	POLL-LOOP: %s tick=%s terminated after %v of confirmed sleep-poll cycling (stride min %d, confirm %d passes)
loop.go:840	POLL-LOOP: pass complete — %d poll-looping session(s) terminated
tick_process.go:1090	QUEUED: reaped %d stale queued tick(s) never dispatched by the previous process (older than %v = %dx tick timeout %v)
tick_process.go:1079	QUEUED: reaping tick %s (project %s): %v
tick_process.go:1055	QUEUED: startup reap query failed: %v
tick_process.go:1045	QUEUED: startup reap skipped — no usable tick timeout; queued rows left untouched
tick_process.go:1070	QUEUED: startup reap — no stale queued rows (threshold %v = %dx tick timeout %v)
wave_recovery.go:131	REAPER: tick %s wave abandoned — wave_size=%d abandoned=%d (worktrees preserved, W6)
wave_recovery.go:127	REAPER: tick %s wave abandonment incomplete: %v
cooldown_residue.go:72	RESIDUE: %s
cooldown_residue.go:54	RESIDUE: cooldown-pin residue check clean (0 lanes live below their pin)
cooldown_residue.go:50	RESIDUE: detection failed: %v
cooldown_residue.go:59	RESIDUE: residue listing failed after detection: %v
session_resume.go:362	RESUME: %d orphaned tick(s) re-nudged after gateway recovery (%s)
session_resume.go:188	RESUME: bump nudge_count tick %s: %v
session_resume.go:328	RESUME: classify nudge tick %s: %v
session_resume.go:296	RESUME: deferring orphaned tick %s (project %s) — load gate active for namespace %q (load %.2f >= threshold %.2f); no nudge consumed
session_resume.go:274	RESUME: deferring orphaned tick %s (project %s) — namespace %s at cap %d (%d in flight, %d admitted this pass)
session_resume.go:315	RESUME: deferring orphaned tick %s (project %s) — shared cooldown gate: %s (remaining=%.0fs of %.0fs, reason=%s, in_flight=%t); no nudge consumed
session_resume.go:332	RESUME: enqueue nudge tick %s: %v
session_resume.go:383	RESUME: namespace %s cap lookup failed (%v) — treating as unlimited
session_resume.go:403	RESUME: namespace %s inflight count failed: %v
session_resume.go:426	RESUME: needs-human scan failed: %v
session_resume.go:351	RESUME: nudged orphaned tick %s (project %s, reason=%s, nudge %d/%d) as %s
session_resume.go:145	RESUME: orphan-scan query failed: %v
session_resume.go:250	RESUME: orphaned tick %s: project %s gone: %v
session_resume.go:261	RESUME: skipping orphaned tick %s (project %s) — lane already admitted or holding a slot this pass; no nudge consumed, no row enqueued
session_resume.go:113	RESUME: stamp orphaned tick %s (%s): %v
router_client.go:276	ROUTER-MISS: %s missing from router registry — dynamic routing degraded, static chain fallback (%s)
spawn.go:1676	ROUTER-PIN: %s router opened no head — lane pin %s/%s is the fallback the router could not serve
spawn.go:1662	ROUTER: %s profile=%s gate=%s head=%s/%s
router_client.go:265	ROUTER: %s unavailable (router not configured) — using chain fallback
router_client.go:278	ROUTER: %s unavailable — using chain fallback (%s)
session_reaper.go:37	SESSION-REAPER (dry-run): %d stale api_server session(s) would be closed (stalest idle %s, threshold %s)
session_reaper.go:34	SESSION-REAPER: closed %d stale api_server session(s) (candidates %d, stalest idle %s, threshold %s)
session_silence.go:193	SESSION-SILENCE: %s tick=%s silent for %v but no live registered session to cancel — skipping
session_silence.go:202	SESSION-SILENCE: %s tick=%s terminated after %v of zero token/tool activity (grace %v)
spawn.go:2263	SESSION-SILENCE: %s tick=%s watchdog cancel recorded — quiet %ds (reason %s)
loop.go:833	SESSION-SILENCE: pass complete — %d silent session(s) terminated
premise_blocked.go:324	SIBLING-HELD: deferring %s — pending row(s) already claimed/in_progress by a sibling (SCHED-GAP-1658)
sim_fixture.go:123	SIM-SETUP: %d test projects inserted (engine budget=%d, engine max_concurrent=%d)
loop.go:706	SIM: %d/%d ticks generated
loop.go:709	SIM: all %d ticks generated — waiting for simulated completion
tick_process.go:478	SIM: spawn %s failed: %v
sim_spawn.go:121	SIM: stamp admit_reason on %s: %v
spawn.go:2808	SKIPPED: %s tick=%s exec fallback disabled, dropping tick: %v
slot_pool.go:625	SLOT: acquired for %s (%d/%d running)
slot_pool.go:598	SLOT: timeout waiting for free slot — dropping %s
slowdown.go:48	SLOWDOWN: %s cooldown %ds is operator-set (>=%ds) — idle escalation skipped
slowdown.go:70	SLOWDOWN: %s cooldown %ds is operator-set (>=%ds) — productive reset skipped
slowdown.go:58	SLOWDOWN: %s idle → cooldown %ds → %ds (%dm)
slowdown.go:75	SLOWDOWN: %s productive → cooldown reset %ds → 600s
spawn.go:1706	SPAWN ROUTE: %s tick=%s policy=%s lane_class=%q
slot_pool.go:821	SPAWN: %s failed: %v
spawn.go:1711	SPAWN: %s tick=%s chain=%s model=%q provider=%q
spawn.go:3084	SPAWN: %s tick=%s pid=%d workdir=%s
spawn.go:569	SPAWN: %s transport-class failure (%s) — consecutive_failures left untouched
slot_pool.go:879	SPAWN: complete %s: %v
slot_pool.go:545	SPAWN: enqueue %s before usage-pool admission: %v
slot_pool.go:652	SPAWN: enqueue %s: %v
slot_pool.go:716	SPAWN: start %s: %v
wave_stale_base.go:143	STALE-BASE-WARN (SCHED-GAP-1609): %s branch %s — base %s advanced past the branch (base_sha=%s branch_sha=%s): SKIP the merge; rebase onto %s and re-run gates before merging
stale_premise.go:222	STALE-PREMISE: deferring %s — pending row(s) already satisfied (commit_hash present on %s; SCHED-GAP-1657)
lifecycle.go:355	STAND-DOWN: %s tick=%s completed with no landed artifact and no dispatch — recorded reason=%q (SCHED-GAP-1653)
load_telemetry.go:74	TELEMETRY: host sample persist failed (evaluation unaffected): %v
spawn.go:3774	TICK: %s %s → %s (%v)
spawn.go:3543	TICK: %s %s → %s (%v) %s
spawn.go:3364	TICK: %s %s → %s (%v): %s
spawn.go:3306	TICK: %s %s → %s (%v): builder no-artifact guard abort (outcome %s)
spawn.go:3285	TICK: %s %s → %s (%v): remote dispatch to %s
spawn.go:3562	TICK: %s %s → push %s
spawn.go:3564	TICK: %s %s → push STRANDED (%s)
spawn.go:3560	TICK: %s %s → push skipped (tick-push disabled, web-primary; SCHED-GAP-1594)
slot_pool.go:964	TIMEOUT: %s tick=%s duration=%v — project stays active, normal cooldown applies
spawn.go:771	TIMEOUT: %s tick=%s session deadline expired during gateway POST — booking timeout (NOT a gateway blip): %v
usage_pool_policy.go:87	USAGE_POOL: lane=%s tick=%s reason=%s error=%v
usage_pool_policy.go:54	USAGE_POOL: observe-only defer lane=%s pool=%s active=%d limit=%d
usage_pool_policy.go:61	USAGE_POOL: recovered %d leases on admission
slot_pool.go:986	USAGE_POOL: release lease=%s lane=%s failed: %v
namespace_alloc.go:189	WARN NamespaceAllocator: total reserved %d exceeds budget %d; scaling reserved proportionally (largest-remainder)
namespace_alloc.go:221	WARN NamespaceAllocator: total weight is 0 across %d enabled namespaces; treating all as weight=1
spawn.go:3996	WARN [board_closure]: SCHED-GAP-163 suppressed repeat closure-evidence event for %s (%d unchanged violation(s), fingerprint %s, last emitted %s ago) — reminder due %s
spawn.go:3988	WARN [board_closure]: SCHED-GAP-163 throttle query failed for %s: %v — emitting HIGH (fail open)
spawn.go:3982	WARN [board_closure]: SCHED-GAP-163 throttle unavailable for %s (spawner=%t db=%t) — emitting HIGH (fail open)
spawn.go:3812	WARN [board_closure]: cannot read board %s: %v
spawn.go:3850	WARN [board_closure]: pre-existing closure-evidence violations on %s (tick %s closed %d row(s) in-window): %s
wave_budget.go:269	WARN [wave]: %v
board_guard.go:211	WARN [wave]: board guard (SCHED-GAP-1699): %s branch %s: %v
board_guard.go:201	WARN [wave]: board guard (SCHED-GAP-1699): %s — %d more branch(es) unchecked (cap %d)
slot_pool.go:925	WARN [wave]: cost attribution %s: %v
slot_pool.go:911	WARN [wave]: manifest ingest %s: %v
wave_stale_base.go:139	WARN [wave]: stale-base guard (SCHED-GAP-1609): %s branch %s: %v
wave_stale_base.go:132	WARN [wave]: stale-base guard (SCHED-GAP-1609): %s — %d more branch(es) unchecked (cap %d)
spawn.go:491	WARN: %s=%q negative — using default %d
spawn.go:447	WARN: %s=%q negative — using default %v
wave_timeout.go:148	WARN: %s=%q unparseable (%v) — falling back to namespace wave_tick_timeout
spawn.go:486	WARN: %s=%q unparseable — using default %d
spawn.go:442	WARN: %s=%q unparseable — using default %v
spawn_mem_limit.go:103	WARN: ADV-R11 spawn mem limit %dMiB not applied to %s tick=%s pid=%d: %v (spawn continues unlimited)
spawn.go:2462	WARN: GATEWAY INSTANT TURN: %s tick=%s events=%d tokens_out=%d tokens_in=%d — recorded failed, not committed: %s
spawn_helpers_other.go:35	WARN: SCHED-GAP-201 process-group kill fallback: FindProcess(%d): %v (best-effort, spawn timeout proceeds)
spawn_helpers_other.go:39	WARN: SCHED-GAP-201 process-group kill fallback: Kill(%d): %v (best-effort)
wave_timeout.go:361	WARN: backstopMaxAge: namespace %q lookup failed (%v) — inheriting --tick-timeout
wave_timeout.go:302	WARN: backstopMaxAge: tick→namespace join failed (%v) — falling back to %v
builder_guard.go:123	WARN: builder_guard knob lookup for namespace %q failed (%v) — using defaults
builder_guard.go:542	WARN: builder_guard nudge stamp for %s: %v
builder_guard.go:352	WARN: builder_guard running-tick query failed: %v
circuit_client.go:112	WARN: circuit client not configured — skipping record-failure for %s/%s
circuit_client.go:95	WARN: circuit script error (%v): %s — %s
circuit_client.go:93	WARN: circuit script timed out after %s: %s
spawn.go:548	WARN: consecutive_failures increment for %s: %v
lifecycle.go:533	WARN: failed to increment consecutive_failures for %s: %v
lifecycle.go:520	WARN: failed to reset consecutive_failures for %s: %v
lifecycle.go:472	WARN: failed to update last_tick_completed/last_tick_status for %s: %v
gateway_endpoint.go:175	WARN: gateway endpoint batch lookup failed (%v) — resolving the pass against the global gateway only
gateway_endpoint.go:122	WARN: gateway endpoint lookup for %s failed (%v) — resolving against the global gateway only
tick_process.go:176	WARN: goroutine count = %d (threshold: 100)
spawn.go:1166	WARN: heartbeat refresh for tick %s: %v
gateway_endpoint.go:195	WARN: iterate gateway endpoint batch rows: %v
wave_budget.go:185	WARN: live wave depth for namespace %q failed (%v) — WAVE_BUDGET not injected this tick
receipt_helper.go:48	WARN: local receipt helper could not run tick=%s error_type=%T
receipt_helper.go:45	WARN: local receipt helper exited unsuccessfully tick=%s exit_code=%d
receipt_helper.go:40	WARN: local receipt helper timed out tick=%s after %s
stall_hop_advance.go:109	WARN: marshal gateway attempts: %v
spawn.go:354	WARN: marshal gateway trace for %s: %v
builder_guard.go:140	WARN: namespace %q no_artifact_recon_floor=%q unparseable — using default %d
builder_guard.go:131	WARN: namespace %q no_artifact_window=%q unparseable — using default %v
wave_timeout.go:159	WARN: namespace %q wave_tick_timeout=%q unparseable — inheriting --tick-timeout
noop_guard.go:234	WARN: noop_guard lane lookup for %s failed (%v) — deriving foreman
noop_guard.go:182	WARN: noop_guard pre-trigger stamp for %s: %v
noop_guard.go:258	WARN: noop_guard verdict stamp for %s: %v
stall_hop_advance.go:226	WARN: persist gateway attempts for %s: %v
spawn.go:358	WARN: persist gateway trace for %s: %v
spawn.go:1910	WARN: placeholder session_id/heartbeat for %s: %v
session_silence.go:556	WARN: poll-loop probe for tick %s: %v (observe nothing)
gateway_stream.go:66	WARN: project %q turn_deadline=%q unparseable — inheriting the global per-turn deadline
gateway_endpoint.go:263	WARN: record gateway endpoint for tick %s: %v
circuit_client.go:117	WARN: record-failure %s/%s not recorded (circuit script unavailable)
circuit_client.go:131	WARN: record-success %s/%s not recorded (circuit script unavailable)
gateway_endpoint.go:182	WARN: scan gateway endpoint batch row: %v
session_silence.go:610	WARN: session_poll_loop running-tick query failed: %v
session_silence.go:115	WARN: session_silence probe for tick %s: %v (observe nothing)
session_silence.go:147	WARN: session_silence running-tick query failed: %v
spawn.go:3063	WARN: stdout scanner error for tick %s: %v
spawn.go:3733	WARN: tick %s git delta NOT measured: %v — commits/files stamped -1 (unknown), NOT evidence of no work
spawn.go:3742	WARN: tick %s git delta NOT measured: no usable baseline (preCommits=%d, cmdDir=%q) — commits/files stamped -1 (unknown), NOT evidence of no work
gateway_stream.go:57	WARN: turn_deadline lookup for %s failed (%v) — inheriting the global per-turn deadline
wave_budget.go:302	WARN: wave shed scan failed (%v) — no namespace shed this cycle (fail-open)
wave_timeout.go:168	WARN: wave tick timeout %v from %s exceeds the 4h ceiling — clamped to %v (S12 §4.3)
wave_timeout.go:108	WARN: wave timeout lookup for namespace %q failed (%v) — inheriting --tick-timeout
wave_budget.go:143	WARN: wave_workers_cap lookup for namespace %q failed (%v) — WAVE_BUDGET not injected this tick
urgency.go:91	WARNING: SetRange ignored: invalid range (min=%.0fs, max=%.0fs)
urgency.go:29	WARNING: invalid interval range (min=%.0fs, max=%.0fs), using ratio=1.0
urgency.go:20	WARNING: numLevels=%d < 2, setting to 2
cost.go:444	WAVE-COST: %s tick=%s workers=%d realized=%d estimated=%d worktree_judge_usd=%.4f
wave_budget.go:195	WAVE-LOAD: %s namespace=%s load-scaling bound budget to %d (cap=%d depth=%d)
wave_budget.go:271	WAVE-RECOVERY: %s tick=%s — %d unfinished wave manifest(s): recovery tick, preamble injected
wave_budget.go:175	WAVE-SHED: %s namespace=%s WAVE_BUDGET: 0 (packer shed — live wave in flight at pack time) — serial tick
wave_budget.go:199	WAVE-SHED: %s namespace=%s cap=%d live_depth=%d — cap forces a serial tick
slot_pool.go:913	WAVE: %s tick=%s ingested %d worker rows
workdir_target.go:62	WORKDIR-TARGET: %q is not resolvable on this host (%s); mount root %s — lane will be treated as having no board here
worker_janitor.go:130	WORKER-JANITOR: abandoned %d stale tick_workers row(s) — tick terminal or older than the wave cap (SCHED-GAP-1706, attribution rows kept)
worker_janitor.go:122	WORKER-JANITOR: abandoning %d stale worker rows failed: %v
worker_janitor.go:105	WORKER-JANITOR: stale worker-row iteration failed: %v
worker_janitor.go:92	WORKER-JANITOR: stale worker-row query failed: %v
loop.go:760	WORKER-JANITOR: startup pass flipped %d running worker row(s) to abandoned
tick_process.go:1191	ZOMBIE: reaped %d gateway tick(s) (stale heartbeat)
tick_process.go:1169	ZOMBIE: reaped %d ticks (process died)
tick_process.go:1119	ZOMBIE: reaper query failed: %v
tick_process.go:1181	ZOMBIE: reaping gateway tick %s: %v
tick_process.go:1158	ZOMBIE: reaping tick %s: %v
tick_process.go:780	ZOMBIE: stale-gateway query failed: %v
tick_process.go:279	cadence ceiling: namespace tick-count query failed open: %v
tick_process.go:250	cadence target: achieved-rate query failed open: %v
slot_pool.go:313	usage-pool: release reaped leases: %v
```
## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Silent success | pass for a `status:"failed"` reply | a real pass | **OPEN** — CF-355 (`dispatch_leg.go:713-726`) |
| `text_b64` undecodable | the node refuses the dispatch (`node-bus-worker.py:1022-1034`) | a malformed envelope | **resolved** — CF-354 (complete): the node decodes `text_b64` first |
| Deadline expiry | `DispatchStateExpired`, `TickTimeout` (`:291-314`) | a failed reply (`TickFailed`, `:316-325`) | the reply is PARTIAL, named `dispatch_deadline` |
| No authoritative lane inventory | 8 vs 16 vs 1 lanes across three modules | a single census | **OPEN** — CF-335 |
| Env-contaminated test | the operator-restart tests FAIL only when `SCHEDULER_OPERATOR_RESTART_APPROVED=1` is ambient | a code break | unset the var (`env -u … go test`) |

## 11. Limits and margins

- The reply await is bounded by the same session deadline the node got as `limits.wall_s`
  (`:255-260`); the wall is printed because it decides both the node's budget and the await.
- `dispatchReplyVerdict`'s documented premise is "absence of a verdict is SUCCESS" (`:709-712`) —
  the exact place a `status` field is ignored.
- **Admission authority.** `admission_mode.go:143-184` `laneOwnsBoard` derives board ownership
  from the filesystem (workdir containment); `boardOwnedByLane` is **defined at `:177`** (doc
  comment `:173`), honours an explicit per-project override (`database.BoardOwnershipOwner`/
  `Shared`) before falling back to the filesystem derivation, and is **called at `:234`** inside
  `tasksAdmissionDue`. Operator mutation auth is in `internal/api/auth.go:187-197`
  `extractBearerOrHeaderToken` (Bearer or `X-Operator-Token` header).

## 12. Cross-references

- F11 SCHEDULING ADMISSION is the primary flow; F1 DISPATCH AND SETTLEMENT is its terminal half — **flow chapter not written** (OUTLINE Part II, all 16 flows MISSING).
- M10 CRIER is the transport (CT-02/CT-04 on its side; CT-03/CT-06 are the node/scheduler ends).
- M2 DISPATCH (node side) and M11 DISPATCHER are the two inbox consumers.
- M4 BOARD rows gate admission (S1); see M4 §12 for the M9-only ownership of that gate.

## 13. Evidence of record

- Code read: `internal/scheduler/dispatch_leg.go` (`:245-364`, `:700-759`), `internal/bus/dispatch.go`
  (`:170-214`), `internal/scheduler/admission_mode.go` (`:98-129, 143-208, 230-267`),
  `internal/scheduler/usage_pool_policy.go:21-70`, `internal/scheduler/packer_select.go:369-531`,
  `internal/scheduler/nowork.go:82-265`, `internal/scheduler/board_stasis.go:320`,
  `internal/scheduler/stale_premise.go:208`, `internal/scheduler/premise_blocked.go:299`,
  `internal/scheduler/cadence_ceiling.go:71`, `internal/scheduler/noop_pacing.go` (log sites),
  `internal/scheduler/slot_pool.go:539-585`, `internal/scheduler/tick_process.go:285`,
  `cmd/schedulerd/main.go:95-200`, `internal/api/auth.go:187-197`, `internal/api/server.go:289-370`,
  `internal/api/server_metrics.go:60-81, :87-119, :125-136, :195`, `config.example.toml` (full),
  `internal/database/migrations.go` (full 30-table census), `internal/config/loader.go:421-422`,
  `internal/scheduler/urgency.go:18-22`.
- Commands run: `go build ./...` (PASS, re-run this round at `d0dad6d9`); `env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./internal/scheduler/ -count=1 -timeout 1800s` (PASS, 547.133s this round); the three env-sensitive tests (PASS, 4.353s this round); the full `go test ./...` at `251d11db` (rc 1 under parallel load — F9-13);
  `git diff --name-only 251d11db..HEAD` (12 paths — two board JSONL, seven `.go`, three `_test.go`);
  `grep -n 'LoadRootConfig' cmd/schedulerd/main.go` (10 sites);
  `grep -rn "log.Printf" internal/scheduler/*.go | grep -v _test.go | wc -l` (381 excluding test; 382 including);
  `grep -rhoE 'log\.Printf\("[^"]*"' internal/scheduler/*.go | grep -v _test.go | sed 's/^log\.Printf("//; s/"$//' | sort -u | wc -l` (370 distinct format strings — the §9 enumeration);
  `cat /usr/lib/go-1.26/VERSION` (go1.26.8); `readlink -f /home/kara/.local/bin/go` (`/home/kara/sdk/go1.26.5/bin/go`); `go env GOVERSION` in-module (go1.26.10 via GOTOOLCHAIN=auto);
  `grep -cE 'flag\.(String|Int|Int64|Bool|Duration|Float64)' cmd/schedulerd/main.go` (57);
  `sqlite3 … '.tables'` (30 tables); `grep -oE 'mux\.HandleFunc\("[^"]+"' internal/api/server.go | sort -u | wc -l` (43).
- Rev re-stamped: `d0dad6d9` (this round). HEAD advanced four commits past `251d11db`
  (`0b357bb9`, `79510add`, `ea7810db`, `d0dad6d9`); the namespace-mode gate order shifted +12 lines
  and `buildForemanPrompt` moved `:1249`→`:1250`; the no-work gate definitions were already in
  `nowork.go` at `251d11db` (unchanged) — only the `packer_select.go` call sites moved.
- Board rows: CF-334, CF-335, CF-337, CF-343, CF-346, CF-353, CF-354, CF-355.
- **Findings:**
  - **F9-1** (carried) — settlement exists (`dispatch_leg.go:260-336`); the real defect is CF-355.
  - **F9-2** (carried) — 30 tables, not 26; no `verdicts` table.
  - **F9-3** (corrected) — `LoadRootConfig` IS loaded at boot (`main.go:640,673,762,854,870,968,995,1023,1054,1309`), three-layer merge in `loader.go`. The only residue: `config.example.toml`'s header NOTE is stale.
  - **F9-4** — `metricsSpawns` is at `:195`, not `:192`.
  - **F9-6** (carried) — round-4's `go test ./...` FAIL was env contamination, not a code break; clean-env PASSES.
  - **F9-7** (re-derived this round at `d0dad6d9`, sol B17) — the ordered admission procedure is the
    packer's call order (`packer_select.go:369-531`), with usage-pool reservation at spawn
    (`slot_pool.go:539-585`), not an alphabetized helper list. The round-18 `251d11db` derivation
    cited the cooldown-branch call sites 12 lines earlier; the new tasks-mode branch (NOOP-PACING,
    post-failure stand-down, FailureBackoff, tasks-pacing) is now named.
  - **F9-16** (new, this round) — scheduler HEAD advanced `251d11db`→`d0dad6d9` (four commits, 12
    paths); §1/§3/§6/§7/§9/§13 re-stamped and re-verified. Only two §9 log locators moved
    (`loop.go:2613→2623`, `:2334→2344`); `buildForemanPrompt` moved `:1249→:1250`; the 381-site /
    370-distinct log census and the 57-flag / 43-route counts are unchanged at the new HEAD.
  - **F9-8** (carried) — `num-levels` "0 breaks the priority sort" was false: `loader.go:421-422` rejects `< 1` and `urgency.go:18-22` clamps `< 2` to 2.
  - **F9-9** (carried) — `tick_duration_ms`'s success shape has **no `available` field**; the `:30` intro comment is wrong for that block.
  - **F9-10** (carried) — the run-correctness write authorities and the recovery selector are named (`execution_store.go`); per-failure-mode post-recovery indications remain unwritten.
  - **F9-11** (new, grok #3) — the `usage_pool*` family and `tick_workers` store keys are now named (the reservation's durable record), closing the "14 tables unnamed" omission.
  - **F9-12** (new, kimi B5/grok #8) — the closed-world `git diff` claim is withdrawn: HEAD advanced and `spawn.go` changed after the round-16 stamps; the diff is quoted with the real five paths and dated.
  - **F9-13** (updated, this round) — the full `go test ./...` at `251d11db` under parallel load hit the
    600s per-package timeout in `internal/scheduler` plus the CTL002 load-window flake; the flake set
    also includes `TestSCHEDGAP1666_SevenDaySimulation` (glm #3). Both pass solo (`internal/scheduler`
    376.454s, CTL002 4.656s). A load artifact, not a test regression — but **only the isolated runs
    are green this round**; no clean full-suite pass is captured (sol B22). **Re-verified this round at
    `d0dad6d9`:** the isolated `internal/scheduler` package PASSes in 547.133s (rc 0; slower than
    round-18's 376.454s under the concurrent crier-test + live-fleet load), and the full `go test
    ./...` was not re-run — the full-suite green state remains last captured at `34e44897` on a quiet
    host (round-16).
  - **F9-14** (new, kimi #3) — the round-17 claim "the host was upgraded to 1.26.10" was FALSE. The
    host bootstrap binaries are 1.26.8 (`/usr/bin/go`) and 1.26.5 (`~/.local/bin/go`); go1.26.10 is
    selected at build time by `go.mod`'s `toolchain go1.26.10` directive via `GOTOOLCHAIN=auto` from
    the module cache. §1/§4a corrected.
  - **F9-15** (new, this round) — §8 per-metric contract filled (11 blocks, type/labels/question/scrape).
    While filling it: `metricsSources()` (`:125-189`) documents 10 blocks; `dispatch_inbox`'s source
    string is misplaced inside `metricsLaneChurn`'s return map (`:713-724`), not in `metricsSources()` —
    a code placement defect, filed as a board row, corrected in §8.

## RED field count: 5 — §9 log inventory (enumeration complete: 381 sites / 370 distinct strings
measured and listed verbatim; per-line `Emitted when`/`Kind` classification of the 368 strings
beyond the two settlement rows is unwritten — the narrowed residual, was "not measured"); S4
per-route operator contract (43 routes inventoried, per-route request/response shapes + write
readbacks not written); S3 per-failure-mode post-recovery indications (write authorities + recovery
selector named, the readback ladder not written); §5 auxiliary-flag range + reader/precedence not
re-verified per flag (sol B18); CT-05 internal UNVERIFIED ("3 of 11 prompt files disagree"
unmeasured). **Closed this round: §8 per-metric contract** (11 blocks filled, sol B04/B21).
**Boundary contracts CT-01 and CT-15 are terminal states, not REDs** (uniform rule: a contract row
whose far side is an external peer — no in-repo `file:function` — is a terminal state and is not
counted as a RED; an internal contract that is UNVERIFIED because it was never measured **is** a
RED).
