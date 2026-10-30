# Scheduler lane verification and sync consumption (CF-022)

## Authority and scope

This is a read-only local verification contract, extending
[SCHEDULER-ADMISSION](SCHEDULER-ADMISSION.md#verification-checklist).
It is not a scheduler, a provisioning mechanism, a fleet policy writer, or proof
of remote execution. NODE.md, ENVELOPE.md and HARNESS.md retain their blocked
remote-integration boundaries. The primary's operator settings are not repair
inputs for this satellite task.

The canonical namespace/cadence matrix is read from the explicitly supplied
scheduler invariant checker's literal constants. Do not copy family constants
into this repository. Workdir admission remains the scheduler API's
`internal/api/lane_onboarding.go`; compare it and live peers during an audit.
The checker has blind spots: its board-link check covers only four suffixes and
accepts a board directory even without a valid tasks file. This audit additionally
requires every enabled Code Factory lane's direct board to contain nonempty,
parseable task objects and resolve to the primary's board, not a duplicate copy.
It does not execute board writers or certify lane-specific dispatchable work.

## Supported invocation

Python 3.11+ (stdlib only) and the operator's trusted scheduler checkout are
required. Supply all paths explicitly; never rely on the checker's defaults:

```bash
python3 -B scripts/audit-lanes.py \
  --db "$HERMES_HOME/coding-hermes/scheduler.db" \
  --toml "$HERMES_HOME/fleet.toml" \
  --checker "$SCHEDULER_ROOT/ops/check-fleet-invariants.py" \
  --hermes-home "$HERMES_HOME" --project-root "$PROJECT_ROOT"
```

PROJECT_ROOT means the live `code-factory` project's registered workdir (possibly
an integration worktree), not necessarily the checkout running this command.
The census is `projects WHERE name LIKE 'code-factory%'`, including disabled
rows. The primary and at least one satellite must exist; zero matches cannot
pass. The DB is opened with `mode=ro` and `PRAGMA query_only`; the TOML and
checker must exist, parse and expose the expected contract. No API writes,
namespace/board creation, dispatch, policy apply or credential access occurs.
The supplied checker is executable trusted operator code: do not point this
option at untrusted downloaded content. It runs once with explicit DB, TOML,
primary board and skills root, and a bounded timeout; stderr and raw findings
are not forwarded into public output.

Exit 0: this bounded census found no scoped drift. Exit 1: scoped checker or
local board/configuration drift. Exit 2: missing/bad input, empty census,
unsupported checker contract, failed checker execution or malformed result.
Unrelated fleet violations are counted separately and do not become Code
Factory failures; the actual checker exit remains visible. A primary exception
is reported unchanged, never silently allowlisted by this tool.

Output is a JSON safe-field projection: lane identifiers, normalized paths,
boolean facts, prompt lengths (never prompt text), pacing fields and issue
codes. Unknown paths/identifiers are replaced with explicit redaction markers;
null pin/family values carry reasons. Checker findings expose class and scoped
subject only, never arbitrary diagnostic text. For exact diagnostics run the
checker separately into private scratch, then manually redact only Code Factory
findings for the public report. Missing TOML project blocks are reported rather
than interpreted as matching DB values. This is a seed-presence/parity test,
not a claim that every scheduler release re-pins all fields at restart.

## API and policy reconciliation boundary

Read back each exact lane with `GET /api/v1/projects/<name>` and unwrap its
`project` object. Compare explicit fields with the DB; do not treat absent fields
as equality. Inspect `GET /api/v1/config` only through selected safe fields and
`GET /api/v1/status`'s `config_drift.path` to identify the loaded TOML. Never
commit full responses, prompt text, delivery identifiers or gateway fields.

Scheduler source at the audited revision describes DB authority / seed-only
loading (SCHED-GAP-219), while the deployed policy generator can still perform a
fleet-wide TOML regeneration. A raw project PUT is not a Code-Factory-scoped
family-policy transaction with a validated durable TOML diff and reversal.
Under CF-022's original acceptance, do not substitute partial DB writes or
hand-edited generated TOML. If no supported scoped durable policy operation is
available, leave live alignment blocked and request a scheduler-owner decision.
`fleet-cooldown-policy.py --dry-run` is observation only; a zero exit does not
prove that its proposals satisfy the checker's family matrix. Never run its
fleet-wide `--apply` for this task.

## Board writer and target boundary

The primary owns `$PROJECT_ROOT/.coding-hermes/board/tasks.jsonl` and its events.
Satellites may read links to that same board; do not create per-lane copies.
All lane records' declared `parent` and suffix-derived target must be reviewed:
`code-factory-docs-qa` strips to `code-factory-docs`, even when its org parent is
`code-factory`. Neither fact alone proves the prompt's intended target.
A link proves resolution, not authorization. PM/QA/dogfood/support findings must
use the primary's `scripts/boardctl` boundary, unique IDs, validated criteria and
foreman review. This document does not authorize this worker to write board
state or claim a lane-specific backlog is dispatchable. No force-dispatch until
target, procedure, writer ownership and dispatchable work are verified.

## Sync orientation and consumption

Intended project memory namespace: `code-factory` (not scheduler namespace
`duckbrain-sync`). The repository audit is consumed by reading
`docs/audits/code-factory-CF-022-140811.md` and its safe JSON snapshot, or rerunning
the command above. This is a local configuration-evidence contract, not proof
that a DuckBrain memory or `/sync/` marker exists or is fresh.

A sync consumer must separately retrieve the namespace's actual contract/marker,
verify timestamp, source revision and read-back content, and retain explicit
UNKNOWN for missing records. `/project/code-factory/status` is a proposed
consumer lookup in the trace contract, not a record written by this worker.
Do not infer successful synchronization from lane enablement or local files.

The live sync workdir still needs a nonempty README naming namespace
`code-factory` and pointing to a real consumption contract (this document can be
that contract once provisioned by its owner). Resolve the owning tracked source
and its writer first. An ancestor Git repository does not make an untracked
sync shell a Code Factory-owned deployment target. CF-022 must not write a README
into an unresolved home-repository boundary or fabricate a companion skill to
silence `sync-orientation`.

## Regression controls

`python3 -B tests/lane-contract.py` runs hermetic synthetic DB/TOML/checker
fixtures. Positive and negative controls must exercise the CLI: missing input,
malformed input, zero matches, drift, dangling/duplicate/malformed boards,
absent TOML pins, checker failures and safe-field redaction. `tests/selftest.sh`
runs this suite serially alongside the existing local fixtures. Synthetic
checker results test adapter plumbing only; the public audit records the
separate real live checker invocation and its nonzero exit.
