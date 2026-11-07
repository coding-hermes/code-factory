# M9 — SCHEDULER

## 1. Identity

| Field | Value |
|---|---|
| Module name | SCHEDULER |
| Path | `/home/kara/coding-hermes-scheduler/coding-hermes-scheduler/` (Go) |
| Revision | `6606f856746f2e2c802fa4e1d37a6b2afef0b85e` (scheduler repo HEAD; moved from `34e44897` through 15 commits. The cited files `cmd/schedulerd/main.go` (57 flags), `internal/scheduler/dispatch_leg.go`, `internal/scheduler/admission_mode.go`, `internal/scheduler/usage_pool_policy.go`, `internal/bus/dispatch.go`, `internal/api/*`, `internal/database/migrations.go` are byte-identical since `34e44897`; `internal/scheduler/packer_select.go` gained +12 lines (board-stasis gate now at `:474`/`:614`), `internal/scheduler/spawn.go` gained +7 (buildForemanPrompt now `:1249`), and a new file `internal/scheduler/noop_pacing.go` (149 lines) added a NOOP-PACING admission step) |
| Language / runtime | Go — `go.mod` declares `go 1.26.0` + `toolchain go1.26.10`; `go env GOVERSION` resolves **go1.26.10** (`GOTOOLCHAIN=auto`). Host bootstrap `go` = **go1.26.5** (`/home/kara/.local/bin/go` → symlink → `/home/kara/sdk/go1.26.5/bin/go`); `/usr/bin/go` = **go1.26.8** (`/usr/lib/go-1.26/bin/go`; measured: `/usr/bin/go version` → `go1.26.8 linux/amd64`, `readlink -f /usr/bin/go` → `/usr/lib/go-1.26/bin/go`, binary dated Oct 5) |
| Owner lane | coding-hermes-scheduler (control plane) |
| Status | **UNVERIFIED** — settlement (`dispatch_leg.go:260-336, :713-726`), `internal/bus/dispatch.go:175-208`, the admission authority (`admission_mode.go:98-129, 143-208, 230-267`), the binary defaults (`cmd/schedulerd/main.go:95-200`), the auth path (`internal/api/auth.go:187-197`), the API route table (`internal/api/server.go:289-370`) and `config.example.toml` read; `tick_process.go`/`packer_select.go`/`namespace_alloc.go` grep-level, not line-by-line; §9 log inventory narrowed to the settlement/batch-dispatch surface (2 of 382 sites) with the uncovered count named as RED |

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
| S1 admission and allocation | `admission_mode.go`, `tick_process.go`, `packer_select.go`, `namespace_alloc.go`, `usage_pool_policy.go`, `noop_pacing.go` | **active** | `admission_mode.go:98` `admissionModeFor` (project override → namespace default → cooldown); `:112` `admissionModeForProject` (DB read); `tick_process.go:40` `evaluate()`; `packer_select.go:19` `Pack`; `namespace_alloc.go:131` `Allocate`; `usage_pool_policy.go:21` `reserveUsagePools`; `noop_pacing.go:74` `tasksNoopStreakDeferred` (new, see NOOP-PACING step below) |
| S2 execution and settlement | `spawn`, `slot_pool`, `lifecycle`, `dispatch_leg` | **active** | `dispatch_leg.go:260` `awaitDispatchReply`; `:262-336` constructs completed/failed/timeout outcomes |
| S3 durable state | `scheduler.db` + migration stores | **active** | live store has **30** tables (measured `sqlite3 … '.tables'`); see §5/§3 note for the run-correctness keys |
| S4 operator surfaces | `cmd/schedulerd`, `scheduler-dispatch`, `scheduler-query`, `queueprobe`, `migrate`, `backfill-commit-signals`, `cooldown-residue` | **operator-invoked** | `ls cmd/` → 7 command dirs; no unit invokes another unit — these are CLI entrypoints an operator (or a foreman step) runs, not a scheduler lane |

**Operator surfaces (B18, corrected — 43 routes, not 33).** The daemon mounts its HTTP
routes in `internal/api/server.go` (the `Handler()` tree spans `:289-370`, not just `:289-346`):
`grep -oE 'mux\.HandleFunc\("[^"]+"' internal/api/server.go | sort -u | wc -l` = **43** (measured).
The full set, all under `/api/v1/`, in mount order: `health`, `live`, `status`, `config`,
`projects`, `projects/`, `hooks`, `hooks/plan`, `hooks/{id}`, `hooks/reload`, `lanes/tree`,
`lanes`, `links`, `links/`, `cadence`, `namespaces`, `namespaces/`, `groups`, `groups/`,
`templates`, `templates/`, `ticks`, `ticks/`, `queue`, `openapi.json`, `metrics`, `evaluate`,
`pause`, `resume`, `events`, `events/stream`, `observatory`, `observatory/stream`,
`gateway-errors`, `features`, `features/prune-candidates`, `peers`, `peers/`, `agents`, `agents/`,
`federation/query`, `federation/catalogue`, `cooldown/residue`. Ten of the 43 are later
additions: `hooks/reload`, `features`, `features/prune-candidates`, `peers`, `peers/`,
`agents`, `agents/`, `federation/query`, `federation/catalogue`, `cooldown/residue`. Auth on
mutations via `extractBearerOrHeaderToken` (`internal/api/auth.go:187-197`); the agent and
federation surfaces are operator-gated reads, not merely gated mutations (`server.go:356-366`).
The recovery commands (`reap-sessions`, `verify-board`, `migrate`) are CLI-only flags/subcommands,
not HTTP routes. Per-route request/response shapes and write-authority readbacks are **not**
written — the route inventory is complete (43), the per-route contract is not (a named
RED on S4, B17/B18).
| S5 doctrine | `scheduler-rules.md`, `dispatch-spec.md`, `execution-contracts.md`, `execution-store.md`, `runbook-drain-restart.md`, `hop-liveness-watchdog.md` | **legacy (documentation)** | six doctrine docs present under `docs/`; presence is existence, not invocation — no unit reads them at runtime |

**Ordered admission procedure (B16).** The composed decision sequence, in
order of authority:

1. **Mode precedence** (`admission_mode.go:98-107` `admissionModeFor`): a project-level
   `cooldown`/`tasks` mode wins; otherwise the namespace's mode wins; otherwise **cooldown**.
   `admissionModeForProject` (`:112-129`) re-reads the same precedence from the DB for post-tick
   paths.
2. **Board ownership** (`boardOwnedByLane`, `:177-184`): an explicit `BoardOwnershipOwner`/
   `BoardOwnershipShared` override wins; otherwise the filesystem derivation (`laneOwnsBoard`,
   workdir containment, `:143-184`).
3. **Board workability** (`tasksAdmissionDue`, `:230-243`): for a tasks-mode lane, a `workable > 0`
   owned board grants the **cooldown waiver**; an empty workdir (`:231-232`), a non-owned board
   (`:234-236`), or an unreadable board (`:238-240`) returns false — which falls the lane back to
   its cooldown pin, **not an outright dispatch refusal** (the fail-open doc at `:222-229`). This
   predicate decides the waiver only, and `packer_select.go` performs the actual gates and
   cooldown decision on top of it.
4. **Last-tick failure** (`lastTickStatusFailed`, `:266-267`): a project whose
   `last_tick_status='failed'` stands the tasks-mode waiver down — the next tick paces on the full
   effective cooldown instead of re-admitting (SCHED-GAP-214).
5. **Usage-pool reservation** (`usage_pool_policy.go:26-63` `reserveUsagePools`). The boolean/error
   pair has **distinct outcomes (B14)**: a *disabled* policy (`!policy.Enabled`) returns
   `(false, nil)` with no reservation and no refusal (enforcement off); a *nil DB authority*
   returns a **named authority-unavailable error**, not `(false, nil)` (`:26-30`); a missing/invalid
   `host_id` or empty pool set returns `ErrUsagePoolMissing`; a denied reservation emits a capacity
   event and returns `(false, nil)` (`:67-74`) — a *capacity denial*, distinguishable from disabled
   enforcement; remote lanes append `host:<id>`, local lanes append `LocalPoolID`; `ObserveOnly`
   checks without reserving; otherwise lease recovery runs, then `ReserveAll` enforces the
   reservation. A nil authority and a disabled enforcement are different outcomes with different
   caller obligations.
6. **Board-stasis gate** (`internal/scheduler/packer_select.go:474` `boardStasisBlocks(m.boardStasisGate, …)`, also `:614` `boardStasisBlockedQuiet`): a cooldown-mode **BUILDER** lane whose board file has not changed since its previous completed tick (mtime+size+content-digest fingerprint) is excluded from selection — no cooldown consumed. Tasks-mode and reporter-class lanes are exempt; an **unreadable board fails open** (the lane is not blocked); an operator `ForceEvaluate` bypasses it for one pass. Flag `board-stasis-gate` default **true** (`cmd/schedulerd/main.go:150`, SCHED-GAP-1678).
7. **Load gate** (`internal/scheduler/load_gate.go:63` `loadGateActive()`; threshold installed by `SetLoadGateThreshold` `:38`, flag `load-gate-threshold` default **0** at `main.go:144`): when enabled and the 1-minute load average is at or above the threshold, new spawns are **deferred, not dropped** — work runs once load falls. Namespaces opt out via `load_gate='off'` (`namespaceLoadGateOff`, `:93`); an unknown/empty namespace or a DB error does **not** opt out (the gate applies), and a missing telemetry reading fails open. 0 = disabled (SCHED-GAP-125).
8. **NOOP-PACING (F9-9)** (`internal/scheduler/packer_select.go:395` `tasksNoopStreakDeferred(pu.Project.NoProgressTicks, pu.Project.CooldownFloorS, &lt, now)` → `continue`, with `noteNoopPacing` (`:396`) and `tasksNoopCooldown` (`:397`) logging; the arithmetic lives in `internal/scheduler/noop_pacing.go:59` `tasksNoopCooldown` / `:74` `tasksNoopStreakDeferred`): a **tasks-admitted** lane that produces no artifact of its own work is not work-driven — it is spinning. N consecutive no-artifact ticks (outcome `dry_run` with `commits=0` and `files_changed=0`) space the next admission by the lane's own `cooldown_floor_s`, doubling per consecutive no-op tick up to 8× the floor (`database.AdaptiveCeilingFloorMultiplier`, `noop_pacing.go:39`); the first no-op already costs the full floor. Any artifact resets the streak to 0 and restores the plain cooldown waiver. This closes the measured defect (live 2026-11-06, task-router-foreman): 76 spawns/day, 63 `dry_run` with `admit_reason='early'`, 50/75 inter-spawn gaps under 5 min, while `projects.no_progress_ticks` stayed 0 because its only writer runs behind the opt-in `adaptive_cooldown` check the lane had at 0 — the no-op tick burned nothing, reset no counter, and re-admitted on the 60 s pacing floor alone (`noop_pacing.go:10-30` documents the measured defect). The stand-down is **distinct** from SCHED-GAP-214 (which stands the waiver down only after a *failed* tick — `last_tick_status='failed'`): a `dry_run` completes CLEANLY and never reaches that path.

**Durable-state store keys (B17).** The 30-table store's run-correctness
keys and their relationships, at `internal/database/migrations.go`:

| Table | Locator | Key / guarantee |
|---|---|---|
| `tick_dispatch` | `:1217-1232` | `tick_id` PRIMARY KEY; `lane, agent, corr_id, message_id, transport, state, reply, error`; indexes on `corr_id`, `message_id`, `state` — the dispatch receipt |
| `execution_runs` | `:1391` (+`recovery_idx :1410`) | one row per run, `state` + `updated_at` for recovery |
| `workspace_leases` | `:1412` (+`one_writer_idx :1423`) | **single-active-writer** unique index — the workspace ownership guarantee |
| `execution_attempts` | `:1427` (+`step_gen_idx :1970`) | attempt generation; `step`/`gen` uniqueness (`execution_attempts_step_gen_idx`) |
| `execution_events` | `:1449` (+`run_idx :1458`) | per-run event sequence (`run_id, event_id`) |
| `verification_receipts` | `:1460` | per-attempt verification receipt |
| `execution_projections` | `:1470` | **per-destination projection/sync state** (NOT the materialized run state): `PRIMARY KEY(run_id, projection)`, `projection ∈ {task_router, duckbrain, board, notification}`, storing `state`, `idempotency_key`, `payload_digest`, `remote_id`, `attempts`, `last_error` — delivery state per sink, distinct from `execution_runs`' authoritative lifecycle (B16) |
| `execution_outbox` | `:1479` (+`pending_idx :1489`) | durable-delivery queue, pending by `state, available_at, created_at` |

Relationship: a run (`execution_runs`) has 1:N attempts (`execution_attempts`) and 1:N ordered
events (`execution_events`); the projection is the per-destination delivery/sync state; the outbox is the
durable-delivery queue; the workspace lease is the single-active-writer boundary. The write
authorities and recovery queries per table are not yet written — the keys, their uniqueness
guarantees and their relationships are.

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| Go toolchain | `go 1.26.0` + `toolchain go1.26.10` (`go.mod`) | build host | `GOTOOLCHAIN=auto` auto-selects 1.26.10 (build PASS); with `GOTOOLCHAIN=local` the 1.26.5 host would be below the toolchain directive |
| SQLite (scheduler.db) | via `modernc.org/sqlite v1.60.1` | control host | DB open failure |

**4b. Library contracts**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `modernc.org/sqlite` | external | the CGo-free SQLite driver backing `scheduler.db` | a driver change breaks the 30-table store |
| `BurntSushi/toml` | external | `config.example.toml` parsing | a config-key change breaks lane config |

**4c. Service contracts** — see §6.

## 5. Settings register

**Binary defaults (B18/F9-3).** The daemon's actual flag defaults are in
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

**Auxiliary / routing / lifecycle flags (default + consequence, expanded (B15)).** The remaining 33 of the 57, with the consequence column filled per row from the flag help text at `cmd/schedulerd/main.go:102-208`:

| Setting | Default | Governs | Consequence if changed |
|---|---|---|---|
| `tls-cert` / `tls-key` | `""` (`:102-103`) | HTTPS listener pair | both set → TLS on; one without the other → no usable cert |
| `public-url` | `""` (`:107`) | advertised daemon URL | affects self-links in status/dashboards |
| `test-verify` | 0 (`:174`) | verification self-check | non-zero runs a verification pass at boot |
| `verify-board` | `""` (`:175`) | board-consistency self-check | names a board to verify at boot |
| `session-reap-threshold` | `DefaultHermesReapStaleAfter` (`:176`) | stale-session age floor for `--reap-sessions` | a lower threshold reaps fresher sessions |
| `reap-sessions` | false (`:177`) | one reap pass against `state.db`, then exit | **dry-run by default** — writes nothing without `--reap-sessions-apply` |
| `reap-sessions-apply` | false (`:178`) | apply the reap pass (`ended_at` + `end_reason='reaped'`) | **the mutation switch** — true closes selected sessions; without it the pass is a dry-run (SCHED-GAP-089) |
| `session-db` | `DefaultHermesSessionDBPath()` (`:179`) | which `state.db` `--reap-sessions` reads | a wrong path reaps (or fails to find) the wrong store |
| `duckbrain-ns` / `duckbrain-url` / `duckbrain-interval` | `"scheduler"` / `http://localhost:3000` / `5m` (`:180-182`) | DuckBrain sync target + cadence | a wrong URL/interval stops the sync spool |
| `simulate` | false (`:183`) | **dry-run mode — no real spawning** | true suppresses real spawns; the sim-* knobs only take effect with it |
| `sim-success` / `sim-idle` / `sim-count` | 0.85 / 0.0 / 0 (`:184-186`) | simulated outcomes | only meaningful under `--simulate`; `sim-count N` generates N synthetic ticks then exits |
| `gateway-url` / `gateway-key` | `http://127.0.0.1:8642` / `$API_SERVER_KEY` (`:187-188`) | the gateway endpoint + key | a wrong URL/key makes every foreman turn fail. An empty `gateway-url` does **not** alone authorize `exec.Command` fallback: the fallback requires `no-exec-fallback=false` (default **true**, `:190`); with the default, a nil gateway client **DEFERS the tick** (transport deferral, `spawn.go:698` `transientGatewayDeferral` def, call site `:1759`, not a lane failure) rather than exec-spawning — the two controls interact (B17) |
| `model-rates-file` | `$SCHEDULER_MODEL_RATES_FILE` (`:189`) | price-sticker JSON applied over builtin rates | a wrong sticker file re-prices the cost model (ADV-R09/G8) |
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

The consequence column is now filled for all 33 (from the flag help text at `main.go:102-208`).
`--simulate` (`:183`) suppresses real spawning and the `--auto-disable-*` trio (`:196-198`) drives
a `projects.enabled=0` write — both are admission/execution controls. The residual RED is that the
*reader* and *precedence* of each flag (env override → TOML → flag) are documented for the group
but not re-verified per flag.

**Load correction (F9-3).** The `[daemon]` / `[gateway]` /
`[duckbrain]` root sections are loaded at boot: `config.LoadRootConfig(*configFile)` is called
ten times at daemon boot
(`cmd/schedulerd/main.go:640, 673, 762, 854, 870, 968, 995, 1023, 1054, 1309`), and
`internal/config/loader.go` implements the three-layer merge: (1) struct defaults, (2) the TOML
file, (3) `SCHEDULER_*` environment overrides (`applyEnvOverrides`). The only true residue is that
`config.example.toml`'s header NOTE is stale — a board row against the example file, not a
statement about the daemon.

## 6. Contracts in and out

Canonical ids are the register of record (OUTLINE Part IV, CT-01..CT-18). Local ids are
retired; each row carries the CT id its peer chapter cites, so two ends can be matched.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-01 | owner | in | **operator config (boundary)** — a human writes `fleet.toml` + `scheduler.db` project rows (lane enabled/cadence/weight/pin); there is no producer function (the load path `config.LoadRootConfig`, called at `main.go:640,673,762,854,870,968,995,1023,1054,1309`, is the consumer's loader, not a producer) | `internal/scheduler/admission_mode.go:112` `admissionModeForProject` (reads the lane's admission mode from the DB) | **UNVERIFIED (boundary)** — the consumer is nameable; the producer is a human writing config, not a function (CT-01 is a boundary contract, not internal) |
| CT-02 | crier | out | `internal/bus/dispatch.go:175` `payload()` emits `text_b64` (base64 at line 202), field **`board`** (not `board_row`) | crier `internal/registry/handler.go:990` `HandleDeliver` | **works** — CF-354 fixed and closed (commit `1f1c0fe`); crier delivers the envelope verbatim; the former `text`/`text_b64` mismatch was node-side consumption |
| CT-06 | crier | in | `dispatcher.py:500-508` builds the completion reply `{in_reply_to, agent, ok, …}`; transported via crier `internal/registry/handler.go:990` `HandleDeliver` into the scheduler's inbox | `internal/scheduler/dispatch_leg.go:713` `dispatchReplyVerdict` reads only `payload["ok"]` | **works (dispatcher leg)** — the dispatcher always sends `ok` (`dispatcher.py:501`), the exact field `dispatchReplyVerdict` reads. CF-355 (the node's `status` reply scoring success-on-failure) is the **node-reply** leg, carried at CT-04, not this producer |
| CT-05 | foreman | in | `scripts/load_lane_config.py:31-37` (reads `prompts/*.md` → `UPDATE projects SET prompt=?, prompt_mode='append'`) | `internal/scheduler/spawn.go:1249` `buildForemanPrompt` (namespace default → project replace/append → dynamic footer; the builtin prompt text instructs "read your own board with `board_read.py`" and "unblock before you block", `spawn.go:1208-1214`) | **UNVERIFIED** — both ends are in-repo (internal, B3); the OUTLINE VIII.1 "3 of 11 prompt files disagree" breakage is **unmeasured** (no command establishes which three files disagree or on what) |
| CT-15 | foreman | out | **external** — the foreman lane's decision/finding/goal writes (out of scope) | **external** — the duckbrain service (out of scope) | **UNVERIFIED (boundary)** — neither side has an in-repo `file:function`, and the wire was not measured; an outline "works" annotation is not implementation evidence (B03) |

CT-01 and CT-15 are boundary contracts: the owner is a human and duckbrain is a service outside
the five covered systems, so the covered side is named and the far side is marked external. The
state for a boundary contract with no measured wire is **UNVERIFIED**. CT-05 is **internal** (both
ends are in-repo files), so its row names both `file:function`; its state is UNVERIFIED because the
"3 of 11 disagree" breakage was never measured, not because a side is external.

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| build | `go build ./...` (scheduler repo) | exit 0 | 2026-11-07, rev `6606f856` | **PASS** (rc 0) |
| durable state | `sqlite3 ~/.hermes/coding-hermes/scheduler.db '.tables'` | tables listed | 2026-11-07 | **PASS** — 30 application tables (`.tables`); no `verdicts` table. `sqlite_master WHERE type='table'` = 32 (the 2 extra are SQLite-internal, not application tables) |
| go test (clean env) | `env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./...` | green | 2026-11-07, rev `6606f856` | **FAIL (1 package)** — `internal/scheduler` (the main package) passed in 246.9s; `internal/api` FAILed `TestPERF001R2StatusPassAB` (a load-sensitive perf A/B: in-window `/api/v1/status` max 2.79s vs 1.65s budget) while this suite ran concurrently with the crier suite and the rest of the verification. The test passes in isolation (`-run 'TestPERF001R2StatusPassAB' -count=1` → `ok 0.646s`), so the failure is a load-window flake, not a code regression (F9-10). 24 of 25 packages ok |
| go test (three env-sensitive tests) | `env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./internal/scheduler/ -run 'TestSCHEDGAP091_DrainTimeoutStampsOrphan|TestOperatorRestartApprovalEnv|TestAbortInFlightTicks_OperatorApprovedStamp' -count=1` | green | 2026-11-07, rev `6606f856` | **PASS (rc 0)** — 0.247s |

**Env-contamination correction (F9-6).** A `go test ./...` FAIL naming
`SCHED-GAP-1726 goroutine census: 1 goroutine(s) still parked in evalDrain at suite exit` is an
artifact of the shell carrying the ambient `SCHEDULER_OPERATOR_RESTART_APPROVED=1`
(the var is load-bearing in `internal/scheduler/restart_approval.go` and
`schedgap1608_operator_restart_test.go`, and this shell reports it =1). With the var **unset** the
three operator-restart tests pass in 0.409s and the full suite is green (25/25).

## 8. Metrics

**Measured — real, not RED.** The scheduler serves `GET /api/v1/metrics`
(`internal/api/server_metrics.go`) with blocks `spawns`, `deferrals`, `nudges`, `ticks`,
`tick_duration_ms`, `gateway`, `outcomes`, `stalls`, `escalations`, `lane_churn`,
`dispatch_inbox`, each carrying an `available: true|false` honesty shape and a per-block source in
`metricsSources()` (`:125`). `metricsWindow` is 24h (`:42`). **Semantics (B22):**
`deferrals` is a per-process SCHED-GAP-155 admission counter, monotonic since daemon boot and
**reset by a restart** (no persisted equivalent) (`:132-136`); `spawns` is read from the `ticks`
table joined to `projects` (`:127-130`). **Locator correction (F9-4):** `metricsSpawns` is the
`func` keyword at `:195`, not `:192` (which is the doc comment).

## 9. Log lines (verbatim)

**Scope, stated.** This is the settlement/batch-dispatch surface, **not** a full
inventory. The control plane has **382** `log.Printf` call sites
(`grep -rn "log.Printf" internal/scheduler/*.go | wc -l` = 382, measured; 3 of the sites are in
the NOOP-PACING path). The two rows
below are the settlement/batch-dispatch lines; the remaining **380** sites are uncovered and are
the named RED on this field — not a "sample" claimed as complete.

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `DISPATCH: %s tick=%s agent=%s corr=%s message=%s transport=%s wall=%s lane_ref=%s board_ref=%s` (`dispatch_leg.go:252`) | a dispatch is issued | evidentiary |
| — | `DISPATCH: <proj> tick=<id> inbox seen=<n> correlated=<n> uncorrelated=<n> keys=<csv> acked=<n> deferred=<n>` (`:456`) | one per retrieve batch | evidentiary |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Silent success | pass for a `status:"failed"` reply | a real pass | **OPEN** — CF-355 (`dispatch_leg.go:713-726`) |
| `text_b64` undecodable | the node refuses the dispatch (`node-bus-worker.py:1022-1034`) | a malformed envelope | **resolved** — CF-354 (complete): the node decodes `text_b64` first |
| Deadline expiry | `DispatchStateExpired`, `TickTimeout` (`:291-314`) | a failed reply (`TickFailed`, `:316-325`) | the reply is PARTIAL, named `dispatch_deadline` |
| No authoritative lane inventory | 8 vs 16 vs 1 lanes across three modules | a single census | **OPEN** — CF-335 |
| Env-contaminated test | the operator-restart tests FAIL only when `SCHEDULER_OPERATOR_RESTART_APPROVED=1` is ambient | a code break | unset the var (`env -u … go test`); F9-6 |

## 11. Limits and margins

- The reply await is bounded by the same session deadline the node got as `limits.wall_s`
  (`:255-260`); the wall is printed because it decides both the node's budget and the await.
- `dispatchReplyVerdict`'s documented premise is "absence of a verdict is SUCCESS" (`:709-712`) —
  the exact place a `status` field is ignored.
- **Admission authority (B19).** `admission_mode.go:143-184`
  `laneOwnsBoard` derives board ownership from the filesystem (workdir containment);
  `boardOwnedByLane` is **defined at `:177`** (doc comment `:173`), honours an explicit
  per-project override (`database.BoardOwnershipOwner`/`Shared`) before falling back to the
  filesystem derivation, and is **called at `:234`** inside `tasksAdmissionDue`. Operator mutation
  auth is in `internal/api/auth.go:187-197` `extractBearerOrHeaderToken` (Bearer or
  `X-Operator-Token` header).

## 12. Cross-references

- F11 SCHEDULING ADMISSION is the primary flow; F1 DISPATCH AND SETTLEMENT is its terminal half.
- M10 CRIER is the transport (CT-02/CT-04 on its side; CT-03/CT-06 are the node/scheduler ends).
- M2 DISPATCH (node side) and M11 DISPATCHER are the two inbox consumers.
- M4 BOARD rows gate admission (S1); see M4 §12 for the M9-only ownership of that gate.

## 13. Evidence of record

- Code read: `internal/scheduler/dispatch_leg.go` (`:245-364`, `:700-759`), `internal/bus/dispatch.go`
  (`:170-214`), `internal/scheduler/admission_mode.go` (`:98-129, 143-208, 230-267`),
  `internal/scheduler/usage_pool_policy.go:26-63`, `cmd/schedulerd/main.go:95-200`,
  `internal/api/auth.go:187-197`, `internal/api/server.go:289-346`, `internal/api/server_metrics.go:125-136, :195`,
  `config.example.toml` (full), `internal/database/migrations.go` (grep: `:1217-1232, :1391-1489, :1970, :2036`),
  `internal/scheduler/noop_pacing.go` (full — 149 lines, NOOP-PACING), `internal/scheduler/packer_select.go:385-400` (the no-op gate insertion), `internal/scheduler/spawn.go:1208-1214, :698, :1249, :1759`.
- Commands run: `go build ./...` (PASS); `env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./...`
  (FAIL 1/25 — `internal/api` `TestPERF001R2StatusPassAB`, load flake; `internal/scheduler` passed 246.9s); the three env-sensitive tests (PASS, 0.247s); the flaky perf test in isolation (`ok 0.646s`);
  `grep -n 'LoadRootConfig' cmd/schedulerd/main.go` (10 sites);
  `grep -rn "log.Printf" internal/scheduler/*.go | wc -l` (382); `grep -cE 'flag\.(String|Int|Int64|Bool|Duration|Float64)' cmd/schedulerd/main.go` (57);
  `sqlite3 … '.tables'` (30 tables); `grep -n 'func tasksNoop' internal/scheduler/noop_pacing.go` (`:59/:74/:94`); `git diff --stat 34e44897..HEAD`.
- Revision: `6606f856` (moved from `34e44897` through 15 commits; cited files byte-identical except `packer_select.go` +12, `spawn.go` +7, and the new `noop_pacing.go`).
- Board rows: CF-334, CF-335, CF-337, CF-343, CF-346, CF-353, CF-354, CF-355.
- **Findings:**
  - **F9-1** (carried) — settlement exists (`dispatch_leg.go:260-336`); the real defect is CF-355.
  - **F9-2** (carried) — 30 application tables, not 26; no `verdicts` table (32 in `sqlite_master`, 2 internal).
  - **F9-3** (corrected) — `LoadRootConfig` IS loaded at boot (`main.go:640,673,762,854,870,968,995,1023,1054,1309`), three-layer merge in `loader.go`. The only residue: `config.example.toml`'s header NOTE is stale.
  - **F9-4** — `metricsSpawns` is at `:195`, not `:192`.
  - **F9-5** (carried) — binary defaults are 30s/10/false (`main.go:108/:112/:113`); the six
    previously-unlocated settings now carry locators (`:122, :128, :138, :142, :143, :145`).
  - **F9-6** (carried) — the `go test ./...` FAIL was env contamination, not a code break; clean-env PASSES (25/25).
  - **F9-7** (new, B16/B17) — the ordered admission procedure and the run-correctness store keys
    are written (see §3 note).
  - **F9-8** (new) — the repo moved `34e44897`→`6606f856`; `packer_select.go` +12 and `spawn.go` +7 shifted the board-stasis (`:462/:602`→`:474/:614`) and `buildForemanPrompt` (`:1244`→`:1249`) locators; `transientGatewayDeferral` re-pinned to def `:698` / call `:1759`.
  - **F9-9** (new) — NOOP-PACING is a new admission step (`packer_select.go:395`, `noop_pacing.go:59/:74/:94`); a tasks-admitted lane producing no artifact is spaced by `cooldown_floor_s` (doubling, 8× cap) — closing the measured 76-spawns/day dry-churn defect.
  - **F9-10** (new) — the full suite now FAILs `internal/api` on `TestPERF001R2StatusPassAB` under concurrent load (max 2.79s vs 1.65s budget); passes in isolation (0.646s) — a load-window flake, not a regression.

## RED field count: 5 (§9 log inventory 2 of 382 sites — the remaining 380 are the named RED, not a "sample"; §3 S1 grep-level (`tick_process`/`packer_select`/`namespace_alloc` not line-by-line — `noop_pacing.go`/`packer_select.go:385-400`/`spawn.go` ARE read); §5 the auxiliary-flag reader/precedence not re-verified per flag (the consequence column is now filled); S4 per-route contract not written — B18; S3 write authorities/recovery queries not written — B17)
