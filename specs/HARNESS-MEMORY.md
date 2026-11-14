# HARNESS-MEMORY — how each harness hands its run to DuckBrain

Status: **PARTIAL — the repository-local fixture and node exporter are implemented; live runtime capture and DuckBrain transport remain UNVERIFIED.**
`scripts/harness/harness_memory.py` is the shared writer/reader used by every row in
`tests/harness-conformance.sh`'s memory leg and also provides the HTTP adapter seam. The node writes
R1 then R2, reads each back by exact key, requires an explicit namespace and mode-600 token file, and
returns a named `UNVERIFIED` result rather than claiming success when transport is unavailable. The
conformance fixture remains repository-local evidence, not live support evidence.

The target shared `factory` namespace remains distinct from the temporary per-project `CF_NAMESPACE`
used before CF-208 token scoping is fixed; R1 is written to `CF_NAMESPACE`, while R2 is written to
`factory`.


This page is the per-harness half of `specs/FLEET-MEMORY.md`: that page defines the records (R1/R2/R3),
this one defines how each harness produces them.

## 1. The one rule that makes the rest possible

**The scheduler's `run_id` is the identity; no harness's own id is.** `specs/TRACE.md:42` mints it per
attempt. Every harness mints its own id and does not accept one from outside, with exactly one
exception (Hermes, below). So each adapter must do one of two things and say which:

| approach | when | consequence |
|---|---|---|
| **set** the harness's id to the run id | only Hermes can (`POST /api/sessions {"id": …}`) | one id, no mapping table |
| **stamp and map** | codex (`--thread-source`), claude-code (`--session-id` = uuid5(run_id)), opencode (`POST /session` metadata) | two ids in the record, joined by `run_id` |
| **map only** | pi, dsh (ids cannot be set or stamped) | the mapping lives only in the record; a lost record loses the join |

A harness that can do neither a stamp nor a set is still supported — it just carries the weak form, and
the adapter must say so rather than pretending the join is exact.

## 2. The record every adapter writes

R1 and R2 exactly as `specs/FLEET-MEMORY.md:28` and `:38` define them. Two fields are harness-specific
and are the only place a per-harness difference is allowed to appear:

| field | why it is per-harness |
|---|---|
| `session_id` | the harness's own id, kept so a human can open the native store |
| `session_id_basis` | `set` \| `uuid5(run_id)` \| `stamped:thread_source` \| `metadata` \| `map-only` |

Everything else — `run_id, project, lane, week, harness, harness_version, model_requested,
model_served, provider_binding, commit, tick, board_row, outcome, artifact_digests, started_at,
ended_at, node` — is uniform. `outcome` is never blank; a missing record is indistinguishable from a
run that never happened (`specs/FLEET-MEMORY.md:87`).

## 3. Per-harness capture

### 3.1 Hermes — the only harness whose session id can BE the run id

| | |
|---|---|
| store | `~/.hermes/state.db` (SQLite, WAL): `sessions`, `messages`, `session_model_usage` |
| identity | **exact**: `POST /api/sessions {"id": "<run_id>"}` then `POST /api/sessions/<run_id>/chat`; also `hermes -z … --usage-file <path>` writes a per-run usage JSON |
| capture | read the store read-only (`?mode=ro`, measured 1.4 ms session / 18.1 ms message census / 7.3 ms usage) or `GET /api/sessions/<id>/messages` for the transcript |
| gaps | `sessions.ended_at` is NULL for **all 189,012** `api_server` sessions; `git_branch` empty for oneshot/cron/api_server; `messages.token_count` is always 0; `estimated_cost_usd` is `0.0` with `cost_status='unknown'` on subscription lanes — **unknown, not free** |
| trap | token totals must filter `task=''`; `title_generation`/`approval`/`background_review` rows double-count a run |
| status | no exporter exists; `~/.hermes/scripts/daily_telemetry_extract.py` is day-aggregate only and its cron job is disabled |

### 3.2 Codex — stamped through a free-form field

| | |
|---|---|
| store | `$CODEX_HOME/sessions/YYYY/MM/DD/rollout-<ts>-<session_id>.jsonl` (append-only JSONL) + `state_5.sqlite` `threads` as an index with `rollout_path` |
| identity | **cannot set**; `codex exec --thread-source "<run_id>"` lands verbatim in `session_meta.thread_source` (verified on both the success and failure paths) |
| capture | post-process the rollout at run end — it carries `model_served` (`thread_settings_applied`), usage (`token_usage_record`), git (`session_meta.git`), and the artifact surface (`item_completed` → `FileChange.changes`) |
| gap | no USD cost anywhere in a rollout (only `rate_limits` percentages) |
| trap | **`scripts/harness/install-codex.sh:439-444` deletes the evidence**: its `trap cleanup EXIT` does `rm -rf "$turn_home"`, removing `sessions/` and both SQLite files before an exporter could read them |
| status | no exporter; the rollout is thrown away on every turn today |

### 3.3 Claude Code — computed id, result object for cost

| | |
|---|---|
| store | `~/.claude/projects/<slug(cwd)>/<sessionId>.jsonl` (slug = cwd with every char outside `[A-Za-z0-9_-]` replaced by `-`) |
| identity | `--session-id <uuid>` sets the id on a fresh run (the CLI validates UUID shape), so the wrapper computes `uuid5(namespace, run_id)` and records both |
| capture | `--output-format json` returns one result object with `session_id`, `modelUsage{model → tokens+costUSD}`, `num_turns`, `duration_ms`, `terminal_reason`; then copy the transcript from the path predicted before the run |
| gap | the `result` object is absent exactly when a run dies — the transcript copy is what covers failure, which is why both are required |
| trap | hooks cannot be used: the adapter runs `--bare`, and `--bare` skips hooks unconditionally (`SessionEnd` also has a 1.5 s default budget, too tight for a network write) |
| status | no exporter; cost is a client-side estimate and must be labelled `cost_basis` |

### 3.4 OpenCode — metadata stamp in a real database

| | |
|---|---|
| store | `~/.local/share/opencode/opencode.db` (SQLite, 21 tables): `session`, `message`, `part`, `event`; `part.data` is typed (`text`, `reasoning`, `tool` with `state.input/output`, `step-finish` with tokens+cost) |
| identity | `POST /session {"metadata": {"run_id": …}}` persists into `session.metadata` (verified round-trip on an isolated DB); the CLI has no `--metadata`, so CLI-only runs can only stamp `--title "run:<id>"` |
| capture | DB read (`?mode=ro` while the app holds it; or `opencode db "SELECT …" --format json`); `opencode run --format json` is a progress feed, not an export |
| gap | v2 has **no artifact** (npm `opencode2` is `0.0.1-security`), so only the v1 schema can be specified — the adapter must version-gate on `session.version` |
| status | no exporter; 163 sessions / 4,522 messages already on this host and none of it recallable |

### 3.5 Pi (oh-my-pi / omp) — strong journal, weak identity

| | |
|---|---|
| store | `~/.omp/agent/sessions/<encoded-cwd>/<timestamp>_<sessionId>.jsonl`, a tree via `parentId` |
| identity | **cannot set** (no `--session-id`; `PI_SESSION_ID` is only exported to bash-tool children) — map-only |
| capture | `-p --mode json` emits a session header plus JSONL events; per assistant message the journal records `provider`, `model`, `usage.cost`, `stopReason`, so `model_served` is real |
| gaps | a session is **memory-only until its first assistant message**, so a run that dies early persists nothing — the adapter must record that as a FAIL, not as missing data; a contested session can move to a new id; `secrets.enabled` is off by default so transcripts can contain credentials |
| status | source-read only (not installed here); no adapter, no exporter |

### 3.6 DeepSeek Harness (dsh) — a plugin seam, one irreducible gap

| | |
|---|---|
| store | event-sourced: `<root>/--<cwd>--/<id>/session.v4.jsonl.zstd` at pinned `0.2.1-rc.5` (**measured** — CF-226 installed the pin and read the record; the earlier v3 path in this row was a source-read of a different revision), one JSON event per line, `flock`, fsync per batch |
| identity | `--session-id` **adopts** an existing session only; a fresh id cannot be set — map-only |
| capture | two options: (a) the `SessionTelemetryBackend` seam (`emit`/`flush`/`shutdown`) mounted via `dsh --patch overlay.yml` — no fork; (b) wrapper capture of `--json`, which is explicitly "a projection, not the log" and truncates at 8 KiB/string |
| gap | **`model_served` cannot be separated from the request**: `normalizeModelInfo` throws unless `resolved.id === model`, so dsh logs ONE model id. **Measured** at the pin: `assistant/message` → `data.message.source{kind:"model", provider, model}` and `request/header` → `config{provider, model}` carry the same id, and `--json` carries none at all — so `install-dsh.sh --turn` prints `model_requested` beside a model it labels **recorded**, never "served". `baseURL` never enters the log, so a shim is invisible in `provider_binding` |
| what IS in the record (measured) | `turn/end` → `reason.kind` (`completed` / `error` + message), `request/header` → `header.tools[]` (25 tools in the measured headless run), `permission/preset` + `approval/policy` + `sandbox/mode` (`workspace-write` / `ask` / `workspace-write`) |
| status | **installer measured** (`scripts/harness/install-dsh.sh`, one real turn); no adapter and no exporter, and no crier adapter by recorded decision (`specs/HARNESS.md` §"dsh — the adapter decision") |

## 4. What every adapter must do — five behaviours, not four

1. **Stamp or set** the run id, and record which (`session_id_basis`).
2. **Capture on both paths.** Success alone is not export. A killed run must still produce a record
   with `outcome: FAIL` — from the transcript/rollout/db that exists at kill time.
3. **Read the native store, not the stream.** Every harness's event stream was measured to be a lossy
   projection; the store is the record of record.
4. **Refuse to invent.** No USD cost where the harness has none; no `model_served` where the harness
   cannot distinguish request from service; no digest the adapter did not compute.
5. **Write R2 last.** R1 first (the detail), then the index. An index entry pointing at an R1 that was
   never written is worse than no index entry: it is a broken promise that looks like coverage.

## 5. Verification — the `memory` conformance leg

`tests/harness-conformance.sh` implements the `memory` fixture for every named adapter in its
`HARNESSES` table. The fixture invokes only `scripts/harness/harness_memory.py`, the shared I3 writer
and reader; it uses an explicit file backend and never contacts DuckBrain. It proves:

    memory fixture — for each named adapter:
      1. the canonical record contains all ten non-empty I3 fields
      2. writing and reading back produces byte-identical canonical UTF-8 JSON
      3. missing, default and mismatched namespaces fail before a backend file is written
      4. the row names the adapter and the fixture-only boundary
      5. the runtime leg is explicitly `UNSUPPORTED` when no exporter supplies complete provenance

This fixture is repository-local wiring evidence, not a real-node or live-DuckBrain claim. A future
runtime adapter must preserve the same writer validation and byte comparison, then add a separately
measured live row. Missing runtime capture must remain an explicit unsupported result rather than a
silent skip.

## 6. Traps that will be hit in that order

| harness | trap | consequence if missed |
|---|---|---|
| codex | `install-codex.sh:439-444` removes `$turn_home` on EXIT | the exporter runs against a deleted directory |
| claude-code | `--bare` disables hooks | a hook-based exporter never fires |
| pi | session is memory-only until the first assistant message | an early failure exports nothing at all |
| dsh | `--json` truncates at 8 KiB/string | the record is silently incomplete |
| hermes | `estimated_cost_usd = 0.0` with `cost_status='unknown'` | the fleet ledger reports free compute |
| opencode | v2 does not exist | an adapter written for v1 is called "v2 support" |

## 7. Inherited defects

| id | what | effect here |
|---|---|---|
| CF-208 | the DuckBrain token is not namespace-scoped | R2's isolation holds only after this |
| CF-276 | `node-create.sh` does not stage `node-bus-worker.py` | the writer may not exist on a fresh node |
| CF-328 | the conformance spec demands five legs, the battery implements three | no adapter can be called supported |
| CF-285 | `lib.sh have()` cannot report absence | a missing capture binary reads as present |
