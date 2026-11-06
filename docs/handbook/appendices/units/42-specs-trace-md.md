# 42. specs/TRACE.md

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/specs/TRACE.md` |
| Repository | `code-factory` |
| Revision | `6eea792` |
| Status | **RED — the ladder is specified; four of its seven hops are broken today** |

## 1. Purpose and why it matters

A board row is not a run. `CF-212` can be dispatched on Monday, fail, be re-dispatched Tuesday and
succeed — and today nothing distinguishes the two attempts, because the row id is the only identity in
play. This page defines the missing one: a `run_id` minted by the scheduler per attempt, carried
through crier, the Hermes session, the node, the commit and the board event.

What breaks if it is ABSENT: every retrospective is a guess, a failure cannot be attributed to an
attempt, and a commit that breaks main cannot be traced to the dispatch that produced it. What breaks
if it LIES: two attempts sharing one id is worse than none, because a merge then looks like a retry.

The envelope already defines its own join key (`specs/ENVELOPE.md:12`) and the round-trip probe already
measured the break (`specs/TRACE.md:71`): five unacked replies carried `in_reply_to` and none carried
`corr_id`. This page turns that into a contract with a parent id.

## 2. Dependencies and library contracts

**Scheduler** — mints `run_id` as UUIDv7 per dispatch attempt (`specs/TRACE.md:42`). It is the only
component that can, because it is the only one that knows an attempt started.

**Crier** — must accept and echo `run_id` alongside `corr_id`, and a reply must carry both. Today a
reply carries `in_reply_to` only (`specs/TRACE.md:71`), which is why five replies could not be
correlated to a tick.

**Hermes session** — the session id exists; the link to `run_id` must be recorded at session open,
because the session is what proves which model actually served the work (a label is not a lane).

**Node / `CF_RUN_ID`** — the variable the node echoes into every record
(`specs/HARNESS-MATRIX.md:127`), and the join into `specs/FLEET-MEMORY.md:28` (R1) and `:38` (R2).

**Board** — a row's history must name the `run_id` that changed it, or a status change has no cause.

**Git** — a commit trailer `Run-Id: <run_id>` (`specs/TRACE.md:64`), so an artifact can be traced
without a database.

## 3. Verification

The spec's acceptance list is `specs/TRACE.md:90` (six statements). Against today's tree they are all
red, and each fails for a different reason:

| statement | today | how it is proven |
|---|---|---|
| two dispatches of one row yield two distinct `run_id`s | **RED — no `run_id` exists** | dispatch twice, compare |
| a reply carries `in_reply_to`, `corr_id` and `run_id`, and is refused otherwise | **RED — replies carry one of the three** | send a reply missing `corr_id` |
| a session is findable from its `run_id` | **RED — sessions are never told** | open a session, query by run |
| a commit carries `Run-Id:` and `git log --grep` finds it | **RED — no trailer is written** | commit on a node, grep |
| a refused dispatch still has a `run_id` and a FAIL record | **RED — nothing is minted before delivery** | reject at crier, then look up |
| killing a node after the envelope leaves a findable, result-less run | **RED — there is nothing to look up** | kill mid-flight |

Every row being red is the correct state for a design page, and the reason this module is RED rather
than VERIFIED.

## 4. Metrics emitted

None of its own. The measurements this page enables are counts over `run_id`: attempts per completed
row, failure rate by hop, and time from dispatch to result. Those are computed by querying the records,
not emitted by this spec — and the number that matters most, *attempts per completed row*, is
uncomputable today because attempts are not distinguishable.

## 5. Log lines it can generate

No code path implements this yet. When it does, the two lines that matter most are the ones that
separate a redelivery from a new attempt:

```
  PASS  dispatch — run <run_id> attempt 2 for CF-212 (corr <corr_id>) to crier
  WARN  dispatch — run <run_id> is a REDELIVERY of <prior_run_id>; not a new attempt
```

Without the second line, a redelivered envelope looks exactly like an operator retry, and the fleet's
attempt counts inflate silently.

## 6. Failure modes

| failure | direction | consequence |
|---|---|---|
| `run_id` minted but not carried past crier | **fail open** | the run is traceable to the transport, not to the work |
| a redelivery minted a fresh `run_id` | **fail open** | one dispatch counted as two attempts; fleet metrics inflate |
| a session opened without its `run_id` | **fail open** | the model that served the run cannot be attributed |
| reply accepted without `corr_id` (today) | **fail open** | uncorrelated replies accumulate; five were measured stuck |
| a commit with no trailer | **silent** | reverting a bad commit cannot name the run that made it |
| `run_id` used as the board row id | **fail closed but wrong** | the row would fork per attempt; the board assumes stable ids |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| `run_id` | scheduler | required on every envelope; UUIDv7 |
| `corr_id` | scheduler (existing) | required; kept as the reply key |
| `idempotency_key` | scheduler | required; a redelivery must resolve to the SAME `run_id` |
| `CF_RUN_ID` | envelope → node | required; echoed into every node record |
| board row id | `boardctl` | required in the envelope; never used as a run identity |
| `Run-Id` trailer | node's commit path | required |

## 8. Evidence of record

- `specs/TRACE.md` (112 lines) — the design authority; its §4 is the measured break register.
- `specs/ENVELOPE.md:12` — the existing `corr_id` shape (`lane-<ts>-<seq>`, not a UUID).
- `docs/master/37-specs-envelope-md.md` — the envelope module, RED, which already records that the
  spec matches neither implementation (CF-216).
- `/home/kara/code-factory-reports/crier-scheduler-roundtrip-2026-11-05.md:258` — five unacked replies,
  `in_reply_to` present, `corr_id` absent.
- `specs/HARNESS-MATRIX.md:127` — `CF_RUN_ID` as a required node variable.
- Board: CF-253 (stalled vs hung), CF-276 (worker not staged), CF-208 (namespace scoping).

To re-establish this page's status: run the six statements in `specs/TRACE.md:90` against a live
dispatch; when they pass, this module can earn VERIFIED.
