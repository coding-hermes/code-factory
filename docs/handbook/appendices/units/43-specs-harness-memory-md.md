# 43. specs/HARNESS-MEMORY.md

| Field | Value |
|---|---|
| Path | `~/code-factory/specs/HARNESS-MEMORY.md` |
| Repository | `code-factory` |
| Revision | `3d54355` |
| Status | **RED — six harnesses researched, zero adapters export anything** |

## 1. Purpose and why it matters

`specs/FLEET-MEMORY.md` says what a run record is; this page says how each of the six harnesses
produces one. Without it every adapter invents its own capture, and the fleet ends up with six
incompatible notions of "a run happened".

What breaks if it is ABSENT: the fleet cannot compare harnesses at all — a run's cost, its served
model, whether it even finished, are measured differently by six tools that each think they are the
only one. What breaks if it LIES: a record claiming `model_served` when the harness can only echo the
request turns a routing bug into a documented fact.

The research that produced it was six passes over the installed binaries, their on-disk stores and
their upstream source, done on 2026-11-05. Five of the six harnesses were audited from their own
storage; pi and dsh were source-read because they are not installed here, and those sections say so.

## 2. Dependencies and library contracts

Per harness, the store that must be read and the seam that must be written
(`specs/HARNESS-MEMORY.md:44`, `:83`, `:101`, `:121`, `:141`, `:161`):

| harness | store of record | identity seam | capture seam |
|---|---|---|---|
| hermes | `~/.hermes/state.db` (sessions/messages/session_model_usage) | `POST /api/sessions {"id": run_id}` — exact | read-only sqlite, or `GET /api/sessions/<id>/messages` |
| codex | `$CODEX_HOME/sessions/**/rollout-*.jsonl` | `--thread-source <run_id>` (verbatim) | post-process the rollout |
| claude-code | `~/.claude/projects/<slug>/<sessionId>.jsonl` | `--session-id uuid5(run_id)` | `--output-format json` result + transcript copy |
| opencode | `~/.local/share/opencode/opencode.db` | `POST /session {"metadata":{run_id}}` | DB read (`?mode=ro`) |
| pi (omp) | `~/.omp/agent/sessions/<cwd>/<ts>_<id>.jsonl` | none — map only | `-p --mode json` JSONL |
| dsh | `<root>/--<cwd>--/<id>/session.v3.jsonl.zstd` | none — adopt only | `SessionTelemetryBackend` plugin, or `--json` (lossy) |

Two of the six carry a structural limitation that the adapter must state rather than paper over:
dsh cannot distinguish `model_served` from the requested model
(`specs/HARNESS-MEMORY.md:97`), and pi keeps a session in memory until its first assistant message,
so an early failure persists nothing (`specs/HARNESS-MEMORY.md:87`).

The uniform fields are `specs/FLEET-MEMORY.md`'s; the only harness-specific ones are `session_id` and
`session_id_basis` (`specs/HARNESS-MEMORY.md:35`), so a reader can always tell whether the join was
exact or a mapping.

## 3. Verification

The conformance leg this page requires is specified at `specs/HARNESS-MEMORY.md:125` — six assertions
per harness, of which the sixth (re-read the native store and compare) is the one that catches a lying
adapter. Today:

| harness | `memory` leg | why |
|---|---|---|
| all six | **RED — no leg exists** | `tests/harness-conformance.sh` implements `check`, `apply`, `smoke` only; `vars` and `memory` have no executor (CF-328) |
| codex | **RED — and the evidence is deleted** | `scripts/harness/install-codex.sh:439-444` removes `$turn_home`, including `sessions/`, on exit |
| claude-code | **RED — hooks cannot fire** | the adapter runs `--bare`, which skips hooks unconditionally |
| hermes | **RED — no exporter** | `scripts/node-bus-worker.py` has no DuckBrain call; `daily_telemetry_extract.py` is day-aggregate and its cron is disabled |

A conformance matrix that cannot run this leg is evidence about three legs, not about support — which
is exactly the defect `docs/master/38-specs-harness-matrix-md.md` records as FAILING.

## 4. Metrics emitted

None. The counts this page makes possible — tokens, API calls, tool calls, cost basis — are record
content, not metrics. The one number worth calling out: Hermes writes **`estimated_cost_usd = 0.0`
with `cost_status='unknown'`** on subscription lanes, so any aggregate that sums the column reports
free compute that was not free (`specs/HARNESS-MEMORY.md:44`).

## 5. Log lines it can generate

No adapter prints them yet. When they exist, the two that matter are the pair that says whether the
join was exact or weak:

```
  PASS  memory — run <run_id> recorded (harness codex, session_id_basis stamped:thread_source)
  WARN  memory — run <run_id> recorded with model_served=unavailable:harness-cannot-distinguish
```

The WARN is not a failure — it is the honest form for dsh, and for any harness where the served model
cannot be proven. The failure is printing it as a PASS with the requested model copied in.

## 6. Failure modes

| failure | direction | consequence |
|---|---|---|
| exporter runs after the adapter's cleanup | **silent** | codex: nothing to read; the run leaves no record |
| hook-based export on `--bare` | **silent** | claude-code: the hook never fires |
| session id not stamped | **fail open** | the record exists but cannot be joined to the dispatch |
| cost written as 0.0 for unknown | **fail open** | the ledger under-reports by design |
| `model_served` echoed from the request | **fail open** | a routing defect becomes a documented fact |
| R2 written before R1 | **broken pointer** | an index entry that promises detail which does not exist |
| transcript copied whole into R2 | **leak** | prompts and tool output (often `.env` contents) land in a shared namespace |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| `run_id` | the envelope (`specs/TRACE.md:42`) | required by every adapter |
| `CF_NAMESPACE` | the envelope | the project namespace for R1 |
| harness store path | the harness | per §2; each adapter discovers it, never assumes one path |
| `CLAUDE_CONFIG_DIR` | claude-code | pinning it also relocates `settings.json` — only pin when the credential arrives via `CF_API_KEY_FILE` |
| `CODEX_HOME` | codex | the adapter already redirects it per run; the same redirect is what deletes the rollout |
| DuckBrain token | `~/.node/auth/duckbrain.token`, mode 600 | path only, never a value (AGENTS.md r8) |

## 8. Evidence of record

- `specs/HARNESS-MEMORY.md` (218 lines) — the per-harness specification, six researched sections.
- `specs/FLEET-MEMORY.md:28`, `:38` — the record shapes this page fills.
- `specs/HARNESS-MATRIX.md:167` — the `memory` leg that has never had an executor.
- `tests/harness-conformance.sh` — three legs measured (5 pass / 7 fail / 9 skip on 2026-11-05).
- `scripts/harness/install-codex.sh:439-444` — the cleanup trap that deletes the rollout.
- Research reports (outside the repo, read-only): `~/code-factory-reports/pi-session-export-duckbrain-2026-11-05.md`
  and `dsh-memory-export-2026-11-05.md`.
- Board: CF-328 (five legs vs three), CF-208 (namespace scoping), CF-276 (worker not staged).

To re-establish this page's status: implement one adapter end to end — hermes is the cheapest, because
its id can be set exactly — then run the six assertions at `specs/HARNESS-MEMORY.md:125` against it.
